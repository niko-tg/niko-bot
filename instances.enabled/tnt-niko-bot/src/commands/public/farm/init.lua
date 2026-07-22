--- Ферма: грядки, посадка и сбор урожая.
--
local log = require('log')
local Command = require('bot.classes.Command')
local farmService = require('src.services.farm')
local render = require('src.commands.public.farm.render')

local command = Command:new({
  commands = { '/farm', 'ферма' },
  flags = { Command.enum.PUBLIC },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local user = command.user

  local state, err = farmService.state(user.id)
  if err then
    log.error(err)
    return
  end

  local view = render.menu(state)

  ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })
end

return command
