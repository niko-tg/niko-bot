--- Сбор готовой добычи (ручной).
--
local log = require('log')
local hdec = require('bot.libs.hdec')
local Command = require('bot.classes.Command')
local gatheringService = require('src.services.gathering')
local render = require('src.render.gather')

local command = Command:new {
  commands = { '/collect', 'собрать' },
  flags = { Command.enum.PUBLIC },
}

local EMPTY_TASK = ([[
🎒 <b>Нет активной добычи</b>
${sep}
Начни: /fishing /mining /sawmill
]]):f({
  sep = hdec.sep
})

function command.call(ctx)
  local user = command.user

  local res, err = gatheringService.collect(user.id)
  if err then
    log.error(err)
    ctx:replyToMessage('⚠️ Ошибка сбора, попробуй ещё')
    return
  end

  if res.status == 'none' then
    ctx:replyToMessage(EMPTY_TASK)
    return
  end

  if res.status == 'not_ready' then
    ctx:replyToMessage(render.notReadyText(res.remaining, res.activity))
    return
  end

  local view = render.result(res)
  ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })
end

return command
