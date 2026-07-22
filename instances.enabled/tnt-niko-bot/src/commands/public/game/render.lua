--- Рендер PVP-игры: меню выбора, инвайт, старт.
--
local hdec = require('bot.libs.hdec')
local separateNumbers = require('src.utils.separateNumbers')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')
local gameTypes = require('src.enums.game_types')

-- Шаблоны (подстановка ${key} через :f).
--
local MENU_TEXT = [[
🎮 <b>Игра на ${bid}р</b>
${sep}
Выбери мини-игру:
]]

local INVITE_TEXT = [[
${emoji} <b>${name}</b>
  ╰ Ставка <b>${bid}</b>р
${sep}
${initiator} зовёт ${opponent} сыграть.
]]

local START_TEXT = [[
${emoji} <b>${name}</b>
  ╰ Ставка <b>${bid}</b>р
${sep}
${initiator} vs ${opponent}

Кидайте <code>${emoji}</code> - по ${maxSteps} броска каждый!
]]

local STEP_TEXT = [[
${emoji} Ход: <b>${step} из ${maxSteps}</b>
${sep}
Очков за ход: +<b>${rollScore}</b>
Очков всего: <b>${totalScore}</b>
]]

local RESULT_TEXT = [[
${emoji} <b>${name}</b>
  ╰ Ставка <b>${bid}</b>р
${sep}
${player1}: ${score1} очк.
${player2}: ${score2} очк.
${sep}
${outcome}
]]

local OUTCOME_DRAW = [[
${sep}
👾 НИЧЬЯ! 👾
${sep}
Ставки возвращены (<b>${bid}</b>р каждому)
]]

local OUTCOME_WIN = [[
🏆 Победитель: ${winner}
${sep}
Выигрыш: <b>${prize}</b>р (+10 XP)
]]

local EXPIRED_TEXT = [[
⌛️ <b>${name}</b> - время вышло
  ╰ Ставка <b>${bid}</b>р
${sep}
${player1}: ${score1} очк.
${player2}: ${score2} очк.
${sep}
${outcome}
]]

local CANCELLED_TEXT = [[
🚫 <b>${name}</b> - игра прервана
  ╰ Ставка <b>${bid}</b>р
${sep}
${player1} vs ${player2}
${sep}
Игрок ${actor} ${verb}.
Ставки возвращены.
]]

local STATUS_TEXT = [[
${emoji} <b>${name}</b>
  ╰ Ставка <b>${bid}</b>р
${sep}
${me}: ход ${myStep}/${maxSteps}, очков <b>${myScore}</b>
${opponent}: ход ${oppStep}/${maxSteps}, очков <b>${oppScore}</b>
${sep}
До конца сессии: <b>${remaining}</b>
]]

--- Форматирование оставшегося времени (ASCII).
local function formatDuration(sec)
  if sec < 0 then
    sec = 0
  end

  local minutes = math.floor(sec / 60)
  local seconds = sec % 60

  if minutes > 0 then
    return ('%dм %dс'):format(minutes, seconds)
  end

  return ('%dс'):format(seconds)
end

--- Строка исхода по очкам (ничья/победа) для result/expired.
local function buildOutcome(session, score1, score2, player1, player2)
  if score1 == score2 then
    return OUTCOME_DRAW:f({
      bid = separateNumbers(session.bid),
      sep = hdec.sep,
    })
  end

  local winner = (score1 > score2) and player1 or player2

  return OUTCOME_WIN:f({
    winner = hdec.user(winner),
    prize = separateNumbers(2 * session.bid),
    sep = hdec.sep,
  })
end

local render = {}

--- Аргументы callback-кнопки игрового меню.
-- @tparam string action действие кнопки
-- @tparam string gameKey ключ игры
-- @tparam number initiatorId id инициатора
-- @tparam number opponentId id оппонента
-- @tparam number bid размер ставки
-- @treturn table аргументы кнопки
local function buttonArgs(action, gameKey, initiatorId, opponentId, bid)
  return {
    action = action,
    game_type = gameKey,
    initiator = initiatorId,
    opponent = opponentId,
    bid = bid,
  }
end

--- Меню выбора игры (жмёт инициатор).
function render.gameMenu(initiator, opponent, bid)
  local rows = {}
  local row = {}

  for i = 1, #gameTypes.list do
    local game = gameTypes.list[i]
    table.insert(row, {
      text = game.emoji .. ' ' .. game.name,
      callback = {
        command = 'cb_game',
        arguments = buttonArgs('pick', game.key, initiator.id, opponent.id, bid),
      },
    })

    if #row == 2 then
      table.insert(rows, row)
      row = {}
    end
  end

  if #row > 0 then
    table.insert(rows, row)
  end

  return {
    text = MENU_TEXT:f({
      bid = separateNumbers(bid),
      sep = hdec.sep,
    }),
    keyboard = inlineCallbackKeyboard(rows),
  }
end

