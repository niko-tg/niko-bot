--- Callback PVP-игры: выбор игры (pick) / принять (accept) / отклонить (decline).
-- Ownership проверяется здесь (cb_game освобождён от isSameUser в onCallbackQuery).
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local usersService = require('src.services.users')
local gamingService = require('src.services.gaming_sessions')
local render = require('src.commands.public.game.render')
local getErrType = require('src.utils.services.getErrType')
local services_error_type = require('src.enums.services.services_error_type')

local command = Command:new({
  commands = { 'cb_game' },
  flags = { Command.enum.CALLBACK, Command.enum.MULTI_USER },
  arguments_schema = { 'action', 'game_type', 'initiator', 'opponent', 'bid' },
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

--- Занят ли игрок активной сессией.
-- @tparam number user_id id игрока
-- @treturn boolean
local function isInGame(user_id)
  return gamingService.getByPlayer(user_id) ~= nil
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local args = command.arguments
  local action = args.action
  local initiatorId = tonumber(args.initiator)
  local opponentId = tonumber(args.opponent)
  local bid = tonumber(args.bid)
  local gameType = args.game_type
  local presser = command.user

  -- Выбор игры - только инициатор.
  if action == 'pick' then
    if presser.id ~= initiatorId then
      ctx:answer({
        text = 'Это не твой выбор 🙃',
        show_alert = true,
      })

      return
    end

    local opponent, err = usersService.read(opponentId)
    if err or not opponent then
      log.error(err or 'opponent not found')

      ctx:answer({
        text = 'Оппонент не найден',
        show_alert = true,
      })

      return
    end

    ctx:answer()
    edit(ctx, render.invite(presser, opponent, gameType, bid))
    return
  end

  -- Принять/отклонить - только оппонент.
  if presser.id ~= opponentId then
    ctx:answer({
      text = 'Это не твоё приглашение 🙃',
      show_alert = true,
    })
    return
  end

  if action == 'decline' then
    ctx:answer('Отклонено')

    edit(ctx, { text = '❌ Игра отклонена.' })
    return
  end

  if action == 'accept' then
    -- Перепроверка: оба свободны (прошло время с инвайта).
    if isInGame(initiatorId) or isInGame(opponentId) then
      ctx:answer({
        text = 'Кто-то уже в игре',
        show_alert = true,
      })

      edit(ctx, { text = '🎮 Игра отменена: кто-то уже играет.' })
      return
    end

    -- Резерв ставок (атомарно; не хватает -> ошибка, ничего не списано).
    local _, reserveErr = usersService.reservePair(initiatorId, opponentId, bid)
    if reserveErr then
      -- Нехватка средств - штатный отказ, в лог не пишем.
      if getErrType(reserveErr) == services_error_type.INSUFFICIENT_FUNDS then
        ctx:answer({
          text = 'У кого-то недостаточно средств',
          show_alert = true,
        })

        edit(ctx, { text = '💸 Игра отменена: недостаточно средств.' })
        return
      end

      log.error(reserveErr)

      ctx:answer({
        text = 'Не удалось сделать ставки',
        show_alert = true,
      })

      edit(ctx, { text = '⚠️ Игра отменена: внутренняя ошибка.' })
      return
    end

    -- Создание сессии.
    local _, createErr = gamingService.create({
      player1_id = initiatorId,
      player2_id = opponentId,
      chat_id = ctx:getChatId(),
      game_type = gameType,
      bid = bid,
    })

    if createErr then
      log.error(createErr)

      usersService.refundGame(initiatorId, opponentId, bid)

      ctx:answer({
        text = 'Не удалось начать игру',
        show_alert = true,
      })

      edit(ctx, { text = '⚠️ Не удалось начать игру.' })
      return
    end

    local initiator = usersService.read(initiatorId)

    ctx:answer('Игра началась! 🎮')
    edit(ctx, render.gameStart(initiator or presser, presser, gameType, bid))
    return
  end
end

return command
