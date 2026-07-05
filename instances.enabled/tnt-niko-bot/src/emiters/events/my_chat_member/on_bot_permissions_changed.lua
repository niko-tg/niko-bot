--- Боту изменили права в чате
--
local log = require('log')
local uicService = require('src.services.user_in_chat')
local Permissions = require('src.models.Permissions')
local missingRightsWarner = require('src.utils.missingRightsWarner')

-- luacheck: ignore ctx
local function on_bot_permissions_changed(ctx)
  log.verbose('[event] %s', 'on_bot_permissions_changed')

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

  -- Права могли быть выданы - сбрасываем флаг warning, чтобы при
  -- следующем rights-error снова напомнить (если они не дали нужные).
  missingRightsWarner.reset(chat.id)
end

return on_bot_permissions_changed
