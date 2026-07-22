--- Сервис CRUD к VIP пользователям.
--
local log = require('log')
local sql = require('bot.libs.sql')
local VipUser = require('src.models.VipUser')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')

local service = {}

--- Чтение записи.
-- @tparam number user_id user id
-- @treturn[1] table модель vip_user
-- @treturn[2] table err
function service.read(user_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        vip_users
      WHERE
        user_id = ${user_id}
    ]], {
      user_id = user_id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local vipUser, errs = VipUser(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return vipUser, nil
end

--- Активна ли VIP-подписка пользователя в данный момент.
-- Запись может оставаться в таблице после окончания подписки, поэтому
-- проверяем срок until_date, а не сам факт наличия записи.
-- @tparam number user_id user id
-- @treturn[1] boolean активна ли подписка
-- @treturn[2] table err
function service.isActive(user_id)
  local vipUser, err = service.read(user_id)
  if err then
    return nil, err
  end

  if vipUser == nil then
    return false, nil
  end

  return vipUser.until_date > os.time(), nil
end

--- Обновление записи.
-- @tparam table fields fields
-- @tparam table where where condition, напр. { user_id = .. }
-- @treturn[1] table res
-- @treturn[2] table err
function service.update(fields, where)
  local res, err = sql.update('vip_users', fields, where)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return res, nil
end

--- Добавление или обновление записи.
-- При вставке создаёт полную запись, при обновлении меняет только переданные поля
-- @tparam table data fields
-- @treturn[1] table модель vip_user
-- @treturn[2] table err
function service.upsert(data)
  -- Если меняется until_date (т.е. продление подписки) и вызывающий явно
  -- не передал reminder_sent - сбрасываем флаг сами, чтобы за сутки до
  -- НОВОЙ даты окончания напоминалка отправилась повторно.
  if data.until_date ~= nil and data.reminder_sent == nil then
    data.reminder_sent = false
  end

  local defaultVipUser, errs = VipUser(data, { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  -- Для обновления существующей записи берём ТОЛЬКО те ключи, что пришли
  -- в исходном data, но значения - уже нормализованные моделью
  local updateFields = {}
  for key in pairs(data) do
    updateFields[key] = defaultVipUser[key]
  end

  local _, err = sql.upsert('vip_users', defaultVipUser, updateFields)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return service.read(defaultVipUser.user_id)
end

--- Список VIP-записей, у которых подписка истекает не позднее чем через
-- thresholdSec секунд и напоминалка ещё не отправлена.
-- Уже истёкшие записи (until_date <= now) не возвращаются.
-- @tparam number thresholdSec
-- @treturn[1] table массив моделей vip_user (может быть пустым)
-- @treturn[2] table err
function service.listExpiringSoon(thresholdSec)
  local now = os.time()

  local items, err = sql(
    [[
      SELECT *
      FROM
        vip_users
      WHERE
        until_date > ${now}
        AND until_date <= ${max_until}
        AND reminder_sent = ${not_sent}
    ]], {
      now = now,
      max_until = now + thresholdSec,
      not_sent = false,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if items == nil then
    return {}, nil
  end

  local list = {}
  for i = 1, #items do
    local item = items[i]
    local vipUser, errs = VipUser(item, { init = true })
    if errs then
      log.error(errs)
    else
      table.insert(list, vipUser)
    end
  end

  return list, nil
end

return service
