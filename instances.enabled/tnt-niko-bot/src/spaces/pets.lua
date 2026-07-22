--- Питомцы. Один питомец - одна запись. id выдаёт sequence (короткий, влезает
-- в callback_data). Параметры состояния - числа 0..100.
--

--- Схема спейса.
local formatSpace = {
  {
    name = 'id',
    type = 'unsigned',
  },
  {
    name = 'owner_id',
    type = 'number',
  },
  {
    name = 'breed',
    type = 'string',
  },
  {
    name = 'color',
    type = 'string',
  },
  {
    name = 'created',
    type = 'datetime',
  },
  {
    name = 'name',
    type = 'string',
  },
  {
    name = 'health',
    type = 'number',
  },
  {
    name = 'hunger',
    type = 'number',
  },
  {
    name = 'mental_health',
    type = 'number',
  },
  {
    name = 'energy',
    type = 'number',
  },
  {
    name = 'dirty',
    type = 'number',
  },
  {
    name = 'status',
    type = 'string',
  },
}

--- Индексы спейса.
local index = {
  -- Первичный ключ - id питомца.
  {
    name = 'primary',
    options = {
      parts = { 'id' },
      unique = true,
      if_not_exists = true,
    },
  },
  -- Питомцы владельца: список и счёт.
  {
    name = 'owner_id',
    options = {
      parts = { 'owner_id' },
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
  sequence = 'pets_id_seq',
}
