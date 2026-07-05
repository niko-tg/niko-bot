--- Получение ID юзера.
--
-- Варианты вызова:
--   /uid               - ответом на сообщение, id из reply.from
--   /uid @oxniko       - лукап в БД по username
--
local log = require('log')
local Command = require('bot.classes.Command')
local hdec = require('bot.libs.hdec')
local resolveTargetUser = require('src.utils.resolveTargetUser')

local command = Command:new {
  commands = { '/uid' },
  flags = { Command.enum.MAINTENANCE },
}

local USAGE = ([[
ℹ️ <b>Использование</b>
${sep}
<code>/uid</code> - ответом на сообщение
<code>/uid @oxniko</code> - по username (лукап в БД)
]]):f({ sep = hdec.sep })

local RESULT_TEMPLATE = [[
🆔 [${user}] <code>${userId}</code>
]]

--- Берёт первый токен после "/uid"
--  Если это @username - возвращает нормализованный.
local function parseUsername(text)
  local tokens = {}
  for token in text:gmatch('%S+') do
    table.insert(tokens, token)
  end

  local arg = tokens[2]
  if arg and arg:sub(1, 1) == '@' then
    return arg:sub(2):lower()
  end

  return nil
end

function command.call(ctx)
  local message = ctx.message
  local reply = message.reply_to_message

  -- Reply имеет приоритет - он самый явный
  if reply and reply.from then
    ctx:replyToMessage(RESULT_TEMPLATE:f({
      user = hdec.user(reply.from, { no_link = true }),
      userId = reply.from.id,
    }))
    return
  end

  local username = parseUsername(message.text)

  if not username then
    ctx:replyToMessage(USAGE)
    return
  end

  local user, lookupErr = resolveTargetUser({ username = username })

  if lookupErr then
    log.error(lookupErr)
    ctx:replyToMessage('⚠️ Ошибка чтения пользователя')
    return
  end

  if not user then
    ctx:replyToMessage('🤷🏼‍♀️ Пользователь не найден в БД')
    return
  end

  ctx:replyToMessage(RESULT_TEMPLATE:f({
    user = hdec.user(user, { no_link = true }),
    userId = user.id,
  }))
end

return command
