--- Пользователи
--

--- Схема спейса
local formatSpace = {
  -- https://core.telegram.org/bots/api#user
  --
  -- Основная информация
  {
    name = 'id',
    type = 'number',
  },
  {
    name = 'first_name',
    type = 'string',
  },
  {
    name = 'last_name',
    type = 'string',
  },
  {
    name = 'username',
    type = 'string',
    is_nullable = true,
  },
  {
    name = 'language_code',
    type = 'string',
  },

  -- Игровая схема
  {
    name = 'gender',
    type = 'string',
    is_nullable = true,
  },
  {
    name = 'birthday_date',
    type = 'datetime',
    is_nullable = true,
  },
  {
    name = 'race',
    type = 'string',
    is_nullable = true,
  },
  {
    name = 'status',
    type = 'string',
  },
  {
    name = 'balance',
    type = 'unsigned',
  },
  {
    name = 'reserved_balance',
    type = 'unsigned'
  },
  {
    name = 'crystals',
    type = 'unsigned',
  },

  -- Числовые значения
  --
  {
    name = 'karma',
    type = 'integer',
  },
  {
    name = 'likes',
    type = 'unsigned',
  },
  {
    name = 'kuses',
    type = 'unsigned',
  },
  {
    name = 'friends',
    type = 'unsigned',
  },
  --

  -- Флаг запуска бота
  {
    name = 'is_started_bot',
    type = 'boolean',
  },

  -- Использует приватность или нет
  {
    name = 'is_private',
    type = 'boolean',
  },

  -- Система уровней и XP
  {
    name = 'level',
    type = 'unsigned',
  },
  {
    name = 'xp',
    type = 'unsigned',
  },
  {
    name = 'xp_to_next',
    type = 'unsigned',
  },

  -- Заблокирован в самом боте
  {
    name = 'locked',
    type ='boolean',
  },

  -- Последняя активность, unix-ts (любой чат, для "активных сегодня" в статистике)
  {
    name = 'last_activity',
    type = 'number',
    is_nullable = true,
  },

  -- Счётчик команд юзера, любой чат (для "команд за день" в статистике)
  {
    name = 'commands_count',
    type = 'unsigned',
  },
}

--- Индексы спейса
local index = {
  {
    name = 'id',
    options = {
      parts = { 'id' },
      unique = true,
      if_not_exists = true
    }
  },
  {
    name = 'username',
    options = {
      parts = { 'username' },
      unique = false,
      if_not_exists = true
    }
  },
  {
    name = 'is_started_bot',
    options = {
      parts = { 'is_started_bot' },
      unique = false,
      if_not_exists = true
    }
  },

  -- Топ игроков: ведущая часть level даёт диапазон без SEQSCAN,
  -- (level, xp) полностью обслуживает ORDER BY level DESC, xp DESC
  {
    name = 'level_xp',
    options = {
      parts = { 'level', 'xp' },
      unique = false,
      if_not_exists = true
    }
  },

  -- Активные за период: диапазон last_activity >= since по индексу (без SEQSCAN)
  {
    name = 'last_activity',
    options = {
      parts = { { field = 'last_activity', is_nullable = true } },
      unique = false,
      if_not_exists = true
    }
  },

  -- Топ кусак: диапазон kuses > 0 по индексу + реверс-скан под ORDER BY kuses DESC
  {
    name = 'kuses',
    options = {
      parts = { 'kuses' },
      unique = false,
      if_not_exists = true
    }
  },

  -- Топ богатых: диапазон balance > 0 по индексу + реверс-скан под ORDER BY balance DESC
  {
    name = 'balance',
    options = {
      parts = { 'balance' },
      unique = false,
      if_not_exists = true
    }
  },
}

--- export
--
return {
  format_space = formatSpace,
  index = index,
}
