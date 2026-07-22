--- Рейд-боссы чатов (PVE, кооператив).
--
-- Одна запись на чат (PK chat_id). Запись НЕ удаляется по концу боя, а
-- переводится в status='finished' с finished_at - от него считается кулдаун
-- призыва следующего босса (переживает рестарт). Новый призыв перезаписывает
-- запись upsert-ом.
--

--- Схема спейса.
local formatSpace = {
  -- Чат боя (PK - один босс на чат).
  {
    name = 'chat_id',
    type = 'number',
  },
  -- Ключ босса из src/dict/bosses.lua.
  {
    name = 'boss_id',
    type = 'string',
  },
  -- Текущее HP (кламп до 0 при добивании).
  {
    name = 'hp',
    type = 'unsigned',
  },
  {
    name = 'hp_max',
    type = 'unsigned',
  },
  -- Сообщение с карточкой боя (для редактирования).
  {
    name = 'message_id',
    type = 'number',
  },
  -- 'active' | 'finished'
  {
    name = 'status',
    type = 'string',
  },
  {
    name = 'created',
    type = 'datetime',
  },
  -- Когда бой закончился (победа/побег), unix-ts. От него - кулдаун призыва.
  {
    name = 'finished_at',
    type = 'number',
    is_nullable = true,
  },
}

--- Индексы спейса.
local index = {
  {
    name = 'primary',
    options = {
      parts = { 'chat_id' },
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
