--- Активные одиночные партии 'Мины' (PVE).
--

--- Схема спейса.
local formatSpace = {
  -- Игрок (PK - одна партия на игрока).
  {
    name = 'user_id',
    type = 'number',
  },
  {
    name = 'chat_id',
    type = 'number',
  },
  -- Сообщение с доской (для редактирования по TTL).
  {
    name = 'message_id',
    type = 'number',
  },
  -- Ставка.
  {
    name = 'bid',
    type = 'unsigned',
  },
  -- Число мин (выбранный риск).
  {
    name = 'mines',
    type = 'unsigned',
  },
  -- Вскрытые безопасные клетки: { [pos] = true }.
  {
    name = 'opened',
    type = 'map',
  },
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
