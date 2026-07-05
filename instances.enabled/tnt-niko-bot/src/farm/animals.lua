--- Реестр животных загона: что покупаем -> какой продукт по таймеру.
--
-- Простой таймер: животное даёт продукт каждые produce_time секунд, сбор ручной.
-- Одно животное каждого типа на игрока (наличие в user_farm.animals).
--   product      - id продукта (ресурс из items), выдаётся при сборе
--   produce_time - период производства в секундах
--   yield_*      - диапазон продукта за сбор (случайно yield_min..yield_max)
--   buy          - цена покупки животного (money)
--   min_level    - уровень фермы, с которого животное доступно
--

local animals = {
  chicken = {
    id = 'chicken',
    name = 'Курица',
    emoji = '🐔',
    product = 'egg',
    produce_time = 600,
    yield_min = 2,
    yield_max = 3,
    buy = 8000,
    min_level = 1,
  },
  sheep = {
    id = 'sheep',
    name = 'Овца',
    emoji = '🐑',
    product = 'wool',
    produce_time = 1200,
    yield_min = 1,
    yield_max = 2,
    buy = 15000,
    min_level = 2,
  },
  bees = {
    id = 'bees',
    name = 'Пчёлы',
    emoji = '🐝',
    product = 'honey',
    produce_time = 1500,
    yield_min = 1,
    yield_max = 2,
    buy = 25000,
    min_level = 3,
  },
  cow = {
    id = 'cow',
    name = 'Корова',
    emoji = '🐄',
    product = 'milk',
    produce_time = 1800,
    yield_min = 1,
    yield_max = 2,
    buy = 30000,
    min_level = 3,
  },
}

-- Порядок для меню/перечислений (pairs по таблице неупорядочен).
animals.order = { 'chicken', 'sheep', 'bees', 'cow' }

--- Животное по id (или nil).
function animals.get(id)
  return animals[id]
end

return animals
