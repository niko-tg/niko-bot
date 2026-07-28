--- Страница настроек чата: переключатели модерации и антифлуда.
--
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local arguments_dict = require(bot.subdir(2, ...)..'.arguments_dict')

local TEMPLATE = ([[
⚙️ <b>Настройки чата</b>
${sep}
<b>ON</b>: Включено
<b>OFF</b>: Выключено
${sep}
⚠️ Модераторские команды: <b>${has_enable_moderation_commands}</b>
  * При <b>OFF</b> - будут выключены все настройки.
${sep}
Антифлуд: <b>${has_enable_antiflood}</b>
Капча для новых участников: <b>${has_enable_captcha}</b>
Удаление ссылок: <b>${has_delete_links}</b>
Запрет пересылать в чат: <b>${has_delete_forward_message}</b>
Запрет писать от лица чатов: <b>${has_ban_sender_chat}</b>
${sep}
Для изменения параметра - нажмите на него.
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
local function showChatSettings(ctx, arguments, pchat)
  if arguments.action ~= 'show' then
    return
  end

  local hasEnableAntiflood = pchat.settings.has_enable_antiflood
  local hasEnableModerationCommands = pchat.settings.has_enable_moderation_commands
  local hasEnableCaptcha = pchat.settings.has_enable_captcha
  local hasDeleteLinks = pchat.settings.has_delete_links
  local hasDeleteForwardMessage = pchat.settings.has_delete_forward_message
  local hasBanSenderChat = pchat.settings.has_ban_sender_chat

  local template = TEMPLATE:f({
    sep = hdec.sep,
    has_enable_antiflood = flagToText(hasEnableAntiflood),
    has_enable_moderation_commands = flagToText(hasEnableModerationCommands),
    has_enable_captcha = flagToText(hasEnableCaptcha),
    has_delete_links = flagToText(hasDeleteLinks),
    has_delete_forward_message = flagToText(hasDeleteForwardMessage),
    has_ban_sender_chat = flagToText(hasBanSenderChat),
  })

  local keyboard = inlineCallbackKeyboard({
    {
      text = ('Антифлуд: ${has_enable_antiflood}'):f({
        has_enable_antiflood = flagToText(hasEnableAntiflood),
      }),
      callback = {
        command = 'cb_set_setting',
        arguments = {
          page = arguments_dict.page.settings,
          param = arguments_dict.param.has_enable_antiflood,
          value = tostring(not hasEnableAntiflood),
        },
      },
    },

    {
      text = ('Капча: ${has_enable_captcha}'):f({
        has_enable_captcha = flagToText(hasEnableCaptcha),
      }),
      callback = {
        command = 'cb_set_setting',
        arguments = {
          page = arguments_dict.page.settings,
          param = arguments_dict.param.has_enable_captcha,
          value = tostring(not hasEnableCaptcha),
        },
      },
    },

    {
      text = ('Удаление ссылок: ${has_delete_links}'):f({
        has_delete_links = flagToText(hasDeleteLinks),
      }),
      callback = {
        command = 'cb_set_setting',
        arguments = {
          page = arguments_dict.page.settings,
          param = arguments_dict.param.has_delete_links,
          value = tostring(not hasDeleteLinks),
        },
      },
    },

    {
      text = ('Запрет пересылать в чат: ${has_delete_forward_message}'):f({
        has_delete_forward_message = flagToText(hasDeleteForwardMessage),
      }),
      callback = {
        command = 'cb_set_setting',
        arguments = {
          page = arguments_dict.page.settings,
          param = arguments_dict.param.has_delete_forward_message,
          value = tostring(not hasDeleteForwardMessage),
        },
      },
    },

    {
      text = ('Запрет писать от лица чатов: ${has_ban_sender_chat}'):f({
        has_ban_sender_chat = flagToText(hasBanSenderChat),
      }),
      callback = {
        command = 'cb_set_setting',
        arguments = {
          page = arguments_dict.page.settings,
          param = arguments_dict.param.has_ban_sender_chat,
          value = tostring(not hasBanSenderChat),
        },
      },
    },

    {
      text = ('Модераторские команды: ${has_enable_moderation_commands}'):f({
        has_enable_moderation_commands = flagToText(hasEnableModerationCommands),
      }),
      callback = {
        command = 'cb_set_setting',
        arguments = {
          page = arguments_dict.page.settings,
          param = arguments_dict.param.has_enable_moderation_commands,
          value = tostring(not hasEnableModerationCommands),
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

  bot:editMessageText({
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    text = template,
    reply_markup = keyboard,
  })
end

return showChatSettings
