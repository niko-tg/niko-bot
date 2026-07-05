--- Фильтр: удаление ссылок.
--
-- Срабатывает на сообщения с url/text_link в message.entities или caption_entities.
-- Источник сообщения:
--   * обычный user - проверяем role, пропускаем bot owner и модератор+
--   * sender_chat - если это анонимный админ текущего чата (sender_chat.id ==
--     chat.id), пропускаем; иначе (внешний канал/группа) удаляем без role-check
--
local log = require('log')
local fiber = require('fiber')
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local auth = require('src.auth')
local entity_type = require('bot.enums.entity_type')
local userInChatService = require('src.services.user_in_chat')
local missingRightsWarner = require('src.utils.missingRightsWarner')
local tgErrors = require('src.utils.tgErrors')

local LINK_ENTITY_TYPES = {
  [entity_type.URL] = true,
  [entity_type.TEXT_LINK] = true,
}

local function hasLinks(entities)
  if not entities then
    return false
  end

  for _, entity in ipairs(entities) do
    if LINK_ENTITY_TYPES[entity.type] then
      return true
    end
  end

  return false
end

local NOTIFICATION_TEMPLATE = [[
⚠️ Ограничение чата
${sep}
${user} [<code>${user_id}</code>] | В этот чат запрещено присылать ссылки.
]]

--- Возвращает true если сообщение было удалено фильтром.
local function deleteLinks(ctx, chatItem)
  local settings = chatItem.settings or {}

  if not settings.has_delete_links then
    return false
  end

  local message = ctx.message

  if not (
    hasLinks(message.entities) or
    hasLinks(message.caption_entities)
  ) then
    return false
  end

  -- Определяем источник: либо обычный юзер, либо sender_chat (канал /
  -- анонимный админ). Логика проверки отличается, поэтому собираем
  -- mention/id в общие переменные и дальше идём по единому пути.
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
      -- При ошибке чтения не рискуем удалить чужое
      return false
    end

    if auth.hasRoleAtLeast(uic, auth.roles.MODERATOR) then
      return false
    end

    mention = hdec.user(user)
    mentionId = user.id

  elseif senderChat then
    -- Анонимные админы группы пишут с sender_chat = текущий чат.
    -- Их мы не трогаем (они admin этого же чата).
    if senderChat.id == chat.id then
      return false
    end

    -- Авто-форвард из связанного канала (linked channel) - легитимный
    -- механизм, который владелец чата сам настроил. Пропускаем.
    if message.is_automatic_forward then
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

return deleteLinks
