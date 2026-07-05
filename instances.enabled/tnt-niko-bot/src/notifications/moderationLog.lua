--- Лог модерации в привязанный мод-чат: бан / разбан / мут.
--[[
Инициатор берётся из chat_member.from.
Но для действий через команды бота Telegram ставит инициатором самого бота -
тогда реального админа берём из pendingModAction (команда кладёт его туда перед вызовом API).
Если действие сделал сам бот, а записи нет (авто-ограничение антифлуда) -
в мод-чат не пишем, чтобы не сорить "бот ограничил".
Если бот удалён из мод-чата (chat not found) - verbose, не error.
--]]
local log = require('log')
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local tgErrors = require('src.utils.tgErrors')
local sendQueue = require('bot.libs.sendQueue')
local pendingModAction = require('src.utils.pendingModAction')

-- Очередь логов: не чаще одного сообщения в 1.1с на чат (per-chat лимит
-- Telegram), при переполнении новые сообщения отбрасываются.
local queue = sendQueue.new({ interval = 1.1, max_queue = 100 })

local BAN_TEMPLATE = ([[
⛔ <i><b>Блокировка участника</b></i>
${sep}
🏘 <b>Чат:</b> ${chat}
👮 <b>Админ:</b> [<code>${actor_id}</code>] ${actor}
👤 <b>Участник:</b> [<code>${target_id}</code>] ${target}
⏳ <b>Дата:</b> ${duration}
]]):f({ sep = hdec.sep })

local UNBAN_TEMPLATE = ([[
🔓 <i><b>Разблокировка участника</b></i>
${sep}
🏘 <b>Чат:</b> [<code>${chat_id}</code>] ${chat}
👮 <b>Админ:</b> [<code>${actor_id}</code>] ${actor}
👤 <b>Участник:</b> [<code>${target_id}</code>] ${target}
]]):f({ sep = hdec.sep })

local MUTE_TEMPLATE = ([[
🔇 <i><b>Ограничение участника</b></i>
${sep}
🏘 <b>Чат:</b> [<code>${chat_id}</code>] ${chat}
👮 <b>Админ:</b> [<code>${actor_id}</code>] ${actor}
👤 <b>Участник:</b> [<code>${target_id}</code>] ${target}
⏳ <b>Дата:</b> ${duration}
]]):f({ sep = hdec.sep })

local PROMOTE_TEMPLATE = ([[
⬆️ <i><b>Повышение до администратора</b></i>
${sep}
🏘 <b>Чат:</b> [<code>${chat_id}</code>] ${chat}
👮 <b>Админ:</b> [<code>${actor_id}</code>] ${actor}
👤 <b>Участник:</b> [<code>${target_id}</code>] ${target}
]]):f({ sep = hdec.sep })

local DEMOTE_TEMPLATE = ([[
⬇️ <i><b>Понижение участника</b></i>
${sep}
🏘 <b>Чат:</b> [<code>${chat_id}</code>] ${chat}
👮 <b>Админ:</b> [<code>${actor_id}</code>] ${actor}
👤 <b>Участник:</b> [<code>${target_id}</code>] ${target}
]]):f({ sep = hdec.sep })

--- id привязанного мод-чата либо nil, если привязки нет.
local function resolveModChatId(chat)
  local modChatId = chat.moderation_chat_id

  if modChatId == nil or modChatId == box.NULL then
    return nil
  end

  return modChatId
end

--- Длительность бана из until_date (unix). 0/nil - навсегда.
local function banDuration(untilDate)
  if not untilDate or untilDate == 0 then
    return 'Навсегда'
  end

  return 'до '..os.date('%d.%m.%Y %H:%M', untilDate)
end

-- Бот удалён из мод-чата (chat not found) - не ошибка, просто verbose.
local function onSendError(err)
  if tgErrors.isChatNotFound(err) then
    log.verbose(err)
  else
    log.error(err)
  end
end

--- Постановка лога в очередь отправки в мод-чат.
local function send(modChatId, text)
  queue:push({
    chat_id = modChatId,
    text = text,
    link_preview_options = { is_disabled = true },
  }, onSendError)
end

