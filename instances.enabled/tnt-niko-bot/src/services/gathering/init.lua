--- Доменный сервис добычи: денежные потоки инвентаря (продажа и далее покупка/крафт).
--
-- Продажа меняет инвентарь и баланс атомарно (sql.atomic): читаем тюпл инвентаря
-- и правим баланс в одной транзакции - чинит race «проверка/обновление» старого бота.
--
local log = require('log')
local sql = require('bot.libs.sql')
local lcg = require('src.utils.lcg')
local config = require('conf.config')
local items = require('src.gathering.items')
local loot = require('src.gathering.loot')
local recipes = require('src.gathering.recipes')
local quests = require('src.gathering.quests')
local activities = require('src.gathering.activities')
local usersService = require('src.services.users')
local userGameStatsService = require('src.services.user_game_stats')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')

local service = {}

--- Map -> копия как обычная Lua-таблица (для правки внутри транзакции).
local function copyMap(map)
  local copy = {}
  for key, value in pairs(map or {}) do
    copy[key] = value
  end
  return copy
end

--- Навыки добычи хранятся в user_game_stats.stats.gathering[activity] = { xp, level }.
-- Уровень гейтит редкий лут (min_level) и слегка повышает улов.

--- Прокачка навыка по накопленному xp. Меняет skill на месте.
-- Порог следующего уровня = level_base * level.
-- @param skill (table) { xp, level }
-- @return boolean был ли подъём уровня
local function applyLevelUps(skill)
  local leveledUp = false

  while true do
    local need = config.gathering.level_base * skill.level
    if skill.xp < need then
      break
    end
    skill.xp = skill.xp - need
    skill.level = skill.level + 1
    leveledUp = true
  end

  return leveledUp
end

--- Все навыки добычи игрока: { fishing = { xp, level }, ... } с дефолтами.
-- @param user_id (number)
-- @return[1] table
-- @return[2] err
function service.skills(user_id)
  local stats, err = userGameStatsService.read(user_id)
  if err then
    return nil, err
  end

  local stored = stats and stats.stats and stats.stats.gathering or {}

  local result = {}
  for _, key in ipairs(activities.order) do
    local skill = stored[key]
    result[key] = {
      xp = (skill and skill.xp) or 0,
      level = (skill and skill.level) or 1,
    }
  end

  return result, nil
end

--- Уровень навыка в активности (для гейта лута). Ошибку трактуем как базовый.
-- @param user_id (number)
-- @param activityKey (string)
-- @return number
function service.skillLevel(user_id, activityKey)
  local stats, err = userGameStatsService.read(user_id)
  if err or stats == nil then
    return 1
  end

  local stored = stats.stats and stats.stats.gathering
  local skill = stored and stored[activityKey]

  return (skill and skill.level) or 1
end

--- Начисление XP навыка за сбор (с возможным подъёмом уровня).
-- @param user_id (number)
-- @param activityKey (string)
-- @param amount (number)
-- @return[1] table { level, leveledUp, gained }
-- @return[2] err
function service.addSkillXp(user_id, activityKey, amount)
  local stats, err = userGameStatsService.read(user_id)
  if err then
    return nil, err
  end

  local data = (stats and stats.stats) or {}
  data.gathering = data.gathering or {}

  local skill = data.gathering[activityKey] or { xp = 0, level = 1 }
  skill.xp = (skill.xp or 0) + amount

  local leveledUp = applyLevelUps(skill)
  data.gathering[activityKey] = skill

  local _, upErr = userGameStatsService.upsert({ user_id = user_id, stats = data })
  if upErr then
    return nil, upErr
  end

  return { level = skill.level, leveledUp = leveledUp, gained = amount }, nil
end

--- Контракты хранятся в user_game_stats.stats.quests = { reset_at, progress, claimed }.
-- Сброс раз в сутки (как /bonus): прогресс и отметки «забрано» обнуляются.

