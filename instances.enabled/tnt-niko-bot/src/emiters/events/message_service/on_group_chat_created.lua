--- Создана группа. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
local function on_group_chat_created(ctx)
  log.verbose('[event] %s', 'on_group_chat_created')
end

return on_group_chat_created
