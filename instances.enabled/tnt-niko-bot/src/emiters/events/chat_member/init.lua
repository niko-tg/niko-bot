--- Регистрация обработчиков событий onChatMember
--
local EventEmitter = require('bot.interfaces.EventEmitter')
local event = require('src.enums.events.event_chat_member')

local emitter = EventEmitter:new()

emitter:on(event.CHANNEL,
  require('src.emiters.events.chat_member.on_channel'))
emitter:on(event.RESTRICTED_RETURN,
  require('src.emiters.events.chat_member.on_restricted_return'))
emitter:on(event.MEMBER_LEFT,
  require('src.emiters.events.chat_member.on_member_left'))
emitter:on(event.NEW_MEMBER,
  require('src.emiters.events.chat_member.on_new_member'))
emitter:on(event.ADMIN_DEMOTED,
  require('src.emiters.events.chat_member.on_admin_demoted'))
emitter:on(event.ADMIN_PROMOTED,
  require('src.emiters.events.chat_member.on_admin_promoted'))
emitter:on(event.MEMBER_KICKED,
  require('src.emiters.events.chat_member.on_member_kicked'))
emitter:on(event.MEMBER_UNBANNED,
  require('src.emiters.events.chat_member.on_member_unbanned'))
emitter:on(event.MEMBER_RESTRICTED,
  require('src.emiters.events.chat_member.on_member_restricted'))
emitter:on(event.ADMIN_LEFT,
  require('src.emiters.events.chat_member.on_admin_left'))
emitter:on(event.OWNER_LEFT,
  require('src.emiters.events.chat_member.on_owner_left'))

return emitter
