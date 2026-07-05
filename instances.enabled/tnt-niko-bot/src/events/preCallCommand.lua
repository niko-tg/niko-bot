--- Обработчик до выполнения команды
--
local log = require('log')
local auth = require('src.auth')
local hdec = require('bot.libs.hdec')
local chatService = require('src.services.chats')
local usersService = require('src.services.users')
local userInChatService = require('src.services.user_in_chat')
local syncChatStaff = require('src.utils.syncChatStaff')
local antifloodCheck = require('src.utils.antifloodCheck')
local command_flags = require('bot.enums.command_flags')
local chat_type = require('bot.enums.chat_type')

local IS_GROUP = {
  [chat_type.GROUP] = true,
  [chat_type.SUPERGROUP] = true,
}

--- Возвращает true  - Команда выполняется дальше
--             false - Команда не должна выполнится
local function preCallCommand(ctx, command)
  local user = ctx:getUserFrom()
  local chat = ctx:getChat()

  -- Создание/обновление записи юзера
  --
  local userItem, userErr = usersService.upsert(user)

  if userErr then
    log.error(userErr)
    return false
  end

  -- Создание/обновление записи чата только для групп.
  -- В PM нет moderation-настроек - хранить там нечего.
  --
  local chatItem, chatErr
  if IS_GROUP[chat.type] then
    chatItem, chatErr = chatService.upsert(chat)

    if chatErr then
      log.error(chatErr)
      return false
    end
  end
  --

  -- Cold-start: если стаф этого группового чата ещё не подтягивали из Telegram -
  -- делаем sync синхронно, чтобы дальнейшие auth-проверки нашли uic вызывающего.
  -- Ошибку sync не считаем фатальной: команда продолжит выполнение, просто
  -- admin/moderator проверки могут не пройти из-за отсутствия данных.
  if IS_GROUP[chat.type] and chatItem and not chatItem.staff_synced then
    local _, syncErr = syncChatStaff(chat.id)

    if syncErr then
      log.error(syncErr)
    else
      chatItem.staff_synced = true
    end
  end

  -- Антифлуд: команды тоже считаются как сообщения. Если юзер зафлудил -
  -- restrict применён, команда не выполняется.
  -- Callback'и (нажатия кнопок) пропускаем: antifloodCheck читает ctx.message,
  -- а у callback это сообщение БОТА (одинаковый текст) - ложно ловится как
  -- флуд. Частые клики и так гасит soft-лимитер в processCommand.
  if IS_GROUP[chat.type] and chatItem and not ctx.is_callback_query
    and antifloodCheck(ctx, chatItem)
  then
    return false
  end

  local isBotOwner = auth.isBotOwner(user)

  -- Команда только для создателя бота
  --
  if command:hasFlag(command_flags.MAINTENANCE) then
    if not isBotOwner then
      return false
    end
  end
  --

  -- Команда только в групповых чатах
  --
  if command:hasFlag(command_flags.IN_CHAT) then
    if not IS_GROUP[chat.type] then
      ctx:reply('🤷🏼‍♀️ Эту команду я могу выполнить только в чате')
      return false
    end
  end
  --

  -- Команда только реплеем на сообщение
  --
  if command:hasFlag(command_flags.REPLY) then
    if not ctx:getReplyToMessage() then
      -- ctx:reply('🌊 Эту можно выполнить только ответом на сообщение')
      return false
    end
  elseif command:hasFlag(command_flags.NO_REPLY) then
    if ctx:getReplyToMessage() then
      return false
    end
  end

  -- Проверки роли в чате. Создатель бота проходит автоматически.
  local requiredRole
  if command:hasFlag(command_flags.ADMINISTRATIVE) then
    requiredRole = auth.roles.ADMIN

  elseif command:hasFlag(command_flags.MODERATION) then
    requiredRole = auth.roles.MODERATOR
  end

  if requiredRole and not isBotOwner then
    -- Чтение записи
    local uic, uicErr = userInChatService.read(chat.id, user.id)

    if uicErr then
      log.error(uicErr)
      return false
    end

    if not auth.hasRoleAtLeast(uic, requiredRole) then
      ctx:replyToMessage('⚠️ Эту команду можно выполнить только с ролью: '..hdec.bold(requiredRole))
      return false
    end
  end

  -- Устанвка ссылок для быстрого доступа
  command.user = userItem
  command.chat = chatItem

  -- Учёт команды и активности юзера. В самом конце - считаем только команды,
  -- прошедшие все проверки. Сообщения и total_messages считаются отдельно в
  -- onChatMessage. Callback - тоже команда, его тоже учитываем.
  local _, touchErr = usersService.touchActivity(user.id)
  if touchErr then
    log.error(touchErr)
  end

  local _, cmdErr = usersService.incCommands(user.id)
  if cmdErr then
    log.error(cmdErr)
  end

  return true
end

return preCallCommand
