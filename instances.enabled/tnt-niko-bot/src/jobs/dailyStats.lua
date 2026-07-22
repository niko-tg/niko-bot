--- Ежедневный снапшот статистики + отчёт админу.
--
-- Раз в час проверяет смену календарного дня. При первом тике нового дня:
--   1. Считает текущие тоталы.
--   2. Шлёт админу отчёт с дельтами к прошлому снапшоту (итоги прошедшего дня).
--   3. Сохраняет снапшот на начало нового дня (база для дельт текущего дня).
--
local log = require('log')
local bot = require('bot')
local fiber = require('fiber')
local config = require('conf.config')
local botStatsService = require('src.services.bot_stats')
local render = require('src.commands.maint.botstats.render')

local TICK_INTERVAL = 60 * 60  -- раз в час

--- Начало дня ts (server-local).
local function startOfDay(ts)
  local d = os.date('*t', ts)
  d.hour, d.min, d.sec = 0, 0, 0
  return os.time(d)
end

--- Один проход: снятие суточного среза статистики бота.
local function tick()
  local todayStart = startOfDay(os.time())

  local latest, latestErr = botStatsService.getLatest()
  if latestErr then
    log.error(latestErr)
    return
  end

  -- Снапшот на сегодня уже есть - ждём следующего дня.
  if latest and latest.date >= todayStart then
    return
  end

  -- Новый день: считаем текущее, шлём отчёт, снапшотим базу нового дня.
  -- "Активны" меряем за ПРОШЕДШИЙ день [prevDayStart, todayStart) - иначе на
  -- первом тике нового дня (между 00:00 и 01:00) окно ">= todayStart" пустое
  -- и "активны сегодня" вышло бы ≈ 0.
  local prevDayStart = todayStart - 24 * 60 * 60
  local current, computeErr = botStatsService.computeCurrent(prevDayStart, todayStart)
  if computeErr then
    log.error(computeErr)
    return
  end

  local _, sendErr = bot:sendMessage({
    chat_id = config.admin_id,
    text = render.report(current, latest),
  })
  if sendErr then
    log.error(sendErr)
  end

  local _, saveErr = botStatsService.saveSnapshot(todayStart, current)
  if saveErr then
    log.error(saveErr)
  end
end

--- Запуск фонового файбера суточной статистики.
local function start()
  fiber.create(function()
    fiber.self():name('daily-stats')

    while true do
      local ok, runErr = pcall(tick)
      if not ok then
        log.error(runErr)
      end

      fiber.sleep(TICK_INTERVAL)
    end
  end)
end

return {
  start = start,
}
