--- Контракты дня: цели по добыче и награды.
--
local log = require('log')
local Command = require('bot.classes.Command')
local gatheringService = require('src.services.gathering')
local render = require('src.commands.public.quests.render')

local command = Command:new {
  commands = { '/quests', 'квесты', 'задания' },
  flags = { Command.enum.PUBLIC },
}

function command.call(ctx)
  local user = command.user

  local state, err = gatheringService.questState(user.id)
  if err then
    log.error(err)
    return
  end

  local view = render.list(state)

  ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })
end

return command
