--- Рендер зоомагазина: экраны питомцев и зоотоваров.
-- Каждый экран - { image, caption, keyboard }: сообщение всегда фото, переходы
-- идут через editMessageMedia.
--
local hdec = require('bot.libs.hdec')
local separateNumbers = require('src.utils.separateNumbers')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')
local assets = require('src.pets.assets')
local catalog = require('src.pets.catalog')
local supplies = require('src.pets.supplies')
local petLogic = require('src.pets.petLogic')

local TIME_LABEL = { day = 'День', evening = 'Вечер', night = 'Ночь' }

local MENU = ([[
🛍 <b>Зоомагазин</b>
${sep}
Тут можно завести питомца или купить зоотовары!
]]):f({ sep = hdec.sep })

local PET_CATEGORIES = ([[
🛍 <b>Зоомагазин</b>
${sep}
Выбери вид питомца
]]):f({ sep = hdec.sep })

local PET_COLORS = ([[
🛍 <b>Зоомагазин</b>
${sep}
Выбери породу
]]):f({ sep = hdec.sep })

local PET_DETAIL = [[
🛍 <b>Зоомагазин</b>
⏳ Время: <b>${time}</b>
${sep}
Порода: <b>${name}</b>
Цена: <b>${price}</b>
${sep}
${description}
]]

local PET_BOUGHT = ([[
⭐️ <b>Ты завёл питомца!</b>
${sep}
Список питомцев: <code>мои питомцы</code>
]]):f({ sep = hdec.sep })

local SUPPLY_CATEGORIES = ([[
🛍 <b>Зоотовары</b>
${sep}
Корма, шампуни и лекарства. Выбирай по виду питомца.
${sep}
Выбери категорию
]]):f({ sep = hdec.sep })

local SUPPLY_LIST = [[
🛍 <b>Зоотовары</b>
${sep}
${category}
Выбери товар по виду питомца
]]

local SUPPLY_DETAIL = [[
🛍 <b>Зоотовары</b>
${sep}
Товар: <b>${name}</b>
Цена: <b>${price}</b>
В упаковке: <b>${count}</b> шт.
]]

local SUPPLY_BOUGHT = [[
✅ <b>Покупка совершена!</b>
  ╰ <b>${name}</b>
]]

local render = {}

--- Callback к cb_zoo. Неиспользуемые аргументы - плейсхолдер '_'.
local function cb(action, a, b)
  return {
    command = 'cb_zoo',
    arguments = { action = action, a = a or '_', b = b or '_' },
  }
end

--- Цена с эмодзи валюты.
local function priceLabel(price, currency)
  return separateNumbers(price)..' '..(currency == 'crystals' and '💎' or '💵')
end

--- Главное меню магазина (питомцы / зоотовары).
function render.menu()
  return {
    image = assets.shop,
    caption = MENU,
    keyboard = inlineCallbackKeyboard({
      { { text = '🐾 Питомцы', callback = cb('pets') } },
      { { text = '🦴 Зоотовары', callback = cb('items') } },
    }),
  }
end

--- Категории питомцев (виды).
function render.petCategories()
  local rows = {}

  for i = 1, #catalog.typeOrder do
    local breed = catalog.typeOrder[i]
    table.insert(rows, {
      { text = catalog.types[breed].button, callback = cb('breed', breed) },
    })
  end

  table.insert(rows, { { text = '⬅️ Назад', callback = cb('menu') } })

  return {
    image = assets.shop,
    caption = PET_CATEGORIES,
    keyboard = inlineCallbackKeyboard(rows),
  }
end

--- Породы выбранного вида.
function render.petColors(breed)
  local colors = catalog.colorOrder[breed]
  if not colors then
    return nil
  end

  local rows = {}

  for i = 1, #colors do
    local color = colors[i]
    local variant = catalog.get(breed, color)
    table.insert(rows, {
      { text = variant.emoji..' '..variant.name, callback = cb('view', breed, color) },
    })
  end

  table.insert(rows, { { text = '⬅️ Назад', callback = cb('pets') } })

  return {
    image = assets.shop,
    caption = PET_COLORS,
    keyboard = inlineCallbackKeyboard(rows),
  }
end

--- Карточка питомца в магазине (с картинкой и кнопкой покупки).
function render.petDetail(breed, color)
  local variant = catalog.get(breed, color)
  if not variant then
    return nil
  end

  local timeType = petLogic.timeType()

  local caption = PET_DETAIL:f({
    sep = hdec.sep,
    time = TIME_LABEL[timeType],
    name = variant.name,
    price = priceLabel(variant.price, variant.currency),
    description = variant.description,
  })

  return {
    image = assets.pet(breed, color, timeType, 'neutral'),
    caption = caption,
    keyboard = inlineCallbackKeyboard({
      { { text = '🫶 Купить', callback = cb('buy', breed, color) } },
      { { text = '⬅️ Назад', callback = cb('breed', breed) } },
    }),
  }
end

--- Экран после покупки питомца.
function render.petBought()
  return {
    image = assets.shop,
    caption = PET_BOUGHT,
    keyboard = inlineCallbackKeyboard({
      { { text = '⬅️ В магазин', callback = cb('menu') } },
    }),
  }
end

--- Категории зоотоваров (корма/шампуни/лекарства).
function render.supplyCategories()
  local rows = {}

  for i = 1, #supplies.categoryOrder do
    local kind = supplies.categoryOrder[i]
    table.insert(rows, {
      { text = supplies.categories[kind].button, callback = cb('cat', kind) },
    })
  end

  table.insert(rows, { { text = '⬅️ Назад', callback = cb('menu') } })

  return {
    image = assets.shop,
    caption = SUPPLY_CATEGORIES,
    keyboard = inlineCallbackKeyboard(rows),
  }
end

--- Товары категории по видам.
function render.supplyList(kind)
  local category = supplies.categories[kind]
  if not category then
    return nil
  end

  local rows = {}

  for i = 1, #supplies.breedOrder do
    local breed = supplies.breedOrder[i]
    local item = supplies.get(supplies.id(breed, kind))
    table.insert(rows, {
      { text = item.emoji..' '..item.name, callback = cb('sview', item.id) },
    })
  end

  table.insert(rows, { { text = '⬅️ Назад', callback = cb('items') } })

  return {
    image = assets.shop,
    caption = SUPPLY_LIST:f({ sep = hdec.sep, category = category.label }),
    keyboard = inlineCallbackKeyboard(rows),
  }
end

--- Карточка товара с кнопкой покупки.
function render.supplyDetail(supplyId)
  local item = supplies.get(supplyId)
  if not item then
    return nil
  end

  return {
    image = assets.shop,
    caption = SUPPLY_DETAIL:f({
      sep = hdec.sep,
      name = item.name,
      price = priceLabel(item.price, item.currency),
      count = item.count,
    }),
    keyboard = inlineCallbackKeyboard({
      { { text = '🛒 Купить', callback = cb('sbuy', supplyId) } },
      { { text = '⬅️ Назад', callback = cb('cat', item.kind) } },
    }),
  }
end

--- Экран после покупки товара.
function render.supplyBought(supplyId)
  local item = supplies.get(supplyId)

  -- Назад ведёт на список товаров этой категории (на одну страницу назад),
  -- чтобы можно было сразу купить тот же товар ещё раз.
  return {
    image = assets.shop,
    caption = SUPPLY_BOUGHT:f({ name = item and item.name or 'товар' }),
    keyboard = inlineCallbackKeyboard({
      { { text = '⬅️ Назад', callback = cb('cat', item and item.kind) } },
    }),
  }
end

return render
