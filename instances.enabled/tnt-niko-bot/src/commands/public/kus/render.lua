--- Рендер укуса: подпись к анимации, промах, кулдаун и подсказки.
--
local hdec = require('bot.libs.hdec')

local render = {}

local USAGE = [[
😈 <b>Кусь</b>
Ответь командой <code>кусь</code> на сообщение того, кого хочешь укусить
]]

-- Подпись к удачному укусу. Третья строка - сила укуса и итог счётчика.
local CAPTION = [[
${label} ${description}
${sep}
${biter} укусил(а) ${victim}!
${sep}
${powerline}
]]

-- Варианты промаха (без засчёта). Подставляются biter и victim.
local MISSES = {
  '🌬️ ${biter} попытался укусить ${victim}, но цапнул воздух!',
  '🤕 ${biter} промахнулся и прикусил себе язык. ${victim} цел.',
  '💨 ${victim} увернулся - ${biter} клацнул зубами впустую!',
}

local CANT_SELF = '🤪 Сам себя не укусишь'
local CANT_BOT = 'Меня кусать?! 😾 Себя укуси :D'

--- Подсказка по использованию (нет ответа на сообщение).
function render.usage()
  return USAGE
end

--- Укус самого себя.
function render.cantSelf()
  return CANT_SELF
end

--- Укус бота.
function render.cantBot()
  return CANT_BOT
end

--- Кулдаун: сколько ещё ждать.
-- @param nextTs (number) unix-секунды, когда можно снова
function render.cooldown(nextTs)
  local left = nextTs - os.time()
  if left < 1 then
    left = 1
  end

  return ('🦷 Не так быстро! Дай зубам отдохнуть (ещё ${left}с)'):f({ left = left })
end

--- Промах: случайный текст без засчёта укуса.
-- @param biter (table) кто кусал
-- @param victim (table) кого пытались укусить
function render.miss(biter, victim)
  local text = MISSES[math.random(#MISSES)]

  return (text):f({
    biter = hdec.user(biter),
    victim = hdec.user(victim),
  })
end

--- Подпись к удачному укусу.
-- @param biter (table) кто кусал
-- @param victim (table) кого укусили
-- @param bite (table) выбранный укус (label, description, power, crit)
-- @param totalKuses (number) сколько всего укусов теперь у кусавшего
function render.caption(biter, victim, bite, totalKuses)
  local powerline = (bite.crit and '💥 Крит! ' or '')
    ..'+'..bite.power..' | твоих укусов: '..totalKuses

  return CAPTION:f({
    label = bite.label,
    description = bite.description,
    biter = hdec.user(biter),
    victim = hdec.user(victim),
    powerline = powerline,
    sep = hdec.sep,
  })
end

return render
