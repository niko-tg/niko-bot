-- Сервис CRUD к пользователям в чатах
--
local log = require('log')
local datetime = require('datetime')
local sql = require('bot.libs.sql')
local UserInChat = require('src.models.UserInChat')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')
local retryTxnConflict = require('src.utils.services.retryTxnConflict')

local service = {}

--- Чтение записи
-- Запись идентифицируется композитным ключом (chat_id, user_id)
-- @param chat_id (number) chat id
-- @param user_id (number) user id
-- @return[1] model user_in_chat
-- @return[2] err
function service.read(chat_id, user_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        user_in_chat
      WHERE
        chat_id = ${chat_id} AND user_id = ${user_id}
    ]], {
      chat_id = chat_id,
      user_id = user_id
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local user_in_chat, errs = UserInChat(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  return user_in_chat, nil
end

--- Обновление записи
-- @param fields (table) fields
-- @param where (table) where condition, напр. { chat_id = .., user_id = .. }
-- @return[1] res
-- @return[2] err
function service.update(fields, where)
  local res, err = sql.update('user_in_chat', fields, where)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return res, nil
end

--- Получение всех записей user_in_chat по статусу в чате
-- @param chat_id (number) chat id
-- @param status (string) chat_member_status
-- @return[1] array моделей user_in_chat (может быть пустым)
-- @return[2] err
function service.getByStatus(chat_id, status)
  local items, err = sql(
    [[
      SELECT *
      FROM
        user_in_chat
      WHERE
        chat_id = ${chat_id} AND status = ${status}
    ]], {
      chat_id = chat_id,
      status = status,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if items == nil then
    return {}, nil
  end

  local list = {}
  for _, item in ipairs(items) do
    local uic, errs = UserInChat(item, { init = true })
    if errs then
      log.error(errs)
    else
      table.insert(list, uic)
    end
  end

  return list, nil
end

--- Топ активных участников чата по числу сообщений (по убыванию).
-- chat_id даёт primary-индекс, count_messages - остаточный фильтр + сортировка
-- (симметрично getByStatus, поэтому SEQSCAN не нужен).
-- @param chat_id (number)
-- @param limit (number)
-- @param offset (number)
-- @return[1] array { user_id, count_messages } (может быть пустым)
-- @return[2] err
function service.topByMessages(chat_id, limit, offset)
  local rows, err = sql(
    [[
      SELECT user_id, count_messages
      FROM user_in_chat
      WHERE chat_id = ${chat_id} AND count_messages > 0
      ORDER BY count_messages DESC
      LIMIT ${limit} OFFSET ${offset}
    ]], {
      chat_id = chat_id,
      limit = limit,
      offset = offset,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return rows or {}, nil
end

--- Кол-во активных участников чата (count_messages > 0) - для пагинации топа.
-- @param chat_id (number)
-- @return[1] number
-- @return[2] err
function service.countActive(chat_id)
  local rows, err = sql(
    [[
      SELECT COUNT(*) AS "cnt"
      FROM user_in_chat
      WHERE chat_id = ${chat_id} AND count_messages > 0
    ]], {
      chat_id = chat_id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if rows and rows[1] then
    return rows[1].cnt, nil
  end

  return 0, nil
end

--- Учёт сообщения участника. Upsert-safe: если записи нет - создаёт со
--- status='member' (дефолт модели). Растит count_messages и last_activity.
--- Read-modify-write безопасен: между read и upsert нет yield (memtx).
function service.incMessages(chat_id, user_id)
  -- Read-modify-write одного кортежа: под MVCC конкурентные сообщения
  -- одного юзера конфликтуют - ретраим всю связку чтение+upsert.
  return retryTxnConflict(function()
    local uic, err = service.read(chat_id, user_id)
    if err then
      return nil, err
    end

    return service.upsert({
      chat_id = chat_id,
      user_id = user_id,
      count_messages = (uic and uic.count_messages or 0) + 1,
      last_activity = datetime.new({ timestamp = os.time() }),
    })
  end)
end

--- Получение всех записей user_in_chat по пользователю и статусу
-- Путь доступа - вторичный индекс user_id, status идёт остаточным фильтром
-- (симметрично getByStatus, где индекс даёт chat_id, а status фильтрует)
-- @param user_id (number) user id
-- @param status (string) chat_member_status
-- @return[1] array моделей user_in_chat (может быть пустым)
-- @return[2] err
function service.getByUserStatus(user_id, status)
  local items, err = sql(
    [[
      SELECT *
      FROM
        user_in_chat
      WHERE
        user_id = ${user_id} AND status = ${status}
    ]], {
      user_id = user_id,
      status = status,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if items == nil then
    return {}, nil
  end

  local list = {}
  for _, item in ipairs(items) do
    local uic, errs = UserInChat(item, { init = true })
    if errs then
      log.error(errs)
    else
      table.insert(list, uic)
    end
  end

  return list, nil
end

--- Удаление всех записей по chat_id
-- @param chat_id (number) chat id
-- @return[1] res
-- @return[2] err
function service.deleteByChatId(chat_id)
  local res, err = sql(
    [[
      DELETE FROM
        user_in_chat
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

--- Добавление или обновление записи
-- При вставке создаёт полную запись с дефолтами
-- При обновлении меняет только переданные поля
-- @param data (table) fields
-- @return[1] model user_in_chat
-- @return[2] err
function service.upsert(data)
  -- Полная модель с дефолтами для случая вставки
  local defaultUic, errs = UserInChat(data, { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  -- Для обновления существующей записи берём ТОЛЬКО те ключи, что пришли
  -- в исходном data, но значения - уже нормализованные моделью
  local updateFields = {}
  for key in pairs(data) do
    updateFields[key] = defaultUic[key]
  end

  -- Атомарная вставка / обновление
  local _, err = sql.upsert('user_in_chat', defaultUic, updateFields)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  -- Чтение записи
  return service.read(defaultUic.chat_id, defaultUic.user_id)
end

return service
