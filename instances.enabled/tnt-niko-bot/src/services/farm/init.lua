--- Доменный сервис фермы: посадка и сбор урожая на грядках.
--[[
-- Грядки в спейсе user_farm.plots (слот -> { crop, ready_at }).
-- Рост ленивый: готовность определяется now >= ready_at, фоновой джобы нет.
-- Посадка тратит семя из инвентаря, сбор выдаёт продукт - всё атомарно (sql.atomic), чтобы
-- инвентарь и ферма не разъезжались. Покупка семян - через generic gathering.buy
-- (семя = consumable), здесь её нет.
--]]
local log = require('log')
local sql = require('bot.libs.sql')
local config = require('conf.config')
local items = require('src.gathering.items')
local crops = require('src.farm.crops')
local animals = require('src.farm.animals')
local usersService = require('src.services.users')
local gatheringService = require('src.services.gathering')

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

--- Число грядок по уровню фермы: база + одна за каждые slots_per_level уровней,
-- не выше max_slots.
local function slotCount(level)
  local extra = math.floor((level - 1) / config.farm.slots_per_level)
  return math.min(config.farm.max_slots, config.farm.slots + extra)
end

--- Состояние фермы игрока: грядки с готовностью + сводка.
-- @param user_id (number)
-- @return[1] table { slots = { { index, empty } | { index, crop, ready_at, ready } }, total, free }
-- @return[2] err
function service.state(user_id)
  local row = box.space.user_farm:get(user_id)
  local plots = row and copyMap(row.plots) or {}
  local level = gatheringService.skillLevel(user_id, 'farm')
  local total = slotCount(level)
  local now = os.time()

  local slots = {}
  local free = 0

  for index = 1, total do
    local plot = plots[tostring(index)]
    if plot == nil then
      slots[#slots + 1] = { index = index, empty = true }
      free = free + 1
    else
      slots[#slots + 1] = {
        index = index,
        crop = plot.crop,
        ready_at = plot.ready_at,
        ready = now >= plot.ready_at,
      }
    end
  end

  return { slots = slots, total = total, free = free, level = level }, nil
end

--- Посадить культуру в первый свободный слот. Списывает семя из инвентаря.
-- @param user_id (number)
-- @param cropId (string)
-- @return[1] table { status = 'ok'|'unknown'|'no_seed'|'no_slot', crop, ready_at }
-- @return[2] err
function service.plant(user_id, cropId)
  local crop = crops.get(cropId)
  if crop == nil then
    return { status = 'unknown' }, nil
  end

  -- Гейт по уровню фермы: культура должна быть открыта.
  local level = gatheringService.skillLevel(user_id, 'farm')
  if level < (crop.min_level or 1) then
    return { status = 'locked', min_level = crop.min_level or 1 }, nil
  end

  local result = { status = 'ok', crop = cropId }

  local _, err = sql.atomic(function()
    local farmRow = box.space.user_farm:get(user_id)
    local plots = farmRow and copyMap(farmRow.plots) or {}
    local animals = farmRow and copyMap(farmRow.animals) or {}

    -- Первый свободный слот 1..total (число грядок зависит от уровня).
    local slot
    for index = 1, slotCount(level) do
      if plots[tostring(index)] == nil then
        slot = tostring(index)
        break
      end
    end

    if slot == nil then
      result.status = 'no_slot'
      return
    end

    -- Семя должно быть в инвентаре.
    local inv = box.space.user_inventory:get(user_id)
    local itemsMap = inv and copyMap(inv.items) or {}
    if (itemsMap[crop.seed] or 0) < 1 then
      result.status = 'no_seed'
      return
    end

    -- Списать семя.
    itemsMap[crop.seed] = itemsMap[crop.seed] - 1
    if itemsMap[crop.seed] <= 0 then
      itemsMap[crop.seed] = nil
    end

    -- Занять слот.
    local ready_at = os.time() + crop.grow
    plots[slot] = { crop = cropId, ready_at = ready_at }
    result.ready_at = ready_at

    -- Семя точно было -> запись инвентаря существует, update безопасен.
    itemsMap = setmetatable(itemsMap, { __serialize = 'map' })
    box.space.user_inventory:update(user_id, { { '=', 'items', itemsMap } })

    -- Ферма: upsert (строки может ещё не быть).
    plots = setmetatable(plots, { __serialize = 'map' })
    animals = setmetatable(animals, { __serialize = 'map' })
    box.space.user_farm:upsert(
      { user_id, plots, animals },
      { { '=', 'plots', plots } })
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return result, nil
end

--- Собрать урожай с готового слота. Освобождает слот, выдаёт продукт в инвентарь.
-- @param user_id (number)
-- @param slotIndex (number|string)
-- @return[1] table { status = 'ok'|'empty'|'not_ready'|'full', product, count }
-- @return[2] err
function service.collect(user_id, slotIndex)
  local slot = tostring(slotIndex)
  local result = { status = 'ok' }

  local _, err = sql.atomic(function()
    local farmRow = box.space.user_farm:get(user_id)
    local plots = farmRow and copyMap(farmRow.plots) or {}
    local plot = plots[slot]

    if plot == nil then
      result.status = 'empty'
      return
    end

    if os.time() < plot.ready_at then
      result.status = 'not_ready'
      return
    end

    local crop = crops.get(plot.crop)
    if crop == nil then
      -- Культура исчезла из реестра - просто освободим слот.
      plots[slot] = nil
      plots = setmetatable(plots, { __serialize = 'map' })
      box.space.user_farm:update(user_id, { { '=', 'plots', plots } })
      result.status = 'empty'
      return
    end

    -- Рюкзак полон (считаем только ресурсы) -> собрать нельзя, надо продать.
    local inv = box.space.user_inventory:get(user_id)
    local itemsMap = inv and copyMap(inv.items) or {}
    if items.resourceWeight(itemsMap) >= config.gathering.capacity then
      result.status = 'full'
      return
    end

    -- Урожай в инвентарь.
    local count = math.random(crop.yield_min, crop.yield_max)
    itemsMap[crop.product] = (itemsMap[crop.product] or 0) + count

    -- Освободить слот.
    plots[slot] = nil

    itemsMap = setmetatable(itemsMap, { __serialize = 'map' })
    box.space.user_inventory:upsert(
      { user_id, itemsMap, setmetatable({}, { __serialize = 'map' }) },
      { { '=', 'items', itemsMap } })

    plots = setmetatable(plots, { __serialize = 'map' })
    box.space.user_farm:update(user_id, { { '=', 'plots', plots } })

    result.product = crop.product
    result.count = count
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  -- Прокачка фермы и прогресс контрактов - вне транзакции, best-effort.
  if result.status == 'ok' then
    local _, xpErr = gatheringService.addSkillXp(user_id, 'farm', config.farm.xp_per_harvest)
    if xpErr then
      log.error(xpErr)
    end

    local _, questErr = gatheringService.addFarmProgress(user_id, result.product, result.count)
    if questErr then
      log.error(questErr)
    end
  end

  return result, nil
end

--- Состояние загона: для каждого животного - куплено/готов продукт/таймер/открыто.
-- @param user_id (number)
-- @return[1] table { list = { { def, owned, ready, ready_at, unlocked } }, level }
-- @return[2] err
function service.animalState(user_id)
  local row = box.space.user_farm:get(user_id)
  local owned = row and copyMap(row.animals) or {}
  local level = gatheringService.skillLevel(user_id, 'farm')
  local now = os.time()

  local list = {}
  for _, key in ipairs(animals.order) do
    local def = animals[key]
    local state = owned[key]
    list[#list + 1] = {
      def = def,
      owned = state ~= nil,
      ready = state ~= nil and (now - state.last_collect_at) >= def.produce_time,
      ready_at = state and (state.last_collect_at + def.produce_time),
      unlocked = level >= (def.min_level or 1),
    }
  end

  return { list = list, level = level }, nil
end

--- Купить животное в загон (одно каждого типа). Списывает баланс.
-- @param user_id (number)
-- @param animalId (string)
-- @return[1] table { status = 'ok'|'unknown'|'locked'|'funds'|'already'|'unavailable', price, min_level }
-- @return[2] err
function service.buyAnimal(user_id, animalId)
  local def = animals.get(animalId)
  if def == nil then
    return { status = 'unknown' }, nil
  end

  local level = gatheringService.skillLevel(user_id, 'farm')
  if level < (def.min_level or 1) then
    return { status = 'locked', min_level = def.min_level or 1 }, nil
  end

  -- Предпроверка средств - для понятного сообщения (целостность держит unsigned-списание).
  local user, readErr = usersService.read(user_id)
  if readErr then
    return nil, readErr
  end
  if user == nil then
    return { status = 'unavailable' }, nil
  end
  if user.balance < def.buy then
    return { status = 'funds', price = def.buy }, nil
  end

  local result = { status = 'ok' }

  local _, err = sql.atomic(function()
    local farmRow = box.space.user_farm:get(user_id)
    local plots = farmRow and copyMap(farmRow.plots) or {}
    local owned = farmRow and copyMap(farmRow.animals) or {}

    if owned[animalId] ~= nil then
      result.status = 'already'
      return
    end

    -- Списание (balance unsigned: не хватит -> UPDATE падает, откат).
    sql.check(sql([[ UPDATE users SET balance = balance - ${p} WHERE id = ${id} ]], { p = def.buy, id = user_id }))

    owned[animalId] = { last_collect_at = os.time() }

    plots = setmetatable(plots, { __serialize = 'map' })
    owned = setmetatable(owned, { __serialize = 'map' })
    box.space.user_farm:upsert(
      { user_id, plots, owned },
      { { '=', 'animals', owned } })
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return result, nil
end

--- Собрать продукт с готового животного. Сбрасывает таймер, выдаёт продукт.
-- @param user_id (number)
-- @param animalId (string)
-- @return[1] table { status = 'ok'|'unknown'|'none'|'not_ready'|'full', product, count }
-- @return[2] err
function service.collectAnimal(user_id, animalId)
  local def = animals.get(animalId)
  if def == nil then
    return { status = 'unknown' }, nil
  end

  local result = { status = 'ok' }

  local _, err = sql.atomic(function()
    local farmRow = box.space.user_farm:get(user_id)
    local owned = farmRow and copyMap(farmRow.animals) or {}
    local state = owned[animalId]

    if state == nil then
      result.status = 'none'
      return
    end

    if (os.time() - state.last_collect_at) < def.produce_time then
      result.status = 'not_ready'
      return
    end

    -- Рюкзак полон (считаем только ресурсы) -> собрать нельзя, надо продать.
    local inv = box.space.user_inventory:get(user_id)
    local itemsMap = inv and copyMap(inv.items) or {}
    if items.resourceWeight(itemsMap) >= config.gathering.capacity then
      result.status = 'full'
      return
    end

    -- Продукт в инвентарь.
    local count = math.random(def.yield_min, def.yield_max)
    itemsMap[def.product] = (itemsMap[def.product] or 0) + count

    -- Сброс таймера производства.
    owned[animalId] = { last_collect_at = os.time() }

    itemsMap = setmetatable(itemsMap, { __serialize = 'map' })
    box.space.user_inventory:upsert(
      { user_id, itemsMap, setmetatable({}, { __serialize = 'map' }) },
      { { '=', 'items', itemsMap } })

    owned = setmetatable(owned, { __serialize = 'map' })
    box.space.user_farm:update(user_id, { { '=', 'animals', owned } })

    result.product = def.product
    result.count = count
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  -- Прокачка фермы - вне транзакции, best-effort.
  if result.status == 'ok' then
    local _, xpErr = gatheringService.addSkillXp(user_id, 'farm', config.farm.xp_per_harvest)
    if xpErr then
      log.error(xpErr)
    end
  end

  return result, nil
end

return service
