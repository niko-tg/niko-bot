--- Модель успешной транзакции (доната)
--
local datetime = require('datetime')
local Errors = require('src.models.Errors')

local function Transaction(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'transactions' })
  local model = {}

  -- Уникальный id платежа от Telegram (первичный ключ)
  if data.telegram_payment_charge_id then
    model.telegram_payment_charge_id = tostring(data.telegram_payment_charge_id)
  else
    errors:field_missing('telegram_payment_charge_id')
  end

  if tonumber(data.user_id) then
    model.user_id = tonumber(data.user_id)
  else
    errors:field_missing('user_id')
  end

  -- Сумма платежа. Для XTR - число звёзд.
  if tonumber(data.amount) then
    model.amount = tonumber(data.amount)
  else
    errors:field_missing('amount')
  end

  -- Валюта: 'XTR' для Telegram Stars или ISO 4217.
  if data.currency then
    model.currency = tostring(data.currency)
  else
    errors:field_missing('currency')
  end

  -- Сырой invoice_payload (напр. 'vip-12') - что куплено.
  if data.payload then
    model.payload = tostring(data.payload)
  else
    errors:field_missing('payload')
  end

  -- Когда совершён платёж.
  if data.created ~= nil then
    model.created = data.created
  elseif init then
    model.created = datetime.new({ timestamp = os.time() })
  end

  -- Возвращён ли платёж (рефанд).
  if data.refunded ~= nil then
    model.refunded = data.refunded
  elseif init then
    model.refunded = false
  end

  if errors:has_errors() then
    return nil, errors:get_compact()
  end

  return model, nil
end

return Transaction
