--- Урон участников по рейд-боссу чата.
--
-- Составной PK (chat_id, user_id) - по одной записи на участника боя.
-- Выборка всех участников боя идёт по префиксу PK (chat_id).
-- Чистятся при выплате (победа), побеге (TTL-джоба) и на всякий случай
-- перед новым призывом.
--

--- Схема спейса.
local formatSpace = {
  {
    name = 'chat_id',
    type = 'number',
  },
  {
    name = 'user_id',
    type = 'number',
  },
  -- Снапшот имени для карточки/итогов (не читать users на каждый рендер).
  {
    name = 'name',
    type = 'string',
  },
  -- Суммарный нанесённый урон.
  {
    name = 'damage',
    type = 'unsigned',
  },
  -- Число ударов.
  {
    name = 'hits',
    type = 'unsigned',
  },
  -- Последний удар, unix-ts (личный кулдаун).
  {
    name = 'last_hit_at',
    type = 'number',
  },
}

--- Индексы спейса.
local index = {
  {
    name = 'primary',
    options = {
      parts = { 'chat_id', 'user_id' },
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
