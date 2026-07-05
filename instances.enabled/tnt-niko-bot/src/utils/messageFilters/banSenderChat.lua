--- Фильтр: бан каналов от написания в чат.
--
-- Срабатывает на любое сообщение от sender_chat (канал/группа пишет
-- от своего имени). Делает banChatSenderChat - канал больше не сможет
-- писать в этот чат.
--
-- Пропускаем:
--   * sender_chat == текущий чат (анонимный админ группы)
--   * is_automatic_forward (auto-post из linked channel)
--
-- Бот должен иметь can_restrict_members. Если бан упал (нет прав или
-- API-ошибка) - сообщение НЕ удаляем и возвращаем false, чтобы дальше
-- по цепочке другие фильтры могли его обработать (например deleteLinks).
--
local log = require('log')
local fiber = require('fiber')
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local missingRightsWarner = require('src.utils.missingRightsWarner')
local tgErrors = require('src.utils.tgErrors')

local NOTIFICATION_TEMPLATE = [[
⚠️ Ограничение чата
${sep}
${user} [<code>${user_id}</code>] | Каналам запрещено писать в этот чат.
]]

--- Возвращает true если канал был забанен (и сообщение удалено).
local function banSenderChat(ctx, chatItem)
  local settings = chatItem.settings or {}

  if not settings.has_ban_sender_chat then
    return false
  end

  local senderChat = ctx:getSenderChat()

  if not senderChat then
    return false
  end

  local chat = ctx:getChat()

  -- Анонимный admin этого же чата - не трогаем
  if senderChat.id == chat.id then
    return false
  end

  -- Auto-forward из linked channel - легитимный механизм
  local message = ctx.message
  if message.is_automatic_forward then
    return false
  end

  -- Бан канала
  --
  local _, banErr = bot:banChatSenderChat({
    chat_id = chat.id,
    sender_chat_id = senderChat.id,
  })

  if banErr then
    log.verbose(banErr)
    missingRightsWarner.handleApiError(banErr, chat.id)
    return false
  end
  --

  -- Удаление сообщения. Если упало - канал уже забанен, продолжаем.
  --
  local _, deleteErr = bot:deleteMessage({
    chat_id = chat.id,
    message_id = message.message_id,
  })

  if deleteErr then
    if tgErrors.isIgnorable(deleteErr) then
      log.verbose(deleteErr)
    else
      log.verbose(deleteErr)
      missingRightsWarner.handleApiError(deleteErr, chat.id)
    end
  end
  --

  -- Уведомление с mention канала
  --
  fiber.sleep(1)

  bot:sendMessage({
    chat_id = chat.id,
    text = NOTIFICATION_TEMPLATE:f({
      user = hdec.chat(senderChat),
      user_id = senderChat.id,
      sep = hdec.sep,
    }),
  })
  --

  return true
end

return banSenderChat
