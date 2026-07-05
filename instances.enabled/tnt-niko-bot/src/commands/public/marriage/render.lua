--- Рендер карточки брака пользователя.
--
local log = require('log')
local hdec = require('bot.libs.hdec')
local timeToDays = require('src.utils.timeToDays')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')
local marriagesService = require('src.services.marriages')
local usersService = require('src.services.users')
local userMention = require('src.render.userMention')

local CARD = [[
💍 <b>Твой брак</b>
${sep}
Партнёр: ${partner}
Вместе: <b>${days}</b> дн.
]]

local NOT_MARRIED = ([[
💍 <b>Брак</b>
${sep}
Ты пока ни с кем не в браке 🥺
Чтобы пожениться - ответь на сообщение человека и напиши <code>вбрак</code>
]]):f({ sep = hdec.sep })

local render = {}

--- Имя пользователя для строки (или плейсхолдер, если записи в БД нет).
local function resolveName(userId)
  local user, err = usersService.read(userId)

  if err then
    log.error(err)
  end

  if user then
    return userMention(user)
  end

  return '<code>#'..userId..'</code>'
end

--- Карточка брака вызвавшего: партнёр, сколько дней вместе + кнопка развода.
-- @param ownerId (number)
-- @return[1] { text, keyboard }
-- @return[2] err
function render.card(ownerId)
  local marriage, err = marriagesService.read(ownerId)
  if err then
    return nil, err
  end

  if not marriage then
    return { text = NOT_MARRIED, keyboard = nil }, nil
  end

  local text = CARD:f({
    sep = hdec.sep,
    partner = resolveName(marriage.partner_id),
    days = timeToDays(marriage.created.timestamp),
  })

  local keyboard = inlineCallbackKeyboard({
    {
      {
        text = '💔 Развестись',
        callback = {
          command = 'cb_divorce',
          arguments = { action = 'ask' }
        }
      }
    }
  })

  return { text = text, keyboard = keyboard }, nil
end

return render
