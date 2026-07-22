--- Модель дружбы (одна сторона: user_id -> friend_id).
--
local datetime = require('datetime')
local Errors = require('src.models.Errors')

--- Конструктор модели Friend.
-- @tparam table data сырые поля (из запроса или из БД)
-- @tparam[opt] table opts опции { init = true } - инициализация всех полей
-- @treturn[1] table model
-- @treturn[2] table errs
local function Friend(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'friends' })
  local model = {}

  -- Чьи друзья
  if tonumber(data.user_id) then
    model.user_id = tonumber(data.user_id)
  else
    errors:field_missing('user_id')
  end

  -- Кто в друзьях
  if tonumber(data.friend_id) then
    model.friend_id = tonumber(data.friend_id)
  else
    errors:field_missing('friend_id')
  end

  -- В каком чате заключили дружбу
  if tonumber(data.chat_id) then
    model.chat_id = tonumber(data.chat_id)
  else
    errors:field_missing('chat_id')
  end

  -- Когда заключили
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

return Friend
