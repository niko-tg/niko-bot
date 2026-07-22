--- Удаление приветственного сообщения чата.
--
-- Удаляет запись из hello_message и выключает has_enable_hello_message
-- в настройках чата (чтобы не оставлять оборванный флаг с пустым приветом).
--
local log = require('log')
local Command = require('bot.classes.Command')
local helloMessageService = require('src.services.hello_message')
local chatService = require('src.services.chats')

local command = Command:new({
  commands = { '/rmhello' },
  flags = {
    Command.enum.IN_CHAT,
    Command.enum.ADMINISTRATIVE,
  },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local chat = command.chat

  -- Проверяем что приветствие вообще есть
  --
  local existing, readErr = helloMessageService.read(chat.id)

  if readErr then
    log.error(readErr)
    ctx:replyToMessage('⚠️ Не удалось проверить приветствие')
    return
  end

  if not existing then
    ctx:replyToMessage('🤷🏼‍♀️ Приветствия и так нет')
    return
  end
  --

  -- Удаление записи
  --
  local _, delErr = helloMessageService.delete(chat.id)

  if delErr then
    log.error(delErr)
    ctx:replyToMessage('⚠️ Не удалось удалить приветствие')
    return
  end
  --

  -- Выключаем флаг в настройках. Не критично если упадёт - приветствие
  -- уже удалено, отправлять нечего.
  --
  local settings = chat.settings or {}
  settings.has_enable_hello_message = false

  local _, chatUpdErr = chatService.update({ settings = settings }, { id = chat.id })

  if chatUpdErr then
    log.error(chatUpdErr)
  end
  --

  ctx:replyToMessage('🗑 Приветствие удалено')
end

return command
