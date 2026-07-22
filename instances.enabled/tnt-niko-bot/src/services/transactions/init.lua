--- Сервис CRUD к успешным транзакциям (донатам).
--
local sql = require('bot.libs.sql')
local Transaction = require('src.models.Transaction')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')

local service = {}

--- Создание записи.
-- @tparam table data record
-- @treturn[1] table модель transaction
-- @treturn[2] table err
function service.create(data)
  local transaction, errs = Transaction(data, { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  local _, err = sql.create('transactions', transaction)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return transaction, nil
end

--- Чтение записи по id платежа Telegram (первичный ключ).
-- Используется для идемпотентности: проверить, не обработан ли платёж ранее.
-- @tparam string telegram_payment_charge_id
-- @treturn[1] ?table модель transaction (или nil, если записи нет)
-- @treturn[2] table err
function service.read(telegram_payment_charge_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        transactions
      WHERE
        telegram_payment_charge_id = ${telegram_payment_charge_id}
    ]], {
      telegram_payment_charge_id = telegram_payment_charge_id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local transaction, errs = Transaction(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return transaction, nil
end

--- Обновление записи.
-- @tparam table fields поля
-- @tparam table where условие, напр. { telegram_payment_charge_id = .. }
-- @treturn[1] table res
-- @treturn[2] table err
function service.update(fields, where)
  local res, err = sql.update('transactions', fields, where)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return res, nil
end

--- Топ донатеров по сумме (глобально, без рефандов).
-- Агрегат по всей таблице -> SEQSCAN (Tarantool 3.x требует явно).
-- @tparam number limit
-- @tparam number offset
-- @treturn[1] table массив { user_id, total } (может быть пустым)
-- @treturn[2] table err
function service.topByAmount(limit, offset)
  local rows, err = sql(
    [[
      SELECT user_id, SUM(amount) AS "total"
      FROM SEQSCAN transactions
      WHERE refunded = FALSE
      GROUP BY user_id
      ORDER BY "total" DESC
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

--- Кол-во уникальных донатеров (без рефандов) - для пагинации топа.
-- @treturn[1] number
-- @treturn[2] table err
function service.countDonors()
  local rows, err = sql(
    [[
      SELECT COUNT(DISTINCT user_id) AS "cnt"
      FROM SEQSCAN transactions
      WHERE refunded = FALSE
    ]])

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if rows and rows[1] then
    return rows[1].cnt, nil
  end

  return 0, nil
end

return service
