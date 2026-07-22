--- Callback 'Мин': start (выбор риска) / open (вскрытие) / cashout (забор).
-- Ownership даёт дефолтный isSameUser-гейт (одиночная игра, не MULTI_USER).
--
local log = require('log')
local bot = require('bot')
local config = require('conf.config')
local Command = require('bot.classes.Command')
local usersService = require('src.services.users')
local mineSessionsService = require('src.services.mine_sessions')
local render = require('src.commands.public.mines.render')
local getErrType = require('src.utils.services.getErrType')
local services_error_type = require('src.enums.services.services_error_type')

local command = Command:new({
  commands = { 'cb_mines' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action', 'bid', 'mines', 'pos' },
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

--- Перерисовка доски с актуальным остатком времени сессии.
local function showBoard(ctx, session)
  local remaining = config.mines.ttl - (os.time() - session.created.timestamp)
  edit(ctx, render.board(session, remaining))
end

--- XP за победу: от размера ставки, с нижним порогом. max(xp_min, floor(bid / xp_per)).
local function grantXP(user_id, bid)
  local xp = math.max(config.mines.xp_min, math.floor(bid / config.mines.xp_per))
  if xp > 0 then
    local _, err = usersService.addXP(user_id, xp)
    if err then
      log.error(err)
    end
  end
end

--- Завершение партии забором (ручной cashout либо авто-победа на всех клетках).
local function cashout(ctx, session)
  local opCount = render.countOpened(session.opened)
  local payout = render.payout(session.bid, opCount, session.mines)

  -- Ставка из резерва, выигрыш на баланс. При ошибке не удаляем - пусть нажмёт снова.
  local _, err = usersService.settleReserve(session.user_id, session.bid, payout)
  if err then
    log.error(err)

    ctx:answer({
      text = 'Ошибка выплаты, попробуй ещё',
      show_alert = true,
    })

    return
  end

  grantXP(session.user_id, session.bid)
  mineSessionsService.delete(session.user_id)

  ctx:answer('🍾 Забрал выигрыш!')
  edit(ctx, render.win(session, payout))
end

--- START: выбор риска -> резерв ставки и создание партии (как cb_game.accept).
local function onStart(ctx, user, bid, mines)
  if not bid or not mines then
    ctx:answer()
    return
  end

  if mineSessionsService.getByUser(user.id) then
    ctx:answer({
      text = 'У тебя уже есть партия',
      show_alert = true,
    })

    return
  end

  -- Резерв ставки (атомарно; не хватает -> ошибка, ничего не списано).
  local _, reserveErr = usersService.reserve(user.id, bid)
  if reserveErr then
    -- Нехватка средств - штатный отказ, в лог не пишем.
    if getErrType(reserveErr) == services_error_type.INSUFFICIENT_FUNDS then
      ctx:answer({
        text = 'Недостаточно средств',
        show_alert = true,
      })

      edit(ctx, {
        text = '💸 Партия отменена: недостаточно средств.',
      })

      return
    end

    log.error(reserveErr)

    ctx:answer({
      text = 'Не удалось сделать ставку',
      show_alert = true,
    })

    edit(ctx, {
      text = '⚠️ Партия отменена: внутренняя ошибка.',
    })

    return
  end

  local session, createErr = mineSessionsService.create({
    user_id = user.id,
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    bid = bid,
    mines = mines,
    opened = {},
  })

  if createErr then
    log.error(createErr)

    -- Возврат резерва
    usersService.settleReserve(user.id, bid, bid)

    ctx:answer({
      text = 'Не удалось начать',
      show_alert = true,
    })

    edit(ctx, {
      text = '⚠️ Не удалось начать игру',
    })

    return
  end

  ctx:answer()
  showBoard(ctx, session)
end

--- OPEN: вскрытие клетки (ставка уже зарезервирована на старте).
local function onOpen(ctx, user, session, pos)
  if not pos or pos < 1 or pos > config.mines.cells then
    ctx:answer()
    return
  end

  -- Уже вскрыта - игнор.
  if session.opened[pos] then
    ctx:answer()
    return
  end

  -- Ролл мины: вероятность mines / (осталось клеток).
  local opCount = render.countOpened(session.opened)
  local remaining = config.mines.cells - opCount
  local hitMine = math.random(1, remaining) <= session.mines

  if hitMine then
    -- Ставка сгорает из резерва
    --  При ошибке не удаляем - TTL спишет резерв
    local _, settleErr = usersService.settleReserve(user.id, session.bid, 0)
    if settleErr then
      log.error(settleErr)
    else
      mineSessionsService.delete(user.id)
    end
    --

    ctx:answer({
      text = '💥 БУМ!',
      show_alert = true,
    })

    edit(ctx, render.lose(session, pos))
    return
  end

  -- Безопасно: вскрываем клетку.
  session.opened[pos] = true

  -- Все безопасные вскрыты -> авто-забор по максимуму.
  --
  local safeTotal = config.mines.cells - session.mines

  if render.countOpened(session.opened) >= safeTotal then
    cashout(ctx, session)
    return
  end
  --

  local _, saveErr = mineSessionsService.save(session)
  if saveErr then
    log.error(saveErr)
  end

  ctx:answer()
  showBoard(ctx, session)
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  -- Все аргументы читаем в локали ДО первого yield: command - общий объект,
  -- за время yield (getByUser) параллельный вызов перезапишет command.arguments.
  local user = command.user
  local action = command.arguments.action
  local bid = tonumber(command.arguments.bid)
  local mines = tonumber(command.arguments.mines)
  local pos = tonumber(command.arguments.pos)

  if action == 'start' then
    onStart(ctx, user, bid, mines)
    return
  end

  -- Для open/cashout нужна активная партия.
  local session, err = mineSessionsService.getByUser(user.id)
  if err then
    log.error(err)
    ctx:answer()
    return
  end

  if session == nil then
    ctx:answer({ text = 'Партия не найдена', show_alert = true })
    return
  end

  if action == 'cashout' then
    if render.countOpened(session.opened) == 0 then
      ctx:answer()
      return
    end

    cashout(ctx, session)
    return
  end

  if action == 'open' then
    onOpen(ctx, user, session, pos)
    return
  end

  ctx:answer()
end

return command
