--- Кусь: укусить человека ответом на его сообщение. Укус случайной редкости
-- даёт кусающему +силу укуса в счётчик. Есть шанс промаха и анти-спам кулдаун.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local config = require('conf.config')
local bites = require('src.commands.public.kus.bites')
local render = require('src.commands.public.kus.render')
local usersService = require('src.services.users')
local userGameStatsService = require('src.services.user_game_stats')

local command = Command:new({
  commands = { '/kus', 'кусь', 'кукусь', 'кукуси', 'кукусики' },
  flags = {
    Command.enum.IN_CHAT,
    Command.enum.REPLY,
  },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local reply = ctx.message.reply_to_message

  -- Флаг REPLY в preCallCommand не enforced - проверяем здесь.
  if not reply or not reply.from then
    ctx:replyToMessage(render.usage())
    return
  end

  local biter = command.user
  local victim = reply.from

  if victim.is_bot then
    ctx:replyToMessage(render.cantBot())
    return
  end

  if victim.id == biter.id then
    ctx:replyToMessage(render.cantSelf())
    return
  end

  -- Анти-спам: кулдаун между укусами. Штамп ставится на каждую попытку.
  local claim, claimErr = userGameStatsService.claimKus(biter.id, config.kus.cooldown)
  if claimErr then
    log.error(claimErr)
    return
  end

  if not claim.granted then
    ctx:replyToMessage(render.cooldown(claim.lastKusAt + config.kus.cooldown))
    return
  end

  -- Промах: укус не засчитывается.
  if math.random(1, 100) <= config.kus.miss_chance then
    ctx:reply({
      text = render.miss(biter, victim),
      reply_parameters = { message_id = reply.message_id },
    })
    return
  end

  -- Удачный укус: тир редкости + сила.
  local bite = bites.roll()

  -- Счётчик кусающему (+сила укуса). command.user.kuses - значение до инкремента.
  local _, incErr = usersService.incKuses(biter.id, bite.power)
  if incErr then
    log.error(incErr)
  end

  local totalKuses = biter.kuses + bite.power

  bot:sendAnimation({
    chat_id = ctx:getChatId(),
    animation = bite.animation,
    caption = render.caption(biter, victim, bite, totalKuses),
    reply_parameters = { message_id = reply.message_id },
  })
end

return command
