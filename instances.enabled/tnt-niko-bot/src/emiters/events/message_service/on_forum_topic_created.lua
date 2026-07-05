--- Создан топик форума. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
local function on_forum_topic_created(ctx)
  log.verbose('[event] %s', 'on_forum_topic_created')
end

return on_forum_topic_created
