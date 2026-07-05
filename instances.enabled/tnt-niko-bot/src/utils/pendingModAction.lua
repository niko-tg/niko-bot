--- Кратковременно помнит, какой админ начал действие модерации.
--
-- Зачем: команды /ban, /mute, /unban выполняют действие через API бота.
-- Telegram в апдейте chat_member ставит инициатором самого бота, поэтому
-- мод-лог (он строится из этого апдейта) не знает реального админа.
-- Команда перед вызовом API кладёт сюда запись "в чате C над юзером U
-- действие A начал админ", а обработчик апдейта забирает её и пишет
-- в мод-чат настоящего админа.
--
-- Запись живёт несколько секунд: окно между вызовом API и приходом
-- апдейта - это миллисекунды. Если записи нет (действие сделал не бот
-- через нативный клиент, либо это авто-ограничение антифлуда) - реального
-- админа мы не знаем, и вызывающий решает что делать.
--
-- Память чистит фоновая задача раз в минуту.
--
local fiber = require('fiber')

-- Сколько секунд держим запись. Апдейт обычно приходит почти сразу,
-- запаса в 15 секунд хватает с большим избытком.
local PENDING_TTL_SECONDS = 15
local CLEANUP_INTERVAL = 60

-- key -> { actor = <таблица юзера>, ts = unix-секунды }
local pending = {}

local M = {}

local function makeKey(chatId, userId, action)
  return chatId..':'..userId..':'..action
end

--- Запоминает, что админ начал действие над юзером.
-- Звать ОБЯЗАТЕЛЬНО до вызова API: апдейт chat_member может прийти раньше,
-- чем команда завершится.
function M.set(chatId, userId, action, actor)
  pending[makeKey(chatId, userId, action)] = {
    actor = actor,
    ts = os.time(),
  }
end

--- Забирает и удаляет запись. Возвращает админа, если запись свежая,
-- иначе nil (записи нет или протухла).
function M.take(chatId, userId, action)
  local key = makeKey(chatId, userId, action)
  local entry = pending[key]

  if not entry then
    return nil
  end

  pending[key] = nil

  if os.time() - entry.ts >= PENDING_TTL_SECONDS then
    return nil
  end

  return entry.actor
end

--- Удаляет протухшие записи - запускается раз в минуту фоновой задачей.
local function cleanup()
  local now = os.time()

  for key, entry in pairs(pending) do
    if now - entry.ts >= PENDING_TTL_SECONDS then
      pending[key] = nil
    end
  end
end

fiber.create(function()
  fiber.self():name('pending-mod-action-cleaner')

  while true do
    fiber.sleep(CLEANUP_INTERVAL)
    cleanup()
  end
end)

return M
