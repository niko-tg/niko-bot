--- Смена расы: /setrace или "сменить расу".
--
local Command = require('bot.classes.Command')
local render = require('src.commands.public.profile.render')

local command = Command:new({
  commands = { '/setrace' },
  flags = { Command.enum.PUBLIC },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  ctx:replyToMessage({
    text = render.CHANGE_PROMPT,
    reply_markup = render.raceChoiceKeyboard(command.user.id, 'change'),
  })
end

return command
