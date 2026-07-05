--- Отредактирован топик форума. Заглушка.
--
local log = require('log')

-- luacheck: ignore ctx
local function on_forum_topic_edited(ctx)
  log.verbose('[event] %s', 'on_forum_topic_edited')
end

return on_forum_topic_edited
