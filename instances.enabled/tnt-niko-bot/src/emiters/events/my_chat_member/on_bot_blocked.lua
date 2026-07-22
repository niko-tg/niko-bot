--- Заблокировали бота.
--
local log = require('log')
local chat_type = require('bot.enums.chat_type')
local userService = require('src.services.users')
local uicService = require('src.services.user_in_chat')
local Permissions = require('src.models.Permissions')

-- luacheck: ignore ctx
--- Заблокировали бота.
-- @tparam table ctx контекст обновления
local function onBotBlocked(ctx)
  log.verbose('[event] %s', 'on_bot_blocked')

  local chat = ctx:getChat()
  local chatType = ctx:getChatType()
  local userFrom = ctx:getUserFrom()
  local newChatMember = ctx:getNewChatMember()

  -- Пользователь заблокировал бота у себя
  if chatType == chat_type.PRIVATE then
    -- Обновление статуса
    --
    local _, err = userService.update({ is_started_bot = false }, { id = userFrom.id })

    if err then
      log.error(err)

      return
    end
    --
  else -- Пользователь заблокировал бота в чате
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
end

return onBotBlocked
