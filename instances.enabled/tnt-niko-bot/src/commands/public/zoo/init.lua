--- Зоомагазин: питомцы и зоотовары. Работает везде.
--
local bot = require('bot')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.zoo.render')

local command = Command:new({
  commands = { '/zoo_shop', 'зоомагазин', 'зоотовары' },
  flags = {
    Command.enum.PUBLIC,
    Command.enum.NO_REPLY,
  },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local view = render.menu()

  bot:sendPhoto({
    chat_id = ctx:getChatId(),
    photo = view.image,
    caption = view.caption,
    reply_markup = view.keyboard,
    reply_parameters = { message_id = ctx:getMessageId() },
  })
end

return command
