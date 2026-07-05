--- Снятие бана пользователя в чате.
--
-- Варианты вызова:
--   /unban                 - ответом на сообщение
--   /unban 123456          - по user_id
--   /unban @oxniko         - по username
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local hdec = require('bot.libs.hdec')
local auth = require('src.auth')
local userInChatService = require('src.services.user_in_chat')
local resolveTargetUser = require('src.utils.resolveTargetUser')
local missingRightsWarner = require('src.utils.missingRightsWarner')
local tgErrors = require('src.utils.tgErrors')
local pendingModAction = require('src.utils.pendingModAction')

local command = Command:new {
  commands = { '/unban', 'разбан', 'анбан' },
  flags = {
    Command.enum.IN_CHAT,
    Command.enum.MODERATION,
  },
}

local USAGE = ([[
ℹ️ <b>Использование</b>
${sep}
<code>/unban</code> - ответом на сообщение
<code>/unban 123</code> - по user_id
<code>/unban @oxniko</code> - по username
]]):f({ sep = hdec.sep })

local SUCCESS_TEMPLATE = [[
✅ <b>Unban</b>
${sep}
👤 ${user} [<code>${userId}</code>]
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

--- Разбирает токены после "/unban".
-- Возвращает target = { user_id = N } | { username = "x" } | nil.
local function parseArgs(text)
  local tokens = {}
  for token in text:gmatch('%S+') do
    table.insert(tokens, token)
  end

  -- Первый токен - сама команда /unban, отбрасываем
  table.remove(tokens, 1)

  if #tokens == 0 then
    return nil
  end

  return asTarget(tokens[1])
end

function command.call(ctx)
  local message = ctx.message
  local reply = message.reply_to_message
  local chat = command.chat
  local actor = command.user

  local target = parseArgs(message.text)

  -- Если таргет не указан явно - берём из reply
  if not target and reply and reply.from then
    target = { user_id = reply.from.id }
  end

  if not target then
    ctx:replyToMessage(USAGE)
    return
  end

  local targetUser, lookupErr = resolveTargetUser(target)

  if lookupErr then
    log.error(lookupErr)
    ctx:replyToMessage('⚠️ Ошибка чтения пользователя')
    return
  end

  -- Если из reply пришёл user_id, а в БД нет - fallback на reply.from
  if not targetUser and target.user_id and reply and reply.from and reply.from.id == target.user_id then
    targetUser = reply.from
  end

  if not targetUser then
    ctx:replyToMessage('🤷🏼‍♀️ Пользователь не найден в БД')
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

  if not auth.canActOn(actorUic, targetUic, 'can_restrict_members') then
    ctx:replyToMessage('⚠️ Недостаточно прав')
    return
  end

  -- Запоминаем реального админа ДО вызова API: апдейт chat_member, из
  -- которого строится мод-лог, может прийти раньше ответа на команду, а
  -- Telegram укажет в нём инициатором самого бота, а не админа.
  pendingModAction.set(chat.id, targetUser.id, 'unban', actor)

  -- only_if_banned = true: если юзера сейчас нет в чате и он не забанен -
  -- unbanChatMember без этого флага считается приглашением, что нам не нужно
  local _, unbanErr = bot:unbanChatMember({
    chat_id = chat.id,
    user_id = targetUser.id,
    only_if_banned = true,
  })

  if unbanErr then
    log.verbose(unbanErr)

    if tgErrors.isIgnorable(unbanErr) then
      return
    end

    if missingRightsWarner.handleApiError(unbanErr, chat.id, ctx:getMessageId()) then
      return
    end

    ctx:replyToMessage('⚠️ Не удалось снять бан')
    return
  end

  ctx:replyToMessage(SUCCESS_TEMPLATE:f({
    sep = hdec.sep,
    user = hdec.user(targetUser),
    userId = targetUser.id,
  }))
end

return command
