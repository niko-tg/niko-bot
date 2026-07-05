--- Группа мигрировала в супергруппу. Событие пришло в старой группе,
--- в message.migrate_to_chat_id лежит id новой супергруппы.
--
local log = require('log')
local chatService = require('src.services.chats')
local uicService = require('src.services.user_in_chat')

local function on_migrate_to(ctx)
  log.verbose('[event] %s', 'on_migrate_to')

  local chat = ctx:getChat()

  -- TODO: переносить settings (moderation_chat_id и др.) и статистику
  -- user_in_chat из старого чата в новый по message.migrate_to_chat_id.
  -- Пока удаляем - данные пересоздадутся в новой супергруппе.

  local _, err = uicService.deleteByChatId(chat.id)
  if err then
    log.error(err)
  end

  _, err = chatService.delete(chat.id)
  if err then
    log.error(err)
  end
end

return on_migrate_to
