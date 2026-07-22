--- General-топик форума показан. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
--- General-топик форума показан. Заглушка.
-- @tparam table ctx контекст обновления
local function onGeneralForumTopicUnhidden(ctx)
  log.verbose('[event] %s', 'on_general_forum_topic_unhidden')
end

return onGeneralForumTopicUnhidden
