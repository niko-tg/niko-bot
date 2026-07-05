--- Изменилось название чата. Обновляем chats.title.
--
local log = require('log')
local chatService = require('src.services.chats')

local function on_new_chat_title(ctx)
  log.verbose('[event] %s', 'on_new_chat_title')

  local chat = ctx:getChat()
  local new_title = ctx.message.new_chat_title

  local _, err = chatService.update({ title = new_title }, { id = chat.id })
  if err then
    log.error(err)
  end
end

return on_new_chat_title
