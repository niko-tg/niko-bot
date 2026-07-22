--- Preview приветственного сообщения чата.
--
-- Подставляет вызвавшего юзера под ${user} и текущий чат под ${chat},
-- отправляет в чат через тот же путь, что и реальный триггер на нового
-- участника (когда сделаем).
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local helloMessageService = require('src.services.hello_message')
local formatHelloMessage = require('src.utils.formatHelloMessage')

local command = Command:new({
  commands = { '/gethello' },
  flags = {
    Command.enum.IN_CHAT,
    Command.enum.ADMINISTRATIVE,
  },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local chat = command.chat
  local user = command.user

  local hello, readErr = helloMessageService.read(chat.id)

  if readErr then
    log.error(readErr)
    ctx:replyToMessage('⚠️ Не удалось получить приветствие')
    return
  end

  if not hello then
    ctx:replyToMessage('🤷🏼‍♀️ Приветствие не задано. Используйте /mkhello')
    return
  end

  local method, payload = formatHelloMessage(hello, user, chat)

  local _, sendErr = bot[method](bot, payload)

  if sendErr then
    log.error(sendErr)
    ctx:replyToMessage('⚠️ Не удалось отправить приветствие')
  end
end

return command
