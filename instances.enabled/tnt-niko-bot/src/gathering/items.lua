--- Единый реестр предметов добычи: ресурсы, инструменты, расходники.
--
-- Одна точка правды (раньше предметы были размазаны по 6 файлам src/items/*).
-- kind:
--   'resource'   - добытый/скрафченный ресурс, продаётся в магазин (sell)
--   'tool'       - инструмент с прочностью (durability), нужен для активности
--   'consumable' - расходник (прикормка), тратится за использование
--
-- Денежные поля: buy/sell в рублях (balance), currency='money'|'crystals' для buy.
--

local utf8 = require('utf8')

-- Все определения предметов по id.
local defs = {
  -- Рыбалка: улов
  fish        = { name = 'Рыба',            emoji = '🐟', kind = 'resource', sell = 1500 },
  red_fish    = { name = 'Красная рыба',    emoji = '🐡', kind = 'resource', sell = 8500 },
  blue_fish   = { name = 'Синяя рыба',      emoji = '🐠', kind = 'resource', sell = 6000 },
  yellow_fish = { name = 'Жёлтая рыба',     emoji = '🟡', kind = 'resource', sell = 5100 },
  turtle      = { name = 'Черепаха',        emoji = '🐢', kind = 'resource', sell = 5200 },
  snake       = { name = 'Змея',            emoji = '🐍', kind = 'resource', sell = 5200 },
  bober       = { name = 'Бобёр',           emoji = '🦫', kind = 'resource', sell = 5200 },
  scrap_metal = { name = 'Металлолом',      emoji = '⚙️', kind = 'resource', sell = 2000 },
  gold_chain  = { name = 'Золотая цепь',    emoji = '⛓️', kind = 'resource', sell = 9200 },

  -- Рудник: материалы
  coal       = { name = 'Уголь',            emoji = '⚫', kind = 'resource', sell = 1000   },
  metal      = { name = 'Металл',           emoji = '🔩', kind = 'resource', sell = 1500   },
  cuprum     = { name = 'Медь',             emoji = '🟠', kind = 'resource', sell = 3500   },
  gold       = { name = 'Золото',           emoji = '🪙', kind = 'resource', sell = 5500   },
  lazurite   = { name = 'Лазурит',          emoji = '🔷', kind = 'resource', sell = 3500   },
  diamond    = { name = 'Алмаз',            emoji = '💎', kind = 'resource', sell = 5500   },
  red_stone  = { name = 'Красный камень',   emoji = '🟥', kind = 'resource', sell = 5500   },
  emerald    = { name = 'Изумруд',          emoji = '🟩', kind = 'resource', sell = 12000  },
  quartz     = { name = 'Кварц',            emoji = '⬜', kind = 'resource', sell = 15000  },
  gravel     = { name = 'Гравий',           emoji = '🪨', kind = 'resource', sell = 1200   },
  granite    = { name = 'Гранит',           emoji = '🧱', kind = 'resource', sell = 1500   },
  andesite   = { name = 'Андезит',          emoji = '🪨', kind = 'resource', sell = 3500   },
  diorite    = { name = 'Диорит',           emoji = '🪨', kind = 'resource', sell = 5500   },
  tuff       = { name = 'Туф',              emoji = '🪨', kind = 'resource', sell = 3000   },
  deep_shale = { name = 'Глубинный сланец', emoji = '🌑', kind = 'resource', sell = 25000  },

  -- Лесопилка: древесина
  oak      = { name = 'Дуб',                emoji = '🪵', kind = 'resource', sell = 1000 },
  birch    = { name = 'Берёза',             emoji = '🪵', kind = 'resource', sell = 1000 },
  spruce   = { name = 'Ель',                emoji = '🌲', kind = 'resource', sell = 1200 },
  acacia   = { name = 'Акация',             emoji = '🪵', kind = 'resource', sell = 1700 },
  dark_oak = { name = 'Тёмный дуб',         emoji = '🪵', kind = 'resource', sell = 2000 },
  jungle   = { name = 'Тропическое дерево', emoji = '🌴', kind = 'resource', sell = 1500 },
  bamboo   = { name = 'Бамбук',             emoji = '🎋', kind = 'resource', sell = 500  },
  vines    = { name = 'Лианы',              emoji = '🌿', kind = 'resource', sell = 300  },
  mushroom = { name = 'Грибы',              emoji = '🍄', kind = 'resource', sell = 700  },
  bark     = { name = 'Кора',               emoji = '🟤', kind = 'resource', sell = 800  },
  resin    = { name = 'Смола',              emoji = '🟫', kind = 'resource', sell = 1500 },
  charcoal = { name = 'Древесный уголь',    emoji = '⬛', kind = 'resource', sell = 1200 },
  sawdust  = { name = 'Стружка',            emoji = '🟨', kind = 'resource', sell = 500  },

  -- Крафт: переработка (выход дороже сырья)
  ingot = { name = 'Слиток', emoji = '🧱', kind = 'resource', sell = 8000, crafted = true },
  plank = { name = 'Доска',  emoji = '🟫', kind = 'resource', sell = 4000, crafted = true },
  soup  = { name = 'Уха',    emoji = '🍲', kind = 'resource', sell = 9000, crafted = true },

  -- Ферма: урожай с грядок
  carrot  = { name = 'Морковь',  emoji = '🥕', kind = 'resource', sell = 1200 },
  wheat   = { name = 'Пшеница',  emoji = '🌾', kind = 'resource', sell = 1500 },
  corn    = { name = 'Кукуруза', emoji = '🌽', kind = 'resource', sell = 2000 },
  pumpkin = { name = 'Тыква',    emoji = '🎃', kind = 'resource', sell = 5000 },

  -- Готовка (переработка урожая фермы, money sink)
  flour       = { name = 'Мука',            emoji = '🌾', kind = 'resource', sell = 3500,  crafted = true },
  bread       = { name = 'Хлеб',            emoji = '🍞', kind = 'resource', sell = 8000,  crafted = true },
  veg_stew    = { name = 'Овощное рагу',    emoji = '🥘', kind = 'resource', sell = 6000,  crafted = true },
  pumpkin_pie = { name = 'Тыквенный пирог', emoji = '🥧', kind = 'resource', sell = 14000, crafted = true },
  pastry      = { name = 'Выпечка',         emoji = '🧁', kind = 'resource', sell = 16000, crafted = true },

  -- Загон: продукты животных
  egg   = { name = 'Яйца',   emoji = '🥚', kind = 'resource', sell = 1500 },
  wool  = { name = 'Шерсть', emoji = '🧶', kind = 'resource', sell = 5000 },
  honey = { name = 'Мёд',    emoji = '🍯', kind = 'resource', sell = 6000 },
  milk  = { name = 'Молоко', emoji = '🥛', kind = 'resource', sell = 4000 },

  -- Инструменты
  rod = {
    name = 'Бамбуковая удочка', emoji = '🎣',
    kind = 'tool', activity = 'fishing', durability = 10, buy = 7000,  currency = 'money',
  },
  rod_pro = {
    name = 'Спиннинг', emoji = '🎣',
    kind = 'tool', activity = 'fishing', durability = 1000, buy = 1, currency = 'crystals',
  },

  pick_wood  = {
    name = 'Деревянная кирка', emoji = '⛏️',
    kind = 'tool', activity = 'mining', durability = 2, buy = 2500,  currency = 'money',
  },
  pick_metal = {
    name = 'Железная кирка', emoji = '⛏️',
    kind = 'tool', activity = 'mining', durability = 10, buy = 10000, currency = 'money',
  },
  pick_pro = {
    name = 'Алмазная кирка', emoji = '⛏️',
    kind = 'tool', activity = 'mining', durability = 100, buy = 1, currency = 'crystals',
  },

  axe_wood = {
    name = 'Деревянный топор', emoji = '🪓',
    kind = 'tool', activity = 'sawmill', durability = 2, buy = 1500, currency = 'money',
  },
  saw_hand = {
    name = 'Ручная пила', emoji = '🪚',
    kind = 'tool', activity = 'sawmill', durability = 10, buy = 6000, currency = 'money',
  },
  saw_pro = {
    name = 'Цепная пила', emoji = '🪚',
    kind = 'tool', activity = 'sawmill', durability = 100, buy = 1, currency = 'crystals',
  },

  -- Расходники
  bait = {
    name = 'Прикормка', emoji = '🪱',
    kind = 'consumable', activity = 'fishing', buy = 15000, currency = 'money', buy_count = 10, sell = 250,
  },

  -- Ферма: семена (расходник, тратится при посадке; продаётся в /ферма, не в /shop)
  seed_carrot  = { name = 'Семена моркови',  emoji = '🥕', kind = 'consumable', buy = 800,  currency = 'money' },
  seed_wheat   = { name = 'Семена пшеницы',  emoji = '🌾', kind = 'consumable', buy = 1200, currency = 'money' },
  seed_corn    = { name = 'Семена кукурузы', emoji = '🌽', kind = 'consumable', buy = 1500, currency = 'money' },
  seed_pumpkin = { name = 'Семена тыквы',    emoji = '🎃', kind = 'consumable', buy = 3000, currency = 'money' },
}

-- Порядок вывода ресурсов в инвентаре/продаже (pairs по map неупорядочен).
local resourceOrder = {
  'fish',      'red_fish',
  'blue_fish', 'yellow_fish',
  'turtle',    'snake',
  'bober',     'scrap_metal',
  'gold_chain',

  'coal',      'metal',
  'cuprum',    'gold',
  'lazurite',  'diamond',
  'red_stone', 'emerald',
  'quartz',

  'gravel',    'granite',
  'andesite',  'diorite',
  'tuff',      'deep_shale',

  'oak',       'birch',
  'spruce',    'acacia',
  'dark_oak',  'jungle',
  'bamboo',    'vines',
  'mushroom',  'bark',
  'resin',     'charcoal',
  'sawdust',

  'ingot', 'plank',
  'soup',

  'carrot', 'wheat',
  'corn',   'pumpkin',

  'flour',    'bread',
  'veg_stew', 'pumpkin_pie',
  'pastry',

  'egg',   'wool',
  'honey', 'milk',
}

-- Порядок инструментов/расходников в снаряжении.
local toolOrder = {
  'rod',
  'rod_pro',
  'pick_wood',
  'pick_metal',
  'pick_pro',
  'axe_wood',
  'saw_hand',
  'saw_pro',
}
local consumableOrder = { 'bait' }

local M = {
  defs = defs,
  resourceOrder = resourceOrder,
  toolOrder = toolOrder,
  consumableOrder = consumableOrder,
}

--- Определение предмета по id (или nil).
function M.get(id)
  return defs[id]
end

--- Подпись "эмодзи Имя" (или сам id, если предмет неизвестен).
function M.label(id)
  local def = defs[id]
  if def == nil then
    return id
  end
  return def.emoji .. ' ' .. def.name
end

--- Цена продажи предмета в рублях (0, если не продаётся).
function M.sell(id)
  local def = defs[id]
  return (def and def.sell) or 0
end

--- Можно ли продать предмет в магазин (только ресурсы с ценой).
function M.isSellable(id)
  local def = defs[id]
  return def ~= nil and def.kind == 'resource' and (def.sell or 0) > 0
end

--- Является ли предмет инструментом.
function M.isTool(id)
  local def = defs[id]
  return def ~= nil and def.kind == 'tool'
end

--- Является ли предмет ресурсом (занимает место в рюкзаке).
function M.isResource(id)
  local def = defs[id]
  return def ~= nil and def.kind == 'resource'
end

--- Занятое место: сумма ресурсов в инвентаре (инструменты/расходники не в счёт).
-- @tparam table itemsMap id -> count
-- @treturn number
function M.resourceWeight(itemsMap)
  local weight = 0
  for id, count in pairs(itemsMap or {}) do
    if M.isResource(id) then
      weight = weight + count
    end
  end
  return weight
end

--- Покупаемые предметы активности (инструменты + расходники) в порядке вывода.
-- @tparam string activityKey 'fishing' | 'mining' | 'sawmill'
-- @treturn table массив id
function M.shopItems(activityKey)
  local list = {}

  for i = 1, #toolOrder do
    local id = toolOrder[i]
    if defs[id].activity == activityKey then
      table.insert(list, id)
    end
  end

  for i = 1, #consumableOrder do
    local id = consumableOrder[i]
    if defs[id].activity == activityKey then
      table.insert(list, id)
    end
  end

  return list
end

-- Правила 'винительный -> именительный' для распознавания названий в /sell
-- (как в старом боте): рыбу->рыба, красную->красная, синюю->синяя, змею->змея.
local DECLENSION_RULES = {
  { 'ую$', 'ая' },
  { 'юю$', 'яя' },
  { 'ою$', 'ая' },
  { 'у$',  'а'  },
  { 'ю$',  'я'  },
}

--- Слово к именительному падежу (первое подходящее правило окончания).
local function toNominative(word)
  word = utf8.lower(word)

  for i = 1, #DECLENSION_RULES do
    local rule = DECLENSION_RULES[i]
    if word:match(rule[1]) then
      return (word:gsub(rule[1], rule[2]))
    end
  end

  return word
end

--- Найти продаваемый ресурс по словам запроса с учётом склонений.
-- @tparam table words слова названия без count, напр. { 'красную', 'рыбу' }
-- @treturn[1] ?string id ресурса
-- @treturn[2] string фраза в именительном (для сообщения, если не найдено)
function M.resolveResource(words)
  local parts = {}
  for i = 1, #words do
    local word = words[i]
    table.insert(parts, toNominative(word))
  end

  local phrase = table.concat(parts, ' ')

  for id, def in pairs(defs) do
    if def.kind == 'resource' and (def.sell or 0) > 0 and utf8.lower(def.name) == phrase then
      return id, phrase
    end
  end

  return nil, phrase
end

return M
