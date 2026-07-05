---
--
local event_message_service = {
  MIGRATE_TO = 'migrate_to',
  MIGRATE_FROM = 'migrate_from',
  CHAT_OWNER_CHANGED = 'chat_owner_changed',
  NEW_CHAT_TITLE = 'new_chat_title',
  GROUP_CHAT_CREATED = 'group_chat_created',
  SUPERGROUP_CHAT_CREATED = 'supergroup_chat_created',
  CHANNEL_CHAT_CREATED = 'channel_chat_created',
  FORUM_TOPIC_CREATED = 'forum_topic_created',
  FORUM_TOPIC_EDITED = 'forum_topic_edited',
  FORUM_TOPIC_CLOSED = 'forum_topic_closed',
  FORUM_TOPIC_REOPENED = 'forum_topic_reopened',
  GENERAL_FORUM_TOPIC_HIDDEN = 'general_forum_topic_hidden',
  GENERAL_FORUM_TOPIC_UNHIDDEN = 'general_forum_topic_unhidden',
}

return event_message_service
