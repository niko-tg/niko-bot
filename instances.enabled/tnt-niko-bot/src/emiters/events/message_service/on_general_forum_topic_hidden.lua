--- General-топик форума скрыт. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
--- General-топик форума скрыт. Заглушка.
-- @tparam table ctx контекст обновления
local function onGeneralForumTopicHidden(ctx)
  log.verbose('[event] %s', 'on_general_forum_topic_hidden')
end

return onGeneralForumTopicHidden
