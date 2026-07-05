--- Команда добавления приветственного сообщения чата.
--
-- Использование: ответ командой /mkhello на сообщение, которое должно
-- стать приветствием. Сообщение может содержать:
--   * text или caption с HTML-тегами и плейсхолдерами ${user}, ${chat}
--   * photo / animation / video (берётся file_id для последующей отправки)
--
local log = require('log')
local Command = require('bot.classes.Command')
local hdec = require('bot.libs.hdec')
local parseTags = require('src.utils.parseTags')
local helloMessageService = require('src.services.hello_message')

local command = Command:new {
  commands = { '/mkhello' },
  flags = {
    Command.enum.IN_CHAT,
    Command.enum.ADMINISTRATIVE,
    Command.enum.REPLY,
  }
}

--- Извлекает file (photo/animation/video) из сообщения. Возвращает {} если нет.
local function extractFile(message)
  if message.photo then
    return {
      type = 'photo',
      id = message.photo[#message.photo].file_id,
    }
  end

  if message.animation then
    return {
      type = 'animation',
      id = message.animation.file_id,
    }
  end

  if message.video then
    return {
      type = 'video',
      id = message.video.file_id,
    }
  end

  return {}
end

local TEMPLATE = [[
✅ <b>Приветствие сохранено</b>
${sep}
Настройки чата: /settings
]]

function command.call(ctx)
  local reply = ctx.message.reply_to_message

  if not reply then
    ctx:replyToMessage('🌊 Ответьте этой командой на сообщение, которое должно стать приветствием')
    return
  end

  local text = reply.text or reply.caption or ''
  local file = extractFile(reply)

  -- Нужно хоть что-то: текст или медиа
  if text == '' and not file.type then
    ctx:replyToMessage('🤷🏼‍♀️ В сообщении нет ни текста, ни медиа')
    return
  end

  -- Валидация HTML-тегов (только если есть текст)
  if text ~= '' then
    local ok, errs = parseTags(text)

    if not ok then
      ctx:replyToMessage(
        '⚠️ <b>Ошибки в тегах</b>'
        .. '\n'
        .. hdec.escape(table.concat(errs, '\n')))
      return
    end
  end

  local _, err = helloMessageService.upsert({
    chat_id = command.chat.id,
    user_id = command.user.id,
    text = text,
    file = file,
  })

  if err then
    log.error(err)
    ctx:replyToMessage('⚠️ Не удалось сохранить приветствие')
    return
  end

  ctx:replyToMessage(TEMPLATE:f({ sep = hdec.sep }))
end

return command
