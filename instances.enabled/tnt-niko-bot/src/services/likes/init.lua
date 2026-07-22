--- Сервис CRUD к лайкам.
--
local sql = require('bot.libs.sql')
local Like = require('src.models.Like')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')

local service = {}

--- Чтение лайка по паре (кто, кому) - первичный ключ.
-- Используется для проверки "уже ставил": один лайк на пару.
-- @tparam number liking_id кто поставил
-- @tparam number likee_id кому поставлен
-- @treturn[1] ?table модель like (или nil, если лайка нет)
-- @treturn[2] table err
function service.read(liking_id, likee_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        likes
      WHERE
        liking_id = ${liking_id} AND likee_id = ${likee_id}
    ]], {
      liking_id = liking_id,
      likee_id = likee_id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local like, errs = Like(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return like, nil
end

--- Создание лайка. Первичный ключ (liking_id, likee_id) гарантирует
-- один лайк на пару: повторная вставка той же пары вернёт ошибку.
-- @tparam number liking_id кто поставил
-- @tparam number likee_id кому поставлен
-- @treturn[1] table модель like
-- @treturn[2] table err
function service.add(liking_id, likee_id)
  local like, errs = Like({
    liking_id = liking_id,
    likee_id = likee_id,
  }, { init = true })

  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  local _, err = sql.create('likes', like)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return like, nil
end

--- Список лайкнувших пользователя (свежие сверху). Фильтр по likee_id идёт
-- через индекс likee, он же даёт порядок по created.
-- @tparam number likee_id чьи полученные лайки
-- @tparam number limit
-- @tparam number offset
-- @treturn[1] table массив { liking_id } (может быть пустым)
-- @treturn[2] table err
function service.listLikers(likee_id, limit, offset)
  local rows, err = sql(
    [[
      SELECT liking_id
      FROM likes
      WHERE likee_id = ${likee_id}
      ORDER BY created DESC
      LIMIT ${limit} OFFSET ${offset}
    ]], {
      likee_id = likee_id,
      limit = limit,
      offset = offset,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return rows or {}, nil
end

--- Кол-во лайкнувших пользователя - для пагинации списка.
-- Считается по диапазону индекса likee.
-- @tparam number likee_id чьи полученные лайки
-- @treturn[1] number
-- @treturn[2] table err
function service.countLikers(likee_id)
  local rows, err = sql(
    [[
      SELECT COUNT(*) AS "cnt"
      FROM likes
      WHERE likee_id = ${likee_id}
    ]], {
      likee_id = likee_id,
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
