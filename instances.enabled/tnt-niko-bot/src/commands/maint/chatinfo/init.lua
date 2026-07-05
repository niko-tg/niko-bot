--- Получение инфы по чату
--
local log = require('log')
local hdec = require('bot.libs.hdec')
local Command = require('bot.classes.Command')
local chatService = require('src.services.chats')
local tableRender = require('src.utils.tableRender')

local command = Command:new {
  commands = { '/chatinfo' },
  flags = { Command.enum.MAINTENANCE }
}

local function parseArgs(text)
  local args = {}

  for key, value in text:gmatch('([%w_]+)=(%S+)') do
    args[key] = value
  end

  return next(args) and args
end

local HEADER = [[
ℹ️ <b>Информация по чату</b>
${sep}
Title: <code>${chat_title}</code>
Chat ID: <code>${chat_id}</code>
${sep}
]]

function command.call(ctx)
  local args = parseArgs(ctx:getText())
  local chatId

  if args == nil then
    chatId = ctx:getChatId()
  elseif args.chat_id then
    chatId = tonumber(args.chat_id)
    if not chatId then
      ctx:reply('Ошибка распознания ID')
      return
    end
  end

  -- Чтение чата из хранилища
  --
  local item, err = chatService.read(chatId)

  if err then
    log.error(err)
    ctx:reply('Ошибка при чтении из хранилища')
    return
  end

  if item == nil then
    ctx:reply('Чат не найден в хранилище')
    return
  end
  --

  ctx:reply(
    HEADER:f({
      chat_title = item.title,
      chat_id = item.id,
      sep = hdec.sep,
    })
    .. '<pre><code class="language-json">'
    .. tableRender(item)
    .. '</code></pre>'
  )
end

return command
