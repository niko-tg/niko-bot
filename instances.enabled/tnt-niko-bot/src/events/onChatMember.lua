--- Обработчик chat_member: классификация смены статуса участника и эмит события.
--
local log = require('log')
local chat_member_status = require('bot.enums.chat_member_status')
local chat_type = require('bot.enums.chat_type')
local emitter = require('src.emiters.events.chat_member')
local event_chat_member = require('src.enums.events.event_chat_member')
local usersService = require('src.services.users')
local chatService = require('src.services.chats')

--- Тонкие обёртки над счётчиком участников чата (chats.members) с логом ошибки.
local function incMembers(chat_id)
  local _, err = chatService.incMembers(chat_id)
  if err then
    log.error(err)
  end
end

--- Уменьшение счётчика участников чата.
-- @tparam number chat_id id чата
local function decMembers(chat_id)
  local _, err = chatService.decMembers(chat_id)
  if err then
    log.error(err)
  end
end

--- Обработчик chat_member: классификация смены статуса и эмит события.
-- @tparam table ctx контекст обновления
local function onChatMember(ctx)
  local chatType = ctx:getChatType()

  -- Событие для каналов
  if chat_type.CHANNEL == chatType then
    return emitter:emit(event_chat_member.CHANNEL, ctx)
  end

  local chat = ctx:getChat()
  local oldChatM = ctx:getOldChatMember()
  local newChatM = ctx:getNewChatMember()
  local oldStatus = oldChatM.status
  local newStatus = newChatM.status
  local oldIsMember = oldChatM.is_member
  local newIsMember = newChatM.is_member

  -- Регистрируем/обновляем затронутого юзера в таблице users. Иначе команды,
  -- которые ищут таргет по @username (напр. /unban @user), не найдут того,
  -- кто никогда не писал боту - а через chat_member мы его уже видим.
  local _, userErr = usersService.upsert(newChatM.user)

  if userErr then
    log.error(userErr)
  end

  --
  -- Диспетчеризация по типу события
  --
  --
  -- Пользователь возвращается в чат с ограниченным статусом
  --
  if oldIsMember == false and newIsMember == true then
    -- Вернулся в чат (был вне -> стал участником)
    incMembers(chat.id)
    return emitter:emit(event_chat_member.RESTRICTED_RETURN, ctx)

  elseif oldIsMember == true and newIsMember == false then
    -- Покинул чат
    decMembers(chat.id)
    return emitter:emit(event_chat_member.MEMBER_LEFT, ctx)
  end

  -- Обработка по новому статусу
  --
  if newStatus == chat_member_status.MEMBER then
    -- Сняли админку (administrator -> обычный участник) - это понижение,
    -- а не новый участник
    if oldStatus == chat_member_status.ADMINISTRATOR then
      return emitter:emit(event_chat_member.ADMIN_DEMOTED, ctx)
    end

    -- Новый участник: +1, только если до этого был ВНЕ чата (реальный вход).
    -- Размут (restricted -> member) или owner -> member - юзер уже был в чате.
    if oldStatus == chat_member_status.LEFT
      or oldStatus == chat_member_status.KICKED
    then
      incMembers(chat.id)
    end

    return emitter:emit(event_chat_member.NEW_MEMBER, ctx)

  elseif newStatus == chat_member_status.RESTRICTED then
    if oldStatus == chat_member_status.ADMINISTRATOR then
      -- У администратора убрали все права
      return emitter:emit(event_chat_member.ADMIN_DEMOTED, ctx)
    end

    -- Участнику выдали ограничение (мут) - он остаётся в чате
    return emitter:emit(event_chat_member.MEMBER_RESTRICTED, ctx)

  elseif newStatus == chat_member_status.ADMINISTRATOR then
    -- Назначили участника администратором
    return emitter:emit(event_chat_member.ADMIN_PROMOTED, ctx)

  elseif newStatus == chat_member_status.KICKED then
    -- Бан: -1, только если до этого был В чате. Бан уже вышедшего - 0.
    if oldStatus ~= chat_member_status.LEFT
      and oldStatus ~= chat_member_status.KICKED
    then
      decMembers(chat.id)
    end

    return emitter:emit(event_chat_member.MEMBER_KICKED, ctx)

  -- Обход различных сценариев выхода
  --
  elseif newStatus == chat_member_status.LEFT then
    if oldStatus == chat_member_status.MEMBER then
      decMembers(chat.id)
      return emitter:emit(event_chat_member.MEMBER_LEFT, ctx)

    elseif oldStatus == chat_member_status.RESTRICTED then
      decMembers(chat.id)
      return emitter:emit(event_chat_member.MEMBER_LEFT, ctx)

    elseif oldStatus == chat_member_status.KICKED then
      -- Разбан (kicked -> left): в чат не вернулся, счётчик не трогаем
      return emitter:emit(event_chat_member.MEMBER_UNBANNED, ctx)

    elseif oldStatus == chat_member_status.ADMINISTRATOR then
      decMembers(chat.id)
      return emitter:emit(event_chat_member.ADMIN_LEFT, ctx)

    elseif oldStatus == chat_member_status.CREATOR then
      decMembers(chat.id)
      return emitter:emit(event_chat_member.OWNER_LEFT, ctx)

    else
      log.error({
        message = 'Unexpected transition status',
        old_status = tostring(oldStatus),
        new_status = tostring(newStatus),
        user_id = newChatM.user.id,
        chat_id = chat.id,
      })
    end
  end
end

return onChatMember
