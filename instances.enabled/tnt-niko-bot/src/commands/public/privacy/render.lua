--- Рендер настройки приватности: статус + кнопка вкл/выкл.
--
local hdec = require('bot.libs.hdec')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local TEMPLATE = [[
🔐 <b>Приватность</b>
${sep}
Статус: <b>${status}</b>

Когда включена - ссылка на тебя в топах скрыта (показывается только имя).
]]

local render = {}

function render.view(user)
  local isPrivate = user.is_private == true

  local text = TEMPLATE:f({
    sep = hdec.sep,
    status = isPrivate and '🔒 включена' or '🔓 выключена',
  })

  local keyboard = inlineCallbackKeyboard({
    {
      text = isPrivate and '🔓 Выключить' or '🔒 Включить',
      callback = {
        command = 'cb_privacy',
        arguments = {
          owner = user.id
        }
      },
    },
  })

  return {
    text = text,
    keyboard = keyboard
  }
end

return render
