--- Навыки добычи: уровни рыбалки/рудника/лесопилки и прогресс до следующего.
--
local log = require('log')
local Command = require('bot.classes.Command')
local gatheringService = require('src.services.gathering')
local render = require('src.render.gather')

local command = Command:new {
  commands = { '/skills', 'навыки' },
  flags = { Command.enum.PUBLIC },
}

function command.call(ctx)
  local user = command.user

  local skills, err = gatheringService.skills(user.id)
  if err then
    log.error(err)
    return
  end

  ctx:replyToMessage(render.skills(skills))
end

return command
