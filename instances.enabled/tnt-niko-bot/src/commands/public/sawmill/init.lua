--- Лесопилка: старт задачи заготовки древесины.
--
local Command = require('bot.classes.Command')
local gatherStart = require('src.commands.handlers.gatherStart')

local command = Command:new({
  commands = { '/sawmill', 'лесопилка' },
  flags = { Command.enum.PUBLIC },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  gatherStart(ctx, command, 'sawmill')
end

return command
