--- Отправка invoice по выбранному типу доната.
--
local uri = require('uri')
local bot = require('bot')
local config = require('conf.config')
local Command = require('bot.classes.Command')
local donat_types = require('src.enums.donat_types')
local separateNumbers = require('src.utils.separateNumbers')

local command = Command:new({
  commands = { 'cb_donat' },
  flags = {
    Command.enum.CALLBACK,
  },
  arguments_schema = { 'type', 'count' },
})

--- Сборка payload инвойса из аргументов кнопки.
-- @tparam table arguments аргументы callback-кнопки
-- @treturn string payload вида '<type>-<count>'
local function genPayload(arguments)
  return arguments.type .. '-' .. arguments.count
end

local DEFAULT_CURRENCY = 'XTR'

local TEMPLATE_DESCRIPTION_XTR = [[
Покупаете: ${item} | За: ${price} ⭐️
]]

--- Собирает поля invoice под конкретный тип доната.
-- Возвращает nil, если count не соответствует ни одному варианту.
local function buildInvoice(arguments)
  local count = tonumber(arguments.count)

  if arguments.type == donat_types.MONEY then
    local amount = config.donat.min_stars_amount * count

    return {
      title = '💵 Покупка валюты',
      description = TEMPLATE_DESCRIPTION_XTR:f({
        item = separateNumbers(config.donat.currency_per_min_stars * count),
        price = separateNumbers(amount),
      }),
      amount = amount,
      photo = 'donat/money.jpeg',
      photo_width = 126,
      photo_height = 138,
    }

  elseif arguments.type == donat_types.CRYSTAL then
    local variants = {
      [1] = {
        amount = config.donat.one_crystal_price_stars,
        photo = 'donat/diamond.jpeg' },
      [5] = {
        amount = config.donat.five_crystals_price_stars,
        photo = 'donat/diamonds5.jpg',
      },
    }

    local variant = variants[count]
    if not variant then
      return
    end

    return {
      title = '💎 Покупка кристалла',
      description = TEMPLATE_DESCRIPTION_XTR:f({
        item = separateNumbers(count),
        price = separateNumbers(variant.amount),
      }),
      amount = variant.amount,
      photo = variant.photo,
      photo_width = 126,
      photo_height = 138,
    }

  elseif arguments.type == donat_types.VIP then
    local variants = {
      [1] = {
        amount = config.donat.vip_1m_price_stars,
        photo = 'donat/vip.jpeg',
        title = '👑 VIP Подписка 👑',
        description = 'Месяц VIP-статуса!',
      },
      [12] = {
        amount = config.donat.vip_1y_price_stars,
        photo = 'donat/vip1y.jpg',
        title = '👑 VIP ПОДПИСКА НА ГОД! 👑',
        description = 'Целый год VIP-статуса!',
      },
    }

    local variant = variants[count]
    if not variant then
      return
    end

    return {
      title = variant.title,
      description = variant.description,
      amount = variant.amount,
      photo = variant.photo,
      photo_width = 127,
      photo_height = 114,
    }

  elseif arguments.type == donat_types.COFFEE then
    return {
      title = '☕️ Покупка кофе для разработчика',
      description = 'Благодаря кофе, я могу продолжать разработку',
      amount = count,
      photo = 'donat/coffee.jpg',
    }
  end
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local arguments = command.arguments

  if not arguments.type then
    return
  end

  ctx:answer()

  local invoice = buildInvoice(arguments)
  if not invoice then
    return
  end

  bot:sendInvoice({
    title = invoice.title,
    description = invoice.description,
    chat_id = ctx:getUserFromId(),
    payload = genPayload(arguments),
    currency = DEFAULT_CURRENCY,
    prices = {
      {
        label = genPayload(arguments),
        amount = invoice.amount,
      },
    },
    photo_url = config.bot.url_assets..uri.escape(invoice.photo),
    photo_width = invoice.photo_width,
    photo_height = invoice.photo_height,
  })
end

return command
