--- Инвентарь пользователя (отдельный спейс, не в записи users).
--
-- Хранение через map, не массив: добавление лута = items[id] = items[id] + n,
-- без переупаковки/стакинга (источник багов старого src/classes/inventory.lua).
--

--- Схема спейса.
local formatSpace = {
  -- PK
  {
    name = 'user_id',
    type = 'number',
  },

  -- Ресурсы и расходники: id -> количество
  {
    name = 'items',
    type = 'map',
  },

  -- Инструменты: id -> остаток прочности (по одному инструменту на тип)
  {
    name = 'tools',
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
