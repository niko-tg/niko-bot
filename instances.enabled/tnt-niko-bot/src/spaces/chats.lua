--- Чаты
--

--- Схема спейса
local formatSpace = {
  -- https://core.telegram.org/bots/api#chat
  {
    name = 'id',
    type ='number',
  },
  {
    name = 'username',
    type ='string',
    is_nullable = true,
  },
  {
    name = 'type',
    type ='string',
  },
  {
    name = 'title',
    type ='string',
  },
  {
    name = 'is_forum',
    type ='boolean',
  },

  -- Модераторский чат, привязывается к чату
  {
    name = 'moderation_chat_id',
    type ='number',
    is_nullable = true,
  },

  -- Колличество участников в чате
  {
    name = 'members',
    type = 'unsigned',
  },

  -- Дата, когда бота добавили в чате
  {
    name = 'bot_invited_date',
    type ='datetime',
  },

  -- Настройки чата
  {
    name = 'settings',
    type = 'map',
  },

  -- Маркер первичной синхронизации стафа из getChatAdministrators
  {
    name = 'staff_synced',
    type = 'boolean',
  },

  -- Касса чата (прогрессивный джекпот слота /spin)
  {
    name = 'casino_cashier',
    type = 'unsigned',
  },

  -- Суммарная активность чата (сообщения + команды) для топа чатов
  {
    name = 'total_messages',
    type = 'unsigned',
  },
}

--- Индексы спейса
local index = {
  {
    name = 'id',
    options = {
      parts = { 'id' },
      unique = true,
      if_not_exists = true
    }
  },

  -- Топ касс: reverse-scan по casino_cashier -> ORDER BY ... DESC без SEQSCAN
  {
    name = 'casino_cashier',
    options = {
      parts = { 'casino_cashier' },
      unique = false,
      if_not_exists = true
    }
  },

  -- Топ чатов: reverse-scan по total_messages
  {
    name = 'total_messages',
    options = {
      parts = { 'total_messages' },
      unique = false,
      if_not_exists = true
    }
  },

  -- Поиск чата по username (maint /delchat @username). username nullable.
  {
    name = 'username',
    options = {
      parts = {{ field = 'username', is_nullable = true }},
      unique = false,
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
