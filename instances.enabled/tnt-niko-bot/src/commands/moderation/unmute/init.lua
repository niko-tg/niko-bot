--- Снятие ограничения пользователя в чате (unmute).
--
-- Варианты вызова:
--   /unmute                - ответом на сообщение
--   /unmute 123456         - по user_id
--   /unmute @oxniko        - по username
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

local command = Command:new({
  commands = { '/unmute', 'анмут' },
  flags = {
    Command.enum.IN_CHAT,
    Command.enum.MODERATION,
  },
})

local FULL_PERMS = {
  can_send_messages = true,
  can_send_audios = true,
  can_send_documents = true,
  can_send_photos = true,
  can_send_videos = true,
  can_send_video_notes = true,
  can_send_voice_notes = true,
  can_send_polls = true,
  can_send_other_messages = true,
  can_add_web_page_previews = true,
  can_change_info = true,
  can_invite_users = true,
  can_pin_messages = true,
  can_manage_topics = true,
}

local USAGE = ([[
ℹ️ <b>Использование</b>
${sep}
<code>/unmute</code> - ответом на сообщение
<code>/unmute 123</code> - по user_id
<code>/unmute @oxniko</code> - по username
]]):f({ sep = hdec.sep })

local SUCCESS_TEMPLATE = [[
🔊 <b>Unmute</b>
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

--- Разбирает токены после "/unmute".
-- Возвращает target = { user_id = N } | { username = "x" } | nil.
local function parseArgs(text)
  local tokens = {}
  for token in text:gmatch('%S+') do
    table.insert(tokens, token)
  end

  -- Первый токен - сама команда /unmute, отбрасываем
  table.remove(tokens, 1)

  if #tokens == 0 then
    return nil
  end

  return asTarget(tokens[1])
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
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
  if not targetUser and
    target.user_id and
    reply and
    reply.from and
    reply.from.id == target.user_id
  then
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
    ctx:replyToMessage('⚠️ Недостаточно прав или цель не ниже вас по рангу')
    return
  end

  local _, restrictErr = bot:restrictChatMember({
    chat_id = chat.id,
    user_id = targetUser.id,
    permissions = FULL_PERMS,
  })

  if restrictErr then
    log.verbose(restrictErr)

    if tgErrors.isIgnorable(restrictErr) then
      return
    end

    if missingRightsWarner.handleApiError(restrictErr, chat.id, ctx:getMessageId()) then
      return
    end

    ctx:replyToMessage('⚠️ Не удалось снять ограничение')
    return
  end

  ctx:replyToMessage(SUCCESS_TEMPLATE:f({
    sep = hdec.sep,
    user = hdec.user(targetUser),
    userId = targetUser.id,
  }))
end

return command
