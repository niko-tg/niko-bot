--- Рендер ежедневного бонуса.
--
local hdec = require('bot.libs.hdec')
local separateNumbers = require('src.utils.separateNumbers')

local render = {}

local CLAIMED = [[
🎁 <b>Ежедневный бонус</b>
${sep}
💰 Начислено: <b>${amount}</b>р${crystal}
💵 Баланс: <b>${balance}</b>р
]]

local ALREADY = [[
Похоже, что ты уже получал(а) бонус :3
Следующий через ${remaining}
]]

--- Остаток времени как HH:MM:SS (ASCII).
local function formatCountdown(sec)
  if sec < 0 then
    sec = 0
  end

  local hours   = math.floor(sec / 3600)
  local minutes = math.floor((sec % 3600) / 60)
  local seconds = sec % 60

  return ('%02d:%02d:%02d'):format(hours, minutes, seconds)
end

--- Успешное начисление бонуса.
-- @param amount (number) сумма начисления
-- @param balance (number) новый баланс
-- @param crystals (number) сколько кристаллов выпало (0 = не выпал)
function render.claimed(amount, balance, crystals)
  local crystal = ''
  if crystals and crystals > 0 then
    crystal = '\n💎 Выпал кристалл! <b>+'..crystals..'</b>'
  end

  return CLAIMED:f({
    sep = hdec.sep,
    amount = separateNumbers(amount),
    balance = separateNumbers(balance),
    crystal = crystal,
  })
end

--- Бонус уже получен: обратный отсчёт до nextAvailableTs (unix-секунды).
-- @param nextAvailableTs (number) время следующего получения, unix-секунды
function render.alreadyClaimed(nextAvailableTs)
  return ALREADY:f({
    remaining = formatCountdown(nextAvailableTs - os.time()),
  })
end

return render
