--- Приватность: статус + кнопка вкл/выкл.
-- Включён is_private -> ссылка на пользователя в топах скрыта (показывается имя).
--
local Command = require('bot.classes.Command')
local render = require('src.commands.public.privacy.render')

local command = Command:new({
  commands = { '/privacy', 'приватность' },
  flags = { Command.enum.PUBLIC },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local view = render.view(command.user)

  ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })
end

return command
