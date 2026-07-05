--- Обработка успешного платежа (донат через Telegram Stars).
-- Каждый платёж сначала фиксируем в transactions (идемпотентность + аудит),
-- затем начисляем награду по payload.
--
local log = require('log')
local bot = require('bot')
local config = require('conf.config')
local parseUnit = require('src.utils.parseUnit')
local donatPayload = require('src.donat.payload')
local donat_types = require('src.enums.donat_types')
local separateNumbers = require('src.utils.separateNumbers')
local usersService = require('src.services.users')
local vipUsersService = require('src.services.vip_users')
local transactionsService = require('src.services.transactions')
local notifyVipActivated = require('src.notifications.vipActivated')

-- Длительность VIP по count (см. cb_donat): 1 -> месяц, 12 -> год.
-- Те же определения месяца/года, что и в /mkvip (parseUnit 'date').
local VIP_DURATION = {
  [1]  = parseUnit('1m', 'date'),
  [12] = parseUnit('1y', 'date'),
}

-- Увеличить числовое поле пользователя на delta. true при успехе.
local function incUserField(userId, field, delta)
  local user, err = usersService.read(userId)
  if err or not user then
    log.error(err or ('[payment] Пользователь не найден: '..tostring(userId)))
    return false
  end

  local _, updErr = usersService.update({ [field] = user[field] + delta }, { id = userId })
  if updErr then
    log.error(updErr)
    return false
  end

  return true
end

-- Начисление по типу доната. Возвращает текст-подтверждение в ЛС или nil.
local function applyReward(userId, donatType, count)
  if donatType == donat_types.MONEY then
    local amount = config.donat.currency_per_min_stars * count

    if incUserField(userId, 'balance', amount) then
      return ('💵 Начислено %sр'):format(separateNumbers(amount))
    end

  elseif donatType == donat_types.CRYSTAL then
    if incUserField(userId, 'crystals', count) then
      return ('💎 Начислено кристаллов: %d'):format(count)
    end

  elseif donatType == donat_types.COFFEE then
    if incUserField(userId, 'karma', count) then
      return ('☕️ Спасибо! +%d к карме'):format(count)
    end

  elseif donatType == donat_types.VIP then
    local seconds = VIP_DURATION[count]
    if not seconds then
      log.warn('[payment] Неизвестный VIP count: %s', tostring(count))
      return nil
    end

    local existing, err = vipUsersService.read(userId)
    if err then
      log.error(err)
      return nil
    end

    local now = os.time()
    local startFrom = (existing and existing.until_date > now) and existing.until_date or now
    local untilDate = startFrom + seconds

    local _, upsertErr = vipUsersService.upsert({
      user_id = userId,
      until_date = untilDate,
    })

    if upsertErr then
      log.error(upsertErr)
      return nil
    end

    -- vipActivated сам шлёт уведомление - отдельный confirmation не нужен.
    notifyVipActivated({ id = userId }, untilDate)
  end

  return nil
end

local function successfulPayment(ctx)
  local payment = ctx:getSuccessfulPayment()
  local userId = ctx:getUserFromId()
  local chargeId = payment:getTelegramPaymentChargeId()
  local invoicePayload = payment:getInvoicePayload()

  -- Идемпотентность: платёж уже обработан - выходим.
  local existing, readErr = transactionsService.read(chargeId)
  if readErr then
    log.error(readErr)
    return
  end

  if existing then
    return
  end

  -- Сначала фиксируем транзакцию (барьер идемпотентности + аудит любого
  -- полученного платежа), только потом начисляем награду.
  local _, createErr = transactionsService.create({
    telegram_payment_charge_id = chargeId,
    user_id = userId,
    amount = payment:getTotalAmount(),
    currency = payment:getCurrency(),
    payload = invoicePayload,
  })

  if createErr then
    log.error(createErr)
    return
  end

  -- pre_checkout уже валидировал формат, но guard'имся.
  local donatType, count = donatPayload.parse(invoicePayload)
  if not donatType then
    log.error('[payment] Платёж записан, но payload не распознан: '..tostring(invoicePayload))
    return
  end

  local confirmation = applyReward(userId, donatType, count)

  if confirmation then
    bot:sendMessage({
      chat_id = userId,
      text = confirmation,
    })
  end
end

return successfulPayment
