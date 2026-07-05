--- Callback предложения дружбы: приём или отказ. Решает только приглашённый.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.infriends.render')
local usersService = require('src.services.users')
local friendsService = require('src.services.friends')
local userMention = require('src.render.userMention')

local command = Command:new {
  commands = { 'cb_infriends' },
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

  -- Уже друзья - проверяем по первичному ключу.
  local existing, readErr = friendsService.read(proposerId, invitedId)
  if readErr then
    log.error(readErr)

    bot:editMessageText({
      chat_id = chatId,
      message_id = messageId,
      text = render.failed()
    })
    return
  end

  if existing then
    bot:editMessageText({
      chat_id = chatId,
      message_id = messageId,
      text = render.already()
    })
    return
  end

  local _, addErr = friendsService.add(proposerId, invitedId, chatId)
  if addErr then
    log.error(addErr)

    bot:editMessageText({
      chat_id = chatId,
      message_id = messageId,
      text = render.failed()
    })
    return
  end

  -- Имена для результата (с учётом приватности).
  local proposer, proposerErr = usersService.read(proposerId)
  if proposerErr then
    log.error(proposerErr)
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
