-- Сервис CRUD к пользователям
--
local sql = require('bot.libs.sql')
local User = require('src.models.User')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')
local retryTxnConflict = require('src.utils.services.retryTxnConflict')

local service = {}

--- Чтение записи
-- @param user_id (number) user id
-- @return[1] model user
-- @return[2] err
function service.read(user_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        users
      WHERE
        id = ${id}
    ]], {
      id = user_id
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local user, errs = User(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return user, nil
end

--- Чтение записи по username
-- Username хранится в нижнем регистре без @, нормализация на стороне вызывающего.
-- @param username (string) lowercase username без @
-- @return[1] model user
-- @return[2] err
function service.readByUsername(username)
  local item, err = sql(
    [[
      SELECT *
      FROM
        users
      WHERE
        username = ${username}
    ]], {
      username = username,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local user, errs = User(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return user, nil
end

--- Топ игроков по уровню и опыту (глобально). Сначала уровень, потом XP внутри уровня.
-- Фильтр level > 0 - это диапазон по ведущей части индекса level_xp, поэтому доступ
-- идёт через индекс (без SEQSCAN), а реверс-скан сразу отдаёт нужный порядок.
-- @param limit (number)
-- @param offset (number)
-- @return[1] array { id, level, xp } (может быть пустым)
-- @return[2] err
function service.topByXP(limit, offset)
  local rows, err = sql(
    [[
      SELECT id, level, xp, xp_to_next
      FROM users
      WHERE level > 0
      ORDER BY level DESC, xp DESC
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

--- Кол-во игроков с прогрессом (level > 0) - для пагинации топа.
-- Считается по диапазону индекса level_xp.
-- @return[1] number
-- @return[2] err
function service.countPlayers()
  local rows, err = sql(
    [[
      SELECT COUNT(*) AS "cnt"
      FROM users
      WHERE level > 0
    ]])

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if rows and rows[1] then
    return rows[1].cnt, nil
  end

  return 0, nil
end

--- Топ кусак по числу сделанных укусов (глобально). Фильтр kuses > 0 - диапазон
-- по индексу kuses, реверс-скан сразу отдаёт нужный порядок (без SEQSCAN).
-- @param limit (number)
-- @param offset (number)
-- @return[1] array { id, kuses } (может быть пустым)
-- @return[2] err
function service.topByKuses(limit, offset)
  local rows, err = sql(
    [[
      SELECT id, kuses
      FROM users
      WHERE kuses > 0
      ORDER BY kuses DESC
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

--- Кол-во кусак (kuses > 0) - для пагинации топа.
-- Считается по диапазону индекса kuses.
-- @return[1] number
-- @return[2] err
function service.countByKuses()
  local rows, err = sql(
    [[
      SELECT COUNT(*) AS "cnt"
      FROM users
      WHERE kuses > 0
    ]])

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if rows and rows[1] then
    return rows[1].cnt, nil
  end

  return 0, nil
end

--- Топ богатых по балансу (глобально). Фильтр balance > 0 - диапазон по индексу
-- balance, реверс-скан сразу отдаёт нужный порядок (без SEQSCAN).
-- @param limit (number)
-- @param offset (number)
-- @return[1] array { id, balance } (может быть пустым)
-- @return[2] err
function service.topByBalance(limit, offset)
  local rows, err = sql(
    [[
      SELECT id, balance
      FROM users
      WHERE balance > 0
      ORDER BY balance DESC
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

--- Кол-во пользователей с балансом (balance > 0) - для пагинации топа.
-- Считается по диапазону индекса balance.
-- @return[1] number
-- @return[2] err
function service.countByBalance()
  local rows, err = sql(
    [[
      SELECT COUNT(*) AS "cnt"
      FROM users
      WHERE balance > 0
    ]])

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if rows and rows[1] then
    return rows[1].cnt, nil
  end

  return 0, nil
end

--- Обновление записи
-- @param fields (table) fields
-- @param where (table) where condition
-- @return[1] res
-- @return[2] err
function service.update(fields, where)
  local res, err = sql.update('users', fields, where)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return res, nil
end

--- Добавление или обновление записи
-- При вставке создаёт полную запись с дефолтами
-- При обновлении меняет только переданные поля
-- @param data (table) fields
-- @return[1] model user
-- @return[2] err
function service.upsert(data)
  -- Полная модель с дефолтами для случая вставки
  local defaultUser, errs = User(data, { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  -- Для обновления существующей записи берём ТОЛЬКО те ключи, что пришли
  -- в исходном data, но значения - уже нормализованные моделью
  -- (иначе username бы сохранялся в исходном регистре)
  local updateFields = {}
  for key in pairs(data) do
    updateFields[key] = defaultUser[key]
  end

  -- Атомарная вставка / обновление
  local _, err = sql.upsert('users', defaultUser, updateFields)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  -- Чтение юзера
  return service.read(defaultUser.id)
end

-- Маркер нехватки средств: бросается таблицей из sql.atomic, pcall доносит
-- её до классификатора без искажений (error со строкой добавил бы file:line).
local INSUFFICIENT_FUNDS_CODE = 'insufficient_funds'

--- Проверка, что юзер существует. SQL UPDATE по несуществующему ключу молча
-- ничего не делает, а денежным операциям нужен откат всей транзакции - поэтому
-- перед арифметикой убеждаемся, что запись есть. Вызывать внутри sql.atomic.
-- @param user_id (number)
-- @param label (string) контекст для сообщения об ошибке
local function assertUserExists(user_id, label)
  local rows = sql.check(sql([[
    SELECT
      id
    FROM
      users
    WHERE
      id = ${user_id}
  ]], {
    user_id = user_id,
  }))

  if rows == nil then
    error(label..' '..tostring(user_id)..' not found')
  end
end

--- Проверка достаточности средств перед списанием. Вызывать внутри sql.atomic
-- после assertUserExists. Поле balance unsigned и упало бы само, но с невнятным
-- "Type mismatch: can not convert integer(-N) to unsigned" - а нехватка средств
-- это штатная ситуация, ей нужен свой тип ошибки, а не storage error в логе.
-- MVCC не даст сработать на устаревшем чтении: конкурентная транзакция откатится.
-- @param user_id (number)
-- @param amount (number) сколько собираемся списать
-- @param label (string) контекст для сообщения об ошибке
local function assertEnoughBalance(user_id, amount, label)
  local rows = sql.check(sql([[
    SELECT
      balance
    FROM
      users
    WHERE
      id = ${user_id}
  ]], {
    user_id = user_id,
  }))

  local have = rows and rows[1] and rows[1].balance or 0

  if have < amount then
    error({
      code = INSUFFICIENT_FUNDS_CODE,
      message = ('%s %s: balance %s < %s'):format(
        label, tostring(user_id), tostring(have), tostring(amount)),
    })
  end
end

--- Классификация ошибки денежной операции из sql.atomic:
-- маркер нехватки средств -> INSUFFICIENT_FUNDS, всё остальное -> STORAGE_ERROR.
local function moneyErr(err)
  if type(err) == 'table' and err.code == INSUFFICIENT_FUNDS_CODE then
    return setErrType({ err.message }, services_error_type.INSUFFICIENT_FUNDS)
  end

  return setErrType({ err }, services_error_type.STORAGE_ERROR)
end

--- Атомарный перевод amount валюты с баланса from_id на to_id.
-- Арифметические SQL-операции внутри транзакции: без lost-update.
-- balance - unsigned, поэтому уход в минус = ошибка и откат всей операции.
-- @param from_id (number)
-- @param to_id (number)
-- @param amount (number)
-- @return[1] true
-- @return[2] err
function service.transfer(from_id, to_id, amount)
  local _, err = sql.atomic(function()
    assertUserExists(from_id, 'transfer: sender')
    assertEnoughBalance(from_id, amount, 'transfer: sender')
    sql.check(sql([[
      UPDATE users
      SET
        balance = balance - ${amount}
      WHERE
        id = ${user_id}
    ]], {
      amount = amount,
      user_id = from_id,
    }))

    assertUserExists(to_id, 'transfer: recipient')
    sql.check(sql([[
      UPDATE users
      SET
        balance = balance + ${amount}
      WHERE
        id = ${user_id}
    ]], {
      amount = amount,
      user_id = to_id,
    }))
  end)

  if err then
    return nil, moneyErr(err)
  end

  return true, nil
end

--- Продажа кристаллов: списать count кристаллов и начислить выручку на баланс.
-- Атомарно. crystals - unsigned: нехватка = ошибка и откат; но количество
-- проверяем и заранее - для понятного сообщения.
-- @param user_id (number)
-- @param count (number) сколько кристаллов продать (>= 1)
-- @param pricePer (number) цена за 1 кристалл
-- @return[1] table { status = 'ok'|'funds'|'no_user', sold, total, have }
-- @return[2] err
function service.sellCrystals(user_id, count, pricePer)
  local user, err = service.read(user_id)
  if err then
    return nil, err
  end

  if user == nil then
    return { status = 'no_user' }, nil
  end

  if user.crystals < count then
    return { status = 'funds', have = user.crystals }, nil
  end

  local total = count * pricePer

  local _, atomicErr = sql.atomic(function()
    assertUserExists(user_id, 'sellCrystals')

    sql.check(sql([[
      UPDATE users
      SET
        crystals = crystals - ${count}
      WHERE
        id = ${user_id}
    ]], {
      count = count,
      user_id = user_id,
    }))

    sql.check(sql([[
      UPDATE users
      SET
        balance = balance + ${total}
      WHERE
        id = ${user_id}
    ]], {
      total = total,
      user_id = user_id,
    }))
  end)

  if atomicErr then
    return nil, setErrType({ atomicErr }, services_error_type.STORAGE_ERROR)
  end

  return { status = 'ok', sold = count, total = total }, nil
end

--- Начисление XP с пересчётом уровня (xp_to_next = 100 + level^2).
-- @param user_id (number)
-- @param amount (number)
-- @return[1] res
-- @return[2] err
function service.addXP(user_id, amount)
  local user, err = service.read(user_id)
  if err then
    return nil, err
  end

  if user == nil then
    return nil, nil
  end

  local xp = user.xp + amount
  local level = user.level
  local xpToNext = user.xp_to_next

  while xpToNext > 0 and xp >= xpToNext do
    xp = xp - xpToNext
    level = level + 1
    xpToNext = 100 + level * level
  end

  return service.update({ xp = xp, level = level, xp_to_next = xpToNext }, { id = user_id })
end

--- Начисление amount на баланс (чтение + update). Возвращает новый баланс.
-- @param user_id (number)
-- @param amount (number)
-- @return[1] number новый баланс
-- @return[2] err
function service.addBalance(user_id, amount)
  local user, err = service.read(user_id)
  if err then
    return nil, err
  end

  if user == nil then
    return nil, nil
  end

  local newBalance = user.balance + amount

  local _, updErr = service.update({ balance = newBalance }, { id = user_id })
  if updErr then
    return nil, updErr
  end

  return newBalance, nil
end

--- Начисление amount кристаллов (чтение + update). Возвращает новое кол-во.
-- @param user_id (number)
-- @param amount (number)
-- @return[1] number новое кол-во кристаллов
-- @return[2] err
function service.addCrystals(user_id, amount)
  local user, err = service.read(user_id)
  if err then
    return nil, err
  end

  if user == nil then
    return nil, nil
  end

  local newCrystals = user.crystals + amount

  local _, updErr = service.update({ crystals = newCrystals }, { id = user_id })
  if updErr then
    return nil, updErr
  end

  return newCrystals, nil
end

--- Отметка последней активности юзера (для "активных сегодня" в статистике).
-- Любое взаимодействие: команда (любой чат, включая ЛС) или сообщение в группе.
-- Горячий путь: конкурентные апдейты одного юзера конфликтуют под MVCC - ретраим.
-- @param user_id (number)
-- @return[1] res
-- @return[2] err
function service.touchActivity(user_id)
  return retryTxnConflict(function()
    return service.update({ last_activity = os.time() }, { id = user_id })
  end)
end

--- Инкремент счётчика команд юзера (для "команд за день" в статистике).
-- Любой чат, включая ЛС. Одиночный UPDATE атомарен сам по себе.
-- Горячий путь: делит кортеж юзера с touchActivity - под MVCC ретраим конфликт.
-- @param user_id (number)
-- @return[1] true
-- @return[2] err
function service.incCommands(user_id)
  local _, err = retryTxnConflict(function()
    return sql([[
      UPDATE users
      SET
        commands_count = commands_count + 1
      WHERE
        id = ${user_id}
    ]], {
      user_id = user_id,
    })
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Инкремент полученных лайков (денормализованный счётчик для профиля).
-- Одиночный UPDATE атомарен сам по себе.
-- @param user_id (number)
-- @return[1] true
-- @return[2] err
function service.incLikes(user_id)
  local _, err = sql([[
    UPDATE users
    SET
      likes = likes + 1
    WHERE
      id = ${user_id}
  ]], {
    user_id = user_id,
  })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Прибавить укусы кусающему (счётчик «сколько укусил ты»).
-- @param user_id (number) кто кусал
-- @param amount (number) сила укуса (+к счётчику)
-- @return[1] true
-- @return[2] err
function service.incKuses(user_id, amount)
  local _, err = sql([[
    UPDATE users
    SET
      kuses = kuses + ${amount}
    WHERE
      id = ${user_id}
  ]], {
    amount = amount,
    user_id = user_id,
  })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Расчёт по зарезервированной ставке: reserved_balance -= reservedAmount,
-- balance += payout (атомарно). payout = выигрыш (забор) / ставка (возврат) / 0 (сгорание).
-- @param user_id (number)
-- @param reservedAmount (number) сколько снять с резерва
-- @param payout (number) сколько начислить на баланс
-- @return[1] true
-- @return[2] err
function service.settleReserve(user_id, reservedAmount, payout)
  local _, err = sql.atomic(function()
    assertUserExists(user_id, 'settleReserve: user')
    sql.check(sql([[
      UPDATE users
      SET
        reserved_balance = reserved_balance - ${reservedAmount},
        balance = balance + ${payout}
      WHERE
        id = ${user_id}
    ]], {
      reservedAmount = reservedAmount,
      payout = payout,
      user_id = user_id,
    }))
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Резерв ставки: balance -> reserved_balance (атомарно).
-- Не хватает средств -> ошибка типа INSUFFICIENT_FUNDS, ничего не списано.
-- @return[1] true
-- @return[2] err
function service.reserve(user_id, amount)
  local _, err = sql.atomic(function()
    assertUserExists(user_id, 'reserve: user')
    assertEnoughBalance(user_id, amount, 'reserve: user')
    sql.check(sql([[
      UPDATE users
      SET
        balance = balance - ${amount},
        reserved_balance = reserved_balance + ${amount}
      WHERE
        id = ${user_id}
    ]], {
      amount = amount,
      user_id = user_id,
    }))
  end)

  if err then
    return nil, moneyErr(err)
  end

  return true, nil
end

--- Расчёт после победы: победителю обе ставки из резерва в баланс,
-- у проигравшего его зарезервированная ставка списывается.
-- @return[1] true
-- @return[2] err
function service.settleGame(winner_id, loser_id, bid)
  local _, err = sql.atomic(function()
    assertUserExists(winner_id, 'settleGame: winner')
    sql.check(sql([[
      UPDATE users
      SET
        reserved_balance = reserved_balance - ${bid},
        balance = balance + ${payout}
      WHERE
        id = ${user_id}
    ]], {
      bid = bid,
      payout = 2 * bid,
      user_id = winner_id,
    }))

    assertUserExists(loser_id, 'settleGame: loser')
    sql.check(sql([[
      UPDATE users
      SET
        reserved_balance = reserved_balance - ${bid}
      WHERE
        id = ${user_id}
    ]], {
      bid = bid,
      user_id = loser_id,
    }))
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Возврат резерва обоим игрокам (ничья / отмена / таймаут).
-- @return[1] true
-- @return[2] err
function service.refundGame(player1_id, player2_id, bid)
  local _, err = sql.atomic(function()
    sql.check(sql([[
      UPDATE users
      SET
        reserved_balance = reserved_balance - ${bid},
        balance = balance + ${bid}
      WHERE
        id = ${user_id}
    ]], {
      bid = bid,
      user_id = player1_id,
    }))

    sql.check(sql([[
      UPDATE users
      SET
        reserved_balance = reserved_balance - ${bid},
        balance = balance + ${bid}
      WHERE
        id = ${user_id}
    ]], {
      bid = bid,
      user_id = player2_id,
    }))
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Резерв ставки сразу у обоих игроков (атомарно). Если у любого не хватает -
-- ошибка типа INSUFFICIENT_FUNDS, оба отката, резерв не проходит.
-- @return[1] true
-- @return[2] err
function service.reservePair(player1_id, player2_id, amount)
  local _, err = sql.atomic(function()
    assertUserExists(player1_id, 'reservePair: player1')
    assertEnoughBalance(player1_id, amount, 'reservePair: player1')
    sql.check(sql([[
      UPDATE users
      SET
        balance = balance - ${amount},
        reserved_balance = reserved_balance + ${amount}
      WHERE
        id = ${user_id}
    ]], {
      amount = amount,
      user_id = player1_id,
    }))

    assertUserExists(player2_id, 'reservePair: player2')
    assertEnoughBalance(player2_id, amount, 'reservePair: player2')
    sql.check(sql([[
      UPDATE users
      SET
        balance = balance - ${amount},
        reserved_balance = reserved_balance + ${amount}
      WHERE
        id = ${user_id}
    ]], {
      amount = amount,
      user_id = player2_id,
    }))
  end)

  if err then
    return nil, moneyErr(err)
  end

  return true, nil
end

--- ID всех, кто запускал бота (is_started_bot = true) - для рассылки.
-- Диапазон по индексу is_started_bot, без SEQSCAN.
-- @return[1] array<number> (может быть пустым)
-- @return[2] err
function service.allStartedIds()
  local rows, err = sql([[
    SELECT id
    FROM users
    WHERE is_started_bot = ${started}
  ]], { started = true })

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
