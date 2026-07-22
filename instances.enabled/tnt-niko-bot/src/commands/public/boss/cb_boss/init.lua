--- Callback рейд-босса: удар.
--
-- MULTI_USER: кнопку жмёт любой участник чата, не только автор карточки.
-- Кулдаун/урон/добивание атомарны в applyHit - выплату делает ровно тот
-- вызов, чей удар получил статус KILLED.
--
local log = require('log')
local bot = require('bot')
local config = require('conf.config')
local Command = require('bot.classes.Command')
local bosses = require('src.dict.bosses')
local usersService = require('src.services.users')
local bossSessionsService = require('src.services.boss_sessions')
local damage = require('src.commands.public.boss.damage')
local render = require('src.commands.public.boss.render')
local separateNumbers = require('src.utils.separateNumbers')

local command = Command:new({
  commands = { 'cb_boss' },
  flags = { Command.enum.CALLBACK, Command.enum.MULTI_USER },
  arguments_schema = { 'action' },
})

local results = bossSessionsService.result

--- Перерисовка карточки на месте (правка исходного сообщения).
-- @tparam table ctx контекст обновления
-- @tparam table view { text, keyboard }
local function edit(ctx, view)
  bot:editMessageText({
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    text = view.text,
    reply_markup = view.keyboard,
  })
end

--- Раздача пула: каждому пропорционально урону, добившему - бонус и шанс
-- кристалла. XP от личной выплаты (как в минах). Ошибки начислений не
-- прерывают раздачу остальным.
local function payoutVictory(ctx, killer, bossInfo)
  local chatId = ctx:getChatId()

  local hits, hitsErr = bossSessionsService.listHits(chatId)
  if hitsErr then
    log.error(hitsErr)
    return
  end

  local totalDamage = 0
  for i = 1, #hits do
    local hit = hits[i]
    totalDamage = totalDamage + hit.damage
  end

  if totalDamage == 0 then
    totalDamage = 1
  end

  local pool = bossInfo.reward
  local killerBonus = math.floor(pool * config.boss.killer_bonus_pc / 100)

  local gotCrystal = false
  if bossInfo.crystal_odds and math.random(bossInfo.crystal_odds) == 1 then
    local _, crystalErr = usersService.addCrystals(killer.id, 1)

    if crystalErr then
      log.error(crystalErr)
    else
      gotCrystal = true
    end
  end

  local rewards = {}
  local killerReward = 0

  for i = 1, #hits do
    local hit = hits[i]
    local reward = math.floor(pool * hit.damage / totalDamage)

    if hit.user_id == killer.id then
      reward = reward + killerBonus
      killerReward = reward
    end

    local _, balErr = usersService.addBalance(hit.user_id, reward)
    if balErr then
      log.error(balErr)
    end

    local xp = math.max(config.boss.xp_min, math.floor(reward / config.boss.xp_per))
    local _, xpErr = usersService.addXP(hit.user_id, xp)
    if xpErr then
      log.error(xpErr)
    end

    table.insert(rewards, {
      name = hit.name,
      damage = hit.damage,
      reward = reward,
    })
  end

  local _, delErr = bossSessionsService.deleteHits(chatId)
  if delErr then
    log.error(delErr)
  end

  ctx:answer({
    text = ('🗡 Добил(а)! Твоя награда: %sр%s'):format(
      separateNumbers(killerReward),
      gotCrystal and ' + 💎' or ''),
    show_alert = true,
  })

  edit(ctx, render.victory(bossInfo, rewards, {
    name = killer.first_name,
    bonus = killerBonus,
    got_crystal = gotCrystal,
  }))
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  -- Аргументы в локали ДО первого yield: command - общий объект.
  local user = command.user
  local action = command.arguments.action

  if action ~= 'hit' then
    ctx:answer()
    return
  end

  local chatId = ctx:getChatId()

  -- Бой и каталог нужны и удару, и выплате.
  local session, readErr = bossSessionsService.getByChat(chatId)
  if readErr then
    log.error(readErr)
    ctx:answer()
    return
  end

  if session == nil or session.status ~= 'active' then
    ctx:answer({ text = '💨 Босс уже повержен или сбежал', show_alert = false })
    return
  end

  local bossInfo = bosses.byKey[session.boss_id]

  if not bossInfo then
    log.error({ message = 'boss not in catalog', boss_id = tostring(session.boss_id) })
    ctx:answer()
    return
  end

  local dmg, isCrit = damage.roll(user)

  local result, hitErr = bossSessionsService.applyHit(
    chatId, user.id, user.first_name, dmg,
    { hit_cooldown = config.boss.hit_cooldown })

  if hitErr then
    log.error(hitErr)
    ctx:answer()
    return
  end

  if result == nil then
    ctx:answer()
    return
  end

  if result.status == results.COOLDOWN then
    ctx:answer({
      text = ('⏳ Рано! Следующий удар через %d сек'):format(result.wait),
      show_alert = false,
    })

    return
  end

  if result.status == results.NO_BOSS then
    ctx:answer({ text = '💨 Босс уже повержен или сбежал', show_alert = false })
    return
  end

  if result.status == results.KILLED then
    payoutVictory(ctx, user, bossInfo)
    return
  end

  -- Обычный удар: попап с уроном + свежая карточка.
  ctx:answer({
    text = ('%s-%s! Босс: %s / %s'):format(
      isCrit and '💥 КРИТ! ' or '⚔️ ',
      separateNumbers(dmg),
      separateNumbers(result.hp),
      separateNumbers(result.hp_max)),
    show_alert = false,
  })

  local hits, hitsErr = bossSessionsService.listHits(chatId)
  if hitsErr then
    log.error(hitsErr)
  end

  session.hp = result.hp
  local remaining = config.boss.ttl - (os.time() - session.created.timestamp)

  edit(ctx, render.card(session, bossInfo, remaining, hits, {
    name = user.first_name,
    damage = dmg,
    is_crit = isCrit,
  }))
end

return command