--- Инвайт оппоненту (принять / отклонить).
function render.invite(initiator, opponent, gameKey, bid)
  local game = gameTypes.byKey[gameKey]

  local text = INVITE_TEXT:f({
    emoji = game.emoji,
    name = game.name,
    bid = separateNumbers(bid),
    sep = hdec.sep,
    initiator = hdec.user(initiator),
    opponent = hdec.user(opponent),
  })

  local keyboard = inlineCallbackKeyboard({
    {
      {
        text = '✅ Принять',
        callback = {
          command = 'cb_game',
          arguments = buttonArgs('accept', gameKey, initiator.id, opponent.id, bid),
        },
      },
      {
        text = '❌ Отклонить',
        callback = {
          command = 'cb_game',
          arguments = buttonArgs('decline', gameKey, initiator.id, opponent.id, bid),
        },
      },
    },
  })

  return { text = text, keyboard = keyboard }
end

--- Старт игры: кидайте dice.
function render.gameStart(initiator, opponent, gameKey, bid)
  local game = gameTypes.byKey[gameKey]

  local text = START_TEXT:f({
    emoji = game.emoji,
    name = game.name,
    bid = separateNumbers(bid),
    initiator = hdec.user(initiator),
    opponent = hdec.user(opponent),
    maxSteps = gameTypes.MAX_STEPS,
    sep = hdec.sep,
  })

  return { text = text }
end

--- Промежуточный ход: текущий бросок и накопленный счёт игрока.
-- @tparam string gameKey ключ игры
-- @tparam number step номер хода (1..MAX_STEPS)
-- @tparam number rollScore очков за текущий бросок
-- @tparam number totalScore накопленных очков
function render.gameStep(gameKey, step, rollScore, totalScore)
  local game = gameTypes.byKey[gameKey]

  local text = STEP_TEXT:f({
    emoji = game.emoji,
    step = step,
    maxSteps = gameTypes.MAX_STEPS,
    rollScore = rollScore,
    totalScore = totalScore,
    sep = hdec.sep,
  })

  return { text = text }
end

--- Итог партии: счёт обоих игроков, победитель/ничья, банк.
-- @tparam table session сессия игры
-- @tparam table data состояние { [user_id] = { score, steps } }
-- @tparam table player1 объект игрока player1 (для упоминания)
-- @tparam table player2 объект игрока player2 (для упоминания)
function render.gameResult(session, data, player1, player2)
  local game = gameTypes.byKey[session.game_type]

  local score1 = (data[session.player1_id] and data[session.player1_id].score) or 0
  local score2 = (data[session.player2_id] and data[session.player2_id].score) or 0

  local text = RESULT_TEXT:f({
    emoji = game.emoji,
    name = game.name,
    bid = separateNumbers(session.bid),
    player1 = hdec.user(player1),
    score1 = score1,
    player2 = hdec.user(player2),
    score2 = score2,
    outcome = buildOutcome(session, score1, score2, player1, player2),
    sep = hdec.sep,
  })

  return { text = text }
end

--- Завершение сессии по таймауту: табло + исход по очкам.
-- @tparam table session сессия игры
-- @tparam table data состояние { [user_id] = { score, steps } }
-- @tparam table player1 объект игрока player1
-- @tparam table player2 объект игрока player2
function render.gameExpired(session, data, player1, player2)
  local game = gameTypes.byKey[session.game_type]

  local score1 = (data[session.player1_id] and data[session.player1_id].score) or 0
  local score2 = (data[session.player2_id] and data[session.player2_id].score) or 0

  local text = EXPIRED_TEXT:f({
    emoji = game.emoji,
    name = game.name,
    bid = separateNumbers(session.bid),
    player1 = hdec.user(player1),
    score1 = score1,
    player2 = hdec.user(player2),
    score2 = score2,
    outcome = buildOutcome(session, score1, score2, player1, player2),
    sep = hdec.sep,
  })

  return { text = text }
end

--- Принудительная отмена сессии (мут/бан игрока).
-- @tparam table session сессия игры
-- @tparam table player1 объект игрока player1
-- @tparam table player2 объект игрока player2
-- @tparam table actor игрок, из-за которого отмена (для упоминания)
-- @tparam string verb причина: 'замучен' | 'забанен'
function render.gameCancelled(session, player1, player2, actor, verb)
  local game = gameTypes.byKey[session.game_type]

  local text = CANCELLED_TEXT:f({
    name = game.name,
    bid = separateNumbers(session.bid),
    sep = hdec.sep,
    player1 = hdec.user(player1),
    player2 = hdec.user(player2),
    actor = hdec.user(actor),
    verb = verb,
  })

  return { text = text }
end

--- Статус активной сессии игрока (/game без реплея, когда он уже в игре).
-- @tparam table session сессия игры
-- @tparam table me объект игрока, запросившего статус
-- @tparam table opponent объект оппонента
-- @tparam number remainingSec сколько секунд сессии осталось жить
function render.gameStatus(session, me, opponent, remainingSec)
  local game = gameTypes.byKey[session.game_type]

  local myState = session.data[me.id] or { score = 0, steps = 0 }
  local oppState = session.data[opponent.id] or { score = 0, steps = 0 }

  local text = STATUS_TEXT:f({
    emoji = game.emoji,
    name = game.name,
    bid = separateNumbers(session.bid),
    sep = hdec.sep,
    me = hdec.user(me),
    myStep = myState.steps,
    myScore = myState.score,
    opponent = hdec.user(opponent),
    oppStep = oppState.steps,
    oppScore = oppState.score,
    maxSteps = gameTypes.MAX_STEPS,
    remaining = formatDuration(remainingSec),
  })

  return { text = text }
end

return render
