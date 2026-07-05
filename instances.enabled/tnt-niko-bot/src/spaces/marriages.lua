--- Браки (двунаправленно: на каждый брак две записи A->B и B->A).
-- Брак глобальный, к чату не привязан.
--

--- Схема спейса
local formatSpace = {
  -- Чей брак.
  {
    name = 'user_id',
    type = 'number',
  },
  -- Партнёр.
  {
    name = 'partner_id',
    type = 'number',
  },
  -- В каком чате поженились.
  {
    name = 'chat_id',
    type = 'number',
  },
  -- Когда поженились.
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
