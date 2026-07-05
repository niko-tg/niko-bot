--- Крафт: переработка сырья в более дорогие предметы.
--
local log = require('log')
local Command = require('bot.classes.Command')
local inventoryService = require('src.services.inventory')
local render = require('src.commands.public.craft.render')

local command = Command:new {
  commands = { '/craft', 'крафт' },
  flags = { Command.enum.PUBLIC },
}

function command.call(ctx)
  local user = command.user

  local inv, err = inventoryService.read(user.id)
  if err then
    log.error(err)
    return
  end

  local view = render.list(inv)

  ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })
end

return command
