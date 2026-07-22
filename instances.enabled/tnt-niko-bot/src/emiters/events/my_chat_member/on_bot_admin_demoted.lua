--- Понизили в админских правах.
--
local log = require('log')
local uicService = require('src.services.user_in_chat')
local Permissions = require('src.models.Permissions')

-- luacheck: ignore ctx
--- Понизили в админских правах.
-- @tparam table ctx контекст обновления
local function onBotAdminDemoted(ctx)
  log.verbose('[event] %s', 'on_bot_admin_demoted')

  local chat = ctx:getChat()
  local newChatMember = ctx:getNewChatMember()

  -- Запись user_in_chat для самого бота: создаём, если её нет,
  -- иначе обновляем (status -> kicked, permissions -> пустой map)
  local _, err = uicService.upsert({
    chat_id = chat.id,
    user_id = newChatMember.user.id,
    status = newChatMember.status,
    permissions = Permissions(newChatMember),
  })

  if err then
    log.error(err)
  end
end

return onBotAdminDemoted
