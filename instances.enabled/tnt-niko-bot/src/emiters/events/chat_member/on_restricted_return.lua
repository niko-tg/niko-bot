--- Событие chat_member: Участник вернулся из ограничения в обычный статус.
--
local log = require('log')
local uicService = require('src.services.user_in_chat')
local chatService = require('src.services.chats')
local Permissions = require('src.models.Permissions')

-- luacheck: ignore ctx
--- Участник вернулся из ограничения в обычный статус.
-- @tparam table ctx контекст обновления
local function onRestrictedReturn(ctx)
  log.verbose('[event] %s', 'on_restricted_return')

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
  --

  -- На случай если чат был ранее неизвестен
  --
  local _, err = chatService.ensure(chat)

  if err then
    log.error(err)
  end
  --
end

return onRestrictedReturn
