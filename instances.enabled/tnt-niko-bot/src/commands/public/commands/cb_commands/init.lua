--- Навигация справочника команд (callback): меню / категория / закрыть.
--
local bot = require('bot')
local auth = require('src.auth')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.commands.render')

local command = Command:new {
  commands = { 'cb_commands' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action' },
}

local function editView(ctx, view)
  bot:editMessageText({
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    text = view.text,
    reply_markup = view.keyboard,
  })
end

function command.call(ctx)
  local action = command.arguments.action
  local isOwner = auth.isBotOwner(command.user)

  if action == 'menu' then
    ctx:answer()
    editView(ctx, render.menu(isOwner))
    return
  end

  local view = render.category(action, isOwner)
  if not view then
    ctx:answer({
      text = 'Недоступно',
      show_alert = true
    })
    return
  end

  ctx:answer()
  editView(ctx, view)
end

return command
