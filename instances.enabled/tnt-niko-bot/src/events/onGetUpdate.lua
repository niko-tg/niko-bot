--- Событие получения обновление (сообщений) от телеграма.
--
local bot = require('bot')

--- Признаки сервисного сообщения. Если в message есть хоть одно из этих полей -
-- отдаём в onMessageService (там точная диспетчеризация по конкретному полю).
local service_fields = {
  'migrate_to_chat_id',
  'migrate_from_chat_id',
  'chat_owner_changed',
  'new_chat_title',
  'group_chat_created',
  'supergroup_chat_created',
  'channel_chat_created',
  'forum_topic_created',
  'forum_topic_edited',
  'forum_topic_closed',
  'forum_topic_reopened',
  'general_forum_topic_hidden',
  'general_forum_topic_unhidden',
}

--- Является ли сообщение сервисным.
-- @tparam table message сообщение Telegram
-- @treturn boolean
local function isServiceMessage(message)
  for i = 1, #service_fields do
    local field = service_fields[i]
    if message[field] then
      return true
    end
  end
  return false
end

--- Корневой обработчик обновления: маршрутизация по типу апдейта.
-- @tparam table ctx контекст обновления
local function onGetUpdate(ctx)
  -- Any events
  --
  if ctx.callback_query then
    return bot.events.onCallbackQuery(ctx)

  elseif ctx.my_chat_member then
    -- https://core.telegram.org/bots/api#chatmemberupdated
    return bot.events.onMyChatMember(ctx)

  elseif ctx.chat_member then
    -- https://core.telegram.org/bots/api#chatmemberupdated
    return bot.events.onChatMember(ctx)

  elseif ctx.pre_checkout_query then
    -- https://core.telegram.org/bots/api#answerprecheckoutquery
    return bot.events.preCheckoutQuery(ctx)
  end

  -- Message events
  --
  if ctx.message then
    if isServiceMessage(ctx.message) then
      return bot.events.onMessageService(ctx)

    elseif ctx.message.successful_payment then
      return bot.events.successfulPayment(ctx)

    elseif ctx.message.entities then
      return bot.events.onGetEntities(ctx)

    elseif ctx.message.text then
      return bot.events.onGetMessageText(ctx)

    elseif ctx.message.dice then
      return bot.events.onDice(ctx)

    else
      -- Медиа без text/entities: photo/video/voice/sticker/document и т.п.
      -- Отдаём в общий обработчик чата (антифлуд, фильтры и т.д.).
      return bot.events.onChatMessage(ctx)
    end
  end
end

return onGetUpdate
