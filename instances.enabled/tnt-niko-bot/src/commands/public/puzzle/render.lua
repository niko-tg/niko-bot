--- Рендер «Пазла»: меню сложности, запомни, повтори, итоги, кулдаун.
--
local hdec = require('bot.libs.hdec')
local config = require('conf.config')
local separateNumbers = require('src.utils.separateNumbers')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local DONE = '✅'
local BTNS_PER_ROW = 4

-- Шаблоны (подстановка ${key} через :f).
--
local MENU_TEXT = [[
🧩 <b>Пазл на память</b>
${sep}
Запомни порядок эмодзи и повтори по памяти.
Выбери сложность (чем сложнее, тем выше выигрыш!)${vip}
]]

local MEMORIZE_TEXT = [[
🧩 <b>Пазл</b>
  ╰ Награда <b>${win}</b>р
${sep}
🧠 Запомни порядок
${seq}
${sep}
Готов?
]]

local RECALL_TEXT = [[
🧩 <b>Пазл</b>
  ╰ Награда <b>${win}</b>р
${sep}
Повтори порядок по памяти!
Введено: <b>${progress}</b> из <b>${total}</b>
]]

local COOLDOWN_TEXT = [[
🧩 Ты уже решал(а) пазл :3
Следующий через <b>${remaining}</b>
]]

local WIN_TEXT = [[
🧩 <b>Пазл пройден!</b>
${sep}
Награда: <b>${win}</b>р (+${xp} XP)
]]

local LOSE_TEXT = [[
💥 <b>Мимо!</b>
${sep}
Правильный порядок был:
${seq}
]]

--- Остаток кулдауна в виде HH:MM:SS (ASCII).
local function formatCountdown(sec)
  if sec < 0 then
    sec = 0
  end

  local hours = math.floor(sec / 3600)
  local minutes = math.floor((sec % 3600) / 60)
  local seconds = sec % 60

  return ('%02d:%02d:%02d'):format(hours, minutes, seconds)
end

--- Эмодзи по индексу.
local function emoji(index)
  return config.puzzle.emojis[index]
end

--- Последовательность как строка эмодзи в исходном порядке.
local function seqString(seq)
  local parts = {}
  for _, index in ipairs(seq) do
    table.insert(parts, emoji(index))
  end
  return table.concat(parts, ' ')
end

--- Примерная награда для длины (середина диапазона) - для меню.
local function approxWin(len)
  return math.floor(len * (config.puzzle.win_min_per + config.puzzle.win_max_per) / 2)
end

local render = {}

--- Меню выбора сложности. Для VIP награды и подсказка увеличены.
-- @param isVip (boolean)
function render.menu(isVip)
  local multiplier = isVip and config.puzzle.vip_multiplier or 1

  local row = {}

  for _, len in ipairs(config.puzzle.lengths) do
    table.insert(row, {
      text = ('%d | До %sр'):format(len, separateNumbers(approxWin(len) * multiplier)),
      callback = {
        command = 'cb_puzzle',
        arguments = { action = 'start', len = len, idx = 0 },
      },
    })
  end

  local vipNote = ''
  if isVip then
    vipNote = ('\n%s\n⭐ VIP: награда x%d'):format(hdec.sep, config.puzzle.vip_multiplier)
  end

  return {
    text = MENU_TEXT:f({ sep = hdec.sep, vip = vipNote }),
    keyboard = inlineCallbackKeyboard({ row }),
  }
end

--- Фаза «запомни»: показываем порядок + кнопка «Запомнил».
function render.memorize(active)
  local keyboard = inlineCallbackKeyboard({
    {
      {
        text = '🧠 Запомнил, начать',
        callback = {
          command = 'cb_puzzle',
          arguments = {
            action = 'memorized',
            len = 0,
            idx = 0
          },
        },
      },
    },
  })

  return {
    text = MEMORIZE_TEXT:f({
      win = separateNumbers(active.win),
      seq = seqString(active.seq),
      sep = hdec.sep,
    }),
    keyboard = keyboard,
  }
end

--- Фаза «повтори»: порядок скрыт, кнопки эмодзи (по индексу), вскрытые -> ✅.
function render.recall(active)
  -- Вскрытые = seq[1..pos-1].
  local consumed = {}
  for i = 1, active.pos - 1 do
    consumed[active.seq[i]] = true
  end

  -- Кнопки = индексы последовательности, отсортированы (порядок не выдаём).
  local indices = {}
  for _, index in ipairs(active.seq) do
    table.insert(indices, index)
  end
  table.sort(indices)

  local rows = {}
  local row = {}

  for _, index in ipairs(indices) do
    if consumed[index] then
      table.insert(row, {
        text = DONE,
        callback = {
          command = 'cb_puzzle',
          arguments = {
            action = 'none',
            len = 0,
            idx = index
          },
        },
      })
    else
      table.insert(row, {
        text = emoji(index),
        callback = {
          command = 'cb_puzzle',
          arguments = {
            action = 'tap',
            len = 0,
            idx = index
          },
        },
      })
    end

    if #row == BTNS_PER_ROW then
      table.insert(rows, row)
      row = {}
    end
  end

  if #row > 0 then
    table.insert(rows, row)
  end

  return {
    text = RECALL_TEXT:f({
      win = separateNumbers(active.win),
      progress = active.pos - 1,
      total = #active.seq,
      sep = hdec.sep,
    }),
    keyboard = inlineCallbackKeyboard(rows),
  }
end

--- Возобновление активного пазла по его фазе.
function render.resume(active)
  if active.phase == 'memorize' then
    return render.memorize(active)
  end

  return render.recall(active)
end

--- Кулдаун: обратный отсчёт до nextTs (unix-секунды).
function render.cooldown(nextTs)
  return COOLDOWN_TEXT:f({
    remaining = formatCountdown(nextTs - os.time()),
  })
end

--- Итог: пазл пройден.
function render.win(active, xp)
  return {
    text = WIN_TEXT:f({
      win = separateNumbers(active.win),
      xp = xp,
      sep = hdec.sep,
    }),
  }
end

--- Итог: ошибка, раскрываем правильный порядок.
function render.lose(active)
  return {
    text = LOSE_TEXT:f({
      seq = seqString(active.seq),
      sep = hdec.sep,
    }),
  }
end

return render
