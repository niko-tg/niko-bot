--- Профиль пользователя
--
local Command = require('bot.classes.Command')
local render = require('src.commands.public.profile.render')

local command = Command:new {
  commands = { '/profile', 'профиль' },
  flags = {
    Command.enum.PUBLIC,
    Command.enum.NO_REPLY
  }
}

function command.call(ctx)
  local view = render.profile(command.user, ctx:getChat())

  ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })
end

return command
