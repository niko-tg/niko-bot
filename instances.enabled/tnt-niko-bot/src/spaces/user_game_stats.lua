--- Игровая статистика пользователя (map - легко расширять).
--

--- Схема спейса
local formatSpace = {
  {
    name = 'user_id',
    type = 'number',
  },
  -- Произвольная статистика: { wins, losses, draws, games, ... }.
  {
    name = 'stats',
    type = 'map',
  },
}

--- Индексы спейса
local index = {
  {
    name = 'primary',
    options = {
      parts = { 'user_id' },
      unique = true,
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
