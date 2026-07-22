--- Модель лайка (кто кому поставил).
--
local datetime = require('datetime')
local Errors = require('src.models.Errors')

--- Конструктор модели Like.
-- @tparam table data сырые поля (из запроса или из БД)
-- @tparam[opt] table opts опции { init = true } - инициализация всех полей
-- @treturn[1] table model
-- @treturn[2] table errs
local function Like(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'likes' })
  local model = {}

  -- Кто поставил лайк
  if tonumber(data.liking_id) then
    model.liking_id = tonumber(data.liking_id)
  else
    errors:field_missing('liking_id')
  end

  -- Кому поставлен лайк
  if tonumber(data.likee_id) then
    model.likee_id = tonumber(data.likee_id)
  else
    errors:field_missing('likee_id')
  end

  -- Когда поставлен
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

return Like
