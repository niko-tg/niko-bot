--- Настройки чата.
--
local bot = require('bot')
local Command = require('bot.classes.Command')
local showMainPage = require(bot.subdir(0, ...)..'.pages.showMainPage')

local command = Command:new({
  commands = { '/settings' },
  flags = { Command.enum.IN_CHAT, Command.enum.ADMINISTRATIVE },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  showMainPage(ctx)
end

return command
