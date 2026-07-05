--- Бан пользователя в чате.
--
-- Варианты вызова:
--   /ban                   - ответом на сообщение, перманентный бан
--   /ban 3ч                - ответом, на 3 часа
--   /ban 123456 12ч        - по user_id
--   /ban @oxniko 1д        - по username
--
-- Юниты длительности (см. utils/parseUntilDate): м/m, ч/h, д/d.
-- Если длительность не указана - бан перманентный.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local hdec = require('bot.libs.hdec')
local auth = require('src.auth')
local userInChatService = require('src.services.user_in_chat')
local resolveTargetUser = require('src.utils.resolveTargetUser')
local parseUntilDate = require('src.utils.parseUntilDate')
local missingRightsWarner = require('src.utils.missingRightsWarner')
local tgErrors = require('src.utils.tgErrors')
local pendingModAction = require('src.utils.pendingModAction')

local command = Command:new {
  commands = { '/ban', 'бан' },
  flags = {
    Command.enum.IN_CHAT,
    Command.enum.MODERATION,
  },
}

local USAGE = ([[
ℹ️ <b>Использование</b>
${sep}
<code>/ban</code> - ответом, перманентно
<code>/ban 3ч</code> - ответом, на 3 часа
<code>/ban 123 12ч</code> - по user_id
<code>/ban @oxniko 1д</code> - по username

Юниты: м/m, ч/h, д/d
]]):f({ sep = hdec.sep })

local SUCCESS_TEMPLATE = [[
⛔ <b>Ban</b>
${sep}
👤 ${user} [<code>${userId}</code>]
⏳ ${duration}
]]

--- Разбирает токен в таргет: @username -> { username }, число -> { user_id }.
local function asTarget(value)
  if value:sub(1, 1) == '@' then
    return { username = value:sub(2):lower() }
  end

  local id = tonumber(value)
  if id then
    return { user_id = id }
  end

  return nil
end

--- Разбирает токены после "/ban".
-- Возвращает (target, durationStr):
--   target == { user_id = N } | { username = "x" } | nil
--   durationStr - строка для parseUntilDate либо nil
--
-- Контракт:
--   2 токена          - первый таргет, второй длительность
--   1 токен + reply   - длительность для reply-таргета
--   1 токен без reply - таргет, без длительности (перманент)
--   0 токенов         - reply, перманент
local function parseArgs(text, hasReply)
  local tokens = {}
  for token in text:gmatch('%S+') do
    table.insert(tokens, token)
  end

  -- Первый токен - сама команда /ban, отбрасываем
  table.remove(tokens, 1)

  if #tokens == 0 then
    return nil, nil
  end

  if #tokens == 1 then
    if hasReply then
      return nil, tokens[1]
    end

    return asTarget(tokens[1]), nil
  end

  return asTarget(tokens[1]), tokens[2]
end

function command.call(ctx)
  local message = ctx.message
  local reply = message.reply_to_message
  local chat = command.chat
  local actor = command.user

  local target, durationStr = parseArgs(message.text, reply ~= nil)

  -- Если таргет не указан явно - берём из reply
  if not target and reply and reply.from then
    target = { user_id = reply.from.id }
  end

  if not target then
    ctx:replyToMessage(USAGE)
    return
  end

  -- Лукап таргета в БД
  local targetUser, lookupErr = resolveTargetUser(target)

  if lookupErr then
    log.error(lookupErr)
    ctx:replyToMessage('⚠️ Ошибка чтения пользователя')
    return
  end

  -- Если из reply пришёл user_id, а записи в БД нет - берём данные прямо из reply.from
  if not targetUser and target.user_id and reply and reply.from and reply.from.id == target.user_id then
    targetUser = reply.from
  end

  if not targetUser then
    ctx:replyToMessage('🤷🏼‍♀️ Пользователь не найден в БД')
    return
  end

  -- Себя банить нельзя
  if targetUser.id == actor.id then
    ctx:replyToMessage('🤷🏼‍♀️ Себя забанить нельзя')
    return
  end

  -- Проверка прав actor над target
  local actorUic, actorUicErr = userInChatService.read(chat.id, actor.id)
  if actorUicErr then
    log.error(actorUicErr)
    return
  end

  local targetUic, targetUicErr = userInChatService.read(chat.id, targetUser.id)
  if targetUicErr then
    log.error(targetUicErr)
    return
  end

  -- Модераторов и выше /ban не трогает
  if auth.hasRoleAtLeast(targetUic, auth.roles.MODERATOR) then
    ctx:replyToMessage('⚠️ Нельзя забанить модератора!')
    return
  end

  if not auth.canActOn(actorUic, targetUic, 'can_restrict_members') then
    ctx:replyToMessage('⚠️ Недостаточно прав')
    return
  end

  -- Длительность опциональна: без неё уходит перманентный бан
  local untilDate, label
  if durationStr then
    untilDate, label = parseUntilDate(durationStr)
    if not untilDate then
      ctx:replyToMessage(USAGE)
      return
    end
  else
    label = 'навсегда'
  end

  -- Запоминаем реального админа ДО вызова API: апдейт chat_member, из
  -- которого строится мод-лог, может прийти раньше ответа на команду, а
  -- Telegram укажет в нём инициатором самого бота, а не админа.
  pendingModAction.set(chat.id, targetUser.id, 'ban', actor)

  local _, banErr = bot:banChatMember({
    chat_id = chat.id,
    user_id = targetUser.id,
    until_date = untilDate,
  })

  if banErr then
    log.verbose(banErr)

    if tgErrors.isIgnorable(banErr) then
      return
    end

    if missingRightsWarner.handleApiError(banErr, chat.id, ctx:getMessageId()) then
      return
    end

    ctx:replyToMessage('⚠️ Не удалось забанить')
    return
  end

  ctx:replyToMessage(SUCCESS_TEMPLATE:f({
    sep = hdec.sep,
    user = hdec.user(targetUser),
    userId = targetUser.id,
    duration = label,
  }))
end

return command
