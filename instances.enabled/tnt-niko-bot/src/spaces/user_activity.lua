--- Активная задача добычи (одна на игрока: PK user_id -> не больше одной строки).
--
-- Пока строка существует, новую рыбалку/рудник/лесопилку начать нельзя.
-- Завершается ручным сбором (/collect) или TTL-джобой по истечении until_date.
--

--- Схема спейса
local formatSpace = {
  -- PK
  {
    name = 'user_id',
    type = 'number'
  },

  -- Активность: 'fishing' | 'mining' | 'sawmill'
  {
    name = 'activity',
    type = 'string'
  },

  -- Инструмент в работе (изнашивается на финише)
  {
    name = 'tool_id',
    type = 'string'
  },

  -- Время готовности (unix-секунды)
  {
    name = 'until_date',
    type = 'unsigned'
  },

  -- Где висит сообщение задачи (для редактирования на финише)
  {
    name = 'chat_id',
    type = 'number'
  },
  {
    name = 'message_id',
    type = 'number'
  },

  -- Сид детерминированного ролла лута: ручной сбор и авто-сбор дают один лут
  {
    name = 'seed',
    type = 'unsigned'
  },
}

--- Индексы спейса
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

--- export
--
return {
  format_space = formatSpace,
  index = index,
}
