--- Приветственное сообщение
--

--- Схема спейса
local formatSpace = {
  {
    name = 'chat_id',
    type ='number',
  },
  {
    name = 'user_id',
    type ='number',
  },
  {
    name = 'text',
    type = 'string',
  },
  {
    name = 'file',
    type = 'map'
  }
}

--- Индексы спейса
local index = {
  {
    name = 'chat_id',
    options = {
      parts = {'chat_id'},
      unique = true,
      if_not_exists = true
    }
  }
}

--- export
--
return {
  format_space = formatSpace,
  index = index,
}
