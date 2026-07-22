--- Энам событий my_chat_member (изменения статуса самого бота в чате).
--
local event_my_chat_member = {
  CHANNEL = 'channel',
  BOT_BLOCKED = 'bot_blocked',
  BOT_KICKED = 'bot_kicked',
  BOT_RESTART = 'bot_restart',
  BOT_LEFT = 'bot_left',
  BOT_ADMIN_DEMOTED = 'bot_admin_demoted',
  BOT_ADMIN_PROMOTED = 'bot_admin_promoted',
  BOT_ADDED_AS_MEMBER = 'bot_added_as_member',
  BOT_PERMISSIONS_CHANGED = 'bot_permissions_changed',
}

return event_my_chat_member