--- Сброс контрактов, если прошёл кулдаун. Меняет qd на месте.
-- @param qd (table|nil) сохранённое состояние контрактов
-- @return[1] table qd с гарантированными полями
-- @return[2] boolean был ли сброс
local function freshQuests(qd)
  qd = qd or {}
  local now = os.time()
  local reset = false

  if qd.reset_at == nil or (now - qd.reset_at) >= config.gathering.quests.cooldown then
    qd.reset_at = now
    qd.progress = {}
    qd.claimed = {}
    reset = true
  end

  qd.progress = qd.progress or {}
  qd.claimed = qd.claimed or {}

  return qd, reset
end

--- Прибавка к прогрессу одного контракта от собранного лута.
local function questIncrement(def, activityKey, loot)
  local inc = 0

  if def.goal.kind == 'item' then
    for _, drop in ipairs(loot) do
      if drop.id == def.goal.item then
        inc = inc + drop.count
      end
    end
  elseif def.goal.kind == 'activity' and def.goal.activity == activityKey then
    for _, drop in ipairs(loot) do
      inc = inc + drop.count
    end
  end

  return inc
end

--- Общий аккумулятор прогресса контрактов: для каждого спросить inc, прибавить
-- положительные. Отдельная запись stats (best-effort, вне основной транзакции).
-- @param user_id (number)
-- @param incFor (function) def -> number прибавки к этому контракту
-- @return[1] true
-- @return[2] err
local function bumpQuests(user_id, incFor)
  local stats, err = userGameStatsService.read(user_id)
  if err then
    return nil, err
  end

  local data = (stats and stats.stats) or {}
  local qd = freshQuests(data.quests)

  for _, def in ipairs(quests) do
    local inc = incFor(def)
    if inc > 0 then
      qd.progress[def.id] = (qd.progress[def.id] or 0) + inc
    end
  end

  data.quests = qd

  local _, upErr = userGameStatsService.upsert({ user_id = user_id, stats = data })
  if upErr then
    return nil, upErr
  end

  return true, nil
end

--- Учёт прогресса контрактов после сбора лута (best-effort).
-- @param user_id (number)
-- @param activityKey (string)
-- @param loot (array) { { id, count } }
function service.addQuestProgress(user_id, activityKey, loot)
  return bumpQuests(user_id, function(def)
    return questIncrement(def, activityKey, loot)
  end)
end

--- Учёт прогресса крафт-контрактов после успешного крафта (best-effort).
-- @param user_id (number)
-- @param outputId (string) id скрафченного предмета
-- @param count (number) сколько произведено
function service.addCraftProgress(user_id, outputId, count)
  return bumpQuests(user_id, function(def)
    if def.goal.kind == 'craft' and def.goal.item == outputId then
      return count
    end
    return 0
  end)
end

--- Учёт прогресса фермерских контрактов после сбора урожая (best-effort).
-- 'farm' - любой урожай, 'harvest' - конкретная культура goal.item.
-- @param user_id (number)
-- @param productId (string) id собранного продукта
-- @param count (number)
function service.addFarmProgress(user_id, productId, count)
  return bumpQuests(user_id, function(def)
    if def.goal.kind == 'farm' then
      return count
    elseif def.goal.kind == 'harvest' and def.goal.item == productId then
      return count
    end
    return 0
  end)
end

--- Состояние контрактов игрока (с ленивым суточным сбросом).
-- @param user_id (number)
-- @return[1] table { next_reset, list = { { def, progress, claimed, complete } } }
-- @return[2] err
function service.questState(user_id)
  local stats, err = userGameStatsService.read(user_id)
  if err then
    return nil, err
  end

  local data = (stats and stats.stats) or {}
  local qd, reset = freshQuests(data.quests)

  -- Сброс произошёл при чтении - зафиксируем.
  if reset then
    data.quests = qd
    local _, upErr = userGameStatsService.upsert({ user_id = user_id, stats = data })
    if upErr then
      return nil, upErr
    end
  end

  local list = {}
  for _, def in ipairs(quests) do
    local progress = qd.progress[def.id] or 0
    table.insert(list, {
      def = def,
      progress = progress,
      claimed = qd.claimed[def.id] == true,
      complete = progress >= def.goal.count,
    })
  end

  return { next_reset = qd.reset_at + config.gathering.quests.cooldown, list = list }, nil
