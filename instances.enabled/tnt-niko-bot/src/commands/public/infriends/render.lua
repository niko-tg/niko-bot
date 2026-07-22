--- Рендер предложения дружбы и его исходов.
--
local hdec = require('bot.libs.hdec')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local render = {}

local USAGE = ([[
ℹ️ <b>В друзья</b>
${sep}
Ответь на сообщение человека и напиши: <code>вдрузья</code>
Он получит предложение дружить
]]):f({ sep = hdec.sep })

local PROPOSAL = [[
🤝 ${invited}, тебе предлагает дружить ${proposer}!
]]

local ACCEPTED = [[
🎭 <b>Теперь вы друзья!</b>
  ╰ ${proposer} и ${invited}
]]

local REJECTED = '😔 Предложение дружбы отклонено'
local ALREADY = '🤠 Вы и так уже друзья!'
local CANT_SELF = '🤷🏼‍♀️ Нельзя добавить в друзья самого себя'
local CANT_BOT = 'Ёу! Мы и так бро 🤩'
local NOT_FOR_YOU = 'Это предложение не тебе :)'
local FAILED = '⚠️ Не удалось заключить дружбу'

--- Подсказка по использованию (нет ответа на сообщение).
function render.usage()
  return USAGE
end

--- Предложение дружбы: текст + кнопки принять/отказать.
-- @tparam table proposer кто предлагает (модель/telegram-юзер)
-- @tparam table invited кому предлагают (telegram-юзер)
function render.proposal(proposer, invited)
  local keyboard = inlineCallbackKeyboard({
    {
      {
        text = '👍 Принять',
        callback = {
          command = 'cb_infriends',
          arguments = {
            action = 'accept',
            proposer = proposer.id,
            invited = invited.id,
          },
        },
      },
      {
        text = '👎 Отказать',
        callback = {
          command = 'cb_infriends',
          arguments = {
            action = 'reject',
            proposer = proposer.id,
            invited = invited.id,
          },
        },
      },
    },
  })

  local text = PROPOSAL:f({
    invited = hdec.user(invited),
    proposer = hdec.user(proposer),
  })

  return { text = text, keyboard = keyboard }
end

--- Дружба заключена.
-- @tparam string proposerMention готовое упоминание
-- @tparam string invitedMention готовое упоминание
function render.accepted(proposerMention, invitedMention)
  return ACCEPTED:f({
    proposer = proposerMention,
    invited = invitedMention,
  })
end

--- Предложение отклонено.
function render.rejected()
  return REJECTED
end

--- Дружба уже была.
function render.already()
  return ALREADY
end

--- Дружба с самим собой.
function render.cantSelf()
  return CANT_SELF
end

--- Дружба с ботом.
function render.cantBot()
  return CANT_BOT
end

--- Кнопку нажал не приглашённый.
function render.notForYou()
  return NOT_FOR_YOU
end

--- Ошибка хранилища.
function render.failed()
  return FAILED
end

return render
