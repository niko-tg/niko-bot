--- Модель одиночной партии «Мины»
--
local datetime = require('datetime')
local Errors = require('src.models.Errors')

local function MineSession(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'mine_sessions' })
  local model = {}

  if tonumber(data.user_id) then
    model.user_id = tonumber(data.user_id)
  else
    errors:field_missing('user_id')
  end

  if tonumber(data.chat_id) then
    model.chat_id = tonumber(data.chat_id)
  else
    errors:field_missing('chat_id')
  end

  if tonumber(data.message_id) then
    model.message_id = tonumber(data.message_id)
  else
    errors:field_missing('message_id')
  end

  if tonumber(data.bid) then
    model.bid = tonumber(data.bid)
  else
    errors:field_missing('bid')
  end

  if tonumber(data.mines) then
    model.mines = tonumber(data.mines)
  else
    errors:field_missing('mines')
  end

  if type(data.opened) == 'table' then
    model.opened = setmetatable(data.opened, { __serialize = 'map' })
  elseif init then
    model.opened = setmetatable({}, { __serialize = 'map' })
  end

  if data.created ~= nil then
    model.created = data.created
  elseif init then
    model.created = datetime.new({ timestamp = os.time() })
  end

  if errors:has_errors() then
    return nil, errors:get_compact()
  end

  return model, nil
end

return MineSession
