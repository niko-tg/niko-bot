--- Репорт модераторам.
--
-- /report <текст>            - репорт с текстом
-- /report <текст> (реплеем)  - + копия сообщения и кнопка-ссылка на него
--
-- Уходит в привязанный мод-чат (chat.moderation_chat_id), а если он не задан -
-- в ЛС всем админам чата (владелец + администраторы).
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local hdec = require('bot.libs.hdec')
local tgErrors = require('src.utils.tgErrors')
local sendQueue = require('bot.libs.sendQueue')
local userInChatService = require('src.services.user_in_chat')
local chat_member_status = require('bot.enums.chat_member_status')
local chat_type = require('bot.enums.chat_type')

local command = Command:new({
  commands = { '/report', 'репорт', 'жалоба' },
  flags = { Command.enum.IN_CHAT },
})

local USAGE = ([[
ℹ️ <b>Репорт модераторам</b>
${sep}
<code>/report текст</code> - что не так
Можно ответом на сообщение нарушителя.
]]):f({ sep = hdec.sep })

local TEMPLATE = [[
🚨 <b>Репорт</b>
${sep}
🏘 <b>Чат:</b> ${chat}
🙋 <b>От:</b> [<code>${reporterId}</code>] ${reporter}${reported}
${sep}
💬 ${text}
]]

--- Текст после команды (без крайних пробелов) или nil.
local function reportText(text)
  local rest = text:match('^%S+%s+(.+)$')

  if not rest then
    return nil
  end

  return (rest:gsub('%s+$', ''))
end

--- Ссылка на сообщение в чате (t.me) или nil, если чат её не поддерживает.
local function messageLink(sourceChat, messageId)
  if sourceChat.username then
    return ('https://t.me/%s/%s'):format(sourceChat.username, messageId)
  end

  if sourceChat.type == chat_type.SUPERGROUP then
    -- приватный супергруппа: -100XXXX -> XXXX
    local shortId = tostring(sourceChat.id):gsub('^-100', '')
    return ('https://t.me/c/%s/%s'):format(shortId, messageId)
  end

  return nil
end

--- ЛС-получатели в фолбэке: владелец + администраторы (без бота и анонимов).
local function collectAdminIds(chatId)
  local ids = {}
  local botId = bot:getBotId()

  local statuses = { chat_member_status.CREATOR, chat_member_status.ADMINISTRATOR }
  for i = 1, #statuses do
    local status = statuses[i]
    local list, err = userInChatService.getByStatus(chatId, status)

    if err then
      return ids, err
    end

    list = list or {}
    for j = 1, #list do
      local uic = list[j]
      local perms = uic.permissions or {}

      if uic.user_id ~= botId and not perms.is_anonymous then
        table.insert(ids, uic.user_id)
      end
    end
  end

  return ids
end

-- Та же настройка, что у мод-логов: per-chat ~1 сообщение в 1.1с.
local queue = sendQueue.new({ interval = 1.1, max_queue = 20 })

--- Ошибка отправки: ЛС недоступна (бот заблокирован / не запущен админом /
-- админ - бот) либо чат не найден - штатные отказы, не ошибка.
local function onSendError(err)
  if tgErrors.isPMUnavailable(err) or tgErrors.isChatNotFound(err) then
    log.verbose(err)
  else
    log.error(err)
  end
end

--- Постановка репорта в очередь отправки одному получателю.
local function deliver(destId, headerText, markup)
  queue:push({
    chat_id = destId,
    text = headerText,
    reply_markup = markup,
    link_preview_options = { is_disabled = true },
  }, onSendError)
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local message = ctx.message
  local reply = message.reply_to_message
  local sourceChat = ctx:getChat()
  local reporter = command.user

  local text = reportText(message.text)

  if not text then
    ctx:replyToMessage(USAGE)
    return
  end

  -- На кого репорт (если reply на пользователя)
  local reported = ''
  if reply and reply.from then
    reported = ('\n👤 <b>На:</b> [<code>%s</code>] %s'):format(reply.from.id, hdec.user(reply.from))
  end

  local headerText = TEMPLATE:f({
    sep = hdec.sep,
    chat = hdec.chat(sourceChat),
    reporter = hdec.user(reporter),
    reporterId = reporter.id,
    reported = reported,
    text = hdec.escape(text),
  })

  -- Кнопка-ссылка (только при reply и если чат её поддерживает)
  local markup
  if reply then
    local link = messageLink(sourceChat, reply.message_id)

    if link then
      markup = { inline_keyboard = {{ { text = '🔗 К сообщению', url = link } }} }
    end
  end

  -- Назначение: мод-чат либо ЛС админам
  local modChatId = command.chat.moderation_chat_id

  if modChatId ~= nil and modChatId ~= box.NULL then
    deliver(modChatId, headerText, markup)
  else
    local adminIds, err = collectAdminIds(command.chat.id)

    if err then
      log.error(err)
      ctx:replyToMessage('⚠️ Не удалось отправить репорт')
      return
    end

    if #adminIds == 0 then
      ctx:replyToMessage('🤷🏼‍♀️ Некому отправить репорт (нет админов)')
      return
    end

    for i = 1, #adminIds do
      local adminId = adminIds[i]
      deliver(adminId, headerText, markup)
    end
  end

  ctx:replyToMessage('✅ Репорт отправлен')
end

return command
