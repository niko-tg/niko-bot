--- Рендер «Мин»: меню риска, доска, итоги.
--
local hdec = require('bot.libs.hdec')
local config = require('conf.config')
local separateNumbers = require('src.utils.separateNumbers')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local CLOSED = '⬜'
local GEM = '💎'
local BOMB = '💣'

-- Шаблоны (подстановка ${key} через :f).
--
local MENU_TEXT = [[
💣 <b>Мины</b>
  ╰ Ставка <b>${bid}</b>р
${sep}
Выбери риск - больше мин, жирнее множитель!
]]

local BOARD_TEXT = [[
💣 <b>Мины</b>
  ╰ ${mines} мины
  ╰ Ставка: <b>${bid}</b>р
${sep}
${gem} Вскрыто: <b>${opened}</b>
🧪 Множитель: <b>${mult}x</b>${next}
⏳ Осталось: <b>${remaining}</b>
]]

local WIN_TEXT = [[
🍾 <b>Забрал!</b> ${mult}x
${sep}
Ставка <b>${bid}</b>р
  ╰ Выигрыш <b>${payout}</b>р
  ╰ Чистыми: <b>+${profit}</b>р
${sep}
${grid}
]]

local LOSE_TEXT = [[
💥 <b>Подорвался!</b>
${sep}
Сгорела ставка: <b>-${bid}</b>р
Вскрыто было: <b>${opened}</b> ${gem}
${sep}
${grid}
]]

local EXPIRED_TEXT = [[
⌛️ <b>Партия истекла</b>
${sep}
Мины (${mines})
Cтавка ${bid}р
]]

--- Множитель в виде строки "2.42".
local function fmtMult(mult)
  return ('%.2f'):format(mult)
end

--- Остаток времени сессии в виде "M:SS".
local function formatRemaining(sec)
  if sec < 0 then
    sec = 0
  end

  return ('%d:%02d'):format(math.floor(sec / 60), sec % 60)
end

--- Кол-во вскрытых клеток в map opened.
local function countOpened(opened)
  local count = 0
  for _ in pairs(opened or {}) do
    count = count + 1
  end
  return count
end

local render = {}

-- Кол-во вскрытых клеток (нужно и в cb, и в TTL-джобе).
render.countOpened = countOpened

--- Честный множитель за `opened` вскрытых клеток при `mines` минах.
-- @param opened (number) вскрыто безопасных клеток
-- @param mines (number) число мин
-- @return number
function render.multiplier(opened, mines)
  if opened <= 0 then
    return 1
  end

  local cells = config.mines.cells
  local mult = 1

  for i = 0, opened - 1 do
    mult = mult * (cells - i) / (cells - mines - i)
  end

  return mult * (1 - config.mines.house_edge)
end

--- Выплата при заборе: floor(bid * множитель).
-- @param bid (number)
-- @param opened (number)
-- @param mines (number)
-- @return number
function render.payout(bid, opened, mines)
  return math.floor(bid * render.multiplier(opened, mines))
end

--- Клавиатура доски: клетки + кнопка забора (если есть вскрытые).
local function buildKeyboard(session)
  local cells = config.mines.cells
  local cols = config.mines.cols
  local opened = session.opened or {}

  local rows = {}
  local row = {}

  for pos = 1, cells do
    table.insert(row, {
      text = opened[pos] and GEM or CLOSED,
      callback = {
        command = 'cb_mines',
        arguments = { action = 'open', bid = 0, mines = 0, pos = pos },
      },
    })

    if #row == cols then
      table.insert(rows, row)
      row = {}
    end
  end

  if #row > 0 then
    table.insert(rows, row)
  end

  local opCount = countOpened(opened)
  if opCount > 0 then
    -- local mult = render.multiplier(opCount, session.mines)
    local payout = render.payout(session.bid, opCount, session.mines)

    table.insert(rows, {
      {
        text = ('💰 Забрать: %sр'):format(separateNumbers(payout)),
        callback = {
          command = 'cb_mines',
          arguments = {
            action = 'cashout',
            bid = 0,
            mines = 0,
            pos = 0
          },
        },
      },
    })
  end

  return inlineCallbackKeyboard(rows)
end

