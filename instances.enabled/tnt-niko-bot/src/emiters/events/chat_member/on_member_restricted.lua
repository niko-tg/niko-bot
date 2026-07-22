--- Участнику выдали ограничение (мут).
--
local log = require('log')
local uicService = require('src.services.user_in_chat')
local chatService = require('src.services.chats')
local Permissions = require('src.models.Permissions')
local moderationLog = require('src.notifications.moderationLog')
local cancelGame = require('src.commands.public.game.cancel')

--- Участнику выданы ограничения: обновление статуса и прав.
-- @tparam table ctx контекст обновления
local function onMemberRestricted(ctx)
  log.verbose('[event] %s', 'on_member_restricted')

  local chat = ctx:getChat()
  local newChatMember = ctx:getNewChatMember()

  -- Запись user_in_chat: статус restricted + актуальные права ограничения
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
  local chatModel, chatErr = chatService.ensure(chat)

  if chatErr then
    log.error(chatErr)
  end
  --

  -- Лог мута в привязанный мод-чат (если у чата задан moderation_chat_id)
  if chatModel then
    moderationLog.muted(ctx, chatModel)
  end

  -- Замученный не может бросать кубик -> отменяем его игру в этом чате.
  cancelGame(chat.id, newChatMember.user, 'замучен')
end

return onMemberRestricted
