--- Рассылка сообщения по всем известным чатам. Только для владельца.
--
-- Ответь этой командой на сообщение -
-- бот скопирует его во все групповые чаты, где есть бот.
--
local log = require('log')
local Command = require('bot.classes.Command')
local hdec = require('bot.libs.hdec')
local runBroadcast = require('src.broadcast.runner')
local chatsService = require('src.services.chats')

local command = Command:new({
  commands = { '/advchats' },
  flags = { Command.enum.MAINTENANCE },
})

local USAGE = ([[
ℹ️ <b>Рассылка по чатам</b>
${sep}
Ответь этой командой на сообщение, которое нужно разослать
по всем чатам с ботом.
]]):f({ sep = hdec.sep })

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local reply = ctx:getReplyToMessage()

  if not reply then
    ctx:replyToMessage(USAGE)
    return
  end

  local ids, err = chatsService.allIds()

  if err then
    log.error(err)
    ctx:replyToMessage('⚠️ Не удалось получить список чатов')
    return
  end

  if #ids == 0 then
    ctx:replyToMessage('🤷🏼‍♀️ Некому рассылать - нет чатов')
    return
  end

  runBroadcast({
    ctx = ctx,
    label = 'по чатам',
    fromChatId = ctx:getChatId(),
    messageId = reply.message_id,
    targets = ids,
  })
end

return command
