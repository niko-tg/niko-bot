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
Антифлуд: ${has_enable_antiflood}
Модераторские команды: ${has_enable_moderation_commands}
Капча для новых участников: ${has_enable_captcha}
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
local function showVipSettingsPage(ctx, arguments, pchat)
  if arguments.action ~= 'show' then
    return
  end

  local hasEnableAntiflood = pchat.settings.has_enable_antiflood
  local hasEnableModerationCommands = pchat.settings.has_enable_moderation_commands
  local hasEnableCaptcha = pchat.settings.has_enable_captcha

  local template = TEMPLATE:f({
    sep = hdec.sep,
    has_enable_antiflood = flagToText(hasEnableAntiflood),
    has_enable_moderation_commands = flagToText(hasEnableModerationCommands),
    has_enable_captcha = flagToText(hasEnableCaptcha),
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

return showVipSettingsPage
