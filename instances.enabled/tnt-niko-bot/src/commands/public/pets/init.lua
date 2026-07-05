--- Список питомцев игрока с переходом в карточку. Работает везде.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.pets.render')

local command = Command:new {
  commands = { '/pets', 'питомцы' },
  flags = { Command.enum.PUBLIC },
}

function command.call(ctx)
  local view, err = render.list(command.user.id)
  if err then
    log.error(err)
    return
  end

  if view.empty then
    ctx:replyToMessage(render.missing())
    return
  end

  bot:sendPhoto({
    chat_id = ctx:getChatId(),
    photo = view.image,
    caption = view.caption,
    reply_markup = view.keyboard,
    reply_parameters = { message_id = ctx:getMessageId() },
  })
end

return command
