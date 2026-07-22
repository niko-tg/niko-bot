--- Сервис CRUD к игровым сессиям.
--
local log = require('log')
local sql = require('bot.libs.sql')
local GameSession = require('src.models.GameSession')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')

local service = {}

--- Создание сессии.
-- @tparam table data record
-- @treturn[1] table модель game_session
-- @treturn[2] table err
function service.create(data)
  local session, errs = GameSession(data, { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  local _, err = sql.create('gaming_sessions', session)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return session, nil
end

--- Чтение сессии по индексированному полю (player1_id PK либо player2_id).
local function readByField(field, value)
  local item, err = sql(
    ('SELECT * FROM gaming_sessions WHERE %s = ${value}'):format(field), {
      value = value,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local session, errs = GameSession(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return session, nil
end

--- Активная сессия игрока (как player1 или player2) либо nil.
-- @tparam number user_id
-- @treturn[1] ?table модель game_session
-- @treturn[2] table err
function service.getByPlayer(user_id)
  local session, err = readByField('player1_id', user_id)
  if err then
    return nil, err
  end

  if session then
    return session, nil
  end

  return readByField('player2_id', user_id)
end

--- Обновление поля data (map). SQL UPDATE для map непригоден -> нативный box.
-- @tparam number player1_id PK сессии
-- @tparam table data новое состояние
-- @treturn[1] ?boolean true
-- @treturn[2] table err
function service.updateData(player1_id, data)
  local ok, res = pcall(function()
    return box.space.gaming_sessions:update(player1_id, {
      { '=', 'data', setmetatable(data, { __serialize = 'map' }) },
    })
  end)

  if not ok then
    return nil, setErrType({ res }, services_error_type.STORAGE_ERROR)
  end

  if res == nil then
    return nil, nil
  end

  return true, nil
end

--- Сессии, протухшие по TTL (created старше ttlSec секунд назад).
-- created - datetime, SQL-сравнения по нему нет -> box-скан + .timestamp.
-- @tparam number ttlSec возраст в секундах, после которого сессия протухла
-- @treturn[1] table массив game_session
-- @treturn[2] table err
function service.listExpired(ttlSec)
  local cutoff = os.time() - ttlSec

  local list = {}
  local ok, res = pcall(function()
    for _, tuple in box.space.gaming_sessions:pairs() do
      if tuple.created.timestamp <= cutoff then
        table.insert(list, tuple:tomap({ names_only = true }))
      end
    end
  end)

  if not ok then
    return nil, setErrType({ res }, services_error_type.STORAGE_ERROR)
  end

  local sessions = {}
  for i = 1, #list do
    local item = list[i]
    local session, errs = GameSession(item, { init = true })
    if errs then
      log.error(errs)
    else
      table.insert(sessions, session)
    end
  end

  return sessions, nil
end

--- Удаление сессии по PK.
-- @tparam number player1_id
-- @treturn[1] table res
-- @treturn[2] table err
function service.delete(player1_id)
  local res, err = sql(
    [[
      DELETE FROM
        gaming_sessions
      WHERE
        player1_id = ${player1_id}
    ]], {
      player1_id = player1_id,
    })

  if err then
    return res, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return res, nil
end

return service
