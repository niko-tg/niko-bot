--- Событие chat_member: Участник вышел из чата сам.
--
local log = require('log')
local uicService = require('src.services.user_in_chat')
local chatService = require('src.services.chats')

-- luacheck: ignore ctx
--- Участник вышел из чата сам.
-- @tparam table ctx контекст обновления
local function onMemberLeft(ctx)
  log.verbose('[event] %s', 'on_member_left')

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
  local _, err = chatService.ensure(chat)

  if err then
    log.error(err)
  end
  --
end

return onMemberLeft
