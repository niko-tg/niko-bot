--- Классификаторы ошибок Telegram Bot API.
--
-- У Bot API нет официального enum, классифицируем substring-match по description.
--
-- Все функции принимают err (table c полем description) и возвращают boolean.
-- nil/не-string description -> false.
--

--- Описания, на которые ругаться не стоит: ok-fail. Сообщение реально
-- не существует (race), edit без изменений и т.п. - не баг и не повод
-- слать warning.
--
local IGNORABLE_PATTERNS = {
  "message to delete not found",
  "message is not modified",
}

--- Описания, означающие что у бота нет нужного admin-права. Telegram
-- не унифицирует текст: для restrict-методов "not enough rights", для
-- deleteMessage без can_delete_messages - "message can't be deleted".
local NOT_ENOUGH_RIGHTS_PATTERNS = {
  'not enough rights',
  "message can't be deleted",
}

--- Проверка вхождения подстроки в description ошибки.
-- @tparam ?table err ошибка Telegram Bot API
-- @tparam string needle искомая подстрока
-- @treturn boolean
local function descriptionContains(err, needle)
  local d = err and err.description

  if type(d) ~= 'string' then
    return false
  end

  return d:find(needle, 1, true) ~= nil
end

local M = {}

--- Telegram отказал но это не критично - сообщение могло быть удалено
-- другим способом, слишком старое, edit без изменений и т.п.
function M.isIgnorable(err)
  if not err or type(err.description) ~= 'string' then
    return false
  end

  for i = 1, #IGNORABLE_PATTERNS do
    local pattern = IGNORABLE_PATTERNS[i]
    if err.description:find(pattern, 1, true) then
      return true
    end
  end

  return false
end

--- У бота нет нужного admin-права для действия.
function M.isNotEnoughRights(err)
  if not err or type(err.description) ~= 'string' then
    return false
  end

  for i = 1, #NOT_ENOUGH_RIGHTS_PATTERNS do
    local pattern = NOT_ENOUGH_RIGHTS_PATTERNS[i]
    if err.description:find(pattern, 1, true) then
      return true
    end
  end

  return false
end

--- Чат не найден / бот удалён из чата.
function M.isChatNotFound(err)
  return descriptionContains(err, 'chat not found')
end

--- Бот заблокирован пользователем (для PM).
function M.isBotBlocked(err)
  return descriptionContains(err, 'bot was blocked by the user')
end

--- ЛС недоступна: юзер заблокировал бота, не начинал с ним диалог,
-- либо адресат - другой бот (ботам писать ботам нельзя).
-- Ожидаемые отказы при рассылке в личку - не повод для error-лога.
function M.isPMUnavailable(err)
  return M.isBotBlocked(err)
    or descriptionContains(err, "bot can't initiate conversation with a user")
    or descriptionContains(err, 'USER_BOT_TO_BOT_DISABLED')
end

--- Список участников чата недоступен боту (скрытые участники / нет прав).
-- Внешнее ограничение Telegram, а не сбой в коде.
function M.isMemberListInaccessible(err)
  return descriptionContains(err, 'member list is inaccessible')
end

--- Telegram просит притормозить: слишком много запросов (flood, код 429).
function M.isFloodWait(err)
  if not err then
    return false
  end

  if err.error_code == 429 then
    return true
  end

  return descriptionContains(err, 'Too Many Requests')
end

--- Сколько секунд Telegram просит подождать (retry_after). Если поля нет - 1.
function M.retryAfter(err)
  local retry = err and err.parameters and err.parameters.retry_after
  return retry or 1
end

return M
