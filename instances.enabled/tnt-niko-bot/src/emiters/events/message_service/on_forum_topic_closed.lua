--- Закрыт топик форума. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
--- Закрыт топик форума. Заглушка.
-- @tparam table ctx контекст обновления
local function onForumTopicClosed(ctx)
  log.verbose('[event] %s', 'on_forum_topic_closed')
end

return onForumTopicClosed
