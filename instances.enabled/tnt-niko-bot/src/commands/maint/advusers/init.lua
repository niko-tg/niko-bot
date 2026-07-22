--- Рассылка сообщения всем, кто запускал бота. Только для владельца.
--
-- Ответь этой командой на сообщение - бот скопирует его всем пользователям
-- с is_started_bot = true.
--
local log = require('log')
local Command = require('bot.classes.Command')
local hdec = require('bot.libs.hdec')
local runBroadcast = require('src.broadcast.runner')
local usersService = require('src.services.users')

local command = Command:new({
  commands = { '/advusers' },
  flags = { Command.enum.MAINTENANCE },
})

local USAGE = ([[
ℹ️ <b>Рассылка по юзерам</b>
${sep}
Ответь этой командой на сообщение, которое нужно разослать всем,
кто запускал бота.
]]):f({ sep = hdec.sep })

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local reply = ctx:getReplyToMessage()

  if not reply then
    ctx:replyToMessage(USAGE)
    return
  end

  local ids, err = usersService.allStartedIds()

  if err then
    log.error(err)
    ctx:replyToMessage('⚠️ Не удалось получить список юзеров')
    return
  end

  if #ids == 0 then
    ctx:replyToMessage('🤷🏼‍♀️ Некому рассылать - нет запустивших бота')
    return
  end

  runBroadcast({
    ctx = ctx,
    label = 'по юзерам',
    fromChatId = ctx:getChatId(),
    messageId = reply.message_id,
    targets = ids,
  })
end

return command
