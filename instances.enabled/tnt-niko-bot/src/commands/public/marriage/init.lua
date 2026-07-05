--- Карточка собственного брака. Работает везде.
--
local log = require('log')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.marriage.render')

local command = Command:new {
  commands = { '/marriage', 'брак' },
  flags = { Command.enum.PUBLIC },
}

function command.call(ctx)
  local view, err = render.card(command.user.id)
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
