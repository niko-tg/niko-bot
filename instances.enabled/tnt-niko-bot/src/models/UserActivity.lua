--- Модель активной задачи добычи.
--
local Errors = require('src.models.Errors')

--- Конструктор модели UserActivity.
-- @tparam table data сырые поля (из запроса или из БД)
-- @tparam[opt] table opts опции { init = true } - инициализация всех полей
-- @treturn[1] table model
-- @treturn[2] table errs
local function UserActivity(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'user_activity' })
  local model = {}

  if tonumber(data.user_id) then
    model.user_id = tonumber(data.user_id)
  else
    errors:field_missing('user_id')
  end

  if type(data.activity) == 'string' then
    model.activity = data.activity
  else
    errors:field_missing('activity')
  end

  if type(data.tool_id) == 'string' then
    model.tool_id = data.tool_id
  else
    errors:field_missing('tool_id')
  end

  if tonumber(data.until_date) then
    model.until_date = tonumber(data.until_date)
  else
    errors:field_missing('until_date')
  end

  if tonumber(data.chat_id) then
    model.chat_id = tonumber(data.chat_id)
  else
    errors:field_missing('chat_id')
  end

  if tonumber(data.message_id) ~= nil then
    model.message_id = tonumber(data.message_id)
  elseif init then
    model.message_id = 0
  end

  if tonumber(data.seed) then
    model.seed = tonumber(data.seed)
  else
    errors:field_missing('seed')
  end

  if errors:has_errors() then
    return nil, errors:get_compact()
  end

  return model, nil
end

return UserActivity
