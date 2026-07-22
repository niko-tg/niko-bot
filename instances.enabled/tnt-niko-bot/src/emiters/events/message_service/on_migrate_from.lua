--- Группа мигрировала в супергруппу. Событие пришло в новой супергруппе,
-- в message.migrate_from_chat_id лежит id старой группы.
--
local log = require('log')
local chatService = require('src.services.chats')

--- Событие миграции в новой супергруппе: перенос данных со старой группы.
-- @tparam table ctx контекст обновления
local function onMigrateFrom(ctx)
  log.verbose('[event] %s', 'on_migrate_from')

  local chat = ctx:getChat()

  -- TODO: подтянуть settings/статистику из старого чата
  -- по message.migrate_from_chat_id. Пока просто гарантируем запись
  -- нового чата с дефолтами.

  local _, err = chatService.upsert({
    id = chat.id,
    type = chat.type,
    title = chat.title,
    username = chat.username,
    is_forum = chat.is_forum,
  })
  if err then
    log.error(err)
  end
end

return onMigrateFrom
