--- Топик форума переоткрыт. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
local function on_forum_topic_reopened(ctx)
  log.verbose('[event] %s', 'on_forum_topic_reopened')
end

return on_forum_topic_reopened
