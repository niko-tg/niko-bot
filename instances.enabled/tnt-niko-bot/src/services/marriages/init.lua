--- Сервис CRUD к бракам. Брак моногамен и двунаправлен: на пару - две записи,.
-- каждая под своим user_id (первичный ключ). Брак глобальный, к чату не привязан.
--
local sql = require('bot.libs.sql')
local Marriage = require('src.models.Marriage')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')

local service = {}

--- Чтение брака пользователя по первичному ключу (user_id).
-- Отвечает на "женат ли я и кто партнёр" и наполняет карточку брака.
-- @tparam number user_id чей брак
-- @treturn[1] ?table модель marriage (или nil, если брака нет)
-- @treturn[2] table err
function service.read(user_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        marriages
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

  local marriage, errs = Marriage(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return marriage, nil
end

--- Заключение брака: две записи (в обе стороны) в одной транзакции.
-- Моногамию гарантирует уникальность первичного ключа: если кто-то уже женат,
-- вставка упрётся в неё и вся транзакция откатится.
-- @tparam number user_id первый
-- @tparam number partner_id второй
-- @tparam number chat_id чат, где поженились
-- @treturn[1] boolean true
-- @treturn[2] table err
function service.marry(user_id, partner_id, chat_id)
  local rowA, errsA = Marriage({
    user_id = user_id,
    partner_id = partner_id,
    chat_id = chat_id,
  }, { init = true })

  if errsA then
    return nil, setErrType(errsA, services_error_type.VALIDATION_ERROR)
  end

  local rowB, errsB = Marriage({
    user_id = partner_id,
    partner_id = user_id,
    chat_id = chat_id,
  }, { init = true })

  if errsB then
    return nil, setErrType(errsB, services_error_type.VALIDATION_ERROR)
  end

  local _, err = sql.atomic(function()
    sql.check(sql.create('marriages', rowA))
    sql.check(sql.create('marriages', rowB))
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Расторжение брака: обе записи в одной транзакции.
-- Вызывать только когда брак точно есть (partner_id берётся из записи).
-- @tparam number user_id первый
-- @tparam number partner_id второй
-- @treturn[1] boolean true
-- @treturn[2] table err
function service.divorce(user_id, partner_id)
  local _, err = sql.atomic(function()
    sql.check(sql([[
      DELETE FROM marriages WHERE user_id = ${id}
    ]], { id = user_id }))

    sql.check(sql([[
      DELETE FROM marriages WHERE user_id = ${id}
    ]], { id = partner_id }))
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Топ браков чата: пары, где ОБА супруга состоят в этом чате (не left/kicked).
-- Брак глобальный, поэтому фильтр по чату - это членство обоих, а не место брака.
-- Ведущая таблица - user_in_chat (префикс chat_id по индексу), marriages цепляется
-- по первичному ключу, второй супруг проверяется тем же индексом - без SEQSCAN.
-- user_id < partner_id отсекает дубль второй записи пары.
-- @tparam number chat_id
-- @tparam number limit
-- @tparam number offset
-- @treturn[1] table массив { user_id, partner_id, created } (может быть пустым)
-- @treturn[2] table err
function service.topInChat(chat_id, limit, offset)
  local rows, err = sql(
    [[
      SELECT
        marriage.user_id AS "user_id",
        marriage.partner_id AS "partner_id",
        marriage.created AS "created"
      FROM user_in_chat AS member
      JOIN marriages AS marriage
        ON marriage.user_id = member.user_id
      WHERE member.chat_id = ${chat_id}
        AND member.status NOT IN ('left', 'kicked')
        AND marriage.user_id < marriage.partner_id
        AND EXISTS (
          SELECT 1 FROM user_in_chat AS partner
          WHERE partner.chat_id = ${chat_id}
            AND partner.user_id = marriage.partner_id
            AND partner.status NOT IN ('left', 'kicked')
        )
      ORDER BY marriage.created ASC
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

--- Кол-во браков чата (оба супруга в чате) - для пагинации топа.
-- @tparam number chat_id
-- @treturn[1] number
-- @treturn[2] table err
function service.countInChat(chat_id)
  local rows, err = sql(
    [[
      SELECT COUNT(*) AS "cnt"
      FROM user_in_chat AS member
      JOIN marriages AS marriage
        ON marriage.user_id = member.user_id
      WHERE member.chat_id = ${chat_id}
        AND member.status NOT IN ('left', 'kicked')
        AND marriage.user_id < marriage.partner_id
        AND EXISTS (
          SELECT 1 FROM user_in_chat AS partner
          WHERE partner.chat_id = ${chat_id}
            AND partner.user_id = marriage.partner_id
            AND partner.status NOT IN ('left', 'kicked')
        )
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

return service
