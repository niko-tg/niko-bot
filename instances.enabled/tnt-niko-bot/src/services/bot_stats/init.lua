--- Сервис статистики бота: живой расчёт агрегатов, дневные снапшоты, дельты.
--
local sql = require('bot.libs.sql')
local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')

local service = {}

-- Тоталы снапшота (по ним считаются дельты).
local SNAPSHOT_FIELDS = {
  'users_total',
  'started_total',
  'chats_total',
  'members_total',
  'messages_total',
  'commands_total',
  'balance_total',
  'crystals_total',
  'cashbox_total',
  'donations_total',
  'active_today',
}

--- nil / box.NULL (SUM по пустой таблице) -> 0.
local function numOr0(value)
  if value == nil or value == box.NULL then
    return 0
  end

  return tonumber(value) or 0
end

--- Скалярный SELECT -> первая строка (или nil).
local function selectRow(query, params)
  local rows, err = sql(query, params)
  if err then
    return nil, err
  end

  return rows and rows[1], nil
end

--- Счётчик включённых настроек по чатам: { имя_настройки = кол-во }.
-- settings - map, SQL по ключам map не фильтрует - поэтому box-итерация.
-- Полный скан chats; для maintenance-команды и дневной джобы это дёшево.
-- @treturn[1] table counts
-- @treturn[2] table err
function service.countChatSettings()
  local counts = {}

  local ok, err = pcall(function()
    for _, tuple in box.space.chats:pairs() do
      local settings = tuple.settings

      if settings ~= nil then
        for key, enabled in pairs(settings) do
          if enabled == true then
            counts[key] = (counts[key] or 0) + 1
          end
        end
      end
    end
  end)

  if not ok then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return counts, nil
end

--- Живой расчёт всех метрик.
-- @tparam number sinceTs нижняя граница окна "активных" (unix-ts)
-- @tparam ?number beforeTs верхняя граница окна. Без неё - открытое окно
--   ">= since" (живой /botstats: "активны сегодня"). С ней - полуинтервал
--   [since, before) для "активны за прошедший день" в ежедневной джобе.
-- @treturn[1] table метрик (тоталы + live)
-- @treturn[2] table err
function service.computeCurrent(sinceTs, beforeTs)
  local queries = {
    usersRow   = {
      [[ SELECT COUNT(*) AS "cnt" FROM users ]],
    },
    chatsRow   = {
      [[ SELECT COUNT(*) AS "cnt" FROM chats ]],
    },
    startedRow = {
      [[ SELECT COUNT(*) AS "cnt" FROM users WHERE is_started_bot = ${s} ]],
      { s = true },
    },
    gamesRow   = {
      [[ SELECT COUNT(*) AS "cnt" FROM gaming_sessions ]],
    },
    minesRow   = {
      [[ SELECT COUNT(*) AS "cnt" FROM mine_sessions ]],
    },
    vipRow     = {
      [[ SELECT COUNT(*) AS "cnt" FROM vip_users WHERE until_date > ${now} ]],
      { now = os.time() },
    },
    usersSum   = {
      [[ SELECT SUM(balance) AS "balance", SUM(crystals) AS "crystals" FROM SEQSCAN users ]],
    },
    chatsSum   = {
      [[ SELECT SUM(members) AS "members", SUM(total_messages) AS "messages", SUM(casino_cashier) AS "cashbox"]]
      .. [[ FROM SEQSCAN chats ]],
    },
    donatSum   = {
      [[ SELECT SUM(amount) AS "donations" FROM SEQSCAN transactions WHERE refunded = FALSE ]],
    },
    commandsRow = {
      [[ SELECT SUM(commands_count) AS "cnt" FROM SEQSCAN users ]],
    },
    activeRow = beforeTs
      and {
        [[ SELECT COUNT(*) AS "cnt" FROM users WHERE last_activity >= ${since} AND last_activity < ${before} ]],
        { since = sinceTs, before = beforeTs },
      }
      or {
          [[ SELECT COUNT(*) AS "cnt" FROM users WHERE last_activity >= ${since} ]],
          { since = sinceTs },
        },
  }

  local r = {}
  for key, q in pairs(queries) do
    local row, err = selectRow(q[1], q[2])
    if err then
      return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
    end
    r[key] = row or {}
  end

  local chatSettings, settingsErr = service.countChatSettings()
  if settingsErr then
    return nil, settingsErr
  end

  return {
    users_total     = numOr0(r.usersRow.cnt),
    started_total   = numOr0(r.startedRow.cnt),
    chats_total     = numOr0(r.chatsRow.cnt),
    members_total   = numOr0(r.chatsSum.members),
    -- Сообщения = чистые сообщения. Команды в total_messages не попадают:
    -- счётчик растёт только в onChatMessage (chats.upsert с
    -- inc_total_messages). Команды считаем отдельно (commands_total).
    messages_total  = numOr0(r.chatsSum.messages),
    commands_total  = numOr0(r.commandsRow.cnt),
    balance_total   = numOr0(r.usersSum.balance),
    crystals_total  = numOr0(r.usersSum.crystals),
    cashbox_total   = numOr0(r.chatsSum.cashbox),
    donations_total = numOr0(r.donatSum.donations),
    active_today    = numOr0(r.activeRow.cnt),

    -- live (в снапшот не пишем, дельт нет)
    live_games      = numOr0(r.gamesRow.cnt) + numOr0(r.minesRow.cnt),
    vip_users       = numOr0(r.vipRow.cnt),
    chat_settings   = chatSettings,
  }, nil
end

--- Сохранение/перезапись снапшота на дату (только SNAPSHOT_FIELDS).
-- @tparam number date начало дня
-- @tparam table stats результат computeCurrent
-- @treturn[1] boolean true
-- @treturn[2] table err
function service.saveSnapshot(date, stats)
  local record = { date = date }
  for i = 1, #SNAPSHOT_FIELDS do
    local field = SNAPSHOT_FIELDS[i]
    record[field] = stats[field] or 0
  end

  local _, err = sql.upsert('bot_stats_daily', record, record)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Самый свежий снапшот (макс. дата) - для дельт.
-- date зарезервировано в SQL, поэтому читаем через box-индекс, не SELECT.
-- @treturn[1] ?table
-- @treturn[2] table err
function service.getLatest()
  local ok, tuple = pcall(function()
    return box.space.bot_stats_daily.index.date:max()
  end)

  if not ok then
    return nil, setErrType({ tuple }, services_error_type.STORAGE_ERROR)
  end

  if tuple == nil then
    return nil, nil
  end

  return tuple:tomap({ names_only = true }), nil
end

return service
