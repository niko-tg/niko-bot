--- Создан канал. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
local function on_channel_chat_created(ctx)
  log.verbose('[event] %s', 'on_channel_chat_created')
end

return on_channel_chat_created
