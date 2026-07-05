--- Магазин: разделы по активностям, покупка инструментов и прикормки.
--
local Command = require('bot.classes.Command')
local render = require('src.commands.public.shop.render')

local command = Command:new {
  commands = { '/shop', 'магазин' },
  flags = { Command.enum.PUBLIC },
}

function command.call(ctx)
  local user = command.user

  local view = render.menu(user)

  ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })
end

return command
