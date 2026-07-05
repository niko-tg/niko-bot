---
--
local log = require('log')
local uicService = require('src.services.user_in_chat')
local chatService = require('src.services.chats')
local moderationLog = require('src.notifications.moderationLog')

local function on_member_unbanned(ctx)
  log.verbose('[event] %s', 'on_member_unbanned')

  local chat = ctx:getChat()
  local newChatMember = ctx:getNewChatMember()

  -- Запись user_in_chat для самого бота: создаём, если её нет,
  -- иначе обновляем (status -> kicked, permissions -> пустой map)
  local _, err = uicService.upsert({
    chat_id = chat.id,
    user_id = newChatMember.user.id,
    status = newChatMember.status,
    permissions = {},
  })

  if err then
    log.error(err)
  end
  --

  -- На случай если чат был ранее неизвестен
  --
  local chatModel, chatErr = chatService.ensure(chat)

  if chatErr then
    log.error(chatErr)
  end
  --

  -- Лог разбана в привязанный мод-чат (если у чата задан moderation_chat_id)
  if chatModel then
    moderationLog.unbanned(ctx, chatModel)
  end
end

return on_member_unbanned
