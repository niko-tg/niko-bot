--- Бот сам вышел из чата
--
local log = require('log')
local uicService = require('src.services.user_in_chat')

-- luacheck: ignore ctx
local function on_bot_left(ctx)
  log.verbose('[event] %s', 'on_bot_left')

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
end

return on_bot_left
