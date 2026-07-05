--- Callback предложения брака: приём или отказ. Решает только приглашённый.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.marry.render')
local usersService = require('src.services.users')
local marriagesService = require('src.services.marriages')
local userMention = require('src.render.userMention')

local command = Command:new {
  commands = { 'cb_marry' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action', 'proposer', 'invited' },
}

function command.call(ctx)
  local arguments = command.arguments
  local action = arguments.action
  local proposerId = tonumber(arguments.proposer)
  local invitedId = tonumber(arguments.invited)

  local presser = command.user

  -- Принять/отказать может только приглашённый.
  if not invitedId or presser.id ~= invitedId then
    ctx:answer({ text = render.notForYou(), show_alert = true })
    return
  end

  ctx:answer()

  if not proposerId then
    return
  end

  local chatId = ctx:getChatId()
  local messageId = ctx:getMessageId()

  -- Отказ.
  if action ~= 'accept' then
    bot:editMessageText({
      chat_id = chatId,
      message_id = messageId,
      text = render.rejected(),
    })
    return
  end

  -- Перепроверка моногамии: между предложением и нажатием кто-то мог жениться.
  local proposerMarriage, proposerErr = marriagesService.read(proposerId)
  if proposerErr then
    log.error(proposerErr)

    bot:editMessageText({
      chat_id = chatId,
      message_id = messageId,
      text = render.failed()
    })
    return
  end

  if proposerMarriage then
    bot:editMessageText({
      chat_id = chatId,
      message_id = messageId,
      text = render.alreadyProposer()
    })
    return
  end

  local invitedMarriage, invitedErr = marriagesService.read(invitedId)
  if invitedErr then
    log.error(invitedErr)

    bot:editMessageText({
      chat_id = chatId,
      message_id = messageId,
      text = render.failed()
    })
    return
  end

  if invitedMarriage then
    bot:editMessageText({
      chat_id = chatId,
      message_id = messageId,
      text = render.alreadyInvited()
    })
    return
  end

  local _, marryErr = marriagesService.marry(proposerId, invitedId, chatId)
  if marryErr then
    log.error(marryErr)

    bot:editMessageText({
      chat_id = chatId,
      message_id = messageId,
      text = render.failed()
    })
    return
  end

  -- Имена для результата (с учётом приватности).
  local proposer, proposerReadErr = usersService.read(proposerId)
  if proposerReadErr then
    log.error(proposerReadErr)
  end

  local proposerMention = proposer and userMention(proposer) or ('<code>#'..proposerId..'</code>')
  local invitedMention = userMention(presser)

  bot:editMessageText({
    chat_id = chatId,
    message_id = messageId,
    text = render.accepted(proposerMention, invitedMention),
  })
end

return command
