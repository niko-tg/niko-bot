--- Событие chat_member для каналов
--
local log = require('log')

-- luacheck: ignore ctx
local function on_channel(ctx)
  log.verbose('[event] %s', 'on_channel')
end

return on_channel
