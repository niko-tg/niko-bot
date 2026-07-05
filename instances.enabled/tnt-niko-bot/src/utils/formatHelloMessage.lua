--- Формирует payload для отправки приветственного сообщения чата.
--
-- Разворачивает плейсхолдеры ${user}, ${chat} через hdec.user/hdec.chat
-- (HTML-mention с ссылкой). В зависимости от helloMessage.file.type
-- возвращает имя bot api-метода и поля.
--
-- Используется и в /gethello (preview), и в триггере на нового участника.
--
local hdec = require('bot.libs.hdec')

--- Заменяет ${user} и ${chat} на mention через string.f (глобальный fstring).
local function expandPlaceholders(text, user, chat)
  if not text or text == '' then
    return text
  end

  return text:f({
    user = hdec.user(user),
    chat = hdec.chat(chat),
    new_user = hdec.user(user),
  })
end

--- Возвращает (methodName, payload) для bot:<method>(payload).
-- @param helloMessage table { text, file }
-- @param user table - кого подставлять под ${user}
-- @param chat table - куда отправлять и кого подставлять под ${chat}
local function formatHelloMessage(helloMessage, user, chat)
  local text = expandPlaceholders(helloMessage.text, user, chat)
  local file = helloMessage.file or {}
  local caption = (text and text ~= '') and text or nil

  if file.type == 'photo' then
    return 'sendPhoto', {
      chat_id = chat.id,
      photo = file.id,
      caption = caption,
    }
  end

  if file.type == 'animation' then
    return 'sendAnimation', {
      chat_id = chat.id,
      animation = file.id,
      caption = caption,
    }
  end

  if file.type == 'video' then
    return 'sendVideo', {
      chat_id = chat.id,
      video = file.id,
      caption = caption,
    }
  end

  return 'sendMessage', {
    chat_id = chat.id,
    text = text or '',
  }
end

return formatHelloMessage
