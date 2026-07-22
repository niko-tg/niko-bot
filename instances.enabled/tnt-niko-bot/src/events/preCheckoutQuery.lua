--- Подтверждение платежа перед списанием (pre_checkout_query).
-- Telegram ждёт ответ в течение ~10 секунд, иначе платёж отменяется.
--
local bot = require('bot')
local log = require('log')
local donatPayload = require('src.donat.payload')

--- Подтверждение платежа перед списанием звёзд.
-- @tparam table ctx контекст обновления
local function preCheckoutQuery(ctx)
  local donatType = donatPayload.parse(ctx:getInvoicePayload())

  -- Незнакомый или битый payload - отклоняем, чтобы не взять деньги
  -- за то, что не сможем выдать.
  if not donatType then
    log.warn('[preCheckout] Неизвестный payload: %s', tostring(ctx:getInvoicePayload()))

    bot:answerPreCheckoutQuery({
      pre_checkout_query_id = ctx:getId(),
      ok = false,
      error_message = 'Не удалось обработать платёж, попробуйте позже',
    })

    return
  end

  -- Цифровой товар всегда 'в наличии' - подтверждаем.
  bot:answerPreCheckoutQuery({
    pre_checkout_query_id = ctx:getId(),
    ok = true,
  })
end

return preCheckoutQuery
