--- Callback топов: переключение между топами и пагинация.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.top.render')

local command = Command:new {
  commands = { 'cb_top' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'which', 'page' },
}

function command.call(ctx)
  local arguments = command.arguments
  local which = arguments.which
  local page = tonumber(arguments.page) or 1

  ctx:answer()

  local view, err
  if which == 'menu' then
    view = render.menu(ctx:getChatType())
  else
    view, err = render.top(which, page, ctx:getChatType(), ctx:getChatId())
  end

  if err then
    log.error(err)
    return
  end

  if not view then
    return
  end

  bot:editMessageText({
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    text = view.text,
    reply_markup = view.keyboard,
    link_preview_options = { is_disabled = true },
  })
end

return command
