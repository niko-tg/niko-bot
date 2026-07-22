--- Рыбалка: старт задачи добычи рыбы.
--
local Command = require('bot.classes.Command')
local gatherStart = require('src.commands.handlers.gatherStart')

local command = Command:new({
  commands = { '/fishing', 'рыбалка', 'рыбачить' },
  flags = { Command.enum.PUBLIC },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  gatherStart(ctx, command, 'fishing')
end

return command
