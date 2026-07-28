--- Сервис CRUD к чатам.
--
local sql = require('bot.libs.sql')
local bot = require('bot')
local Chat = require('src.models.Chat')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')
local retryTxnConflict = require('src.utils.services.retryTxnConflict')

local service = {}

--- Создание записи.
-- @tparam table data record(s)
-- @treturn[1] table модель chat
-- @treturn[2] table err
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

--- Чтение записи.
-- @tparam number chat_id chat id
-- @treturn[1] table модель chat
-- @treturn[2] table err
function service.read(chat_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        chats
      WHERE
        id = ${id}
    ]], {
      id = chat_id,
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
-- @tparam string username без префикса @, в любом регистре
-- @treturn[1] ?table модель chat
-- @treturn[2] table err
function service.readByUsername(username)
  local item, err = sql(
    [[
      SELECT *
      FROM
        chats
      WHERE
        username = ${username}
    ]], {
      username = tostring(username):lower(),
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

--- Обновление записи.
-- @tparam table fields fields
-- @tparam table where where condition
-- @treturn[1] table res
-- @treturn[2] table err
function service.update(fields, where)
  -- NoSQL вариант: settings - map, SQL UPDATE для map-полей в Tarantool 3
  -- не работает. where должен быть полным первичным ключом ({ id }).
  local res, err = sql.update_nosql('chats', fields, where)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return res, nil
end

--- Удаление записи.
-- @tparam number chat_id chat id
-- @treturn[1] table res
-- @treturn[2] table err
function service.delete(chat_id)
  local res, err = sql(
    [[
      DELETE FROM
        chats
      WHERE
        id = ${id}
    ]], {
      id = chat_id,
    })

  if err then
    return res, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return res, nil
end

--- Гарантированное создание записи (если записи не существует).
-- @tparam table data chat object
-- @treturn[1] table модель chat
-- @treturn[2] table err
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

--- Upsert чата с атомарным +1 к total_messages той же операцией.
-- sql.upsert умеет только '='-ops, а отдельный UPDATE счётчика был второй
-- записью в самый контендящийся кортеж (все сообщения чата бьют в одну
-- запись) и удваивал окно MVCC-конфликта. Здесь box.space:upsert:
-- телеграм-поля обновляются и счётчик растёт одной записью.
-- @tparam table defaultChat полная модель для случая вставки
-- @tparam table data сырые поля для '='-ops (как update_fields у sql.upsert)
-- @treturn[1] boolean true
-- @treturn[2] table err
local function upsertIncMessages(defaultChat, data)
  local space = box.space.chats

  local tuple = {}
  local ops = { { '+', 'total_messages', 1 } }

  local format = space:format()
  for i = 1, #format do
    local name = format[i].name
    local value = defaultChat[name]

    if value == nil or value == box.NULL then
      tuple[i] = box.NULL
    else
      tuple[i] = value
    end

    -- id - первичный ключ, менять его ops-ами нельзя;
    -- total_messages занят '+'-оп-ом выше
    if name ~= 'id' and name ~= 'total_messages' and data[name] ~= nil then
      table.insert(ops, { '=', name, data[name] })
    end
  end

  local ok, err = pcall(space.upsert, space, tuple, ops)
  if not ok then
    return nil, err
  end

  return true, nil
end

--- Добавление или обновление записи.
-- При вставке создаёт полную запись с дефолтами
-- При обновлении меняет только переданные поля
-- data обязан содержать id и type - обязательные поля модели Chat
-- @tparam table data fields
-- @tparam[opt] table opts { inc_total_messages = true } - учесть сообщение
--   в total_messages той же записью (горячий путь onChatMessage)
-- @treturn[1] table модель chat
-- @treturn[2] table err
function service.upsert(data, opts)
  local incTotal = opts and opts.inc_total_messages

  -- Полная модель с дефолтами для случая вставки
  local defaultChat, errs = Chat(data, { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  local _, err

  if incTotal then
    -- Вставка = первое сообщение чата: счётчик сразу с единицы,
    -- '+'-ops при вставке не применяются
    defaultChat.total_messages = 1

    _, err = retryTxnConflict(function()
      return upsertIncMessages(defaultChat, data)
    end)
  else
    -- Атомарная вставка / обновление
    _, err = sql.upsert('chats', defaultChat, data)
  end

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  -- Чтение чата
  return service.read(defaultChat.id)
end

--- Инкремент кассы чата (пополнение из проигрышей слота).
-- Одиночный SQL UPDATE атомарен сам по себе, лишней транзакции не нужно.
-- casino_cashier - unsigned, прибавление в минус не уходит.
-- @tparam number chat_id
-- @tparam number amount
-- @treturn[1] boolean true
-- @treturn[2] table err
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
-- @tparam number chat_id
-- @treturn[1] number сколько было в кассе
-- @treturn[2] table err
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

--- Атомарный +1 к числу участников чата (вход/возврат участника).
-- @tparam number chat_id
-- @treturn[1] boolean true
-- @treturn[2] table err
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
-- @tparam number chat_id
-- @treturn[1] boolean true
-- @treturn[2] table err
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
-- @tparam number limit
-- @tparam number offset
-- @treturn[1] table массив { id, title, username, casino_cashier }
-- @treturn[2] table err
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
-- @treturn[1] number
-- @treturn[2] table err
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
-- @tparam number limit
-- @tparam number offset
-- @treturn[1] table массив { id, title, username, total_messages }
-- @treturn[2] table err
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
-- @treturn[1] number
-- @treturn[2] table err
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
-- @treturn[1] table массив (может быть пустым)
-- @treturn[2] table err
function service.allIds()
  local rows, err = sql([[
    SELECT id
    FROM SEQSCAN chats
  ]])

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  local ids = {}
  rows = rows or {}
  for i = 1, #rows do
    local row = rows[i]
    ids[#ids + 1] = row.id
  end

  return ids, nil
end

return service
