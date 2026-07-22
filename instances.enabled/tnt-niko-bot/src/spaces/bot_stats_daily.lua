--- Дневные снапшоты статистики бота (для дельт в /botstats).
--

--- Схема спейса.
local formatSpace = {
  -- Начало дня (unix), первичный ключ
  { name = 'date',            type = 'number' },

  -- Кумулятивные тоталы (по ним считаются дельты)
  { name = 'users_total',     type = 'unsigned' },
  { name = 'started_total',   type = 'unsigned' },
  { name = 'chats_total',     type = 'unsigned' },
  { name = 'members_total',   type = 'unsigned' },
  { name = 'messages_total',  type = 'unsigned' },
  { name = 'commands_total',  type = 'unsigned' },
  { name = 'balance_total',   type = 'unsigned' },
  { name = 'crystals_total',  type = 'unsigned' },
  { name = 'cashbox_total',   type = 'unsigned' },
  { name = 'donations_total', type = 'unsigned' },

  -- Точечное за день (для истории, без дельты)
  { name = 'active_today',    type = 'unsigned' },
}

--- Индексы спейса.
local index = {
  {
    name = 'date',
    options = {
      parts = { 'date' },
      unique = true,
      if_not_exists = true,
    },
  },
}

-- Экспорт модуля.
--
return {
  format_space = formatSpace,
  index = index,
}
