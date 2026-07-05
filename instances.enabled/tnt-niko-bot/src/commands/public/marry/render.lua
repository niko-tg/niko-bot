--- Рендер предложения брака и его исходов.
--
local hdec = require('bot.libs.hdec')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local render = {}

local USAGE = ([[
ℹ️ <b>В брак</b>
${sep}
Ответь на сообщение человека и напиши: <code>вбрак</code>
Он получит предложение руки и сердца
]]):f({ sep = hdec.sep })

local PROPOSAL = ([[
💍 ${invited}, тебе делает предложение ${proposer}!
${sep}
Согласишься связать себя узами брака?
]]):f({ sep = hdec.sep })

local ACCEPTED = ([[
🎉 <b>Совет да любовь!</b>
  ╰ ${proposer} 💕 ${invited}
${sep}
Теперь вы официально женаты!
]]):f({ sep = hdec.sep })

local REJECTED = '💔 Предложение брака отклонено'
local ALREADY_PROPOSER = '💍 Ты уже состоишь в браке'
local ALREADY_INVITED = '💍 Этот человек уже состоит в браке'
local CANT_SELF = '🤷🏼‍♀️ Нельзя жениться на самом себе'
local CANT_BOT = 'Прости, моё сердце принадлежит создателю 🥰'
local NOT_FOR_YOU = 'Это предложение не тебе :)'
local FAILED = '⚠️ Не удалось заключить брак'

--- Подсказка по использованию (нет ответа на сообщение).
function render.usage()
  return USAGE
end

--- Предложение брака: текст + кнопки принять/отказать.
-- @param proposer (table) кто предлагает (модель/telegram-юзер)
-- @param invited (table) кому предлагают (telegram-юзер)
function render.proposal(proposer, invited)
  local keyboard = inlineCallbackKeyboard({
    {
      {
        text = '💍 Согласиться',
        callback = {
          command = 'cb_marry',
          arguments = {
            action = 'accept',
            proposer = proposer.id,
            invited = invited.id
          }
        },
      },
      {
        text = '💔 Отказать',
        callback = {
          command = 'cb_marry',
          arguments = {
            action = 'reject',
            proposer = proposer.id,
            invited = invited.id
          }
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

--- Брак заключён.
-- @param proposerMention (string) готовое упоминание
-- @param invitedMention (string) готовое упоминание
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

--- Предлагающий уже в браке.
function render.alreadyProposer()
  return ALREADY_PROPOSER
end

--- Приглашённый уже в браке.
function render.alreadyInvited()
  return ALREADY_INVITED
end

--- Брак с самим собой.
function render.cantSelf()
  return CANT_SELF
end

--- Брак с ботом.
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
