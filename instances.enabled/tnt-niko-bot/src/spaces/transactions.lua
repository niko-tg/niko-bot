--- Успешные транзакции (донаты).
--

--- Схема спейса.
local formatSpace = {
  -- Уникальный идентификатор платежа от Telegram.
  -- Первичный ключ - даёт идемпотентность: повторная доставка
  -- successful_payment не задвоит запись.
  {
    name = 'telegram_payment_charge_id',
    type = 'string',
  },
  {
    name = 'user_id',
    type = 'number',
  },
  -- Сумма платежа. Для XTR - число звёзд.
  {
    name = 'amount',
    type = 'unsigned',
  },
  -- Валюта: 'XTR' для Telegram Stars или ISO 4217.
  {
    name = 'currency',
    type = 'string',
  },
  -- Сырой invoice_payload (напр. 'vip-12') - что куплено.
  {
    name = 'payload',
    type = 'string',
  },
  -- Когда совершён платёж.
  {
    name = 'created',
    type = 'datetime',
  },
  -- Возвращён ли платёж (рефанд).
  {
    name = 'refunded',
    type = 'boolean',
  },
}

--- Индексы спейса.
local index = {
  {
    name = 'primary',
    options = {
      parts = { 'telegram_payment_charge_id' },
      unique = true,
      if_not_exists = true,
    },
  },
  -- Все транзакции пользователя / статистика
  {
    name = 'user_id',
    options = {
      parts = { 'user_id' },
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
