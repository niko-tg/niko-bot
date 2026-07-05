--- Фильтр: удаление пересланных сообщений.
--
-- Триггерится на любом форварде (legacy forward_from* или forward_origin).
-- Источник сообщения:
--   * обычный user - проверяем role, пропускаем bot owner и модератор+
--   * sender_chat - если это анонимный админ текущего чата
--     (sender_chat.id == chat.id), пропускаем; иначе (внешний канал/группа)
--     удаляем без role-check
--
-- Исключение: is_automatic_forward (auto-post из linked channel) -
-- легитимный механизм, оставляем.
--
local log = require('log')
local fiber = require('fiber')
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local auth = require('src.auth')
local isForward = require('src.utils.isForward')
local userInChatService = require('src.services.user_in_chat')
local missingRightsWarner = require('src.utils.missingRightsWarner')
local tgErrors = require('src.utils.tgErrors')

local NOTIFICATION_TEMPLATE = [[
⚠️ Ограничение чата
${sep}
${user} [<code>${user_id}</code>] | В этот чат запрещено пересылать сообщения.
]]

--- Возвращает true если сообщение было удалено фильтром.
local function deleteForwardMessage(ctx, chatItem)
  local settings = chatItem.settings or {}

  if not settings.has_delete_forward_message then
    return false
  end

  local message = ctx.message

  if not isForward(message) then
    return false
  end

  -- Авто-форвард из linked channel пропускаем (как в deleteLinks).
  if message.is_automatic_forward then
    return false
  end

  -- Определяем источник: либо обычный юзер, либо sender_chat.
  --
  local chat = ctx:getChat()
  local user = ctx:getUserFrom()
  local senderChat = ctx:getSenderChat()

  local mention
  local mentionId

  if user then
    -- Создатель бота проходит везде
    if auth.isBotOwner(user) then
      return false
    end

    -- Модератор+ освобождены
    local uic, uicErr = userInChatService.read(chat.id, user.id)

    if uicErr then
      log.error(uicErr)
      return false
    end

    if auth.hasRoleAtLeast(uic, auth.roles.MODERATOR) then
      return false
    end

    mention = hdec.user(user)
    mentionId = user.id

  elseif senderChat then
    -- Анонимный админ этого же чата - не трогаем.
    if senderChat.id == chat.id then
      return false
    end

    mention = hdec.chat(senderChat)
    mentionId = senderChat.id

  else
    return false
  end

  -- Удаляем сообщение
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

    return false
  end
  --

  -- Уведомление с mention автора
  --
  fiber.sleep(1)

  bot:sendMessage({
    chat_id = chat.id,
    text = NOTIFICATION_TEMPLATE:f({
      user = mention,
      user_id = mentionId,
      sep = hdec.sep,
    }),
  })
  --

  return true
end

return deleteForwardMessage
