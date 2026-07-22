--- Пользователь перезапустил бота.
--
local log = require('log')
local userService = require('src.services.users')

-- luacheck: ignore ctx
--- Пользователь перезапустил бота.
-- @tparam table ctx контекст обновления
local function onBotRestart(ctx)
  log.verbose('[event] %s', 'on_bot_restart')

  local userFrom = ctx:getUserFrom()

  -- Обновление статуса
  --
  local _, err = userService.update({ is_started_bot = true }, { id = userFrom.id })

  if err then
    log.error(err)

    return
  end
  --
end

return onBotRestart
