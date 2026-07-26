--- Кик новых участников, не прошедших капчу вовремя.
--
-- Раз в 30 секунд находит капча-сессии старше TTL и выгоняет юзера
-- коротким баном (Telegram снимет его сам - можно зайти и пройти капчу
-- повторно). Сообщение с кнопкой удаляется.
--
local log = require('log')
local fiber = require('fiber')
local captchaService = require('src.services.captcha_sessions')
local flow = require('src.commands.moderation.captcha.flow')

local TICK_INTERVAL = 30   -- частота проверки
local KICK_DELAY    = 1    -- пауза между киками (rate limit API)

--- Один проход: кик всех, у кого вышло время на капчу.
local function tick()
  local sessions, err = captchaService.listExpired(flow.CAPTCHA_TTL)

  if err then
    log.error(err)
    return
  end

  if not sessions then
    return
  end

  for i = 1, #sessions do
    local session = sessions[i]
    flow.expire(session)
    fiber.sleep(KICK_DELAY)
  end
end

--- Запуск фонового файбера контроля TTL капча-сессий.
local function start()
  fiber.create(function()
    fiber.self():name('captcha-timeout')

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
