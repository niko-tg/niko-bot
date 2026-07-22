--- Рендер рейд-босса: карточка боя, победа, побег.
--
local hdec = require('bot.libs.hdec')
local separateNumbers = require('src.utils.separateNumbers')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local BAR_FILLED = '█'
local BAR_EMPTY = '░'
local BAR_SEGMENTS = 10

local MEDALS = { '🥇', '🥈', '🥉' }

-- Шаблоны (подстановка ${key} через :f).
--
local CARD_TEXT = [[
${emoji} <b>${name}</b> напал на чат!
<i>${about}</i>
${sep}
❤️ ${bar} ${hp} / ${hp_max}
💰 Награда чату: <b>${reward}</b>р
⏳ Сбежит через: <b>${remaining}</b>${last_hit}${top}
]]

local VICTORY_TEXT = [[
🎉 <b>${name} повержен!</b>
${sep}
💰 Пул награды: <b>${reward}</b>р
🗡 Добил(а): ${killer} <b>+${killer_bonus}</b>р бонусом${crystal}
${sep}
${rewards}${rest}
${sep}
Каждому герою начислен XP. Следующий босс отдохнёт и придёт!
]]

local ESCAPED_TEXT = [[
💨 <b>${name} сбежал!</b>
${sep}
Чат не добил босса: осталось <b>${hp}</b> HP из ${hp_max}.
Награда ушла вместе с ним. В следующий раз бейте дружнее!
]]

--- HP-бар из BAR_SEGMENTS сегментов.
local function hpBar(hp, hpMax)
  if hpMax <= 0 then
    return BAR_EMPTY:rep(BAR_SEGMENTS)
  end

  local filled = math.ceil(hp / hpMax * BAR_SEGMENTS)
  filled = math.max(0, math.min(BAR_SEGMENTS, filled))

  return BAR_FILLED:rep(filled)..BAR_EMPTY:rep(BAR_SEGMENTS - filled)
end

--- Остаток времени в виде "M:SS".
local function formatRemaining(sec)
  if sec < 0 then
    sec = 0
  end

  return ('%d:%02d'):format(math.floor(sec / 60), sec % 60)
end

--- Топ-3 по урону для карточки.
-- @tparam table hits модели boss_hit по убыванию урона
local function topFragment(hits)
  if not hits or #hits == 0 then
    return ''
  end

  local lines = { '' }

  for i = 1, math.min(3, #hits) do
    local hit = hits[i]

    table.insert(lines, ('%s %s - %s'):format(
      MEDALS[i], hdec.escape(hit.name), separateNumbers(hit.damage)))
  end

  return table.concat(lines, '\n')
end

local render = {}

render.formatRemaining = formatRemaining

--- Клавиатура боя: одна кнопка удара.
local function battleKeyboard()
  return inlineCallbackKeyboard({
    {
      {
        text = '⚔️ Ударить',
        callback = {
          command = 'cb_boss',
          arguments = { action = 'hit' },
        },
      },
    },
  })
end

--- Карточка боя.
-- @tparam table session модель боя
-- @tparam table bossInfo запись каталога боссов
-- @tparam number remainingSec до побега
-- @tparam table hits участники по убыванию урона (для топ-3)
-- @tparam ?table lastHit { name, damage, is_crit } - последний удар
function render.card(session, bossInfo, remainingSec, hits, lastHit)
  local lastHitFragment = ''

  if lastHit then
    lastHitFragment = ('\n%s\n⚔️ %s: -%s%s'):format(
      hdec.sep,
      hdec.escape(lastHit.name),
      separateNumbers(lastHit.damage),
      lastHit.is_crit and ' 💥КРИТ!' or '')
  end

  return {
    text = CARD_TEXT:f({
      emoji = bossInfo.emoji,
      name = bossInfo.name,
      about = bossInfo.about,
      bar = hpBar(session.hp, session.hp_max),
      hp = separateNumbers(session.hp),
      hp_max = separateNumbers(session.hp_max),
      reward = separateNumbers(bossInfo.reward),
      remaining = formatRemaining(remainingSec),
      last_hit = lastHitFragment,
      top = topFragment(hits),
      sep = hdec.sep,
    }),
    keyboard = battleKeyboard(),
  }
end

--- Итог: босс повержен, награды розданы.
-- @tparam table bossInfo запись каталога
-- @tparam table rewards { name, damage, reward } по убыванию урона
-- @tparam table killer { name, bonus, got_crystal }
function render.victory(bossInfo, rewards, killer)
  local lines = {}
  local shown = math.min(5, #rewards)

  for i = 1, shown do
    local item = rewards[i]
    local medal = MEDALS[i] or '▫️'

    table.insert(lines, ('%s %s - %s урона ➡️ <b>%s</b>р'):format(
      medal,
      hdec.escape(item.name),
      separateNumbers(item.damage),
      separateNumbers(item.reward)))
  end

  local rest = ''
  if #rewards > shown then
    rest = ('\nи ещё %d героев с наградой'):format(#rewards - shown)
  end

  return {
    text = VICTORY_TEXT:f({
      name = bossInfo.name,
      reward = separateNumbers(bossInfo.reward),
      killer = hdec.escape(killer.name),
      killer_bonus = separateNumbers(killer.bonus),
      crystal = killer.got_crystal and ' и 💎 кристалл!' or '',
      rewards = table.concat(lines, '\n'),
      rest = rest,
      sep = hdec.sep,
    }),
  }
end

--- Итог: босс сбежал по TTL.
-- @tparam table session модель боя
-- @tparam table bossInfo запись каталога
function render.escaped(session, bossInfo)
  return {
    text = ESCAPED_TEXT:f({
      name = bossInfo.name,
      hp = separateNumbers(session.hp),
      hp_max = separateNumbers(session.hp_max),
      sep = hdec.sep,
    }),
  }
end

return render
