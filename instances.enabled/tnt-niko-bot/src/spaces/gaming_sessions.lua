--- Активные PVP игровые сессии.
--

--- Схема спейса
local formatSpace = {
  -- Инициатор (PK - одна инициированная игра на игрока).
  {
    name = 'player1_id',
    type = 'number',
  },
  -- Оппонент.
  {
    name = 'player2_id',
    type = 'number',
  },
  {
    name = 'chat_id',
    type = 'number',
  },
  {
    name = 'game_type',
    type = 'string',
  },
  -- Ставка (зарезервирована у обоих).
  {
    name = 'bid',
    type = 'unsigned',
  },
  -- Состояние игры: scores/steps по игрокам.
  {
    name = 'data',
    type = 'map',
  },
  {
    name = 'created',
    type = 'datetime',
  },
}

--- Индексы спейса
local index = {
  {
    name = 'primary',
    options = {
      parts = { 'player1_id' },
      unique = true,
      if_not_exists = true
    }
  },
  -- Поиск сессии по оппоненту (при броске dice).
  {
    name = 'player2_id',
    options = {
      parts = { 'player2_id' },
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
