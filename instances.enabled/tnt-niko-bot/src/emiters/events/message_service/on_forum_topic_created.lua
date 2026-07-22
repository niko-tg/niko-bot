--- Создан топик форума. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
--- Создан топик форума. Заглушка.
-- @tparam table ctx контекст обновления
local function onForumTopicCreated(ctx)
  log.verbose('[event] %s', 'on_forum_topic_created')
end

return onForumTopicCreated
