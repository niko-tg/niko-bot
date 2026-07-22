--- Топик форума переоткрыт. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
--- Топик форума переоткрыт. Заглушка.
-- @tparam table ctx контекст обновления
local function onForumTopicReopened(ctx)
  log.verbose('[event] %s', 'on_forum_topic_reopened')
end

return onForumTopicReopened
