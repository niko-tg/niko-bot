--- Модель пользователя с VIP подпиской.
--
local Errors = require('src.models.Errors')

--- Конструктор модели VipUser.
-- @tparam table data сырые поля (из запроса или из БД)
-- @tparam[opt] table opts опции { init = true } - инициализация всех полей
-- @treturn[1] table model
-- @treturn[2] table errs
local function VipUser(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'vip_users' })
  local model = {}

  if tonumber(data.user_id) then
    model.user_id = tonumber(data.user_id)
  else
    errors:field_missing('user_id')
  end

  -- Unix-таймстамп окончания подписки (секунды)
  if tonumber(data.until_date) then
    model.until_date = tonumber(data.until_date)
  else
    errors:field_missing('until_date')
  end

  -- Признак того что напоминалку об окончании уже отправили.
  -- При продлении подписки команда явно передаёт false, чтобы сбросить.
  if data.reminder_sent ~= nil then
    model.reminder_sent = data.reminder_sent
  elseif init then
    model.reminder_sent = false
  end

  if errors:has_errors() then
    return nil, errors:get_compact()
  end

  return model, nil
end

return VipUser
