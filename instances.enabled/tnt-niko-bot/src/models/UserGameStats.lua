--- Модель игровой статистики пользователя
--
local Errors = require('src.models.Errors')

local function UserGameStats(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'user_game_stats' })
  local model = {}

  if tonumber(data.user_id) then
    model.user_id = tonumber(data.user_id)
  else
    errors:field_missing('user_id')
  end

  if type(data.stats) == 'table' then
    model.stats = setmetatable(data.stats, { __serialize = 'map' })
  elseif init then
    model.stats = setmetatable({}, { __serialize = 'map' })
  end

  if errors:has_errors() then
    return nil, errors:get_compact()
  end

  return model, nil
end

return UserGameStats
