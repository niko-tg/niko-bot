--- Расторжение собственного брака (с подтверждением). Работает везде.
--
local log = require('log')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.divorce.render')

local command = Command:new({
  commands = { '/divorce', 'развод', 'развестись' },
  flags = { Command.enum.PUBLIC },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local view, err = render.confirm(command.user.id)
  if err then
    log.error(err)
    return
  end

  if not view then
    return
  end

  ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })
end

return command
