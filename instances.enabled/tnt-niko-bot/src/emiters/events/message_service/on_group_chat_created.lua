--- Создана группа. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
--- Создана группа. Заглушка.
-- @tparam table ctx контекст обновления
local function onGroupChatCreated(ctx)
  log.verbose('[event] %s', 'on_group_chat_created')
end

return onGroupChatCreated
