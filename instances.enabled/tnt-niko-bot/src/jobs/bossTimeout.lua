--- Побег протухших рейд-боссов.
--
-- Периодически завершает бои старше TTL: бой -> finished (от finished_at
-- пойдёт кулдаун призыва), урон чистится, карточка гасится 'сбежал'.
-- Награда при побеге не выплачивается - мотивация добивать.
--
local log = require('log')
local bot = require('bot')
local fiber = require('fiber')
local config = require('conf.config')
local bosses = require('src.dict.bosses')
local bossSessionsService = require('src.services.boss_sessions')
local tgErrors = require('src.utils.tgErrors')
local render = require('src.commands.public.boss.render')

local SEND_DELAY = 1  -- пауза между editMessageText (per-chat 1/sec)

--- Побег одного босса.
local function expire(session)
  local _, finishErr = bossSessionsService.finish(session.chat_id)

  -- Бой не завершили -> не чистим и не гасим, повторим на следующем тике.
  if finishErr then
    log.error(finishErr)
    return
  end

  local _, delErr = bossSessionsService.deleteHits(session.chat_id)
  if delErr then
    log.error(delErr)
  end

  -- Карточки может не быть (message_id = 0 - бой без отправленной карточки).
  local bossInfo = bosses.byKey[session.boss_id]

  if not bossInfo or session.message_id == 0 then
    return
  end

  local _, editErr = bot:editMessageText({
    chat_id = session.chat_id,
    message_id = session.message_id,
    text = render.escaped(session, bossInfo).text,
  })

  if editErr then
    if tgErrors.isIgnorable(editErr) or tgErrors.isChatNotFound(editErr) then
      log.verbose(editErr)
    else
      log.error(editErr)
    end
  end
end

--- Один проход: закрытие боёв, у которых вышел TTL.
local function tick()
  local sessions, err = bossSessionsService.listExpired(config.boss.ttl)

  if err then
    log.error(err)
    return
  end

  if not sessions then
    return
  end

  for i = 1, #sessions do
    local session = sessions[i]
    expire(session)
    fiber.sleep(SEND_DELAY)
  end
end

--- Запуск фонового файбера контроля TTL боссов.
local function start()
  fiber.create(function()
    fiber.self():name('boss-timeout')

    while true do
      local ok, runErr = pcall(tick)
      if not ok then
        log.error(runErr)
      end

      fiber.sleep(config.boss.job_tick)
    end
  end)
end

return {
  start = start,
}
