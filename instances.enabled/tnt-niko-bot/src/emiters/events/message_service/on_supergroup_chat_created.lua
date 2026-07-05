--- Создана супергруппа. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
local function on_supergroup_chat_created(ctx)
  log.verbose('[event] %s', 'on_supergroup_chat_created')
end

return on_supergroup_chat_created
