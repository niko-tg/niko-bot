--- Завершение протухших PVP-сессий по очкам.
--
-- Раз в минуту находит сессии старше TTL (игроки не доиграли) и считает
-- исход по накопленным очкам (settle): победа -> банк победителю, равно
-- (вкл. 0:0) -> возврат ставок. Иначе reserved_balance залип бы навсегда.
-- Сессию удаляем только после успешного перевода денег.
--
local log = require('log')
local bot = require('bot')
local fiber = require('fiber')
local gameTypes = require('src.enums.game_types')
local gamingService = require('src.services.gaming_sessions')
local usersService = require('src.services.users')
local tgErrors = require('src.utils.tgErrors')
local settle = require('src.commands.public.game.settle')
local render = require('src.commands.public.game.render')

local TICK_INTERVAL = 60   -- раз в минуту
local SEND_DELAY    = 1    -- пауза между sendMessage (per-chat 1/sec)

--- Расчёт исхода по очкам + удаление одной протухшей сессии.
local function expire(session)
  local data = session.data or {}

  local _, err = settle(session, data)

  -- Деньги не перевелись -> сессию НЕ удаляем, повторим на следующем тике.
  if err then
    log.error(err)
    return
  end

  gamingService.delete(session.player1_id)

  local player1 = usersService.read(session.player1_id) or { id = session.player1_id }
  local player2 = usersService.read(session.player2_id) or { id = session.player2_id }

  local _, sendErr = bot:sendMessage({
    chat_id = session.chat_id,
    text = render.gameExpired(session, data, player1, player2).text,
  })

  if sendErr then
    if tgErrors.isBotBlocked(sendErr) or tgErrors.isChatNotFound(sendErr) then
      log.verbose(sendErr)
    else
      log.error(sendErr)
    end
  end
end

--- Один проход: отмена игровых сессий, у которых вышел TTL.
local function tick()
  local sessions, err = gamingService.listExpired(gameTypes.SESSION_TTL)

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

--- Запуск фонового файбера контроля TTL игровых сессий.
local function start()
  fiber.create(function()
    fiber.self():name('game-timeout')

    while true do
      local ok, runErr = pcall(tick)
      if not ok then
        log.error(runErr)
      end

      fiber.sleep(TICK_INTERVAL)
    end
  end)
end

return {
  start = start,
}
