--- /botstats - живая статистика бота с дельтами к последнему снапшоту.
-- MAINTENANCE: только создатель бота (гейт в preCallCommand).
--
local log = require('log')
local Command = require('bot.classes.Command')
local botStatsService = require('src.services.bot_stats')
local render = require('src.commands.maint.botstats.render')

local command = Command:new({
  commands = { '/botstats' },
  flags = { Command.enum.MAINTENANCE },
})

--- Начало текущего дня (server-local) - база для "активных сегодня".
local function startOfToday()
  local d = os.date('*t')
  d.hour, d.min, d.sec = 0, 0, 0
  return os.time(d)
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local current, err = botStatsService.computeCurrent(startOfToday())
  if err then
    log.error(err)
    ctx:replyToMessage('⚠️ Не удалось собрать статистику')
    return
  end

  local latest, latestErr = botStatsService.getLatest()
  if latestErr then
    log.error(latestErr)

    -- Дельт не будет, но текущее покажем
    latest = nil
  end

  ctx:replyToMessage(render.report(current, latest))
end

return command
