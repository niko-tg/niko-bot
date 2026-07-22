--- Предложение дружбы ответом на сообщение. Принимает только приглашённый.
--
local Command = require('bot.classes.Command')
local render = require('src.commands.public.infriends.render')

local command = Command:new({
  commands = { '/infriends', 'вдрузья' },
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

  local view = render.proposal(proposer, invited)

  ctx:reply({
    text = view.text,
    reply_markup = view.keyboard,
    reply_parameters = { message_id = reply.message_id },
  })
end

return command
