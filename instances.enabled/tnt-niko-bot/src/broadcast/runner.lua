--- Рассылка одного сообщения по списку получателей.
--[[
Получателей перебираем по очереди с небольшой паузой, чтобы не упереться в общий лимит Telegram.
Сообщение копируем (copyMessage) из исходного чата - получатель видит его -
как обычное сообщение от бота, без пометки «переслано».
Ход рассылки показываем отдельным сообщением и время от времени обновляем.
--]]
local log = require('log')
local bot = require('bot')
local fiber = require('fiber')
local hdec = require('bot.libs.hdec')

-- Пауза между отправками - примерно 10 сообщений в секунду.
local SEND_INTERVAL = 0.1
-- Через сколько отправок обновлять сообщение с ходом рассылки.
local PROGRESS_EVERY = 25
-- Сколько раз пробуем одного получателя, если Telegram просит подождать (429).
local MAX_RETRIES = 3
-- Добавка к запрошенному Telegram времени ожидания при 429.
local RETRY_PADDING = 2

local PROGRESS_TEMPLATE = [[
📨 <b>Рассылка ${label}</b>
${sep}
🎯 Целей: <b>${total}</b>
✅ Отправлено: <b>${sent}</b>
⚠️ Ошибок: <b>${errors}</b>
]]

-- opts.ctx        - Кнтекст команды (куда слать сообщение с ходом)
-- opts.label      - Подпись: «по чатам» / «по юзерам»
-- opts.fromChatId - Исходный чат, откуда берём сообщение
-- opts.messageId  - id сообщения, которое рассылаем
-- opts.targets    - Список id получателей
local function runBroadcast(opts)
  local total = #opts.targets
  local sent = 0
  local errors = 0

  local function progressText()
    return PROGRESS_TEMPLATE:f({
      sep = hdec.sep,
      label = opts.label,
      total = total,
      sent = sent,
      errors = errors,
    })
  end

  -- Сообщение с ходом рассылки - его потом редактируем.
  -- Если не отправилось, рассылку всё равно делаем, просто без живого счётчика.
  local progress = opts.ctx:reply(progressText())
  local progressChatId = opts.ctx:getChatId()
  local progressMessageId = progress and progress.message_id

  local function updateProgress()
    if not progressMessageId then
      return
    end

    local _, err = bot:editMessageText({
      chat_id = progressChatId,
      message_id = progressMessageId,
      text = progressText(),
    })

    -- «Message is not modified» и подобное не важны - молча пропускаем.
    if err and err.error_code ~= 429 then
      log.verbose(err)
    end
  end

  -- Отправляет одному получателю. На 429 ждёт столько, сколько просит
  -- Telegram, и пробует снова. true - доставлено.
  local function sendOne(targetId)
    for _ = 1, MAX_RETRIES do
      local _, err = bot:copyMessage({
        chat_id = targetId,
        from_chat_id = opts.fromChatId,
        message_id = opts.messageId,
      })

      if not err then
        return true
      end

      if err.error_code ~= 429 then
        -- Обычно «бот заблокирован» или «чат не найден» - это ожидаемо.
        log.verbose(err)
        return false
      end

      local retryAfter = (err.parameters and err.parameters.retry_after) or 1
      fiber.sleep(retryAfter + RETRY_PADDING)
    end

    return false
  end

  for index = 1, total do
    if sendOne(opts.targets[index]) then
      sent = sent + 1
    else
      errors = errors + 1
    end

    if (sent + errors) % PROGRESS_EVERY == 0 then
      updateProgress()
    end

    fiber.sleep(SEND_INTERVAL)
  end

  updateProgress()
end

return runBroadcast
