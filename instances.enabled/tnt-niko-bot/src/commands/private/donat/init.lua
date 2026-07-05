--- Обработка доната
--
local hdec = require('bot.libs.hdec')
local config = require('conf.config')
local Command = require('bot.classes.Command')
local separateNumbers = require('src.utils.separateNumbers')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')
local donat_types = require('src.enums.donat_types')

local command = Command:new {
  commands = { '/donat', 'донат' },
  flags = { Command.enum.PRIVATE }
}

local TEMPLATE = [[
⭐️ <b>Донат за звезды!</b> ⭐️
${sep}
<b>Цены</b>
${sep}
💵 <b>${x100m_currency}</b>р = ⭐️ ${x100_stars_amount} звёзд
💵 <b>${x10m_currency}</b>р = ⭐️ ${min_stars_amount} звёзд
${sep}
💎 5 Кристаллов = ⭐️ ${five_crystals_price_stars} звёзд
💎 1 Кристалл = ⭐️ ${one_crystal_price_stars} звёзд
${sep}
👑 Год VIP статуса = ⭐️ ${vip_1y_price_stars} звёзд
👑 Месяц VIP статуса = ⭐️ ${vip_1m_price_stars} звёзд
${sep}
За покупку кофе вы получите +1 к карме, а так же сможете поддержать проект, даже если у вас всего 1 звезда
]]

function command.call(ctx)

  local strVals = {
    -- Цена 100млн валюты за 100 звёзд
    x100m_currency            = separateNumbers(config.donat.currency_per_min_stars * 10),
    x100_stars_amount         = separateNumbers(config.donat.min_stars_amount * 10),
    -- Цена 10млн валюты за 10 звёзд
    x10m_currency             = separateNumbers(config.donat.currency_per_min_stars),
    min_stars_amount          = separateNumbers(config.donat.min_stars_amount),
    -- Цена за 5 кристаллов
    five_crystals_price_stars = separateNumbers(config.donat.five_crystals_price_stars),
    -- Цена за 1 кристалл
    one_crystal_price_stars   = separateNumbers(config.donat.one_crystal_price_stars),
    -- Цены на VIP-статутсы
    vip_1y_price_stars        = separateNumbers(config.donat.vip_1y_price_stars),
    vip_1m_price_stars        = separateNumbers(config.donat.vip_1m_price_stars),

    sep = hdec.sep,
  }

  local keyboard = inlineCallbackKeyboard({
    -- Section money
    {
      {
        text = '💵 ' .. strVals.x100m_currency,
        callback = {
          command = 'cb_donat',
          arguments = {
            type = donat_types.MONEY, count = 10,
          }
        }
      },
      {
        text = '💵 ' .. strVals.x10m_currency,
        callback = {
          command = 'cb_donat',
          arguments = {
            type = donat_types.MONEY, count = 1,
          }
        }
      },
    },
    -- Section crystals
    {
      {
        text = '💎 5 кристаллов',
        callback = {
          command = 'cb_donat',
          arguments = {
            type = donat_types.CRYSTAL, count = 5,
          }
        }
      },
      {
        text = '💎 1 кристалл',
        callback = {
          command = 'cb_donat',
          arguments = {
            type = donat_types.CRYSTAL, count = 1,
          }
        }
      },
    },
    -- Section VIP
    {
      {
        text = '👑 VIP НА ГОД!',
        callback = {
          command = 'cb_donat',
          arguments = {
            type = donat_types.VIP, count = 12,
          }
        }
      },
      {
        text = '👑 VIP на месяц',
        callback = {
          command = 'cb_donat',
          arguments = {
            type = donat_types.VIP, count = 1,
          }
        }
      },
    },
    -- Other section
    {
      text = '☕️ Кофе для разработчика',
      callback = {
        command = 'cb_donat',
        arguments = {
          type = donat_types.COFFEE, count = 1,
        }
      }
    },
  })

  table.insert(keyboard.inline_keyboard, {
    {
      text = '🧑‍💻 Служба поддержки',
      url = 'tg://user?id=1268212938'
    }
  })

  ctx:replyToMessage({
    text = TEMPLATE:f(strVals),
    reply_markup = keyboard
  })
end

return command
