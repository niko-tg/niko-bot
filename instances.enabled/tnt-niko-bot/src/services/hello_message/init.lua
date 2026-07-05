--- Сервис CRUD к приветственным сообщениям чатов
--
local sql = require('bot.libs.sql')
local HelloMessage = require('src.models.HelloMessage')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')

local service = {}

--- Чтение записи по chat_id (PK)
-- @param chat_id (number)
-- @return[1] model hello_message
-- @return[2] err
function service.read(chat_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        hello_message
      WHERE
        chat_id = ${chat_id}
    ]], {
      chat_id = chat_id
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local helloMessage, errs = HelloMessage(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return helloMessage, nil
end

--- Удаление записи по chat_id
function service.delete(chat_id)
  local res, err = sql(
    [[
      DELETE FROM
        hello_message
      WHERE
        chat_id = ${chat_id}
    ]], {
      chat_id = chat_id
    })

  if err then
    return res, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return res, nil
end

--- Добавление или обновление по chat_id (один приветственный месседж на чат)
function service.upsert(data)
  local defaultHello, errs = HelloMessage(data, { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  local _, err = sql.upsert('hello_message', defaultHello, data)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return service.read(defaultHello.chat_id)
end

return service
