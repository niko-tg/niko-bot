---
--
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local arguments_dict = require(bot.subdir(2, ...)..'.arguments_dict')

local TEMPLATE = ([[
👑 <b>Настройки</b>
${sep}
<b>ON</b>: Включено
<b>OFF</b>: Выключено
${sep}
Удаление ссылок: ${has_delete_links}
Запрет пересылать в чат: ${has_delete_forward_message}
Запрет писать от лица чатов: ${has_ban_sender_chat}
]]):f({ sep = hdec.sep })

local function flagToText(flag)
  if flag then
    return 'ON'
  end

  return 'OFF'
end

local function showVipSettingsPage(ctx, arguments, pchat)
  if arguments.action ~= 'show' then
    return
  end

  local hasDeleteLinks = pchat.settings.has_delete_links
  local hasDeleteForwardMessage = pchat.settings.has_delete_forward_message
  local hasBanSenderChat = pchat.settings.has_ban_sender_chat

  local template = TEMPLATE:f({
    sep = hdec.sep,
    has_delete_links = flagToText(hasDeleteLinks),
    has_delete_forward_message = flagToText(hasDeleteForwardMessage),
    has_ban_sender_chat = flagToText(hasBanSenderChat),
  })

  local keyboard = inlineCallbackKeyboard({
    {
      text = ('Удаление ссылок: ${has_delete_links}'):f({
        has_delete_links = flagToText(hasDeleteLinks)
      }),
      callback = {
        command = 'cb_set_setting',
        arguments = {
          page = arguments_dict.page.vip_settings,
          param = arguments_dict.param.has_delete_links,
          value = tostring(not hasDeleteLinks)
        }
      }
    },

    {
      text = ('Запрет пересылать в чат: ${has_delete_forward_message}'):f({
        has_delete_forward_message = flagToText(hasDeleteForwardMessage)
      }),
      callback = {
        command = 'cb_set_setting',
        arguments = {
          page = arguments_dict.page.vip_settings,
          param = arguments_dict.param.has_delete_forward_message,
          value = tostring(not hasDeleteForwardMessage)
        }
      }
    },

    {
      text = ('Запрет писать от лица чатов: ${has_ban_sender_chat}'):f({
        has_ban_sender_chat = flagToText(hasBanSenderChat)
      }),
      callback = {
        command = 'cb_set_setting',
        arguments = {
          page = arguments_dict.page.vip_settings,
          param = arguments_dict.param.has_ban_sender_chat,
          value = tostring(not hasBanSenderChat)
        }
      }
    },

    {
      text = '◀️ Назад',
      callback = {
        command = 'cb_settings',
        arguments = {
          page = 'main',
          action = 'edit'
        }
      }
    },
  })

  bot:editMessageText({
    text = template,
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    reply_markup = keyboard,
  })
end

return showVipSettingsPage
