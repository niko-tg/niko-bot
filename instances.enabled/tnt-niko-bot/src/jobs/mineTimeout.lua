--- Чистка протухших партий 'Мины'.
--
-- Раз в минуту удаляет партии старше TTL и гасит доску ("истекла").
-- Деньги не трогаем: ставка списывается при первом вскрытии, забор/мина её уже разрулили,
-- а брошенная партия = ставка потеряна (если было вскрытие) либо не списана.
--
local log = require('log')
local bot = require('bot')
local fiber = require('fiber')
local config = require('conf.config')
local mineSessionsService = require('src.services.mine_sessions')
local usersService = require('src.services.users')
local tgErrors = require('src.utils.tgErrors')
local render = require('src.commands.public.mines.render')

local TICK_INTERVAL = 60   -- раз в минуту
local SEND_DELAY    = 1    -- пауза между editMessageText (per-chat 1/sec)

--- Расчёт резерва + удаление одной протухшей партии + гашение доски.
local function expire(session)
  -- Не сделал ни одного хода -> возврат ставки; играл и бросил -> ставка сгорает.
  local opCount = render.countOpened(session.opened)
  local payout = (opCount == 0) and session.bid or 0

  local _, settleErr = usersService.settleReserve(session.user_id, session.bid, payout)

  -- Резерв не разрулили -> сессию НЕ удаляем, повторим на следующем тике.
  if settleErr then
    log.error(settleErr)
    return
  end

  mineSessionsService.delete(session.user_id)

  local _, editErr = bot:editMessageText({
    chat_id = session.chat_id,
    message_id = session.message_id,
    text = render.expired(session).text,
  })

  if editErr then
    if tgErrors.isBotBlocked(editErr) or tgErrors.isChatNotFound(editErr) then
      log.verbose(editErr)
    else
      log.error(editErr)
    end
  end
end

--- Один проход: закрытие партий "Мины", у которых вышел TTL.
local function tick()
  local sessions, err = mineSessionsService.listExpired(config.mines.ttl)

  if err then
    log.error(err)
    return
  end

  if not sessions then
    return
  end

  for i = 1, #sessions do
    local session = sessions[i]
    expire(session)
    fiber.sleep(SEND_DELAY)
  end
end

--- Запуск фонового файбера контроля TTL партий.
local function start()
  fiber.create(function()
    fiber.self():name('mine-timeout')

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
