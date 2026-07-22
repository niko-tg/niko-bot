--- Инвентарь игрока: ресурсы, снаряжение, продажа по кнопкам.
--
local log = require('log')
local Command = require('bot.classes.Command')
local inventoryService = require('src.services.inventory')
local render = require('src.commands.public.inventory.render')

local command = Command:new({
  commands = { '/inv', 'инвентарь', 'инв' },
  flags = { Command.enum.PUBLIC },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local user = command.user

  local inv, err = inventoryService.read(user.id)
  if err then
    log.error(err)
    return
  end

  local view = render.inventory(inv)

  ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })
end

return command
