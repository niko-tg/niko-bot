--- Ограничение пользователя в чате (mute).
--
-- Варианты вызова:
--   /mute                  - ответом на сообщение, 5 минут
--   /mute 3ч               - ответом, на 3 часа
--   /mute 123456 12ч       - по user_id
--   /mute @oxniko 100m     - по username
--
-- Юниты длительности (см. utils/parseUntilDate):
--   м/m - минуты, ч/h - часы, д/d - дни.
-- Если длительность не указана - дефолт 5 минут.
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

local command = Command:new({
  commands = { '/mute', 'мут' },
  flags = {
    Command.enum.IN_CHAT,
    Command.enum.MODERATION,
  },
})

local READ_ONLY_PERMS = {
  can_send_messages = false,
  can_send_audios = false,
  can_send_documents = false,
  can_send_photos = false,
  can_send_videos = false,
  can_send_video_notes = false,
  can_send_voice_notes = false,
  can_send_polls = false,
  can_send_other_messages = false,
  can_add_web_page_previews = false,
  can_change_info = false,
  can_invite_users = false,
  can_pin_messages = false,
  can_manage_topics = false,
}

local USAGE = ([[
ℹ️ <b>Использование</b>
${sep}
<code>/mute</code> - ответом, 5 мин
<code>/mute 3ч</code> - ответом, 3 часа
<code>/mute 123456789 12ч</code> - по user_id
<code>/mute @oxniko 100m</code> - по username

Юниты: м/m, ч/h, д/d
]]):f({ sep = hdec.sep })

local SUCCESS_TEMPLATE = [[
🔇 <b>Mute</b>
${sep}
👤 ${user} [<code>${userId}</code>]
⏳ ${duration}
]]

--- Разбирает токен в таргет: @username -> { username }, число -> { user_id }.
-- Возвращает nil если токен не похож ни на одно, ни на другое.
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

--- Разбирает токены после "/mute".
-- Возвращает (target, durationStr):
--   target == { user_id = N } | { username = "x" } | nil
--   durationStr - строка для parseUntilDate либо nil
--
-- Контракт:
--   2 токена          - первый таргет, второй длительность
--   1 токен + reply   - длительность для reply-таргета
--   1 токен без reply - таргет, длительность дефолтная
--   0 токенов         - reply + дефолтная длительность
local function parseArgs(text, hasReply)
  local tokens = {}
  for token in text:gmatch('%S+') do
    table.insert(tokens, token)
  end

  -- Первый токен - это сама команда /mute, отбрасываем
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

--- Точка входа команды.
-- @tparam table ctx контекст обновления
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

  -- Лукап целевого юзера в БД
  local targetUser, lookupErr = resolveTargetUser(target)

  if lookupErr then
    log.error(lookupErr)
    ctx:replyToMessage('⚠️ Ошибка чтения пользователя')
    return
  end

  -- Если из reply пришёл user_id, а записи в БД нет - берём данные прямо из reply.from,
  -- чтобы можно было замутить незнакомого боту юзера (id всё равно валидный)
  if not targetUser and target.user_id and reply and reply.from and reply.from.id == target.user_id then
    targetUser = reply.from
  end

  if not targetUser then
    ctx:replyToMessage('🤷🏼‍♀️ Пользователь не найден в БД')
    return
  end

  -- Сам себя замутить нельзя
  if targetUser.id == actor.id then
    ctx:replyToMessage('🤷🏼‍♀️ Себя замутить нельзя')
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

  -- Модераторов и выше /mute не трогает: от админов их защищаем явно,
  -- а у обычных юзеров и так нет ранга чтобы дойти до canActOn ниже
  if auth.hasRoleAtLeast(targetUic, auth.roles.MODERATOR) then
    ctx:replyToMessage('⚠️ Нельзя выдать ограничение модератору!')
    return
  end

  if not auth.canActOn(actorUic, targetUic, 'can_restrict_members') then
    ctx:replyToMessage('⚠️ Недостаточно прав')
    return
  end

  local untilDate, label = parseUntilDate(durationStr)
  if not untilDate then
    ctx:replyToMessage(USAGE)
    return
  end

  -- Запоминаем реального админа ДО вызова API: апдейт chat_member -
  -- из которого строится мод-лог, может прийти раньше ответа на команду,
  -- а Telegram укажет в нём инициатором самого бота, а не админа.
  pendingModAction.set(chat.id, targetUser.id, 'mute', actor)

  local _, restrictErr = bot:restrictChatMember({
    chat_id = chat.id,
    user_id = targetUser.id,
    permissions = READ_ONLY_PERMS,
    until_date = untilDate,
  })

  if restrictErr then
    log.verbose(restrictErr)

    if tgErrors.isIgnorable(restrictErr) then
      return
    end

    if missingRightsWarner.handleApiError(restrictErr, chat.id, ctx:getMessageId()) then
      return
    end

    ctx:replyToMessage('⚠️ Не удалось применить ограничение')
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
