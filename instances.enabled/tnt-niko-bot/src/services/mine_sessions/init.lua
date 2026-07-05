-- Сервис CRUD к партиям «Мины»
--
local log = require('log')
local sql = require('bot.libs.sql')
local MineSession = require('src.models.MineSession')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')

local service = {}

--- Создание партии
-- @param data (table) record
-- @return[1] model mine_session
-- @return[2] err
function service.create(data)
  local session, errs = MineSession(data, { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  local _, err = sql.create('mine_sessions', session)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return session, nil
end

--- Активная партия игрока либо nil.
-- @param user_id (number)
-- @return[1] model mine_session | nil
-- @return[2] err
function service.getByUser(user_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        mine_sessions
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

  local session, errs = MineSession(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return session, nil
end

--- Сохранение партии (обновление; для map opened через sql.upsert).
-- @param data (table) полная запись партии
-- @return[1] model mine_session
-- @return[2] err
function service.save(data)
  local session, errs = MineSession(data, { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  -- Обновляем только пришедшие ключи, значения - нормализованные моделью.
  local updateFields = {}
  for key in pairs(data) do
    updateFields[key] = session[key]
  end

  local _, err = sql.upsert('mine_sessions', session, updateFields)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return session, nil
end

--- Удаление партии по PK.
-- @param user_id (number)
-- @return[1] res
-- @return[2] err
function service.delete(user_id)
  local res, err = sql(
    [[
      DELETE FROM
        mine_sessions
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

--- Протухшие партии (created старше ttlSec назад).
-- created - datetime, SQL-сравнения по нему нет -> box-скан + .timestamp.
-- @param ttlSec (number)
-- @return[1] array mine_session
-- @return[2] err
function service.listExpired(ttlSec)
  local cutoff = os.time() - ttlSec

  local list = {}
  local ok, res = pcall(function()
    for _, tuple in box.space.mine_sessions:pairs() do
      if tuple.created.timestamp <= cutoff then
        table.insert(list, tuple:tomap({ names_only = true }))
      end
    end
  end)

  if not ok then
    return nil, setErrType({ res }, services_error_type.STORAGE_ERROR)
  end

  local sessions = {}
  for _, item in ipairs(list) do
    local session, errs = MineSession(item, { init = true })
    if errs then
      log.error(errs)
    else
      table.insert(sessions, session)
    end
  end

  return sessions, nil
end

return service
