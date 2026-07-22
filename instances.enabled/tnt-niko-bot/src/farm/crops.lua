--- Реестр культур фермы: что сажаем -> что вырастает.
--
-- Только агрономия (как activities/loot в добыче). Сами предметы (семена и продукты)
-- лежат в реестре src/gathering/items.lua.
--   seed      - id семени (расходник из items), тратится при посадке
--   product   - id продукта (ресурс из items), выдаётся при сборе
--   grow      - время роста в секундах (от посадки до готовности)
--   yield_*   - диапазон урожая за сбор (случайно yield_min..yield_max)
--   min_level - уровень фермы, с которого культура доступна (гейт посадки/покупки семян)
--

local crops = {
  carrot = {
    id = 'carrot',
    name = 'Морковь',
    emoji = '🥕',
    seed = 'seed_carrot',
    product = 'carrot',
    grow = 300,
    yield_min = 2,
    yield_max = 4,
    min_level = 1,
  },
  wheat = {
    id = 'wheat',
    name = 'Пшеница',
    emoji = '🌾',
    seed = 'seed_wheat',
    product = 'wheat',
    grow = 600,
    yield_min = 3,
    yield_max = 5,
    min_level = 1,
  },
  corn = {
    id = 'corn',
    name = 'Кукуруза',
    emoji = '🌽',
    seed = 'seed_corn',
    product = 'corn',
    grow = 720,
    yield_min = 2,
    yield_max = 3,
    min_level = 2,
  },
  pumpkin = {
    id = 'pumpkin',
    name = 'Тыква',
    emoji = '🎃',
    seed = 'seed_pumpkin',
    product = 'pumpkin',
    grow = 1800,
    yield_min = 1,
    yield_max = 2,
    min_level = 3,
  },
}

-- Порядок для меню/перечислений (pairs по таблице неупорядочен).
crops.order = { 'carrot', 'wheat', 'corn', 'pumpkin' }

--- Культура по id (или nil).
function crops.get(id)
  return crops[id]
end

--- Культура по id семени (или nil).
function crops.bySeed(seedId)
  for i = 1, #crops.order do
    local key = crops.order[i]
    if crops[key].seed == seedId then
      return crops[key]
    end
  end
  return nil
end

return crops
