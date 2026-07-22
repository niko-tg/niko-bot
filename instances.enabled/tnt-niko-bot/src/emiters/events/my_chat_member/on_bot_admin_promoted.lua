--- Бота повысили до админа или добавили в чат как админа.
--
local log = require('log')
local fiber = require('fiber')
local uicService = require('src.services.user_in_chat')
local Permissions = require('src.models.Permissions')
local syncChatStaff = require('src.utils.syncChatStaff')
local notifyBotAddedToChat = require('src.notifications.botAddedToChat')

-- luacheck: ignore ctx
--- Бота повысили до админа или добавили в чат как админа.
-- @tparam table ctx контекст обновления
local function onBotAdminPromoted(ctx)
  log.verbose('[event] %s', 'on_bot_admin_promoted')

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

  -- Если бота добавили сразу как админа - мы могли пропустить on_bot_added_as_member,
  -- поэтому тоже подтягиваем стаф чата
  fiber.create(syncChatStaff, chat.id)

  -- Если это правда новое добавление (был вне чата), а не повышение из member - уведомляем
  notifyBotAddedToChat(ctx)
end

return onBotAdminPromoted
