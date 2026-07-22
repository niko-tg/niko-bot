--- Callback короткого гайда: меняет подпись стартового фото на обзор возможностей.
--
local log = require('log')
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local config = require('conf.config')
local Command = require('bot.classes.Command')
local inlineKeyboard = require('bot.middlewares.inlineKeyboard')

local command = Command:new({
  commands = { 'cb_start_guide' },
  flags = { Command.enum.CALLBACK },
})

local GUIDE = ([[
🐲 <b>Что умеет Нико</b>
${sep}
🦄 Питомцы — заведи и ухаживай
🎮 Мини-игры — мины, слот, пазл, PVP
⛏ Добыча — рыбалка, рудник, лесопилка
🎒 Инвентарь, крафт, магазин
💒 Браки | 🎭 друзья | ❤️ лайки | 😈 куси
⚙️ Модерация своего чата
${sep}
<b>Команды</b>
/commands — все команды
/profile — профиль
/bonus — ежедневный бонус
/zoo_shop — зоомагазин
/donat — донат и VIP
${sep}
🏠 <a href="${chat}">Чат</a> · 🗞 <a href="${news}">Новости</a>
]]):f({ sep = hdec.sep, chat = config.links.chat, news = config.links.news })

--- Клавиатура гайда: кнопка добавления бота в группу.
-- @treturn table разметка клавиатуры
local function guideKeyboard()
  return inlineKeyboard({
    {
      {
        text = '👉 Добавить в группу 👈',
        url = ('https://t.me/${u}?startgroup=true'):f({ u = bot.username }),
      },
    },
  })
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  ctx:answer()

  local _, err = bot:editMessageCaption({
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    caption = GUIDE,
    reply_markup = guideKeyboard(),
  })

  if err then
    log.verbose(err)
  end
end

return command
