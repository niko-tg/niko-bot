--- Callback друзей: пагинация списка, карточка, подтверждение и удаление.
-- Всё над друзьями вызвавшего (command.user) - чужими не поуправляешь.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.friends.render')
local friendsService = require('src.services.friends')

local command = Command:new({
  commands = { 'cb_friends' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action', 'friend', 'page' },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local arguments = command.arguments
  local action = arguments.action
  local friendId = tonumber(arguments.friend)
  local page = tonumber(arguments.page) or 1
  local ownerId = command.user.id

  ctx:answer()

  local view, err

  if action == 'view' and friendId then
    view, err = render.card(ownerId, friendId, page)

  elseif action == 'del' and friendId then
    view, err = render.confirmDelete(friendId, page)

  elseif action == 'delyes' and friendId then
    local _, rmErr = friendsService.remove(ownerId, friendId)
    if rmErr then
      log.error(rmErr)
      return
    end

    view, err = render.deleted(page)

  else
    -- 'page' и всё прочее - страница списка.
    view, err = render.list(ownerId, page)
  end

  if err then
    log.error(err)
    return
  end

  if not view then
    return
  end

  bot:editMessageText({
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    text = view.text,
    reply_markup = view.keyboard,
  })
end

return command
