--- Напоминалка об окончании VIP-подписки.
--
-- Раз в час проходит по vip_users и для записей, у которых подписка
-- кончится в ближайшие сутки и напоминалка ещё не отправлена, шлёт
-- юзеру в личку сообщение и помечает reminder_sent = true.
--
-- При продлении подписки команда /mkvip явно ставит reminder_sent = false,
-- поэтому за сутки до НОВОЙ даты окончания напоминалка снова сработает.
--
local log = require('log')
local bot = require('bot')
local fiber = require('fiber')
local hdec = require('bot.libs.hdec')
local vipUsersService = require('src.services.vip_users')
local tgErrors = require('src.utils.tgErrors')

local TICK_INTERVAL    = 60 * 60        -- раз в час
local REMINDER_WINDOW  = 24 * 60 * 60   -- за сутки до окончания
local SEND_DELAY       = 1              -- пауза между sendMessage (per-chat 1/sec)

local TEMPLATE = [[
📆 <b>VIP подписка заканчивается!</b>
${sep}
Действует до: <b>${untilDate}</b>
${sep}
По окончанию вы потеряете все преимущества VIP-подписки.
А ваши чаты не будут под эффективной защитой от спама 🙀
${sep}
Вы можете продлить /donat ❤️
]]

--- Шлёт напоминалку одному юзеру и помечает запись.
-- reminder_sent ставится даже при ошибке отправки - иначе при заблокированном
-- боте мы каждый час повторно генерим error в логи.
local function notify(record)
  local _, sendErr = bot:sendMessage({
    chat_id = record.user_id,
    text = TEMPLATE:f({
      sep = hdec.sep,
      untilDate = os.date('%d.%m.%Y', record.until_date),
    }),
  })

  if sendErr then
    if tgErrors.isPMUnavailable(sendErr) or tgErrors.isChatNotFound(sendErr) then
      log.verbose(sendErr)
    else
      log.error(sendErr)
    end
  end

  local _, updErr = vipUsersService.update(
    { reminder_sent = true },
    { user_id = record.user_id }
  )

  if updErr then
    log.error(updErr)
  end
end

--- Один проход: рассылка напоминаний по истекающим подпискам.
local function tick()
  local records, err = vipUsersService.listExpiringSoon(REMINDER_WINDOW)

  if err then
    log.error(err)
    return
  end

  if not records then
    return
  end

  for i = 1, #records do
    local record = records[i]
    notify(record)
    fiber.sleep(SEND_DELAY)
  end
end

--- Запуск фонового файбера напоминалки.
local function start()
  fiber.create(function()
    fiber.self():name('vip-reminder')

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
