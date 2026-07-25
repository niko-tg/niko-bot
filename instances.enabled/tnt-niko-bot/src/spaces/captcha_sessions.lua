--- Активные капча-сессии новых участников.
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
  -- Сообщение с кнопкой капчи (удаляется при прохождении/таймауте)
  {
    name = 'message_id',
    type = 'number',
  },
  -- Слать ли приветствие после прохождения (юзер реально новый и
  -- в чате включено has_enable_hello_message)
  {
    name = 'greet',
    type = 'boolean',
  },
  {
    name = 'created',
    type = 'datetime',
  },
}

--- Индексы спейса.
local index = {
  -- Композитный первичный ключ: одна капча на юзера в чате
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
