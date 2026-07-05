--- Callback списка лайкнувших: пагинация.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.likes.render')

local command = Command:new {
  commands = { 'cb_likes' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'owner', 'page' },
}

function command.call(ctx)
  local arguments = command.arguments
  local owner = tonumber(arguments.owner)
  local page = tonumber(arguments.page) or 1

  ctx:answer()

  if not owner then
    return
  end

  local view, err = render.likers(owner, page)
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
  })
end

return command
