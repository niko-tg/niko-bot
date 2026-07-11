---
--
local utf8 = require('utf8')
local bot = require('bot')
local processCommand = require('bot.processes.processCommand')
local isForward = require('src.utils.isForward')

local function onGetMessageText(ctx)
  -- Форварды команд не запускаем, но фильтры/антифлуд должны их видеть.
  if isForward(ctx.message) then
    return bot.events.onChatMessage(ctx)
  end

  -- Нет ни одного слова (текст из пробелов/переносов) - точно не команда.
  local firstToken = ctx.message.text and ctx.message.text:match('(%S+)')
  if not firstToken then
    return bot.events.onChatMessage(ctx)
  end

  local commandName = utf8.lower(firstToken)

  if bot.commands[commandName] then
    return processCommand(ctx, {
      is_text_command = true,
      command = bot.commands[commandName]
    })
  end

  -- Не команда - отдаём в общий обработчик чата (антифлуд и т.п.)
  return bot.events.onChatMessage(ctx)
end

return onGetMessageText
