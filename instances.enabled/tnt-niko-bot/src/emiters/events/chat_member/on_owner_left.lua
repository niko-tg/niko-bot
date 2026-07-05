---
--
local log = require('log')
local uicService = require('src.services.user_in_chat')
local chatService = require('src.services.chats')

-- luacheck: ignore ctx
local function on_owner_left(ctx)
  log.verbose('[event] %s', 'on_owner_left')

  local chat = ctx:getChat()
  local newChatMember = ctx:getNewChatMember()

  -- Запись user_in_chat для самого бота: создаём, если её нет,
  -- иначе обновляем (status -> kicked, permissions -> пустой map)
  local _, err = uicService.upsert({
    chat_id = chat.id,
    user_id = newChatMember.user.id,
    status = newChatMember.status,
  })

  if err then
    log.error(err)
  end
  --

  -- На случай если чат был ранее неизвестен
  --
  local _, err = chatService.ensure(chat)

  if err then
    log.error(err)
  end
  --
end

return on_owner_left
