--- Стартовая команда: приветствие при первом запуске + экран с приглашением
--- добавить бота в чат и кнопкой короткого гайда.
--
local log = require('log')
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local config = require('conf.config')
local Command = require('bot.classes.Command')
local inlineKeyboard = require('bot.middlewares.inlineKeyboard')
local usersService = require('src.services.users')

local command = Command:new {
  commands = { '/start' },
  flags = { Command.enum.PRIVATE },
}

local START = ([[
🐲 <b>Нико — игровой бот для чатов</b>
${sep}
<b>1.</b> Загляни в наш чат и новости
<b>2.</b> /help — помощь
<b>3.</b> /commands — все команды
${sep}
<b> Добавь меня в свой чат и назначь админом — кнопка ниже 👇</b>
]]):f({ sep = hdec.sep })

-- Клавиатура старта: добавить в группу, короткий гайд, ссылки.
local function startKeyboard()
  return inlineKeyboard({
    {
      {
        text = '👉 Добавить в группу 👈',
        url = ('https://t.me/${u}?startgroup=true'):f({ u = bot.username }),
      }
    },
    { { text = '📜 Короткий гайд', callback = 'cb_start_guide' } },
    {
      { text = '🏠 Чат', url = config.links.chat },
      { text = '🗞 Новости', url = config.links.news },
    },
  })
end

-- Экран старта (фото + приглашение + кнопки).
local function sendStart(chatId)
  bot:sendPhoto({
    chat_id = chatId,
    photo = config.bot.url_assets..'start/start.jpeg?v=2',
    caption = START,
    reply_markup = startKeyboard(),
    link_preview_options = { is_disabled = true },
  })
end

function command.call(ctx)
  local user = command.user
  local chatId = ctx:getChatId()

  -- Первый запуск: приветствие + отметка флага.
  if not user.is_started_bot then
    local _, err = usersService.update({ is_started_bot = true }, { id = user.id })
    if err then
      log.error(err)
    end
  end

  sendStart(chatId)
end

return command