end

--- Забрать награду за выполненный контракт. Атомарно: отметка «забрано» + награда.
-- @param user_id (number)
-- @param questId (string)
-- @return[1] table { status = 'ok'|'incomplete'|'claimed'|'unavailable', reward }
-- @return[2] err
function service.claimQuest(user_id, questId)
  local def
  for _, quest in ipairs(quests) do
    if quest.id == questId then
      def = quest
      break
    end
  end

  if def == nil then
    return { status = 'unavailable' }, nil
  end

  local result = { status = 'ok' }

  local _, err = sql.atomic(function()
    local row = box.space.user_game_stats:get(user_id)
    local statsMap = row and copyMap(row.stats) or {}
    local qd = freshQuests(statsMap.quests)

    if qd.claimed[questId] then
      result.status = 'claimed'
      return
    end

    if (qd.progress[questId] or 0) < def.goal.count then
      result.status = 'incomplete'
      return
    end

    qd.claimed[questId] = true
    statsMap.quests = qd

    statsMap = setmetatable(statsMap, { __serialize = 'map' })
    box.space.user_game_stats:upsert(
      { user_id, statsMap },
      { { '=', 'stats', statsMap } })

    if def.reward.money then
      sql.check(sql([[ UPDATE users SET balance = balance + ${m} WHERE id = ${id} ]],
        { m = def.reward.money, id = user_id }))
    end
    if def.reward.crystals then
      sql.check(sql([[ UPDATE users SET crystals = crystals + ${c} WHERE id = ${id} ]],
        { c = def.reward.crystals, id = user_id }))
    end

    result.reward = def.reward
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return result, nil
end

--- Детерминированный ролл лута по сиду (одинаков для ручного и авто-сбора).
-- @param activityKey (string)
-- @param level (number) уровень навыка - открывает редкости (min_level)
-- @param seed (number)
-- @return table { list = { { id, count } }, jackpot = id|nil }
local function rollLoot(activityKey, level, seed)
  local lootTable = loot[activityKey]
  local cfg = config.gathering[activityKey]
  local rnd = lcg(seed)

  -- Базовый улов: yield_min..yield_max штук случайных предметов из base-пула.
  -- Уровень навыка слегка повышает потолок улова (+1 за каждые 3 уровня).
  local aggregate = {}
  local maxYield = cfg.yield_max + math.floor((level - 1) / 3)
  local total = rnd.range(cfg.yield_min, maxYield)
  for _ = 1, total do
    local id = lootTable.base[rnd.range(1, #lootTable.base)]
    aggregate[id] = (aggregate[id] or 0) + 1
  end

  -- Редкий дроп: шанс 1 из rare_odds, выбор по весу среди открытых по уровню.
  local jackpot
  if rnd.range(1, cfg.rare_odds) == 1 then
    local eligible = {}
    local totalWeight = 0
    for _, drop in ipairs(lootTable.rare) do
      if drop.min_level <= level then
        totalWeight = totalWeight + drop.weight
        table.insert(eligible, drop)
      end
    end

    if totalWeight > 0 then
      local pick = rnd.range(1, totalWeight)
      local acc = 0
      for _, drop in ipairs(eligible) do
        acc = acc + drop.weight
        if pick <= acc then
          aggregate[drop.id] = (aggregate[drop.id] or 0) + 1
          if drop.jackpot then
            jackpot = drop.id
          end
          break
        end
      end
    end
  end

  local list = {}
  for id, count in pairs(aggregate) do
    table.insert(list, { id = id, count = count })
  end

  return { list = list, jackpot = jackpot }
end

--- Продажа всех ресурсов из инвентаря (расходники/инструменты не трогаем).
-- @param user_id (number)
-- @return[1] table { total, lines = { { id, count, sum } } }
-- @return[2] err
function service.sellAll(user_id)
  local result = { total = 0, lines = {} }

  local _, err = sql.atomic(function()
    local inv = box.space.user_inventory:get(user_id)
    if inv == nil then
      return
    end

    local remaining = copyMap(inv.items)
    local total = 0

    for id, count in pairs(remaining) do
      if items.isSellable(id) and count > 0 then
        local sum = items.sell(id) * count
        total = total + sum
        table.insert(result.lines, { id = id, count = count, sum = sum })
        remaining[id] = nil
      end
    end

    if total == 0 then
      return
    end

    box.space.user_inventory:update(user_id, {
      { '=', 'items', setmetatable(remaining, { __serialize = 'map' }) },
    })

    sql.check(sql([[
      UPDATE users SET balance = balance + ${total} WHERE id = ${user_id}
    ]], { total = total, user_id = user_id }))

    result.total = total
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return result, nil
end

--- Продажа одного ресурса. count = nil -> весь стак.
-- @param user_id (number)
-- @param id (string) предмет
-- @param count (number|nil) сколько продать (по умолчанию весь стак)
-- @return[1] table { id, sold, total }
-- @return[2] err
function service.sellItem(user_id, id, count)
  local result = { id = id, sold = 0, total = 0 }

  if not items.isSellable(id) then
    return result, nil
  end

  local _, err = sql.atomic(function()
    local inv = box.space.user_inventory:get(user_id)
    if inv == nil then
      return
    end

    local remaining = copyMap(inv.items)
    local have = remaining[id] or 0
    if have <= 0 then
      return
    end

    local sold = have
    if count ~= nil and count < have then
      sold = count
    end

    local total = items.sell(id) * sold

    remaining[id] = have - sold
    if remaining[id] <= 0 then
      remaining[id] = nil
    end

    box.space.user_inventory:update(user_id, {
      { '=', 'items', setmetatable(remaining, { __serialize = 'map' }) },
    })

    sql.check(sql([[
      UPDATE users SET balance = balance + ${total} WHERE id = ${user_id}
    ]], { total = total, user_id = user_id }))

    result.sold = sold
    result.total = total
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return result, nil
end

--- Покупка предмета (инструмент или расходник) за balance/crystals.
-- Атомарно: списание валюты + выдача в инвентарь.
-- Инструмент покупается по одному на тип - покупка обновляет прочность до полной.
-- @param user_id (number)
-- @param itemId (string)
-- @return[1] table { status = 'ok' | 'funds' | 'unavailable', currency, price, kind }
-- @return[2] err
function service.buy(user_id, itemId)
  local def = items.get(itemId)
  if def == nil or def.buy == nil or not (def.kind == 'tool' or def.kind == 'consumable') then
    return { status = 'unavailable' }, nil
  end

  local price = def.buy
  local currency = def.currency or 'money'

  -- Предпроверка средств - для понятного сообщения (целостность всё равно
  -- держит unsigned-списание внутри транзакции).
  local user, readErr = usersService.read(user_id)
  if readErr then
    return nil, readErr
  end
  if user == nil then
    return { status = 'unavailable' }, nil
  end

  local funds = (currency == 'crystals') and user.crystals or user.balance
  if funds < price then
    return { status = 'funds', currency = currency, price = price }, nil
  end

  local _, err = sql.atomic(function()
    -- Списание валюты. balance/crystals unsigned: не хватит -> UPDATE падает, откат.
    if currency == 'crystals' then
      sql.check(sql([[
        UPDATE users SET crystals = crystals - ${price} WHERE id = ${user_id}
      ]], { price = price, user_id = user_id }))
    else
      sql.check(sql([[
        UPDATE users SET balance = balance - ${price} WHERE id = ${user_id}
      ]], { price = price, user_id = user_id }))
    end

    -- Выдача в инвентарь (создаёт запись, если её ещё нет).
    local inv = box.space.user_inventory:get(user_id)
    local itemsMap = inv and copyMap(inv.items) or {}
    local toolsMap = inv and copyMap(inv.tools) or {}

    if def.kind == 'tool' then
      toolsMap[itemId] = def.durability
    else
      itemsMap[itemId] = (itemsMap[itemId] or 0) + (def.buy_count or 1)
    end

    itemsMap = setmetatable(itemsMap, { __serialize = 'map' })
    toolsMap = setmetatable(toolsMap, { __serialize = 'map' })

    box.space.user_inventory:upsert(
      { user_id, itemsMap, toolsMap },
      {
        { '=', 'items', itemsMap },
        { '=', 'tools', toolsMap },
      })
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return { status = 'ok', kind = def.kind, currency = currency, price = price }, nil
end

--- Рецепт по id (или nil).
local function findRecipe(recipeId)
  for _, recipe in ipairs(recipes) do
    if recipe.id == recipeId then
      return recipe
    end
  end
  return nil
end

--- Крафт: списать входы, выдать выход. Атомарно (без частичных списаний).
-- @param user_id (number)
-- @param recipeId (string)
-- @return[1] table { status = 'ok'|'missing'|'unavailable', recipe }
-- @return[2] err
function service.craft(user_id, recipeId)
  local recipe = findRecipe(recipeId)
  if recipe == nil then
    return { status = 'unavailable' }, nil
  end

  local result = { status = 'ok', recipe = recipeId }

  local _, err = sql.atomic(function()
    local inv = box.space.user_inventory:get(user_id)
    local itemsMap = inv and copyMap(inv.items) or {}

    -- Хватает ли всех входов.
    for _, input in ipairs(recipe.inputs) do
      if (itemsMap[input.id] or 0) < input.count then
        result.status = 'missing'
        return
      end
    end

    -- Списать входы.
    for _, input in ipairs(recipe.inputs) do
      itemsMap[input.id] = itemsMap[input.id] - input.count
      if itemsMap[input.id] <= 0 then
        itemsMap[input.id] = nil
      end
    end

    -- Выдать выход.
    itemsMap[recipe.output.id] = (itemsMap[recipe.output.id] or 0) + recipe.output.count

    itemsMap = setmetatable(itemsMap, { __serialize = 'map' })
    box.space.user_inventory:update(user_id, { { '=', 'items', itemsMap } })
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  -- Прогресс крафт-контрактов (best-effort, не валит крафт).
  if result.status == 'ok' then
    local _, questErr = service.addCraftProgress(user_id, recipe.output.id, recipe.output.count)
    if questErr then
      log.error(questErr)
    end
  end

  return result, nil
end

--- Старт задачи добычи. Атомарно: проверка «нет активной задачи», выбор лучшего
-- инструмента, трата прикормки (если есть), создание записи задачи.
-- message_id ставится позже (после отправки сообщения) через user_activity.setMessage.
-- @param user_id (number)
-- @param activityKey (string)
-- @param chat_id (number)
-- @param isVip (boolean)
-- @return[1] table { status = 'ok'|'busy'|'no_tool', tool_id, until_date, bait_used }
-- @return[2] err
function service.begin(user_id, activityKey, chat_id, isVip)
  local activity = activities[activityKey]
  local cfg = config.gathering[activityKey]
  local result = {}

  local _, err = sql.atomic(function()
    if box.space.user_activity:get(user_id) ~= nil then
      result.status = 'busy'
      return
    end

    local inv = box.space.user_inventory:get(user_id)
    local toolsMap = inv and copyMap(inv.tools) or {}
    local itemsMap = inv and copyMap(inv.items) or {}

    -- Лучший инструмент из имеющихся (activity.tools идут по возрастанию класса).
    local toolId
    for _, id in ipairs(activity.tools) do
      if (toolsMap[id] or 0) > 0 then
        toolId = id
      end
    end

    if toolId == nil then
      result.status = 'no_tool'
      return
    end

    -- Рюкзак полон (считаем только ресурсы) -> начать нельзя, надо продать.
    if items.resourceWeight(itemsMap) >= config.gathering.capacity then
      result.status = 'full'
      return
    end

    -- Длительность с сокращениями (прикормка, VIP) и нижним пределом.
    local duration = cfg.time or math.random(cfg.time_min, cfg.time_max)
    local baitUsed = false

    if activity.bait and (itemsMap[activity.bait] or 0) > 0 then
      duration = duration - cfg.bait_reduce
      itemsMap[activity.bait] = itemsMap[activity.bait] - 1
      if itemsMap[activity.bait] <= 0 then
        itemsMap[activity.bait] = nil
      end
      baitUsed = true
    end

    if isVip then
      duration = duration - cfg.vip_reduce
    end

    if duration < config.gathering.min_time then
      duration = config.gathering.min_time
    end

    -- Трата прикормки - запись инвентаря (только если использована).
    if baitUsed then
      box.space.user_inventory:update(user_id, {
        { '=', 'items', setmetatable(itemsMap, { __serialize = 'map' }) },
      })
    end

    local untilDate = os.time() + duration
    local seed = math.random(1, 2147483647)

    -- Порядок полей = схема user_activity; message_id ставим позже.
    box.space.user_activity:insert({ user_id, activityKey, toolId, untilDate, chat_id, 0, seed })

    result.status = 'ok'
    result.tool_id = toolId
    result.until_date = untilDate
    result.bait_used = baitUsed
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return result, nil
end

--- Сбор задачи: выдать лут, износить инструмент, удалить задачу. Атомарно.
-- Используется и ручным /collect, и TTL-джобой; благодаря сиду лут одинаков,
-- а транзакция гарантирует, что начисление произойдёт ровно один раз.
-- @param user_id (number)
-- @return[1] table { status = 'done'|'none'|'not_ready', remaining, activity, loot, jackpot, tool_id, tool_broken, tool_left }
-- @return[2] err
function service.collect(user_id)
  -- Предпросмотр вне транзакции: уровень навыка может читать БД (Фаза 4),
  -- держим возможный yield вне atomic.
  local pre = box.space.user_activity:get(user_id)
  if pre == nil then
    return { status = 'none' }, nil
  end

  local now = os.time()
  if pre.until_date > now then
    return { status = 'not_ready', remaining = pre.until_date - now, activity = pre.activity }, nil
  end

  local level = service.skillLevel(user_id, pre.activity)
  local rolled = rollLoot(pre.activity, level, pre.seed)

  local result = { status = 'done', activity = pre.activity }

  local _, err = sql.atomic(function()
    local act = box.space.user_activity:get(user_id)

    -- Забрали параллельно (ручной сбор vs джоба) - ничего не начисляем.
    if act == nil then
      result.status = 'none'
      return
    end

    if act.until_date > os.time() then
      result.status = 'not_ready'
      result.remaining = act.until_date - os.time()
      return
    end

    local inv = box.space.user_inventory:get(user_id)
    local itemsMap = inv and copyMap(inv.items) or {}
    local toolsMap = inv and copyMap(inv.tools) or {}

    for _, drop in ipairs(rolled.list) do
      itemsMap[drop.id] = (itemsMap[drop.id] or 0) + drop.count
    end

    -- Износ инструмента на финише.
    local toolLeft = (toolsMap[act.tool_id] or 0) - 1
    local broken = toolLeft <= 0
    if broken then
      toolsMap[act.tool_id] = nil
    else
      toolsMap[act.tool_id] = toolLeft
    end

    itemsMap = setmetatable(itemsMap, { __serialize = 'map' })
    toolsMap = setmetatable(toolsMap, { __serialize = 'map' })

    box.space.user_inventory:upsert(
      { user_id, itemsMap, toolsMap },
      {
        { '=', 'items', itemsMap },
        { '=', 'tools', toolsMap },
      })

    box.space.user_activity:delete(user_id)

    result.tool_id = act.tool_id
    result.tool_broken = broken
    result.tool_left = broken and 0 or toolLeft
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if result.status ~= 'done' then
    return result, nil
  end

  result.loot = rolled.list
  result.jackpot = rolled.jackpot

  -- Прокачка навыка за сбор (вне транзакции; для лута уже использован уровень
  -- ДО начисления, так что новый xp влияет на следующий сбор).
  local skillRes, skillErr = service.addSkillXp(user_id, pre.activity, config.gathering.xp_per_gather)
  if skillErr then
    log.error(skillErr)
  else
    result.skill = skillRes
  end

  -- Прогресс контрактов (best-effort, не валит сбор).
  local _, questErr = service.addQuestProgress(user_id, pre.activity, rolled.list)
  if questErr then
    log.error(questErr)
  end

  return result, nil
end

return service
