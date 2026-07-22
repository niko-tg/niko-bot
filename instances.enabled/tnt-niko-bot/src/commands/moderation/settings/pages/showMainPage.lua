--- Главная страница настроек чата: выбор раздела.
--
local bot = require('bot')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local TEMPLATE = [[
<b>Настройки</b>
]]

--- Показ главной страницы настроек.
-- @tparam table ctx контекст обновления
-- @tparam table arguments аргументы callback-кнопки
local function showMainPage(ctx, arguments)
  local keyboard = inlineCallbackKeyboard({
    {
      text = '⚙️ Настройки',
      callback = {
        command = 'cb_settings',
        arguments = {
          page = 'settings',
          action = 'show',
        },
      },
    },
    {
      text = '👑 VIP настройки',
      callback = {
        command = 'cb_settings',
        arguments = {
          page = 'vip_settings',
          action = 'show',
        },
      },
    },
    {
      text = '💬 Приветственное сообщение',
      callback = {
        command = 'cb_settings',
        arguments = {
          page = 'hello_message',
          action = 'show',
        },
      },
    },
  })

  if arguments and arguments.action == 'edit' then
    bot:editMessageText({
      text = TEMPLATE,
      chat_id = ctx:getChatId(),
      message_id = ctx:getMessageId(),
      reply_markup = keyboard,
    })

    return
  end

  ctx:replyToMessage({
    text = TEMPLATE,
    reply_markup = keyboard,
  })
end

return showMainPage