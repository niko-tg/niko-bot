--- Страница настройки приветственного сообщения.
--
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local arguments_dict = require(bot.subdir(2, ...)..'.arguments_dict')

local TEMPLATE = ([[
💬 <b>Приветственное сообщение</b>
${sep}
Это такое сообщение, которые нужно настроить через команду: /mkhello
Бот будет привествовать новых участников чата
${sep}
<b>ON</b>: Включено
<b>OFF</b>: Выключено
${sep}
Включено?: ${has_enable_hello_message}
]]):f({ sep = hdec.sep })

--- Подпись переключателя настройки.
-- @tparam boolean flag значение настройки
-- @treturn string 'ON' либо 'OFF'
local function flagToText(flag)
  if flag then
    return 'ON'
  end

  return 'OFF'
end

--- Показ страницы настроек.
-- @tparam table ctx контекст обновления
-- @tparam table arguments аргументы callback-кнопки
-- @tparam table pchat модель чата с настройками
local function showHelloMessagePage(ctx, arguments, pchat)
  if arguments.action ~= 'show' then
    return
  end

  local hasEnableHelloMessage = pchat.settings.has_enable_hello_message

  local keyboard = inlineCallbackKeyboard({
    {
      text = ('Приветственное: ${has_enable_hello_message}'):f({
        has_enable_hello_message = flagToText(hasEnableHelloMessage),
      }),
      callback = {
        command = 'cb_set_setting',
        arguments = {
          page = arguments_dict.page.hello_message,
          param = arguments_dict.param.has_enable_hello_message,
          value = tostring(not hasEnableHelloMessage),
        },
      },
    },
    {
      text = '◀️ Назад',
      callback = {
        command = 'cb_settings',
        arguments = {
          page = 'main',
          action = 'edit',
        },
      },
    },
  })

  local template = TEMPLATE:f({
    has_enable_hello_message = flagToText(hasEnableHelloMessage),
  })

  bot:editMessageText({
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    text = template,
    reply_markup = keyboard,
  })
end

return showHelloMessagePage