--- Текстовая сетка для финала: opened=💎, bombPos=💣, остальное ⬜.
local function buildTextGrid(opened, bombPos)
  local cells = config.mines.cells
  local cols = config.mines.cols

  local lines = {}
  local row = {}

  for pos = 1, cells do
    local glyph = CLOSED
    if pos == bombPos then
      glyph = BOMB
    elseif opened and opened[pos] then
      glyph = GEM
    end

    table.insert(row, glyph)

    if #row == cols then
      table.insert(lines, table.concat(row, ' '))
      row = {}
    end
  end

  return table.concat(lines, '\n')
end

--- Меню выбора риска (число мин). Кнопка показывает стартовый множитель.
-- @param bid (number)
function render.riskMenu(bid)
  local row = {}

  for _, mines in ipairs(config.mines.risk) do
    local firstMult = render.multiplier(1, mines)

    table.insert(row, {
      text = ('💣 %d | %sx'):format(mines, fmtMult(firstMult)),
      callback = {
        command = 'cb_mines',
        arguments = {
          action = 'start',
          bid = bid,
          mines = mines,
          pos = 0
        },
      },
    })
  end

  return {
    text = MENU_TEXT:f({
      bid = separateNumbers(bid),
      sep = hdec.sep,
    }),
    keyboard = inlineCallbackKeyboard({ row }),
  }
end

--- Доска во время игры.
-- @param session (table) модель партии
-- @param remainingSec (number) сколько секунд сессии осталось
function render.board(session, remainingSec)
  local opCount = countOpened(session.opened)
  local mult = render.multiplier(opCount, session.mines)

  -- Тиз следующего множителя, если ещё остались безопасные клетки.
  local nextFragment = ''
  local safeTotal = config.mines.cells - session.mines
  if opCount < safeTotal then
    local nextMult = render.multiplier(opCount + 1, session.mines)
    nextFragment = (' ➡️ <b>%sx</b>'):format(fmtMult(nextMult))
  end

  local text = BOARD_TEXT:f({
    mines = session.mines,
    bid = separateNumbers(session.bid),
    opened = opCount,
    gem = GEM,
    mult = fmtMult(mult),
    next = nextFragment,
    remaining = formatRemaining(remainingSec or 0),
    sep = hdec.sep,
  })

  return { text = text, keyboard = buildKeyboard(session) }
end

--- Клавиатура повтора для финальных экранов: та же ставка / x2.
-- Обе кнопки переиспользуют action='start' (резерв + новая партия) с тем же
-- числом мин. Хватает ли на x2 - проверит сам резерв в onStart.
-- @param session (table) только что завершённая партия
local function replayKeyboard(session)
  local doubleBid = session.bid * 2

  return inlineCallbackKeyboard({
      {
        text = ('🔄 Повторить %sр'):format(separateNumbers(session.bid)),
        callback = {
          command = 'cb_mines',
          arguments = {
            action = 'start',
            bid = session.bid,
            mines = session.mines,
            pos = 0
          },
        }
      },
      {
        text = ('⬆️ Удвоить %sр'):format(separateNumbers(doubleBid)),
        callback = {
          command = 'cb_mines',
          arguments = {
            action = 'start',
            bid = doubleBid,
            mines = session.mines,
            pos = 0
          },
        }
      },
    })
end

--- Итог: забрал выигрыш.
-- @param session (table) модель партии
-- @param payout (number) выплата
function render.win(session, payout)
  local opCount = countOpened(session.opened)
  local mult = render.multiplier(opCount, session.mines)

  return {
    text = WIN_TEXT:f({
      mult = fmtMult(mult),
      bid = separateNumbers(session.bid),
      payout = separateNumbers(payout),
      profit = separateNumbers(payout - session.bid),
      grid = buildTextGrid(session.opened, nil),
      sep = hdec.sep,
    }),
    keyboard = replayKeyboard(session),
  }
end

--- Итог: подорвался.
-- @param session (table) модель партии
-- @param bombPos (number) позиция мины
function render.lose(session, bombPos)
  return {
    text = LOSE_TEXT:f({
      bid = separateNumbers(session.bid),
      opened = countOpened(session.opened),
      gem = GEM,
      grid = buildTextGrid(session.opened, bombPos),
      sep = hdec.sep,
    }),
    keyboard = replayKeyboard(session),
  }
end

--- Итог: партия истекла по TTL.
-- @param session (table) модель партии
function render.expired(session)
  return {
    text = EXPIRED_TEXT:f({
      mines = session.mines,
      bid = separateNumbers(session.bid),
      sep = hdec.sep,
    }),
  }
end

return render
