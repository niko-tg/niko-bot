--- Помощь по боту: ссылки на чат/новости/гайды + отсылка к списку команд.
--
local Command = require('bot.classes.Command')
local hdec = require('bot.libs.hdec')
local config = require('conf.config')
local inlineKeyboard = require('bot.middlewares.inlineKeyboard')

local command = Command:new {
  commands = { '/help', 'помощь' },
  flags = { Command.enum.PRIVATE },
}

local HELP = ([[
🤓 <b>Помощь по Нико</b>
${sep}
📋 Все команды бота: /commands
${sep}
Полезные ссылки — на кнопках ниже 👇
]]):f({ sep = hdec.sep })

-- Кнопки-ссылки (статичны, берём из config.links).
local keyboard = inlineKeyboard({
  {
    { text = '🏠 Чат', url = config.links.chat },
    { text = '🗞 Новости', url = config.links.news },
  },
  { { text = '📄 Гайд по боту', url = config.links.guide } },
  { { text = '👮 Команды модерации', url = config.links.mod_guide } },
})

function command.call(ctx)
  ctx:reply({
    text = HELP,
    reply_markup = keyboard,
  })
end

return command
