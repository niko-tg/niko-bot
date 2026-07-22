--- Страница со списком чатов пользователя для привязки логов модерации.
--
local log = require('log')
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')
local chatService = require('src.services.chats')
local userInChatService = require('src.services.user_in_chat')
local chat_member_status = require('bot.enums.chat_member_status')

local TEMPLATE = ([[
<b>Модераторский чат</b>
${sep}
Выберите чат, логи модерации которого будут приходить сюда.
${sep}
✅ Чат уже привязан к этому модераторскому чату (нажмите ещё раз, чтобы отвязать).
]]):f({ sep = hdec.sep })

local EMPTY_TEMPLATE = ([[
<b>Модераторский чат</b>
${sep}
У вас нет других чатов, где вы являетесь владельцем.
]]):f({ sep = hdec.sep })

--- Подпись кнопки: Eсли чат уже шлёт логи в этот модераторский чат.
-- Текст кнопки - Это plain text, HTML тут не работает, поэтому название сырое.
local function chatButtonText(chat, moderationChatId)
  local title = (chat.title ~= nil and chat.title ~= '') and chat.title or tostring(chat.id)

  if chat.moderation_chat_id == moderationChatId then
    return '✅ '..title
  end

  return title
end

--- Отправить новое сообщение (reply) или обновить текущее (edit).
local function render(ctx, action, text, keyboard)
  if action == 'edit' then
    bot:editMessageText({
      text = text,
      chat_id = ctx:getChatId(),
      message_id = ctx:getMessageId(),
      reply_markup = keyboard,
    })

    return
  end

  ctx:replyToMessage({
    text = text,
    reply_markup = keyboard,
  })
end

--- text + футер в конце (если задан), иначе просто text.
local function appendFooter(text, footer)
  if footer then
    return text..footer
  end

  return text
end

--- Показ списка чатов, доступных модератору.
-- @tparam table ctx контекст обновления
-- @tparam table arguments аргументы callback-кнопки
-- @tparam table command описание команды
local function showChatList(ctx, arguments, command)
  local action = arguments and arguments.action
  local footer = arguments and arguments.footer

  local ownedChats, err = userInChatService.getByUserStatus(command.user.id, chat_member_status.CREATOR)

  if err then
    log.error(err)
    return
  end

  local buttons = {}

  ownedChats = ownedChats or {}
  for i = 1, #ownedChats do
    local uic = ownedChats[i]
    -- Сам модераторский чат в список не добавляем - привязка к себе бессмысленна
    if uic.chat_id ~= command.chat.id then
      local chat, chatErr = chatService.read(uic.chat_id)

      if chatErr then
        log.error(chatErr)
      elseif chat then
        table.insert(buttons, {
          text = chatButtonText(chat, command.chat.id),
          callback = {
            command = 'cb_modlog',
            arguments = { chat_id = chat.id },
          },
        })
      end
    end
  end

  if #buttons == 0 then
    render(ctx, action, appendFooter(EMPTY_TEMPLATE, footer), nil)
    return
  end

  render(ctx, action, appendFooter(TEMPLATE, footer), inlineCallbackKeyboard(buttons))
end

return showChatList
