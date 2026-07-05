--- Рендер добычи: экран «в процессе», результат сбора, служебные сообщения.
--
local hdec = require('bot.libs.hdec')
local config = require('conf.config')
local items = require('src.gathering.items')
local activities = require('src.gathering.activities')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local render = {}

local PROGRESS_TEXT = [[
${emoji} <b>${name}</b>
${sep}
⏳ Осталось: <b>${clock}</b>
${sep}
Жми Собрать, когда будет готово
]]

--- Остаток времени как "M:SS".
local function clock(sec)
  if sec < 0 then
    sec = 0
  end
  return ('%d:%02d'):format(math.floor(sec / 60), sec % 60)
end

render.clock = clock

--- Кнопка «Собрать» (действует на единственную активную задачу игрока).
local function collectKeyboard()
  return inlineCallbackKeyboard({
    {
      text = '🧺 Собрать',
      callback = {
        command = 'cb_collect',
        arguments = { action = 'collect', activity = '0' }
      },
    },
  })
end

--- Кнопка «Повторить» (запускает ту же активность заново).
local function repeatKeyboard(activityKey)
  return inlineCallbackKeyboard({
    {
      text = '🔄 Повторить',
      callback = {
        command = 'cb_collect',
        arguments = { action = 'repeat', activity = activityKey }
      },
    },
  })
end

--- Экран идущей задачи.
-- @param activityKey (string)
-- @param untilDate (number) время готовности (unix)
-- @return table { text, keyboard }
function render.inProgress(activityKey, untilDate)
  local activity = activities[activityKey]

  return {
    text = PROGRESS_TEXT:f({
      emoji = activity.emoji,
      name = activity.name,
      clock = clock(untilDate - os.time()),
      sep = hdec.sep,
    }),
    keyboard = collectKeyboard(),
  }
end

-- Сломавшийся инструмент: короткое сообщение на активность.
local TOOL_BROKEN = {
  fishing = '✖️ Удочка сломалась',
  mining  = '✖️ Кирка сломалась',
  sawmill = '✖️ Топор сломался',
}

local RESULT_HEADER = '${emoji} <b>${name}: готово!</b>'
local LOOT_LINE = '  ╰ ${label}: <b>${count}</b>'
local JACKPOT_LINE = '✨ Редкая находка: <b>${label}</b>!'
local SKILL_LINE = '📈 <code>${name}</code>: ур. <b>${level}</b> (+${xp} xp)'
local LEVELUP_LINE = '🎉 Новый уровень навыка - открылся лут получше!'

--- Экран результата сбора.
-- @param result (table) из gathering.collect (status='done')
-- @return table { text, keyboard }
function render.result(result)
  local activity = activities[result.activity]

  -- Лут в стабильном порядке реестра.
  local counts = {}
  for _, drop in ipairs(result.loot) do
    counts[drop.id] = (counts[drop.id] or 0) + drop.count
  end

  local lines = {}
  for _, id in ipairs(items.resourceOrder) do
    if counts[id] then
      table.insert(lines, LOOT_LINE:f({ label = items.label(id), count = counts[id] }))
    end
  end

  local parts = {
    RESULT_HEADER:f({ emoji = activity.emoji, name = activity.name }),
    hdec.sep,
    'Добыто:\n' .. table.concat(lines, '\n'),
  }

  if result.jackpot then
    table.insert(parts, JACKPOT_LINE:f({ label = items.label(result.jackpot) }))
  end

  table.insert(parts, hdec.sep)

  if result.tool_broken then
    table.insert(parts, TOOL_BROKEN[result.activity])
  end

  if result.skill then
    table.insert(parts, SKILL_LINE:f({ name = activity.name, level = result.skill.level, xp = result.skill.gained }))
    if result.skill.leveledUp then
      table.insert(parts, hdec.sep .. '\n' .. LEVELUP_LINE)
    end
  end

  return {
    text = table.concat(parts, '\n'),
    keyboard = repeatKeyboard(result.activity),
  }
end

local SKILLS_ROW = '  ╰ ${emoji} ${name}: ур. <b>${level}</b> (${xp}/${need} xp)'

local SKILLS_TEXT = [[
📈 <b>Навыки добычи</b>
${sep}
${rows}]]

--- Экран навыков добычи.
-- @param skills (table) { fishing = { xp, level }, ... } из gathering.skills
-- @return string
function render.skills(skills)
  local lines = {}
  for _, key in ipairs(activities.order) do
    local activity = activities[key]
    local skill = skills[key]
    local need = config.gathering.level_base * skill.level

    table.insert(lines, SKILLS_ROW:f({
      emoji = activity.emoji,
      name = activity.name,
      level = skill.level,
      xp = skill.xp,
      need = need,
    }))
  end

  return SKILLS_TEXT:f({ sep = hdec.sep, rows = table.concat(lines, '\n') })
end

-- Служебные сообщения. Тексты по строкам - правятся легко.

local BUSY_TEXT = ([[
⏳ Ты уже занят добычей!
${sep}
Дождись или забери: /collect
]]):f({
  sep = hdec.sep
})

local FULL_TEXT = ([[
🎒 Рюкзак полон!
${sep}
Продай ресурсы: /sell всё
]]):f({
  sep = hdec.sep
})

-- Нет инструмента: своё сообщение на активность (с нужным инструментом).
local NO_TOOL_TEXT = {
fishing = ([[
🎣 Для рыбалки нужна удочка
${sep}
Загляни в /shop
]]):f({
  sep = hdec.sep
}),

mining = ([[
⛏️ Для рудника нужна кирка
${sep}
Загляни в /shop
]]):f({
  sep = hdec.sep
}),

sawmill = ([[
🪓 Для лесопилки нужен топор
${sep}
Загляни в /shop
]]):f({
  sep = hdec.sep
  }),
}

local NOT_READY_TEXT = ([[
${emoji} ${name} ещё в процессе
${sep}
⏳ Осталось: <b>${clock}</b>
]]):f({
  sep = hdec.sep
})

--- Уже занят другой задачей.
function render.busyText()
  return BUSY_TEXT
end

--- Рюкзак полон.
function render.fullText()
  return FULL_TEXT
end

--- Нет инструмента для активности.
-- @param activityKey (string)
function render.noToolText(activityKey)
  return NO_TOOL_TEXT[activityKey]
end

--- Ещё не готово.
-- @param remaining (number) секунд
-- @param activityKey (string)
function render.notReadyText(remaining, activityKey)
  local activity = activities[activityKey]
  return NOT_READY_TEXT:f({
    emoji = activity.emoji,
    name = activity.name,
    clock = clock(remaining),
  })
end

return render
