--- Предложение брака ответом на сообщение. Принимает только приглашённый.
--
local log = require('log')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.marry.render')
local marriagesService = require('src.services.marriages')

local command = Command:new({
  commands = { '/marry', 'вбрак' },
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

  local proposer = command.user
  local invited = reply.from

  if invited.is_bot then
    ctx:replyToMessage(render.cantBot())
    return
  end

  if invited.id == proposer.id then
    ctx:replyToMessage(render.cantSelf())
    return
  end

  -- Брак моногамен: оба должны быть свободны. Проверяем до показа кнопок.
  local proposerMarriage, proposerErr = marriagesService.read(proposer.id)
  if proposerErr then
    log.error(proposerErr)
    ctx:replyToMessage(render.failed())
    return
  end

  if proposerMarriage then
    ctx:replyToMessage(render.alreadyProposer())
    return
  end

  local invitedMarriage, invitedErr = marriagesService.read(invited.id)
  if invitedErr then
    log.error(invitedErr)
    ctx:replyToMessage(render.failed())
    return
  end

  if invitedMarriage then
    ctx:replyToMessage(render.alreadyInvited())
    return
  end

  local view = render.proposal(proposer, invited)

  ctx:reply({
    text = view.text,
    reply_markup = view.keyboard,
    reply_parameters = { message_id = reply.message_id },
  })
end

return command
