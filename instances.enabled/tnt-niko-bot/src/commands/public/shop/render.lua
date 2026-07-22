--- Рендер магазина: меню разделов, список товаров, карточка предмета.
--
local hdec = require('bot.libs.hdec')
local items = require('src.gathering.items')
local activities = require('src.gathering.activities')
local separateNumbers = require('src.utils.separateNumbers')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local render = {}

local MENU_TEXT = [[
🛒 <b>Магазин</b>
${sep}
💵 Баланс: <b>${balance}</b>р
💎 Кристаллы: <b>${crystals}</b>
${sep}
Выбери раздел
]]

local CATEGORY_TEXT = [[
${emoji} <b>Магазин - ${name}</b>
${sep}
Выбери товар]]

-- ${spec}/${owned} - опциональные фрагменты (могут быть пустыми).
local ITEM_TEXT = [[
<b>${title}</b>
${sep}
Для: ${activity}
${spec}Цена: <b>${price}</b>${owned}]]

--- Цена с символом валюты.
local function priceLabel(def)
  if def.currency == 'crystals' then
    return def.buy .. '💎'
  end
  return separateNumbers(def.buy) .. 'р'
end

--- Меню разделов.
-- @tparam table user для показа баланса
function render.menu(user)
  local row = {}
  for i = 1, #activities.order do
    local key = activities.order[i]
    local activity = activities[key]
    table.insert(row, {
      text = activity.emoji .. ' ' .. activity.name,
      callback = {
        command = 'cb_shop',
        arguments = {
          action = 'cat',
          item = key,
        },
      },
    })
  end

  return {
    text = MENU_TEXT:f({
      sep = hdec.sep,
      balance = separateNumbers(user.balance),
      crystals = separateNumbers(user.crystals),
    }),
    keyboard = inlineCallbackKeyboard({ row }),
  }
end

--- Список товаров раздела: кнопки с названиями (детали - по клику).
-- @tparam string activityKey
function render.category(activityKey)
  local activity = activities[activityKey]

  local rows = {}
  local shopIds = items.shopItems(activityKey)
  for i = 1, #shopIds do
    local id = shopIds[i]
    table.insert(rows, {
      {
        text = items.label(id),
        callback = {
          command = 'cb_shop',
          arguments = {
            action = 'item',
            item = id,
          },
        },
      },
    })
  end

  table.insert(rows, {
    {
      text = '◀️ Назад',
      callback = {
        command = 'cb_shop',
        arguments = {
          action = 'menu',
          item = '0',
        },
      },
    },
  })

  local text = CATEGORY_TEXT:f({
    emoji = activity.emoji,
    name = activity.name,
    sep = hdec.sep,
  })

  return {
    text = text,
    keyboard = inlineCallbackKeyboard(rows),
  }
end

--- Карточка товара: характеристики + кнопки 'Купить' и 'Назад'.
-- @tparam string itemId
-- @tparam ?table inv инвентарь игрока (для строки 'у тебя')
function render.item(itemId, inv)
  local def = items.get(itemId)
  local activity = activities[def.activity]

  -- Опциональная спецификация (своя строка перед ценой).
  local spec = ''
  if def.kind == 'tool' then
    spec = 'Прочность: <b>' .. def.durability .. '</b>\n'

  elseif def.buy_count then
    spec = 'В пачке: <b>' .. def.buy_count .. '</b> шт\n'
  end

  -- Опциональная строка 'у тебя' (после цены).
  local owned = ''
  if inv then
    if def.kind == 'tool' and inv.tools and inv.tools[itemId] then
      owned = '\nУ тебя есть, прочность <b>' .. inv.tools[itemId] .. '</b>'

    elseif inv.items and (inv.items[itemId] or 0) > 0 then
      owned = '\nУ тебя: <b>' .. inv.items[itemId] .. '</b>'
    end
  end

  local text = ITEM_TEXT:f({
    title = items.label(itemId),
    sep = hdec.sep,
    activity = activity.emoji .. ' ' .. activity.name,
    spec = spec,
    price = priceLabel(def),
    owned = owned,
  })

  local rows = {
    {
      {
        text = '💰 Купить',
        callback = {
          command = 'cb_shop',
          arguments = {
            action = 'buy',
            item = itemId,
          },
        },
      },
    },
    {
      {
        text = '◀️ Назад',
        callback = {
          command = 'cb_shop',
          arguments = {
            action = 'cat',
            item = def.activity,
          },
        },
      },
    },
  }

  return {
    text = text,
    keyboard = inlineCallbackKeyboard(rows),
  }
end

return render