--- Реальный инициатор действия модерации.
--
-- Если действие выполнил не бот (from != бот) - это нативный клиент
-- Telegram, в from настоящий человек, его и возвращаем.
--
-- Если действие выполнил сам бот - значит это команда модерации
-- (тогда админ лежит в pendingModAction, команда положила его перед вызовом API)
-- либо авто-ограничение антифлуда (записи нет).
-- Во втором случае возвращаем nil - такой лог в мод-чат слать не нужно.
local function resolveActor(ctx, chatId, userId, action)
  local from = ctx:getUserFrom()
  local botId = bot:getBotId()

  if not botId or from.id ~= botId then
    return from
  end

  return pendingModAction.take(chatId, userId, action)
end

local M = {}

--- Лог бана. chat - модель Chat чата-источника (нужен moderation_chat_id).
function M.banned(ctx, chat)
  local modChatId = resolveModChatId(chat)

  if not modChatId then
    return
  end

  -- Для отображения берём сырой чат из апдейта: там username - честный nil,
  -- а не box.NULL модели (иначе hdec.chat упадёт на format).
  local sourceChat = ctx:getChat()
  local newChatMember = ctx:getNewChatMember()
  local target = newChatMember.user

  local actor = resolveActor(ctx, sourceChat.id, target.id, 'ban')
  if not actor then
    return
  end

  send(modChatId, BAN_TEMPLATE:f({
    chat = hdec.chat(sourceChat),
    chat_id = sourceChat.id,
    target = hdec.user(target),
    target_id = target.id,
    actor = hdec.user(actor),
    actor_id = actor.id,
    duration = banDuration(newChatMember.until_date),
  }))
end

--- Лог разбана. chat - модель Chat чата-источника (нужен moderation_chat_id).
function M.unbanned(ctx, chat)
  local modChatId = resolveModChatId(chat)

  if not modChatId then
    return
  end

  local sourceChat = ctx:getChat()
  local target = ctx:getNewChatMember().user

  local actor = resolveActor(ctx, sourceChat.id, target.id, 'unban')
  if not actor then
    return
  end

  send(modChatId, UNBAN_TEMPLATE:f({
    chat = hdec.chat(sourceChat),
    chat_id = sourceChat.id,
    target = hdec.user(target),
    target_id = target.id,
    actor_id = actor.id,
    actor = hdec.user(actor),
  }))
end

--- Лог мута (ограничения). chat - модель Chat чата-источника.
function M.muted(ctx, chat)
  local modChatId = resolveModChatId(chat)

  if not modChatId then
    return
  end

  local sourceChat = ctx:getChat()
  local newChatMember = ctx:getNewChatMember()
  local target = newChatMember.user

  local actor = resolveActor(ctx, sourceChat.id, target.id, 'mute')
  if not actor then
    return
  end

  send(modChatId, MUTE_TEMPLATE:f({
    chat = hdec.chat(sourceChat),
    chat_id = sourceChat.id,
    target = hdec.user(target),
    target_id = target.id,
    actor = hdec.user(actor),
    actor_id = actor.id,
    duration = banDuration(newChatMember.until_date),
  }))
end

--- Лог повышения до администратора. chat - модель Chat чата-источника.
function M.promoted(ctx, chat)
  local modChatId = resolveModChatId(chat)

  if not modChatId then
    return
  end

  local sourceChat = ctx:getChat()
  local target = ctx:getNewChatMember().user
  local actor = ctx:getUserFrom()

  send(modChatId, PROMOTE_TEMPLATE:f({
    chat = hdec.chat(sourceChat),
    chat_id = sourceChat.id,
    target = hdec.user(target),
    target_id = target.id,
    actor = hdec.user(actor),
    actor_id = actor.id,
  }))
end

--- Лог понижения (снятия админки). chat - модель Chat чата-источника.
function M.demoted(ctx, chat)
  local modChatId = resolveModChatId(chat)

  if not modChatId then
    return
  end

  local sourceChat = ctx:getChat()
  local target = ctx:getNewChatMember().user
  local actor = ctx:getUserFrom()

  send(modChatId, DEMOTE_TEMPLATE:f({
    chat = hdec.chat(sourceChat),
    chat_id = sourceChat.id,
    target = hdec.user(target),
    target_id = target.id,
    actor = hdec.user(actor),
    actor_id = actor.id,
  }))
end

return M
