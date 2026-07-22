--- Отредактирован топик форума. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
--- Отредактирован топик форума. Заглушка.
-- @tparam table ctx контекст обновления
local function onForumTopicEdited(ctx)
  log.verbose('[event] %s', 'on_forum_topic_edited')
end

return onForumTopicEdited
