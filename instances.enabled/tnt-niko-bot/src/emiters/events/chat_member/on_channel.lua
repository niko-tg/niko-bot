--- Событие chat_member для каналов.
--
local log = require('log')

-- luacheck: ignore ctx
--- Событие chat_member для каналов.
-- @tparam table ctx контекст обновления
local function onChannel(ctx)
  log.verbose('[event] %s', 'on_channel')
end

return onChannel
