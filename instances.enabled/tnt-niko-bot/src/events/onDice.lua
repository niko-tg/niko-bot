--- Обработчик броска dice как хода в PVP-игре.
--
-- Засчитываем бросок ходом, только если бросивший в активной сессии, кубик
-- брошен в чате игры, его эмодзи совпадает с игрой сессии и ходы ещё остались.
-- Иначе это обычный кубик в чате -> отдаём в onChatMessage (антифлуд/фильтры).
--
local log = require('log')
local bot = require('bot')
local isForward = require('src.utils.isForward')
local gameTypes = require('src.enums.game_types')
local gamingService = require('src.services.gaming_sessions')
local usersService = require('src.services.users')
local settle = require('src.commands.public.game.settle')
local render = require('src.commands.public.game.render')

--- Завершение партии: расчёт исхода по очкам + удаление сессии.
local function finish(ctx, session, data)
  local _, err = settle(session, data)
  if err then
    log.error(err)
    return
  end

  gamingService.delete(session.player1_id)

  -- Объекты игроков для упоминаний в итоге (id -> fallback, если не нашлись).
  local player1 = usersService.read(session.player1_id) or { id = session.player1_id }
  local player2 = usersService.read(session.player2_id) or { id = session.player2_id }

  ctx:reply(render.gameResult(session, data, player1, player2))
end

--- Обработчик игральных кубиков (dice).
-- @tparam table ctx контекст обновления
local function onDice(ctx)
  -- Пересланный кубик - не бросок (можно переслать чужой с нужным числом).
  -- Отдаём в общий чат: там отработает фильтр форвардов.
  if isForward(ctx.message) then
    return bot.events.onChatMessage(ctx)
  end

  local rollerId = ctx:getUserFromId()

  -- Аноним/канал бросить ход не может -> обычная обработка.
  if not rollerId then
    return bot.events.onChatMessage(ctx)
  end

  local session, err = gamingService.getByPlayer(rollerId)
  if err then
    log.error(err)
    return
  end

  local dice = ctx:getDice()
  local game = session and gameTypes.byKey[session.game_type]

  -- Не игровой бросок (нет сессии / другой чат / не та игра) -> в общий чат.
  if not session
    or ctx:getChatId() ~= session.chat_id
    or not game
    or dice.emoji ~= game.emoji
  then
    return bot.events.onChatMessage(ctx)
  end

  local data = session.data or {}
  local state = data[rollerId] or { score = 0, steps = 0 }

  -- Лимит бросков исчерпан -> бросок игнорируем.
  if state.steps >= gameTypes.MAX_STEPS then
    return
  end

  state.score = state.score + dice.value
  state.steps = state.steps + 1
  data[rollerId] = state

  local _, updateErr = gamingService.updateData(session.player1_id, data)
  if updateErr then
    log.error(updateErr)
    return
  end

  -- Партия завершается, когда оба сделали все ходы.
  local state1 = data[session.player1_id]
  local state2 = data[session.player2_id]

  if state1 and state2
    and state1.steps >= gameTypes.MAX_STEPS
    and state2.steps >= gameTypes.MAX_STEPS
  then
    finish(ctx, session, data)
    return
  end

  -- Промежуточный ход: показываем игроку текущий счёт.
  ctx:replyToMessage(render.gameStep(session.game_type, state.steps, dice.value, state.score))
end

return onDice
