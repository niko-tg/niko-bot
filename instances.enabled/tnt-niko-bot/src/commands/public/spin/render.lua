--- Рендер «Спина»: барабаны, касса, итоги. Веса/выплаты - из config.spin.
--
local hdec = require('bot.libs.hdec')
local config = require('conf.config')
local separateNumbers = require('src.utils.separateNumbers')

-- Шаблоны (подстановка ${key} через :f).
--
local INFO_TEXT = [[
🎰 <b>Спин</b>
${sep}
${cashbox_line}
${sep}
<b>Комбинации</b>
3 разных - проигрыш
2 одинаковых - выигрыш x${win2}
3 одинаковых - ДЖЕКПОТ x${jackpot} + касса
3 💎 - УЛЬТРА x${ultra} + касса + кристалл
${sep}
Как крутить: <code>спин 1000</code>
Мин. ставка: <b>${min_bid}</b>р
]]

local LOSE_TEXT = [[
😢 Проигрыш: <b>-${amount}</b>р
${sep}
[ ${reels} ]
]]

local WIN2_TEXT = [[
🎉 <b>Выигрыш!</b> +<b>${amount}</b>р
${sep}
[ ${reels} ]
]]

local JACKPOT_TEXT = [[
🏆 <b>ЭТО ДЖЕКПОТ!</b> +<b>${amount}</b>р${cashbox}
${sep}
[ ${reels} ]
]]

local ULTRA_TEXT = [[
💎 <b>УЛЬТРА ДЖЕКПОТ!</b> +<b>${amount}</b>р${cashbox}${crystal}
${sep}
[ ${reels} ]
]]

local render = {}

--- Инфо со ставкой/кассой/комбинациями (/spin без ставки).
-- @param cashbox (number)
-- @param isGroup (boolean) в группе ли (касса только в группах)
function render.info(cashbox, isGroup)
  local spin = config.spin

  local cashboxLine = '🏦 Касса - только в группах'
  if isGroup then
    cashboxLine = '🏦 Касса чата: <b>'..separateNumbers(cashbox)..'</b>р'
  end

  return INFO_TEXT:f({
    cashbox_line = cashboxLine,
    win2 = spin.win2_mult,
    jackpot = spin.jackpot_mult,
    ultra = spin.ultra_mult,
    min_bid = separateNumbers(spin.min_bid),
    sep = hdec.sep,
  })
end

--- Итог спина.
-- @param result (table) { category, reels, amount, balance, cashboxWon, gotCrystal }
function render.result(result)
  local cashboxFrag = ''
  if result.cashboxWon and result.cashboxWon > 0 then
    cashboxFrag = '\n🏦 + касса чата: <b>'..separateNumbers(result.cashboxWon)..'</b>р'
  end

  local fields = {
    reels = result.reels,
    amount = separateNumbers(result.amount),
    cashbox = cashboxFrag,
    sep = hdec.sep,
  }

  if result.category == 'lose' then
    return LOSE_TEXT:f(fields)

  elseif result.category == 'win2' then
    return WIN2_TEXT:f(fields)

  elseif result.category == 'jackpot' then
    return JACKPOT_TEXT:f(fields)
  end

  -- ultra
  fields.crystal = result.gotCrystal and '\n+1 💎 Кристалл!' or ''
  return ULTRA_TEXT:f(fields)
end

return render
