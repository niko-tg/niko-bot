--- Пользователи с VIP подпиской.
--

--- Схема спейса.
local formatSpace = {
  {
    name = 'user_id',
    type ='number',
  },
  {
    name = 'until_date',
    type = 'unsigned',
  },
  -- Был ли отправлен напоминалка-сообщение об окончании подписки.
  -- Сбрасывается в false при upsert (продление обновляет until_date).
  {
    name = 'reminder_sent',
    type = 'boolean',
  },
}

--- Индексы спейса.
local index = {
  {
    name = 'user_id',
    options = {
      parts = {'user_id'},
      unique = true,
      if_not_exists = true,
    },
  },
  {
    name = 'until_date',
    options = {
      parts = {'until_date'},
      unique = false,
      if_not_exists = true,
    },
  },
  {
    name = 'reminder_sent',
    options = {
      parts = {'reminder_sent'},
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
}
