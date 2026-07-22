--- Смена пола: /setgender.
--
local Command = require('bot.classes.Command')
local render = require('src.commands.public.profile.render')

local command = Command:new({
  commands = { '/setgender' },
  flags = { Command.enum.PUBLIC },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  ctx:replyToMessage({
    text = render.GENDER_CHANGE_PROMPT,
    reply_markup = render.genderChoiceKeyboard(command.user.id, 'change', false),
  })
end

return command
