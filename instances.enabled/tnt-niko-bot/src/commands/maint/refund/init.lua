--- Возврат платежа (рефанд Telegram Stars).
--
-- /refund charge_id=<telegram_payment_charge_id>
--
-- Возвращает звёзды и помечает транзакцию refunded. Награду НЕ откатывает.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local hdec = require('bot.libs.hdec')
local separateNumbers = require('src.utils.separateNumbers')
local transactionsService = require('src.services.transactions')

local command = Command:new({
  commands = { '/refund' },
  flags = { Command.enum.MAINTENANCE },
})

local USAGE = ([[
ℹ️ <b>Использование</b>
${sep}
<code>/refund charge_id=...</code>

charge_id - telegram_payment_charge_id из транзакции
]]):f({ sep = hdec.sep })

local TEMPLATE = [[
✅ <b>Платёж возвращён</b>
${sep}
🆔 <code>${userId}</code>
💳 <code>${chargeId}</code>
💰 ${amount} ${currency}
📦 <code>${payload}</code>
]]

--- Разбор аргументов вида key=value из текста команды.
-- @tparam string text текст сообщения
-- @treturn table пары ключ-значение
local function parseArgs(text)
  local args = {}

  for key, value in text:gmatch('([%w_]+)=(%S+)') do
    args[key] = value
  end

  return args
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local args = parseArgs(ctx.message.text)

  if not args.charge_id then
    ctx:replyToMessage(USAGE)
    return
  end

  local chargeId = args.charge_id

  local transaction, readErr = transactionsService.read(chargeId)

  if readErr then
    log.error(readErr)
    ctx:replyToMessage('⚠️ Ошибка чтения транзакции')
    return
  end

  if not transaction then
    ctx:replyToMessage('🤷🏼‍♀️ Транзакция не найдена')
    return
  end

  if transaction.refunded then
    ctx:replyToMessage('↩️ Этот платёж уже возвращён')
    return
  end

  local _, refundErr = bot:refundStarPayment({
    user_id = transaction.user_id,
    telegram_payment_charge_id = chargeId,
  })

  if refundErr then
    log.error(refundErr)
    ctx:replyToMessage('⚠️ Не удалось вернуть платёж')
    return
  end

  -- Помечаем только после успешного refund - защита от повторного возврата.
  local _, updErr = transactionsService.update(
    { refunded = true },
    { telegram_payment_charge_id = chargeId }
  )

  if updErr then
    log.error(updErr)
  end

  ctx:replyToMessage(TEMPLATE:f({
    sep = hdec.sep,
    userId = transaction.user_id,
    chargeId = chargeId,
    amount = separateNumbers(transaction.amount),
    currency = transaction.currency,
    payload = transaction.payload,
  }))
end

return command
