--- General-топик форума показан. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
local function on_general_forum_topic_unhidden(ctx)
  log.verbose('[event] %s', 'on_general_forum_topic_unhidden')
end

return on_general_forum_topic_unhidden
