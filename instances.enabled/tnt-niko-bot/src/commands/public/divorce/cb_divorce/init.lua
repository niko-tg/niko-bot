--- Callback развода: подтверждение из карточки, расторжение или отмена.
-- Расторгает брак вызвавшего (command.user) - своим, чужим не поуправляешь.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.divorce.render')
local marriagesService = require('src.services.marriages')

local command = Command:new {
  commands = { 'cb_divorce' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action' },
}

function command.call(ctx)
  local action = command.arguments.action
  local ownerId = command.user.id

  ctx:answer()

  local chatId = ctx:getChatId()
  local messageId = ctx:getMessageId()

  -- Запрос подтверждения (кнопка «Развестись» из карточки брака).
  if action == 'ask' then
    local view, err = render.confirm(ownerId)
    if err then
      log.error(err)
      return
    end

    bot:editMessageText({
      chat_id = chatId,
      message_id = messageId,
      text = view.text,
      reply_markup = view.keyboard,
    })
    return
  end

  -- Отказ - оставляем брак.
  if action ~= 'yes' then
    bot:editMessageText({
      chat_id = chatId,
      message_id = messageId,
      text = render.saved(),
    })
    return
  end

  -- Подтверждён развод: партнёра берём из живой записи.
  local marriage, readErr = marriagesService.read(ownerId)
  if readErr then
    log.error(readErr)
    return
  end

  if not marriage then
    bot:editMessageText({
      chat_id = chatId,
      message_id = messageId,
      text = render.notMarried(),
    })
    return
  end

  local _, divorceErr = marriagesService.divorce(ownerId, marriage.partner_id)
  if divorceErr then
    log.error(divorceErr)
    return
  end

  bot:editMessageText({
    chat_id = chatId,
    message_id = messageId,
    text = render.divorced(),
  })
end

return command
