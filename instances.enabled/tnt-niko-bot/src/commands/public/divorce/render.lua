--- Рендер развода: подтверждение и исходы.
--
local log = require('log')
local hdec = require('bot.libs.hdec')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')
local marriagesService = require('src.services.marriages')
local usersService = require('src.services.users')
local userMention = require('src.render.userMention')

local CONFIRM = [[
💔 <b>Развод</b>
${sep}
Точно развестись с ${partner}?
]]

local NOT_MARRIED = ([[
💍 <b>Развод</b>
${sep}
Ты пока ни с кем не в браке 🤷🏼‍♀️
]]):f({ sep = hdec.sep })

local DIVORCED = '💔 Брак расторгнут'
local SAVED = '❤️ Брак сохранён'

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

--- Подтверждение развода вызвавшего: партнёр + кнопки да/нет.
-- Если брака нет - сообщение об этом без кнопок.
-- @tparam number ownerId
-- @treturn[1] table { text, keyboard }
-- @treturn[2] table err
function render.confirm(ownerId)
  local marriage, err = marriagesService.read(ownerId)
  if err then
    return nil, err
  end

  if not marriage then
    return { text = NOT_MARRIED, keyboard = nil }, nil
  end

  local text = CONFIRM:f({
    sep = hdec.sep,
    partner = resolveName(marriage.partner_id),
  })

  local keyboard = inlineCallbackKeyboard({
    {
      {
        text = '💔 Да, развестись',
        callback = {
          command = 'cb_divorce',
          arguments = { action = 'yes' },
        },
      },
      {
        text = '❤️ Нет',
        callback = {
          command = 'cb_divorce',
          arguments = { action = 'no' },
        },
      },
    },
  })

  return { text = text, keyboard = keyboard }, nil
end

--- Брак расторгнут.
function render.divorced()
  return DIVORCED
end

--- Развод отменён - брак сохранён.
function render.saved()
  return SAVED
end

--- Брака нет.
function render.notMarried()
  return NOT_MARRIED
end

return render
