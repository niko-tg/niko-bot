--- Рейд-босс чата (PVE, кооператив): призыв и карточка боя.
--
-- /boss - призвать босса либо перепостить карточку идущего боя.
-- Бьют босса кнопкой (cb_boss), убегает по TTL (bossTimeout).
--
local log = require('log')
local config = require('conf.config')
local Command = require('bot.classes.Command')
local bosses = require('src.dict.bosses')
local bossSessionsService = require('src.services.boss_sessions')
local render = require('src.commands.public.boss.render')

local command = Command:new({
  commands = { '/boss', 'босс', 'рейд' },
  flags = { Command.enum.PUBLIC, Command.enum.IN_CHAT },
})

--- Перепост карточки идущего боя новым сообщением + перепривязка message_id.
-- (как в /mines: старую карточку могли удалить).
local function repostCard(ctx, session)
  local bossInfo = bosses.byKey[session.boss_id]

  if not bossInfo then
    log.error({ message = 'boss not in catalog', boss_id = tostring(session.boss_id) })
    return
  end

  local hits, hitsErr = bossSessionsService.listHits(session.chat_id)
  if hitsErr then
    log.error(hitsErr)
  end

  local remaining = config.boss.ttl - (os.time() - session.created.timestamp)
  local view = render.card(session, bossInfo, remaining, hits)

  local sent = ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })

  if sent then
    local _, saveErr = bossSessionsService.saveMessageId(session.chat_id, sent.message_id)
    if saveErr then
      log.error(saveErr)
    end
  end
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local chatId = ctx:getChatId()

  -- Идёт бой - показываем его, а не отказ.
  local existing, readErr = bossSessionsService.getByChat(chatId)
  if readErr then
    log.error(readErr)
    return
  end

  if existing and existing.status == 'active' then
    repostCard(ctx, existing)
    return
  end

  -- Призыв нового.
  local bossInfo = bosses.pickRandom()

  local result, spawnErr = bossSessionsService.spawn({
    chat_id = chatId,
    boss_id = bossInfo.key,
    hp = bossInfo.hp,
    hp_max = bossInfo.hp,
    message_id = 0,
  }, {
    spawn_cooldown = config.boss.spawn_cooldown,
  })

  if spawnErr then
    log.error(spawnErr)
    ctx:replyToMessage('⚠️ Не удалось призвать босса')
    return
  end

  if result == nil then
    return
  end

  -- Гонка двух призывов: бой уже создан параллельным вызовом.
  if result.status == bossSessionsService.result.EXISTS then
    local session = bossSessionsService.getByChat(chatId)

    if session and session.status == 'active' then
      repostCard(ctx, session)
    end

    return
  end

  if result.status == bossSessionsService.result.RESTING then
    ctx:replyToMessage(('😴 Боссы отдыхают. Следующий придёт через <b>%s</b>')
      :format(render.formatRemaining(result.wait)))

    return
  end

  local view = render.card(result.session, bossInfo, config.boss.ttl, nil)

  local sent = ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })

  if sent then
    local _, saveErr = bossSessionsService.saveMessageId(chatId, sent.message_id)
    if saveErr then
      log.error(saveErr)
    end
  end
end

return command
