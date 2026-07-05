--- /commands - справочник команд по категориям.
--
local Command = require('bot.classes.Command')
local auth = require('src.auth')
local render = require('src.commands.public.commands.render')

local command = Command:new {
  commands = { '/commands', 'команды' },
  flags = {
    Command.enum.PUBLIC,
    Command.enum.NO_REPLY,
  },
}

function command.call(ctx)
  local view = render.menu(auth.isBotOwner(command.user))

  ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })
end

return command
