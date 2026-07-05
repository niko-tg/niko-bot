--- Диспетчер сервисных сообщений (migrate_to/from_chat_id, chat_owner_changed,
--- new_chat_title, *_chat_created, forum_topic_*, general_forum_topic_*)
--
local emitter = require('src.emiters.events.message_service')
local event_message_service = require('src.enums.events.event_message_service')

local function onMessageService(ctx)
  local message = ctx.message

  if message.migrate_to_chat_id then
    return emitter:emit(event_message_service.MIGRATE_TO, ctx)

  elseif message.migrate_from_chat_id then
    return emitter:emit(event_message_service.MIGRATE_FROM, ctx)

  elseif message.chat_owner_changed then
    return emitter:emit(event_message_service.CHAT_OWNER_CHANGED, ctx)

  elseif message.new_chat_title then
    return emitter:emit(event_message_service.NEW_CHAT_TITLE, ctx)

  elseif message.group_chat_created then
    return emitter:emit(event_message_service.GROUP_CHAT_CREATED, ctx)

  elseif message.supergroup_chat_created then
    return emitter:emit(event_message_service.SUPERGROUP_CHAT_CREATED, ctx)

  elseif message.channel_chat_created then
    return emitter:emit(event_message_service.CHANNEL_CHAT_CREATED, ctx)

  elseif message.forum_topic_created then
    return emitter:emit(event_message_service.FORUM_TOPIC_CREATED, ctx)

  elseif message.forum_topic_edited then
    return emitter:emit(event_message_service.FORUM_TOPIC_EDITED, ctx)

  elseif message.forum_topic_closed then
    return emitter:emit(event_message_service.FORUM_TOPIC_CLOSED, ctx)

  elseif message.forum_topic_reopened then
    return emitter:emit(event_message_service.FORUM_TOPIC_REOPENED, ctx)

  elseif message.general_forum_topic_hidden then
    return emitter:emit(event_message_service.GENERAL_FORUM_TOPIC_HIDDEN, ctx)

  elseif message.general_forum_topic_unhidden then
    return emitter:emit(event_message_service.GENERAL_FORUM_TOPIC_UNHIDDEN, ctx)
  end
end

return onMessageService
