--- Модель инвентаря пользователя
--
local Errors = require('src.models.Errors')

local function Inventory(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'user_inventory' })
  local model = {}

  if tonumber(data.user_id) then
    model.user_id = tonumber(data.user_id)
  else
    errors:field_missing('user_id')
  end

  if type(data.items) == 'table' then
    model.items = setmetatable(data.items, { __serialize = 'map' })
  elseif init then
    model.items = setmetatable({}, { __serialize = 'map' })
  end

  if type(data.tools) == 'table' then
    model.tools = setmetatable(data.tools, { __serialize = 'map' })
  elseif init then
    model.tools = setmetatable({}, { __serialize = 'map' })
  end

  if errors:has_errors() then
    return nil, errors:get_compact()
  end

  return model, nil
end

return Inventory
