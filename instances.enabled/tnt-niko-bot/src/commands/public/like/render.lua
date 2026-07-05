--- Рендер установки лайка.
--
local hdec = require('bot.libs.hdec')

local render = {}

local USAGE = ([[
ℹ️ <b>Лайк</b>
${sep}
Ответь на сообщение человека и напиши: <code>лайк</code>
Так ты поставишь ему ❤️
]]):f({ sep = hdec.sep })

local LIKED = [[
❤️ <b>Лайк поставлен!</b>
  ╰ Кому: ${user}
]]

local ALREADY = [[
ℹ️ <b>Ты уже ставил(а) лайк</b>
  ╰ Кому: ${user}
]]

local CANT_SELF = '🤷🏼‍♀️ Нельзя поставить лайк самому себе'
local CANT_BOT = 'Спасибо! Но лайкать ботов - так себе идея ❤️'
local FAILED = '⚠️ Не удалось поставить лайк'

--- Подсказка по использованию (нет ответа на сообщение).
function render.usage()
  return USAGE
end

--- Лайк поставлен.
-- @param recipient (table) получатель (telegram-юзер)
function render.liked(recipient)
  return LIKED:f({ user = hdec.user(recipient) })
end

--- Лайк этому человеку уже стоял.
-- @param recipient (table) получатель (telegram-юзер)
function render.alreadyLiked(recipient)
  return ALREADY:f({ user = hdec.user(recipient) })
end

--- Лайк самому себе.
function render.cantLikeSelf()
  return CANT_SELF
end

--- Лайк боту.
function render.cantLikeBot()
  return CANT_BOT
end

--- Ошибка хранилища.
function render.failed()
  return FAILED
end

return render
