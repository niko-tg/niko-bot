--- Событие chat_member: Участник исключён (бан) из чата.
--
local log = require('log')
local uicService = require('src.services.user_in_chat')
local chatService = require('src.services.chats')
local moderationLog = require('src.notifications.moderationLog')
local cancelGame = require('src.commands.public.game.cancel')

--- Участник исключён из чата: обновление статуса и счётчика участников.
-- @tparam table ctx контекст обновления
local function onMemberKicked(ctx)
  log.verbose('[event] %s', 'on_member_kicked')

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

  -- Лог бана в привязанный мод-чат (если у чата задан moderation_chat_id)
  if chatModel then
    moderationLog.banned(ctx, chatModel)
  end

  -- Забаненный больше не в чате -> отменяем его игру в этом чате.
  cancelGame(chat.id, newChatMember.user, 'забанен')
end

return onMemberKicked
