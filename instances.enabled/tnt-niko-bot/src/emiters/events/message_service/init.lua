--- Регистрация обработчиков сервисных сообщений.
--
local EventEmitter = require('bot.interfaces.EventEmitter')
local event = require('src.enums.events.event_message_service')

local emitter = EventEmitter:new()

emitter:on(event.MIGRATE_TO,
  require('src.emiters.events.message_service.on_migrate_to'))
emitter:on(event.MIGRATE_FROM,
  require('src.emiters.events.message_service.on_migrate_from'))
emitter:on(event.CHAT_OWNER_CHANGED,
  require('src.emiters.events.message_service.on_chat_owner_changed'))
emitter:on(event.NEW_CHAT_TITLE,
  require('src.emiters.events.message_service.on_new_chat_title'))
emitter:on(event.GROUP_CHAT_CREATED,
  require('src.emiters.events.message_service.on_group_chat_created'))
emitter:on(event.SUPERGROUP_CHAT_CREATED,
  require('src.emiters.events.message_service.on_supergroup_chat_created'))
emitter:on(event.CHANNEL_CHAT_CREATED,
  require('src.emiters.events.message_service.on_channel_chat_created'))
emitter:on(event.FORUM_TOPIC_CREATED,
  require('src.emiters.events.message_service.on_forum_topic_created'))
emitter:on(event.FORUM_TOPIC_EDITED,
  require('src.emiters.events.message_service.on_forum_topic_edited'))
emitter:on(event.FORUM_TOPIC_CLOSED,
  require('src.emiters.events.message_service.on_forum_topic_closed'))
emitter:on(event.FORUM_TOPIC_REOPENED,
  require('src.emiters.events.message_service.on_forum_topic_reopened'))
emitter:on(event.GENERAL_FORUM_TOPIC_HIDDEN,
  require('src.emiters.events.message_service.on_general_forum_topic_hidden'))
emitter:on(event.GENERAL_FORUM_TOPIC_UNHIDDEN,
  require('src.emiters.events.message_service.on_general_forum_topic_unhidden'))

return emitter
