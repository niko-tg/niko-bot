--- Список друзей с управлением (просмотр карточки, удаление). Работает везде.
--
local log = require('log')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.friends.render')

local command = Command:new({
  commands = { '/friends', 'друзья' },
  flags = { Command.enum.PUBLIC },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  -- Друзья личные - всегда показываем список вызвавшего.
  local view, err = render.list(command.user.id, 1)
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
