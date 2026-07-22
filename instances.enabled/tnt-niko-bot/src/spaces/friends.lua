--- Друзья (двунаправленно: на каждую дружбу две записи A->B и B->A).
--

--- Схема спейса.
local formatSpace = {
  -- Чьи друзья.
  {
    name = 'user_id',
    type = 'number',
  },
  -- Кто в друзьях.
  {
    name = 'friend_id',
    type = 'number',
  },
  -- В каком чате заключили дружбу.
  {
    name = 'chat_id',
    type = 'number',
  },
  -- Когда заключили.
  {
    name = 'created',
    type = 'datetime',
  },
}

--- Индексы спейса.
local index = {
  {
    name = 'primary',
    options = {
      parts = { 'user_id', 'friend_id' },
      unique = true,
      if_not_exists = true,
    },
  },
  {
    name = 'by_user',
    options = {
      parts = { 'user_id', 'created' },
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
