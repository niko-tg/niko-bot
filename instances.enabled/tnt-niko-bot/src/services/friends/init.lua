--- Сервис CRUD к друзьям. Дружба двунаправленна: на пару - две записи.
--
local sql = require('bot.libs.sql')
local Friend = require('src.models.Friend')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')

local service = {}

--- Чтение одной стороны дружбы по паре (чей, кто) - первичный ключ.
-- Используется для проверки "уже друзья" и для карточки друга.
-- @tparam number user_id чьи друзья
-- @tparam number friend_id кто в друзьях
-- @treturn[1] ?table модель friend (или nil, если дружбы нет)
-- @treturn[2] table err
function service.read(user_id, friend_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        friends
      WHERE
        user_id = ${user_id} AND friend_id = ${friend_id}
    ]], {
      user_id = user_id,
      friend_id = friend_id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local friend, errs = Friend(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return friend, nil
end

--- Заключение дружбы: две записи (в обе стороны) и счётчик friends обоим.
-- Всё в одной транзакции - дружба либо целиком есть, либо её нет.
-- @tparam number user_id первый
-- @tparam number friend_id второй
-- @tparam number chat_id чат, где заключили
-- @treturn[1] boolean true
-- @treturn[2] table err
function service.add(user_id, friend_id, chat_id)
  local rowA, errsA = Friend({
    user_id = user_id,
    friend_id = friend_id,
    chat_id = chat_id,
  }, { init = true })

  if errsA then
    return nil, setErrType(errsA, services_error_type.VALIDATION_ERROR)
  end

  local rowB, errsB = Friend({
    user_id = friend_id,
    friend_id = user_id,
    chat_id = chat_id,
  }, { init = true })

  if errsB then
    return nil, setErrType(errsB, services_error_type.VALIDATION_ERROR)
  end

  local _, err = sql.atomic(function()
    sql.check(sql.create('friends', rowA))
    sql.check(sql.create('friends', rowB))

    sql.check(sql([[
      UPDATE users SET friends = friends + 1 WHERE id = ${id}
    ]], { id = user_id }))

    sql.check(sql([[
      UPDATE users SET friends = friends + 1 WHERE id = ${id}
    ]], { id = friend_id }))
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Удаление дружбы: обе записи и счётчик friends обоим (с гейтом от ухода в минус).
-- Вызывать только когда дружба точно есть, иначе счётчик уедет вниз без записи.
-- @tparam number user_id первый
-- @tparam number friend_id второй
-- @treturn[1] boolean true
-- @treturn[2] table err
function service.remove(user_id, friend_id)
  local _, err = sql.atomic(function()
    sql.check(sql([[
      DELETE FROM friends WHERE user_id = ${u} AND friend_id = ${f}
    ]], { u = user_id, f = friend_id }))

    sql.check(sql([[
      DELETE FROM friends WHERE user_id = ${f} AND friend_id = ${u}
    ]], { u = user_id, f = friend_id }))

    sql.check(sql([[
      UPDATE users SET friends = friends - 1 WHERE id = ${id} AND friends > 0
    ]], { id = user_id }))

    sql.check(sql([[
      UPDATE users SET friends = friends - 1 WHERE id = ${id} AND friends > 0
    ]], { id = friend_id }))
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Список друзей пользователя (свежие сверху). Фильтр по user_id идёт через
-- индекс by_user, он же даёт порядок по created.
-- @tparam number user_id чьи друзья
-- @tparam number limit
-- @tparam number offset
-- @treturn[1] table массив { friend_id } (может быть пустым)
-- @treturn[2] table err
function service.listFriends(user_id, limit, offset)
  local rows, err = sql(
    [[
      SELECT friend_id
      FROM friends
      WHERE user_id = ${user_id}
      ORDER BY created DESC
      LIMIT ${limit} OFFSET ${offset}
    ]], {
      user_id = user_id,
      limit = limit,
      offset = offset,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return rows or {}, nil
end

--- Кол-во друзей пользователя - для пагинации списка.
-- Считается по диапазону индекса by_user.
-- @tparam number user_id чьи друзья
-- @treturn[1] number
-- @treturn[2] table err
function service.countFriends(user_id)
  local rows, err = sql(
    [[
      SELECT COUNT(*) AS "cnt"
      FROM friends
      WHERE user_id = ${user_id}
    ]], {
      user_id = user_id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if rows and rows[1] then
    return rows[1].cnt, nil
  end

  return 0, nil
end

return service
