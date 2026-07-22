--- Модель брака (одна сторона: user_id -> partner_id).
--
local datetime = require('datetime')
local Errors = require('src.models.Errors')

--- Конструктор модели Marriage.
-- @tparam table data сырые поля (из запроса или из БД)
-- @tparam[opt] table opts опции { init = true } - инициализация всех полей
-- @treturn[1] table model
-- @treturn[2] table errs
local function Marriage(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'marriages' })
  local model = {}

  -- Чей брак
  if tonumber(data.user_id) then
    model.user_id = tonumber(data.user_id)
  else
    errors:field_missing('user_id')
  end

  -- Партнёр в браке
  if tonumber(data.partner_id) then
    model.partner_id = tonumber(data.partner_id)
  else
    errors:field_missing('partner_id')
  end

  -- В каком чате поженились (только для отображения, брак к чату не привязан)
  if tonumber(data.chat_id) then
    model.chat_id = tonumber(data.chat_id)
  else
    errors:field_missing('chat_id')
  end

  -- Когда поженились
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

return Marriage
