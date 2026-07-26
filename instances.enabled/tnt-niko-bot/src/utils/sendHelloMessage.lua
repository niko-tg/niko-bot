--- Отправка приветственного сообщения чата новому участнику.
--
-- Читает hello_message чата и шлёт его юзеру. Флаг has_enable_hello_message
-- НЕ проверяет - это забота вызывающего. Используется в двух местах:
-- триггер на нового участника (капча выключена) и прохождение капчи
-- (приветствуем только доказавших, что они не боты).
--
local log = require('log')
local bot = require('bot')
local helloMessageService = require('src.services.hello_message')
local formatHelloMessage = require('src.utils.formatHelloMessage')

--- Отправляет приветствие, если оно задано для чата.
-- @tparam table chat сырой Telegram-чат (нужны id и title для ${chat})
-- @tparam table user кого подставлять под ${user}
local function sendHelloMessage(chat, user)
  local hello, helloErr = helloMessageService.read(chat.id)

  if helloErr then
    log.error(helloErr)
    return
  end

  if not hello then
    return
  end

  local method, payload = formatHelloMessage(hello, user, chat)

  local _, sendErr = bot[method](bot, payload)

  if sendErr then
    -- sendMessage/sendPhoto/etc не требует admin-прав, поэтому warner
    -- здесь не нужен. Ошибки тихо: бот мог быть кикнут, флуд-лимит и т.п.
    log.verbose(sendErr)
  end
end

return sendHelloMessage
