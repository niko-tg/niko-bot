--- Создан канал. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
--- Создан канал. Заглушка.
-- @tparam table ctx контекст обновления
local function onChannelChatCreated(ctx)
  log.verbose('[event] %s', 'on_channel_chat_created')
end

return onChannelChatCreated
