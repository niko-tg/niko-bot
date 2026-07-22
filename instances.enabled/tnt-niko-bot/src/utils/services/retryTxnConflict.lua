--- Ретрай операции при конфликте MVCC-транзакций.
--
-- При memtx.use_mvcc_engine конкурентные апдейты одного кортежа (например,
-- два сообщения одного юзера в параллельных файберах) откатываются с
-- "Transaction has been aborted by conflict". Это не сбой, а штатная работа
-- serializable-изоляции: откаченную транзакцию нужно просто повторить.
--
local fiber = require('fiber')

local CONFLICT_MESSAGE = 'Transaction has been aborted by conflict'

local ATTEMPTS = 5
-- Базовая пауза перед повтором: даёт конкурирующей транзакции закоммититься.
local BACKOFF_SEC = 0.02

--- Является ли ошибка конфликтом транзакций.
-- Ошибка может прийти как box.error (tostring даёт message), строкой либо
-- обёрнутой в массив setErrType-ом - разворачиваем рекурсивно.
local function isConflict(err)
  if err == nil then
    return false
  end

  if type(err) == 'table' then
    for i = 1, #err do
      local item = err[i]
      if isConflict(item) then
        return true
      end
    end

    return false
  end

  return tostring(err):find(CONFLICT_MESSAGE, 1, true) ~= nil
end

--- Выполняет fn (протокол `res, err`), повторяя при конфликте транзакций.
-- Не-конфликтные ошибки возвращаются сразу без повторов.
-- @tparam function fn () -> res, err
-- @treturn[1] table res
-- @treturn[2] table err (последняя ошибка, если все попытки конфликтнули)
local function retryTxnConflict(fn)
  local res, err

  for attempt = 1, ATTEMPTS do
    res, err = fn()

    if err == nil or not isConflict(err) then
      return res, err
    end

    if attempt < ATTEMPTS then
      fiber.sleep(BACKOFF_SEC * attempt)
    end
  end

  return res, err
end

return retryTxnConflict
