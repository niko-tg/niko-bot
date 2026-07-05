--- Модель фермы пользователя
--
local Errors = require('src.models.Errors')

local function UserFarm(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'user_farm' })
  local model = {}

  if tonumber(data.user_id) then
    model.user_id = tonumber(data.user_id)
  else
    errors:field_missing('user_id')
  end

  if type(data.plots) == 'table' then
    model.plots = setmetatable(data.plots, { __serialize = 'map' })
  elseif init then
    model.plots = setmetatable({}, { __serialize = 'map' })
  end

  if type(data.animals) == 'table' then
    model.animals = setmetatable(data.animals, { __serialize = 'map' })
  elseif init then
    model.animals = setmetatable({}, { __serialize = 'map' })
  end

  if errors:has_errors() then
    return nil, errors:get_compact()
  end

  return model, nil
end

return UserFarm
