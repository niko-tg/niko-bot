--- Уведомление чата о нехватке прав у бота.
--
-- Когда фильтр пытается удалить/забанить, но Telegram отвечает
-- "not enough rights" - зовём warn(chatId). Шлём сообщение один раз
-- в WARN_TTL (24ч). Если за это время на чат снова падает rights-error -
-- молчим. Через TTL warning повторяется (если права так и не дали).
--
-- Также через reset(chatId) можно forced сбросить - вызывается при
-- on_bot_permissions_changed event (юзер изменил права бота, проверим
-- заново при следующем error).
--
-- Cache живёт в памяти процесса; после рестарта warning может прийти
-- повторно - это даже желательно (если права не дали, стоит напомнить).
--
local log = require('log')
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local tgErrors = require('src.utils.tgErrors')

local WARN_TTL = 24 * 60 * 60

local WARNING_TEXT = ([[
‼️ <b>У меня недостаточно прав</b>
${sep}
В настройках чата включены ограничения.
Мне нужны все права администратора чтобы следовать настройкам или выполнять модераторские команды.
]]):f({ sep = hdec.sep })

-- chat_id -> timestamp последнего warning (lazy TTL cleanup на доступе)
local warned = {}

--- Отправляет warning в чат, если в последние WARN_TTL не отправляли.
-- replyToMessageId (опц.) - сделать warning реплеем на это сообщение.
local function warning(chatId, replyToMessageId)
  local lastWarnTs = warned[chatId]
  local now = os.time()

  if lastWarnTs and (now - lastWarnTs) < WARN_TTL then
    return
  end

  warned[chatId] = now

  local fields = {
    chat_id = chatId,
    text = WARNING_TEXT,
  }

  if replyToMessageId then
    fields.reply_parameters = { message_id = replyToMessageId }
  end

  local _, err = bot:sendMessage(fields)

  if err then
    -- Если даже sendMessage упал (бот не в чате?) - сбрасываем флаг,
    -- чтобы следующий раз попытаться снова.
    warned[chatId] = nil
    log.error(err)
  end
end

--- Сбрасывает флаг для чата - следующий error снова шлёт warning.
local function reset(chatId)
  warned[chatId] = nil
end

--- Проверка err и автоматический warn при "not enough rights".
-- replyToMessageId (опц.) - сделать warning реплеем на это сообщение.
-- Возвращает true если был распознан rights-error.
local function handleApiError(err, chatId, replyToMessageId)
  if tgErrors.isNotEnoughRights(err) then
    warning(chatId, replyToMessageId)
    return true
  end

  return false
end

return {
  warn = warning,
  reset = reset,
  handleApiError = handleApiError,
}
