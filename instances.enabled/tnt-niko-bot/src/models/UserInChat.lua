--- Модель пользователя в чате.
--
local datetime = require('datetime')
local Errors = require('src.models.Errors')

--- Конструктор модели UserInChat.
-- @tparam table data сырые поля (из запроса или из БД)
-- @tparam[opt] table opts опции { init = true } - инициализация всех полей
-- @treturn[1] table model
-- @treturn[2] table errs
local function UserInChat(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'user_in_chat' })
  local model = {}

  -- Связка user <-> chat
  --
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

  -- Дата вступления пользователя в чат
  if data.joined_date ~= nil then
    model.joined_date = data.joined_date
  elseif init then
    model.joined_date = datetime.new({ timestamp = os.time() })
  end

  -- Права пользователя в чате
  if type(data.permissions) == 'table' then
    model.permissions = setmetatable(data.permissions, { __serialize = 'map' })
  elseif init then
    model.permissions = setmetatable({}, { __serialize = 'map' })
  end

  -- Параметры для статистики
  --
  if tonumber(data.count_messages) then
    model.count_messages = tonumber(data.count_messages)
  elseif init then
    model.count_messages = 0
  end

  -- Время последней активности
  if data.last_activity ~= nil then
    model.last_activity = data.last_activity
  elseif init then
    model.last_activity = datetime.new({ timestamp = os.time() })
  end

  -- Статус пользователя в чате, см. bot.enums.chat_member_status
  if data.status then
    model.status = tostring(data.status)
  elseif init then
    model.status = 'member'
  end

  -- Антифлуд: счётчик нарушений и timestamp последнего
  --
  if tonumber(data.antiflood_violations) then
    model.antiflood_violations = tonumber(data.antiflood_violations)
  elseif init then
    model.antiflood_violations = 0
  end

  if tonumber(data.antiflood_last_violation) then
    model.antiflood_last_violation = tonumber(data.antiflood_last_violation)
  elseif init then
    model.antiflood_last_violation = 0
  end

  if errors:has_errors() then
    return nil, errors:get_compact()
  end

  return model, nil
end

return UserInChat
