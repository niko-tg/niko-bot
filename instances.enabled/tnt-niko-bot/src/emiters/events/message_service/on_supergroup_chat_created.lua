--- Создана супергруппа. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
--- Создана супергруппа. Заглушка.
-- @tparam table ctx контекст обновления
local function onSupergroupChatCreated(ctx)
  log.verbose('[event] %s', 'on_supergroup_chat_created')
end

return onSupergroupChatCreated
