--- Callback 'Пазла': start (сложность) / memorized (фаза повтора) / tap (ввод).
-- Ownership даёт дефолтный isSameUser-гейт (одиночная игра, не MULTI_USER).
--
local log = require('log')
local bot = require('bot')
local config = require('conf.config')
local Command = require('bot.classes.Command')
local usersService = require('src.services.users')
local vipUsersService = require('src.services.vip_users')
local userGameStatsService = require('src.services.user_game_stats')
local render = require('src.commands.public.puzzle.render')

local command = Command:new({
  commands = { 'cb_puzzle' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action', 'len', 'idx' },
})

--- Перерисовка карточки на месте (правка исходного сообщения).
-- @tparam table ctx контекст обновления
-- @tparam table view { text, keyboard }
local function edit(ctx, view)
  bot:editMessageText({
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    text = view.text,
    reply_markup = view.keyboard,
  })
end

--- Генерация последовательности из len разных индексов эмодзи.
local function genSequence(len)
  local pool = {}
  for i = 1, #config.puzzle.emojis do
    pool[i] = i
  end

  local seq = {}
  for i = 1, len do
    local j = math.random(i, #pool)
    pool[i], pool[j] = pool[j], pool[i]
    seq[i] = pool[i]
  end

  return seq
end

--- Завершение пазла: кулдаун + очистка активного.
local function finishCooldown(user_id)
  return userGameStatsService.finishPuzzle(user_id, os.time() + config.puzzle.cooldown)
end

--- START: выбор сложности -> генерация и фаза 'запомни'.
local function onStart(ctx, user, len)
  local valid = false
  for i = 1, #config.puzzle.lengths do
    local allowed = config.puzzle.lengths[i]
    if allowed == len then
      valid = true
      break
    end
  end

  if not valid then
    ctx:answer()
    return
  end

  local state, err = userGameStatsService.readPuzzle(user.id)
  if err then
    log.error(err)
    ctx:answer()
    return
  end

  if os.time() < state.next then
    ctx:answer({ text = 'Пазл на кулдауне', show_alert = true })
    return
  end

  -- Уже есть активный -> возобновляем (не реролл).
  if state.active then
    ctx:answer()
    edit(ctx, render.resume(state.active))
    return
  end

  -- VIP получает увеличенный выигрыш. Ошибку проверки трактуем как 'не VIP'.
  local isVip, vipErr = vipUsersService.isActive(user.id)
  if vipErr then
    log.error(vipErr)
    isVip = false
  end

  local seq = genSequence(len)
  local win = math.random(len * config.puzzle.win_min_per, len * config.puzzle.win_max_per)
  if isVip then
    win = win * config.puzzle.vip_multiplier
  end

  local active = {
    seq = seq,
    pos = 1,
    phase = 'memorize',
    win = win,
  }

  local _, saveErr = userGameStatsService.savePuzzle(user.id, active)
  if saveErr then
    log.error(saveErr)
    ctx:answer({ text = 'Ошибка', show_alert = true })
    return
  end

  ctx:answer()
  edit(ctx, render.memorize(active))
end

--- MEMORIZED: 'запомнил' -> фаза 'повтори' (порядок скрыт).
local function onMemorized(ctx, user)
  local state, err = userGameStatsService.readPuzzle(user.id)
  if err then
    log.error(err)
    ctx:answer()
    return
  end

  local active = state.active
  if not active or active.phase ~= 'memorize' then
    ctx:answer()
    return
  end

  active.phase = 'recall'

  local _, saveErr = userGameStatsService.savePuzzle(user.id, active)
  if saveErr then
    log.error(saveErr)

    ctx:answer({
      text = 'Ошибка',
      show_alert = true,
    })

    return
  end

  ctx:answer()
  edit(ctx, render.recall(active))
end

--- TAP: ввод эмодзи в фазе 'повтори'.
local function onTap(ctx, user, idx)
  if not idx then
    ctx:answer()
    return
  end

  local state, err = userGameStatsService.readPuzzle(user.id)
  if err then
    log.error(err)
    ctx:answer()
    return
  end

  local active = state.active
  if not active or active.phase ~= 'recall' then
    ctx:answer()
    return
  end

  -- Неверно -> проигрыш: кулдаун, затем раскрытие порядка.
  if active.seq[active.pos] ~= idx then
    local _, finErr = finishCooldown(user.id)
    if finErr then
      log.error(finErr)

      ctx:answer({
        text = 'Ошибка, попробуй ещё',
        show_alert = true,
      })

      return
    end

    ctx:answer({
      text = '💥 Мимо!',
      show_alert = true,
    })

    edit(ctx, render.lose(active))
    return
  end

  -- Верно -> продвигаем.
  active.pos = active.pos + 1

  -- Решено?
  if active.pos > #active.seq then
    local xp = #active.seq * config.puzzle.xp_per_len

    -- Кулдаун + очистка ПЕРВЫМ (защита от двойной выплаты), затем выплата.
    local _, finErr = finishCooldown(user.id)
    if finErr then
      log.error(finErr)

      ctx:answer({
        text = 'Ошибка, попробуй ещё',
        show_alert = true,
      })

      return
    end

    local _, balErr = usersService.addBalance(user.id, active.win)
    if balErr then
      log.error(balErr)
    end

    local _, xpErr = usersService.addXP(user.id, xp)
    if xpErr then
      log.error(xpErr)
    end

    ctx:answer('🧩 Решено!')
    edit(ctx, render.win(active, xp))
    return
  end

  -- Ещё не всё -> сохраняем прогресс.
  local _, saveErr = userGameStatsService.savePuzzle(user.id, active)
  if saveErr then
    log.error(saveErr)
  end

  ctx:answer()
  edit(ctx, render.recall(active))
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  -- Аргументы в локали ДО первого yield (command - общий объект).
  local user = command.user
  local action = command.arguments.action
  local len = tonumber(command.arguments.len)
  local idx = tonumber(command.arguments.idx)

  if action == 'start' then
    onStart(ctx, user, len)
  elseif action == 'memorized' then
    onMemorized(ctx, user)
  elseif action == 'tap' then
    onTap(ctx, user, idx)
  else
    ctx:answer()
  end
end

return command
