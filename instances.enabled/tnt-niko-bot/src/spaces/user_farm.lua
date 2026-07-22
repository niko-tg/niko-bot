--- Ферма пользователя (отдельный спейс).
--
-- plots   - грядки: слот (строка '1'..'N') -> { crop = id, ready_at = ts }.
--           Свободный слот = нет ключа. Готовность ленивая: now >= ready_at.
-- animals - загон (фаза 2): id животного -> состояние. Поле заложено заранее,
--           чтобы не менять format живого спейса при добавлении животных.
--

--- Схема спейса.
local formatSpace = {
  -- PK
  {
    name = 'user_id',
    type = 'number',
  },

  -- Грядки: слот -> { crop, ready_at }
  {
    name = 'plots',
    type = 'map',
  },

  -- Животные (фаза 2): id -> состояние
  {
    name = 'animals',
    type = 'map',
  },
}

--- Индексы спейса.
local index = {
  {
    name = 'user_id',
    options = {
      parts = { 'user_id' },
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
