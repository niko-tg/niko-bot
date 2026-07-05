--- Список лайкнувших: без ответа - свои лайки, ответом на сообщение - чужие.
--
local log = require('log')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.likes.render')

local command = Command:new {
  commands = { '/likes', 'лайки' },
  flags = { Command.enum.PUBLIC },
}

function command.call(ctx)
  -- Ответом на сообщение смотрим лайки того человека, иначе свои.
  local reply = ctx.message.reply_to_message
  local target = (reply and reply.from) or command.user

  local view, err = render.likers(target.id, 1)
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
