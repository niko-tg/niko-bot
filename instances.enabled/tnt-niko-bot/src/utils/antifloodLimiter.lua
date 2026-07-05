--- Считает сообщения пользователя в чате и сообщает когда он флудит.
--
-- Считает по двум признакам, любой срабатывает отдельно:
--   1. БЫСТРО:    3 любых сообщения за 1 секунду
--   2. ОДИНАКОВО: 3 сообщения с одинаковым содержимым за 5 секунд
--                 (например 3 одинаковых стикера)
--
-- Время берём из message.date (когда пользователь реально отправил),
-- а не из os.time() (когда бот обработал) - иначе если бот тормозит,
-- юзеру даётся больше окна, чем должно быть.
--
-- Пауза после срабатывания: когда детект сработал, сразу ставим паузу
-- на 5 секунд. Это нужно для случая когда несколько сообщений из одной
-- пачки обрабатываются в параллельных файберах - первый файбер запустит
-- ограничение, остальные увидят что пауза идёт и ничего не сделают
-- (не будут слать ещё 5 одинаковых уведомлений в чат).
--
-- После 5 секунд пауза снимается сама. Если пользователь реально
-- замьючен телеграмом - он не пишет, hit() не вызывается, и в памяти
-- ничего не висит. Если админ снял мьют - пользователь снова пишет,
-- hit() считает с нуля. Никаких хитрых синхронизаций не нужно.
--
-- Чистка памяти: фоновая задача раз в минуту удаляет устаревшие записи,
-- чтобы таблицы не росли бесконечно по неактивным юзерам.
--
local fiber = require('fiber')

local COUNT_WINDOW_SECONDS = 1
local COUNT_THRESHOLD = 3
local SAME_WINDOW_SECONDS = 5
local SAME_THRESHOLD = 3
local DETECT_COOLDOWN_SECONDS = 5
local CLEANUP_INTERVAL = 60

-- key -> { {time, sig}, ... } - последние сообщения юзера в окне
local windows = {}
-- key -> ts - до какого времени держим паузу после срабатывания
local cooldownUntil = {}

local M = {}

--- Регистрирует сообщение. Возвращает true если это срабатывание (флуд).
-- @param key (string) - chat_id..':'..user_id
-- @param eventTime (number) - ctx.message.date (unix-секунды)
-- @param signature (string|nil) - подпись содержимого (для признака "одинаково")
function M.hit(key, eventTime, signature)
  local until_ts = cooldownUntil[key]

  -- Пауза ещё идёт - молча игнорируем
  if until_ts and eventTime < until_ts then
    return false
  end

  -- Пауза истекла - удаляем запись
  if until_ts then
    cooldownUntil[key] = nil
  end

  -- Удаляем из окна те записи, что старше длинного (5 сек) окна
  local prev = windows[key]
  local cleaned = {}

  if prev then
    for _, e in ipairs(prev) do
      if eventTime - e.time < SAME_WINDOW_SECONDS then
        table.insert(cleaned, e)
      end
    end
  end

  table.insert(cleaned, { time = eventTime, sig = signature })
  windows[key] = cleaned

  -- Признак #1: сколько всего сообщений за последнюю 1 секунду
  local countInShort = 0
  for _, e in ipairs(cleaned) do
    if eventTime - e.time < COUNT_WINDOW_SECONDS then
      countInShort = countInShort + 1
    end
  end

  -- Признак #2: сколько сообщений с такой же подписью за 5 сек
  -- (только если подпись передали - например текст или стикер)
  local sameCount = 0
  if signature then
    for _, e in ipairs(cleaned) do
      if e.sig == signature then
        sameCount = sameCount + 1
      end
    end
  end

  -- Хотя бы один признак сработал - флуд
  if countInShort >= COUNT_THRESHOLD or
    sameCount >= SAME_THRESHOLD
  then
    cooldownUntil[key] = eventTime + DETECT_COOLDOWN_SECONDS
    windows[key] = nil

    return true
  end

  return false
end

--- Удаляет устаревшие записи - запускается раз в минуту фоновой задачей.
local function cleanup()
  local now = os.time()

  -- Чистим истёкшие паузы
  for key, ts in pairs(cooldownUntil) do
    if now >= ts then
      cooldownUntil[key] = nil
    end
  end

  -- Чистим окна, в которых нет ни одной свежей записи
  for key, list in pairs(windows) do
    local hasFresh = false

    for _, e in ipairs(list) do
      if now - e.time < SAME_WINDOW_SECONDS then
        hasFresh = true
        break
      end
    end

    if not hasFresh then
      windows[key] = nil
    end
  end
end

fiber.create(function()
  fiber.self():name('antiflood-cleaner')

  while true do
    fiber.sleep(CLEANUP_INTERVAL)
    cleanup()
  end
end)

return M
