--- Зоотовары игрока: расходники для ухода за питомцами (корм/шампунь/лекарства).
-- Изолированы от инвентаря добычи: не видны в /inventory и не продаются /sell.
--

--- Схема спейса
local formatSpace = {
  -- PK
  {
    name = 'user_id',
    type = 'number',
  },
  -- Товары: id -> количество (map).
  {
    name = 'items',
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
