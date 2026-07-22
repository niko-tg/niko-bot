--- Пользователь в чате.
--

--- Схема спейса.
local formatSpace = {
  {
    name = 'user_id',
    type ='number',
  },
  {
    name = 'chat_id',
    type ='number',
  },
  {
    name = 'joined_date',
    type ='datetime',
  },
  {
    name = 'permissions',
    type = 'map',
  },

  -- Параметры для статистики
  --
  -- Кол-во сообщений в чат отправил
  {
    name = 'count_messages',
    type ='unsigned',
  },
  -- Время последней активности
  {
    name = 'last_activity',
    type ='datetime',
  },
  --

  -- Статус пользователя в чате (creator, administrator, member, restricted, left, kicked, ...)
  {
    name = 'status',
    type ='string',
  },

  -- Антифлуд: счётчик нарушений с прогрессивной длительностью restrict
  -- (decay - если последнее нарушение >24ч, счётчик сбрасывается).
  -- last_violation как unix-секунды (0 = никогда) - проще арифметика.
  --
  {
    name = 'antiflood_violations',
    type = 'unsigned',
  },
  {
    name = 'antiflood_last_violation',
    type = 'unsigned',
  },
}

--- Индексы спейса.
local index = {
  -- Композитный первичный ключ (предотвращает дубли user<->chat).
  -- Поиск по префиксу chat_id даёт всех участников чата
  {
    name = 'primary',
    options = {
      parts = { 'chat_id', 'user_id' },
      unique = true,
      if_not_exists = true,
    },
  },
  -- Поиск всех чатов пользователя
  {
    name = 'user_id',
    options = {
      parts = { 'user_id' },
      unique = false,
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
