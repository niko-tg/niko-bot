--- Зоотовары: корма, шампуни, лекарства. По одному товару на (вид × категорию).
-- id товара = "<breed>_<kind>" (напр. cats_food) - совпадает с потребностью ухода.
--
local supplies = {}

-- Категории в порядке показа. stat - какой параметр питомца лечит товар.
supplies.categoryOrder = { 'food', 'shampoo', 'medicine' }

supplies.categories = {
  food     = { label = 'Корма',     emoji = '🥕', button = '🥕 Корма'     },
  shampoo  = { label = 'Шампуни',   emoji = '🧴', button = '🧴 Шампуни'   },
  medicine = { label = 'Лекарства', emoji = '💊', button = '💊 Лекарства' },
}

-- Виды в порядке показа внутри категории.
supplies.breedOrder = { 'dogs', 'cats', 'hamsters', 'fantasy' }

-- Подписи видов для кнопок товаров.
local BREED_LABEL = {
  dogs     = 'для собак',
  cats     = 'для кошек',
  hamsters = 'для хомяков',
  fantasy  = 'для уникальных',
}

-- Цены и количества по виду и категории (как в старом боте).
local PRICE = {
  dogs     = { food = 2000, shampoo = 2000, medicine = 2000 },
  cats     = { food = 2000, shampoo = 2000, medicine = 2000 },
  hamsters = { food = 1000, shampoo = 1000, medicine = 1000 },
  fantasy  = { food = 5000, shampoo = 5000, medicine = 5000 },
}

local PACK = { food = 10, shampoo = 5, medicine = 3 }
local EMOJI = { food = '🥕', shampoo = '🧴', medicine = '💊' }

-- Существительное товара для имени (категория -> слово).
local KIND_NOUN = { food = 'Корм', shampoo = 'Шампунь', medicine = 'Лекарства' }

--- id товара по виду и категории.
function supplies.id(breed, kind)
  return breed..'_'..kind
end

-- Сборка таблицы товаров: { id -> { id, name, emoji, breed, kind, price, currency, count } }.
supplies.items = {}

for _, breed in ipairs(supplies.breedOrder) do
  for _, kind in ipairs(supplies.categoryOrder) do
    local id = supplies.id(breed, kind)

    supplies.items[id] = {
      id = id,
      name = KIND_NOUN[kind]..' '..BREED_LABEL[breed],
      emoji = EMOJI[kind],
      breed = breed,
      kind = kind,
      price = PRICE[breed][kind],
      currency = 'money',
      count = PACK[kind],
    }
  end
end

--- Данные товара по id или nil.
function supplies.get(id)
  return supplies.items[id]
end

return supplies
