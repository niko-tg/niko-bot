--- Регистрация обработчиков событий onMyChatMember.
--
local EventEmitter = require('bot.interfaces.EventEmitter')
local event = require('src.enums.events.event_my_chat_member')

local emitter = EventEmitter:new()

emitter:on(event.BOT_BLOCKED,
  require('src.emiters.events.my_chat_member.on_bot_blocked'))
emitter:on(event.BOT_KICKED,
  require('src.emiters.events.my_chat_member.on_bot_kicked'))
emitter:on(event.BOT_RESTART,
  require('src.emiters.events.my_chat_member.on_bot_restart'))
emitter:on(event.BOT_LEFT,
  require('src.emiters.events.my_chat_member.on_bot_left'))
emitter:on(event.BOT_ADDED_AS_MEMBER,
  require('src.emiters.events.my_chat_member.on_bot_added_as_member'))
emitter:on(event.BOT_PERMISSIONS_CHANGED,
  require('src.emiters.events.my_chat_member.on_bot_permissions_changed'))
emitter:on(event.BOT_ADMIN_DEMOTED,
  require('src.emiters.events.my_chat_member.on_bot_admin_demoted'))
emitter:on(event.BOT_ADMIN_PROMOTED,
  require('src.emiters.events.my_chat_member.on_bot_admin_promoted'))

return emitter
