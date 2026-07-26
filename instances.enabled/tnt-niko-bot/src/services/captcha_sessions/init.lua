--- Сервис CRUD к капча-сессиям новых участников.
--
local log = require('log')
local sql = require('bot.libs.sql')
local CaptchaSession = require('src.models.CaptchaSession')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')

local service = {}

--- Чтение записи по композитному PK (chat_id, user_id).
-- @tparam number chat_id
-- @tparam number user_id
-- @treturn[1] table модель captcha_session
-- @treturn[2] table err
function service.read(chat_id, user_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        captcha_sessions
      WHERE
        chat_id = ${chat_id} AND user_id = ${user_id}
    ]], {
      chat_id = chat_id,
      user_id = user_id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local session, errs = CaptchaSession(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return session, nil
end

--- Добавление или обновление сессии (одна капча на юзера в чате).
function service.upsert(data)
  local defaultSession, errs = CaptchaSession(data, { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  local _, err = sql.upsert('captcha_sessions', defaultSession, data)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return service.read(defaultSession.chat_id, defaultSession.user_id)
end

--- Удаление записи по композитному PK.
function service.delete(chat_id, user_id)
  local res, err = sql(
    [[
      DELETE FROM
        captcha_sessions
      WHERE
        chat_id = ${chat_id} AND user_id = ${user_id}
    ]], {
      chat_id = chat_id,
      user_id = user_id,
    })

  if err then
    return res, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return res, nil
end

--- Атомарное обновление полей сессии по композитному PK.
-- Через box.update: отсутствующая запись не воскрешается (в отличие
-- от upsert) - вернёт nil, если сессию уже забрали обработчик успеха
-- или job таймаута.
-- @tparam number chat_id
-- @tparam number user_id
-- @tparam table fields обновляемые поля { name = value }
-- @treturn[1] table модель captcha_session (nil - сессии уже нет)
-- @treturn[2] nil, table err
function service.update(chat_id, user_id, fields)
  local ops = {}
  for name, value in pairs(fields) do
    table.insert(ops, { '=', name, value })
  end

  local ok, res = pcall(function()
    return box.space.captcha_sessions:update({ chat_id, user_id }, ops)
  end)

  if not ok then
    return nil, setErrType({ res }, services_error_type.STORAGE_ERROR)
  end

  if res == nil then
    return nil, nil
  end

  local session, errs = CaptchaSession(res:tomap({ names_only = true }), { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return session, nil
end

--- Атомарно забирает сессию: удаляет и возвращает удалённую запись.
-- box-delete возвращает удалённый кортеж, поэтому из двух конкурентных
-- обработчиков (нажатие кнопки vs job таймаута) сессию получит только один.
-- @tparam number chat_id
-- @tparam number user_id
-- @treturn[1] table модель captcha_session (nil - сессии уже не было)
-- @treturn[2] nil, table err
function service.take(chat_id, user_id)
  local ok, res = pcall(function()
    return box.space.captcha_sessions:delete({ chat_id, user_id })
  end)

  if not ok then
    return nil, setErrType({ res }, services_error_type.STORAGE_ERROR)
  end

  if res == nil then
    return nil, nil
  end

  local session, errs = CaptchaSession(res:tomap({ names_only = true }), { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return session, nil
end

--- Список сессий старше ttlSec (капча не пройдена вовремя).
-- @tparam number ttlSec TTL в секундах
-- @treturn[1] table список моделей captcha_session
-- @treturn[2] nil, table err
function service.listExpired(ttlSec)
  local cutoff = os.time() - ttlSec

  local list = {}
  local ok, res = pcall(function()
    for _, tuple in box.space.captcha_sessions:pairs() do
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
    local session, errs = CaptchaSession(item, { init = true })
    if errs then
      log.error(errs)
    else
      table.insert(sessions, session)
    end
  end

  return sessions, nil
end

return service
