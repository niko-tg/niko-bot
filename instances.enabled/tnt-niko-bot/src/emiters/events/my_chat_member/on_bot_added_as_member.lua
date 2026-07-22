--- Добавили в качестве участника.
--
local log = require('log')
local fiber = require('fiber')
local datetime = require('datetime')
local uicService = require('src.services.user_in_chat')
local syncChatStaff = require('src.utils.syncChatStaff')
local notifyBotAddedToChat = require('src.notifications.botAddedToChat')

-- luacheck: ignore ctx
--- Добавили в качестве участника.
-- @tparam table ctx контекст обновления
local function onBotAddedAsMember(ctx)
  log.verbose('[event] %s', 'on_bot_added_as_member')

  local chat = ctx:getChat()
  local newChatMember = ctx:getNewChatMember()

  -- Запись user_in_chat для самого бота: создаём, если её нет,
  -- иначе обновляем (status -> kicked, permissions -> пустой map)
  local _, err = uicService.upsert({
    chat_id = chat.id,
    user_id = newChatMember.user.id,
    status = newChatMember.status,
    permissions = {},
    joined_date = datetime.now(),
  })

  if err then
    log.error(err)
  end

  -- Подтягиваем стаф чата асинхронно, чтобы не блокировать обработку события
  fiber.create(syncChatStaff, chat.id)

  -- Если это правда новое добавление, а не понижение из admin - уведомляем
  notifyBotAddedToChat(ctx)
end

return onBotAddedAsMember
