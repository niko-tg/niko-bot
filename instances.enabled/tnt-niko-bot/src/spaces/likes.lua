--- Лайки (кто кому поставил)
--

--- Схема спейса
local formatSpace = {
  -- Кто поставил лайк.
  {
    name = 'liking_id',
    type = 'number',
  },
  -- Кому поставлен лайк.
  {
    name = 'likee_id',
    type = 'number',
  },
  -- Когда поставлен.
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
      parts = { 'liking_id', 'likee_id' },
      unique = true,
      if_not_exists = true
    }
  },
  {
    name = 'likee',
    options = {
      parts = { 'likee_id', 'created' },
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
