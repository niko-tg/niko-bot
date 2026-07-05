--- General-топик форума скрыт. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
local function on_general_forum_topic_hidden(ctx)
  log.verbose('[event] %s', 'on_general_forum_topic_hidden')
end

return on_general_forum_topic_hidden
