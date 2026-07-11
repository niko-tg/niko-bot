-- Сервис CRUD к чатам
--
local sql = require('bot.libs.sql')
local bot = require('bot')
local Chat = require('src.models.Chat')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')
local retryTxnConflict = require('src.utils.services.retryTxnConflict')

local service = {}

--- Создание записи
-- @param data (table) record(s)
-- @return[1] model chat
-- @return[2] err
function service.create(data)
  local chat, errs = Chat(data, { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  local _, err = sql.create('chats', chat)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return chat, nil
end

--- Чтение записи
-- @param chat_id (number) chat id
-- @return[1] model chat
-- @return[2] err
function service.read(chat_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        chats
      WHERE
        id = ${id}
    ]], {
      id = chat_id
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local chat, errs = Chat(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  return chat, nil
end

--- Чтение записи по username (для maint-команд). username хранится в нижнем
-- регистре (Chat-модель), поэтому ищем по lower. Требует индекс username.
-- @param username (string) без префикса @, в любом регистре
-- @return[1] model chat | nil
-- @return[2] err
function service.readByUsername(username)
  local item, err = sql(
    [[
      SELECT *
      FROM
        chats
      WHERE
        username = ${username}
    ]], {
      username = tostring(username):lower()
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local chat, errs = Chat(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  return chat, nil
end

--- Обновление записи
-- @param fields (table) fields
-- @param where (table) where condition
-- @return[1] res
-- @return[2] err
function service.update(fields, where)
  -- NoSQL вариант: settings - map, SQL UPDATE для map-полей в Tarantool 3
  -- не работает. where должен быть полным первичным ключом ({ id }).
  local res, err = sql.update_nosql('chats', fields, where)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return res, nil
end

--- Удаление записи
-- @param chat_id (number) chat id
-- @return[1] res
-- @return[2] err
function service.delete(chat_id)
  local res, err = sql(
    [[
      DELETE FROM
        chats
      WHERE
        id = ${id}
    ]], {
      id = chat_id
    })

  if err then
    return res, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return res, nil
end

--- Гарантированное создание записи (если записи не существует)
-- @param data (table) chat object
-- @return[1] chat model
-- @return[2] err
function service.ensure(data)
  if data.id == nil then
    error('Field id is empty', 1)
  end

  local chat, err = service.read(data.id)
  if err then
    return nil, err
  end

  if chat then
    return chat, nil
  end

  return service.create(data)
end

--- Добавление или обновление записи
-- При вставке создаёт полную запись с дефолтами
-- При обновлении меняет только переданные поля
-- data обязан содержать id и type - обязательные поля модели Chat
-- @param data (table) fields
-- @return[1] model chat
-- @return[2] err
function service.upsert(data)
  -- Полная модель с дефолтами для случая вставки
  local defaultChat, errs = Chat(data, { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  -- Атомарная вставка / обновление
  local _, err = sql.upsert('chats', defaultChat, data)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  -- Чтение чата
  return service.read(defaultChat.id)
end

--- Инкремент кассы чата (пополнение из проигрышей слота).
-- Одиночный SQL UPDATE атомарен сам по себе, лишней транзакции не нужно.
-- casino_cashier - unsigned, прибавление в минус не уходит.
-- @param chat_id (number)
-- @param amount (number)
-- @return[1] true
-- @return[2] err
function service.addCashbox(chat_id, amount)
  local _, err = sql([[
    UPDATE chats
    SET
      casino_cashier = casino_cashier + ${amount}
    WHERE
      id = ${chat_id}
  ]], {
    amount = amount,
    chat_id = chat_id,
  })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Атомарно забрать кассу: вернуть текущее значение и обнулить (джекпот).
-- @param chat_id (number)
-- @return[1] number сколько было в кассе
-- @return[2] err
function service.takeCashbox(chat_id)
  local taken = 0

  local _, err = sql.atomic(function()
    local rows = sql.check(sql([[
      SELECT
        casino_cashier
      FROM
        chats
      WHERE
        id = ${chat_id}
    ]], {
      chat_id = chat_id,
    }))

    -- Чата нет - забирать нечего.
    if rows == nil then
      return
    end

    taken = rows[1].casino_cashier or 0

    if taken > 0 then
      sql.check(sql([[
        UPDATE chats
        SET
          casino_cashier = 0
        WHERE
          id = ${chat_id}
      ]], {
        chat_id = chat_id,
      }))
    end
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return taken, nil
end

--- Атомарный инкремент счётчика активности чата (+1 на сообщение).
-- Самый контендящийся кортеж: все сообщения чата бьют в одну запись,
-- под MVCC параллельные файберы конфликтуют - ретраим.
-- @param chat_id (number)
-- @return[1] true
-- @return[2] err
function service.incTotalMessages(chat_id)
  local _, err = retryTxnConflict(function()
    return sql([[
      UPDATE chats
      SET
        total_messages = total_messages + 1
      WHERE
        id = ${chat_id}
    ]], {
      chat_id = chat_id,
    })
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Атомарный +1 к числу участников чата (вход/возврат участника).
-- @param chat_id (number)
-- @return[1] true
-- @return[2] err
function service.incMembers(chat_id)
  local _, err = sql([[
    UPDATE chats
    SET
      members = members + 1
    WHERE
      id = ${chat_id}
  ]], {
    chat_id = chat_id,
  })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Атомарный -1 к числу участников чата (выход/бан участника).
-- Проверка members > 0: поле unsigned, ниже нуля уходить нельзя (бросит ошибку).
-- @param chat_id (number)
-- @return[1] true
-- @return[2] err
function service.decMembers(chat_id)
  local _, err = sql([[
    UPDATE chats
    SET
      members = members - 1
    WHERE
      id = ${chat_id} AND members > 0
  ]], {
    chat_id = chat_id,
  })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Топ чатов по кассе. casino_cashier > 0 идёт по индексу, reverse-scan -> ORDER BY DESC.
-- Исключаем чаты, где бота кикнули/забанили или он вышел (статус бота в user_in_chat
-- kicked/left) - такие в топ не попадают.
-- @param limit (number)
-- @param offset (number)
-- @return[1] array { id, title, username, casino_cashier }
-- @return[2] err
function service.topByCashbox(limit, offset)
  local botId = bot:getBotId()

  local rows, err = sql([[
    SELECT
      id, title, username, casino_cashier
    FROM
      chats
    WHERE
      casino_cashier > 0
      AND id NOT IN (
        SELECT chat_id FROM user_in_chat
        WHERE user_id = ${botId} AND status IN ('kicked', 'left')
      )
    ORDER BY
      casino_cashier DESC
    LIMIT ${limit}
    OFFSET ${offset}
  ]], {
    botId = botId,
    limit = limit,
    offset = offset,
  })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return rows or {}, nil
end

--- Кол-во чатов с кассой (casino_cashier > 0) - для пагинации.
-- Тот же фильтр, что и topByCashbox (исключаем чаты с кикнутым/вышедшим ботом), иначе число страниц
-- разойдётся со списком.
-- @return[1] number
-- @return[2] err
function service.countByCashbox()
  local botId = bot:getBotId()

  local rows, err = sql([[
    SELECT COUNT(*) AS "cnt"
    FROM chats
    WHERE casino_cashier > 0
      AND id NOT IN (
        SELECT chat_id FROM user_in_chat
        WHERE user_id = ${botId} AND status IN ('kicked', 'left')
      )
  ]], {
    botId = botId,
  })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if rows and rows[1] then
    return rows[1].cnt, nil
  end

  return 0, nil
end

--- Топ чатов по активности (total_messages). Диапазон > 0 по индексу, reverse-scan.
-- @param limit (number)
-- @param offset (number)
-- @return[1] array { id, title, username, total_messages }
-- @return[2] err
function service.topByMessages(limit, offset)
  local rows, err = sql([[
    SELECT id, title, username, total_messages
    FROM chats
    WHERE total_messages > 0
    ORDER BY total_messages DESC
    LIMIT ${limit} OFFSET ${offset}
  ]], {
    limit = limit,
    offset = offset,
  })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return rows or {}, nil
end

--- Кол-во чатов с активностью (total_messages > 0) - для пагинации.
-- @return[1] number
-- @return[2] err
function service.countByMessages()
  local rows, err = sql([[
    SELECT COUNT(*) AS "cnt"
    FROM chats
    WHERE total_messages > 0
  ]])

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if rows and rows[1] then
    return rows[1].cnt, nil
  end

  return 0, nil
end

--- ID всех известных чатов - для рассылки. Полный перебор -> SEQSCAN.
-- @return[1] array<number> (может быть пустым)
-- @return[2] err
function service.allIds()
  local rows, err = sql([[
    SELECT id
    FROM SEQSCAN chats
  ]])

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  local ids = {}
  for _, row in ipairs(rows or {}) do
    ids[#ids + 1] = row.id
  end

  return ids, nil
end

return service
