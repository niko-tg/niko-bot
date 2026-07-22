--- Рудник: старт задачи добычи камня и руды.
--
local Command = require('bot.classes.Command')
local gatherStart = require('src.commands.handlers.gatherStart')

local command = Command:new({
  commands = { '/mining', 'рудник', 'шахта' },
  flags = { Command.enum.PUBLIC },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  gatherStart(ctx, command, 'mining')
end

return command
