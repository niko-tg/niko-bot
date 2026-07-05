--- Топ браков чата командой "браки" (сокращение для "топ браков").
-- Только в группах: топ показывает пары, где оба супруга в этом чате.
--
local log = require('log')
local Command = require('bot.classes.Command')
local topRender = require('src.commands.public.top.render')

local command = Command:new {
  commands = { 'браки' },
  flags = { Command.enum.IN_CHAT },
}

function command.call(ctx)
  local view, err = topRender.top('marriages', 1, ctx:getChatType(), ctx:getChatId())
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
