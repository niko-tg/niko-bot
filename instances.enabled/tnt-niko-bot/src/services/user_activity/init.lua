--- Сервис активной задачи добычи: чтение / патч сообщения / удаление.
--
-- Создание задачи живёт в gathering.begin (атомарно с инвентарём), поэтому
-- здесь только чтение и обслуживание.
--
local sql = require('bot.libs.sql')
local UserActivity = require('src.models.UserActivity')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')

local service = {}

--- Активная задача игрока либо nil.
-- @param user_id (number)
-- @return[1] model user_activity | nil
-- @return[2] err
function service.getByUser(user_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        user_activity
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

  local activity, errs = UserActivity(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return activity, nil
end

--- Привязать message_id к задаче (после отправки сообщения о старте).
-- @param user_id (number)
-- @param message_id (number)
-- @return[1] res
-- @return[2] err
function service.setMessage(user_id, message_id)
  local res, err = sql.update('user_activity', { message_id = message_id }, { user_id = user_id })
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return res, nil
end

--- Удаление задачи по PK.
-- @param user_id (number)
-- @return[1] res
-- @return[2] err
function service.delete(user_id)
  local res, err = sql(
    [[
      DELETE FROM
        user_activity
      WHERE
        user_id = ${user_id}
    ]], {
      user_id = user_id,
    })

  if err then
    return res, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return res, nil
end

return service
