--- PVP мини-игры: "играть 10к" реплеем -> выбор игры -> инвайт оппоненту.
--
local log = require('log')
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local Command = require('bot.classes.Command')
local decodeMoneyString = require('src.utils.decodeMoneyString')
local usersService = require('src.services.users')
local gamingService = require('src.services.gaming_sessions')
local gameTypes = require('src.enums.game_types')
local render = require('src.commands.public.game.render')

local command = Command:new {
  commands = { '/game', 'играть', 'игра' },
  flags = { Command.enum.IN_CHAT },
}

local MIN_BID = 1000

local USAGE = ([[
🎮 <b>Игра</b>
${sep}
Ответь на сообщение игрока и напиши: <code>играть 10к</code>
Минимальная ставка: <b>${min_bid}</b>р
]]):f({
  min_bid = MIN_BID,
  sep = hdec.sep
})

local function isInGame(user_id)
  return gamingService.getByPlayer(user_id) ~= nil
end

function command.call(ctx)
  local message = ctx.message
  local reply = message.reply_to_message

  if not reply or not reply.from then
    -- Игрок уже в сессии -> показываем её статус вместо подсказки.
    local session = gamingService.getByPlayer(command.user.id)

    if session then
      local opponentId = (session.player1_id == command.user.id) and
        session.player2_id or
        session.player1_id

      local opponent = usersService.read(opponentId) or { id = opponentId }
      local remaining = gameTypes.SESSION_TTL - (os.time() - session.created.timestamp)

      ctx:replyToMessage(render.gameStatus(session, command.user, opponent, remaining))
      return
    end

    ctx:replyToMessage(USAGE)
    return
  end

  local initiator = command.user
  local opponentRaw = reply.from

  if opponentRaw.id == bot:getBotId() then
    ctx:replyToMessage('😈 Я бы с тобой конечно поиграла, но я не умею')
    return
  end

  if opponentRaw.is_bot or opponentRaw.id == initiator.id then
    ctx:replyToMessage('🐶 Как ты это себе представляешь? :>')
    return
  end

  local arg = message.text:match('^%S+%s+(%S+)')
  local bid = arg and decodeMoneyString(arg)

  if not bid then
    ctx:replyToMessage(USAGE)
    return
  elseif bid < MIN_BID then
    ctx:replyToMessage(('💸 Минимальная ставка: <b>${min_bid}</b>р'):f({ min_bid = MIN_BID }))
    return
  end

  if initiator.balance < bid then
    ctx:replyToMessage('💸 У тебя недостаточно средств')
    return
  end

  -- Оппонент должен быть в БД (мог не пользоваться ботом) и иметь баланс.
  local opponent, err = usersService.upsert(opponentRaw)
  if err then
    log.error(err)
    ctx:replyToMessage('⚠️ Ошибка')
    return
  end

  if opponent.balance < bid then
    ctx:replyToMessage('💸 У оппонента недостаточно средств')
    return
  end

  if isInGame(initiator.id) then
    ctx:replyToMessage('🎮 Ты уже в игре')
    return
  end

  if isInGame(opponent.id) then
    ctx:replyToMessage('🎮 Оппонент уже в игре')
    return
  end

  local view = render.gameMenu(initiator, opponent, bid)

  ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })
end

return command
