--- Обработчик my_chat_member: классификация смены статуса бота и эмит события.
--
local chat_member_status = require('bot.enums.chat_member_status')
local chat_type = require('bot.enums.chat_type')
local emitter = require('src.emiters.events.my_chat_member')
local event_my_chat_member = require('src.enums.events.event_my_chat_member')

--- Обработчик my_chat_member: классификация смены статуса бота и эмит события.
-- @tparam table ctx контекст обновления
local function onMyChatMember(ctx)
  local chatType = ctx:getChatType()

  -- Событие для каналов
  if chat_type.CHANNEL == chatType then
    return emitter:emit(event_my_chat_member.CHANNEL, ctx)
  end

  local chat = ctx:getChat()
  local newStatus = ctx:getNewChatMemberStatus()
  local oldStatus = ctx:getOldChatMemberStatus()

  -- События в ЛС пользователя и бота
  --
  if chat.type == chat_type.PRIVATE then
    if newStatus == chat_member_status.KICKED then
      -- Пользователь заблокировал у себя бота
      return emitter:emit(event_my_chat_member.BOT_BLOCKED, ctx)

    elseif newStatus == chat_member_status.MEMBER then
      if oldStatus == chat_member_status.KICKED then
        -- Бота перезапустили
        return emitter:emit(event_my_chat_member.BOT_RESTART, ctx)
      end
    end
  end

  -- Изменили права или повысили до администратора
  --
  if newStatus == chat_member_status.ADMINISTRATOR then
    if oldStatus == chat_member_status.ADMINISTRATOR then
      -- Изменили права
      return emitter:emit(event_my_chat_member.BOT_PERMISSIONS_CHANGED, ctx)
    else
      -- Повысили до администратора
      return emitter:emit(event_my_chat_member.BOT_ADMIN_PROMOTED, ctx)
    end
  end

  -- Добавили бота в чат
  --
  if newStatus == chat_member_status.MEMBER then
    -- Добавили в качестве участника
    return emitter:emit(event_my_chat_member.BOT_ADDED_AS_MEMBER, ctx)

  elseif newStatus == chat_member_status.KICKED then
    -- Бота кикнули из чата
    return emitter:emit(event_my_chat_member.BOT_KICKED, ctx)

  elseif newStatus == chat_member_status.RESTRICTED then
    -- Понизили с админа до member
    if oldStatus == chat_member_status.ADMINISTRATOR then
      return emitter:emit(event_my_chat_member.BOT_ADMIN_DEMOTED, ctx)
    end

    -- Изменили права
    return emitter:emit(event_my_chat_member.BOT_PERMISSIONS_CHANGED, ctx)

  elseif newStatus == chat_member_status.LEFT then
    -- Скорее всего чат удалили или бот сам вышел
    return emitter:emit(event_my_chat_member.BOT_LEFT, ctx)
  end
end

return onMyChatMember
