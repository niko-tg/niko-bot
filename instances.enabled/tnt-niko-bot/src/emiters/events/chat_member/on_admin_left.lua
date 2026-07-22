--- Событие chat_member: Администратор вышел из чата.
--
local log = require('log')
local uicService = require('src.services.user_in_chat')
local chatService = require('src.services.chats')

-- luacheck: ignore ctx
--- Администратор вышел из чата.
-- @tparam table ctx контекст обновления
local function onAdminLeft(ctx)
  log.verbose('[event] %s', 'on_admin_left')

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

return onAdminLeft
