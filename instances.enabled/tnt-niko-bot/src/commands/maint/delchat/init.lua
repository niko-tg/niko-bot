--- Удаление чата из хранилища по chat_id или @username (maintenance).
--
-- Варианты вызова:
--   /delchat -1001234567   - по chat_id
--   /delchat @niko_chat    - по username (лукап в БД)
--
local log = require('log')
local hdec = require('bot.libs.hdec')
local Command = require('bot.classes.Command')
local chatService = require('src.services.chats')

local command = Command:new({
  commands = { '/delchat' },
  flags = { Command.enum.MAINTENANCE },
})

local USAGE = ([[
ℹ️ <b>Использование</b>
${sep}
<code>/delchat -1001234567</code> - по chat_id
<code>/delchat @niko_chat</code> - по username
]]):f({ sep = hdec.sep })

--- Первый токен после команды (chat_id или @username).
local function parseTarget(text)
  local tokens = {}
  for token in text:gmatch('%S+') do
    table.insert(tokens, token)
  end
  return tokens[2]
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local arg = parseTarget(ctx:getText())

  if not arg then
    ctx:reply(USAGE)
    return
  end

  -- Резолв чата: целое число -> chat_id, иначе -> лукап по username.
  local chat, err
  if arg:match('^-?%d+$') then
    chat, err = chatService.read(tonumber(arg))
  else
    chat, err = chatService.readByUsername(arg:gsub('^@', ''))
  end

  if err then
    log.error(err)
    ctx:reply('⚠️ Ошибка при чтении из хранилища')
    return
  end

  if chat == nil then
    ctx:reply('🤷🏼‍♀️ Чат не найден в хранилище')
    return
  end

  local _, delErr = chatService.delete(chat.id)
  if delErr then
    log.error(delErr)
    ctx:reply('⚠️ Ошибка при удалении')
    return
  end

  ctx:reply(('🗑 Чат удалён: <code>%s</code> (<code>%s</code>)'):format(chat.title or '-', chat.id))
end

return command
