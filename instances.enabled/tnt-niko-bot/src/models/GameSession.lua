--- Модель PVP игровой сессии.
--
local datetime = require('datetime')
local Errors = require('src.models.Errors')

--- Конструктор модели GameSession.
-- @tparam table data сырые поля (из запроса или из БД)
-- @tparam[opt] table opts опции { init = true } - инициализация всех полей
-- @treturn[1] table model
-- @treturn[2] table errs
local function GameSession(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'gaming_sessions' })
  local model = {}

  if tonumber(data.player1_id) then
    model.player1_id = tonumber(data.player1_id)
  else
    errors:field_missing('player1_id')
  end

  if tonumber(data.player2_id) then
    model.player2_id = tonumber(data.player2_id)
  else
    errors:field_missing('player2_id')
  end

  if tonumber(data.chat_id) then
    model.chat_id = tonumber(data.chat_id)
  else
    errors:field_missing('chat_id')
  end

  if data.game_type then
    model.game_type = tostring(data.game_type)
  else
    errors:field_missing('game_type')
  end

  if tonumber(data.bid) then
    model.bid = tonumber(data.bid)
  else
    errors:field_missing('bid')
  end

  if type(data.data) == 'table' then
    model.data = setmetatable(data.data, { __serialize = 'map' })
  elseif init then
    model.data = setmetatable({}, { __serialize = 'map' })
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

return GameSession
