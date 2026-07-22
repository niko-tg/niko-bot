--- Установка лайка ответом на сообщение. Один лайк на пару, +XP получателю.
--
local log = require('log')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.like.render')
local usersService = require('src.services.users')
local likesService = require('src.services.likes')

local command = Command:new({
  commands = { '/like', 'лайк' },
  flags = {
    Command.enum.IN_CHAT,
    Command.enum.REPLY,
  },
})

-- Награда получателю за полученный лайк.
local LIKE_XP = 10

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local reply = ctx.message.reply_to_message

  -- Флаг REPLY в preCallCommand не enforced - проверяем здесь.
  if not reply or not reply.from then
    ctx:replyToMessage(render.usage())
    return
  end

  local sender = command.user
  local recipient = reply.from

  if recipient.is_bot then
    ctx:replyToMessage(render.cantLikeBot())
    return
  end

  if recipient.id == sender.id then
    ctx:replyToMessage(render.cantLikeSelf())
    return
  end

  -- Гарантируем запись получателя: мог писать только обычные сообщения, без
  -- команд (users-запись создаёт preCallCommand). На update счётчики не трогаются.
  local _, ensureErr = usersService.upsert(recipient)
  if ensureErr then
    log.error(ensureErr)
    ctx:replyToMessage(render.failed())
    return
  end

  -- Один лайк на пару - проверяем по первичному ключу.
  local existing, readErr = likesService.read(sender.id, recipient.id)
  if readErr then
    log.error(readErr)
    ctx:replyToMessage(render.failed())
    return
  end

  if existing then
    ctx:replyToMessage(render.alreadyLiked(recipient))
    return
  end

  local _, addErr = likesService.add(sender.id, recipient.id)
  if addErr then
    log.error(addErr)
    ctx:replyToMessage(render.failed())
    return
  end

  -- Денормализованный счётчик в профиле получателя.
  local _, incErr = usersService.incLikes(recipient.id)
  if incErr then
    log.error(incErr)
  end

  -- Опыт получателю (как в старом боте).
  local _, xpErr = usersService.addXP(recipient.id, LIKE_XP)
  if xpErr then
    log.error(xpErr)
  end

  ctx:replyToMessage(render.liked(recipient))
end

return command
