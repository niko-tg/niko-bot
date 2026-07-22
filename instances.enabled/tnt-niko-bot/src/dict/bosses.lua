--- Каталог рейд-боссов: тиры с HP, пулом награды и весом спавна.
--
-- weight - вес взвешенного рандома при призыве (сумма произвольная).
-- crystal_odds - шанс кристалла добившему: 1 из N (nil - без кристалла).
-- Общие параметры боя (TTL, кулдауны, урон) - conf/config.lua -> boss.
--
local BOSSES = {
  {
    key = 'slime',
    emoji = '🟢',
    name = 'Гигантский слизень',
    about = 'Выполз из канализации и жрёт всё подряд',
    hp = 2500,
    reward = 60000,
    weight = 60,
    crystal_odds = nil,
  },
  {
    key = 'golem',
    emoji = '🗿',
    name = 'Каменный голем',
    about = 'Ожившая скала. Бить больно, но надо',
    hp = 6000,
    reward = 200000,
    weight = 30,
    crystal_odds = 3,
  },
  {
    key = 'dragon',
    emoji = '🐉',
    name = 'Древний дракон',
    about = 'Спал тысячу лет и проснулся очень злым',
    hp = 12000,
    reward = 700000,
    weight = 10,
    crystal_odds = 1,
  },
}

local M = {
  -- list - упорядочено по тирам
  list = BOSSES,
  -- byKey - для поиска по сессии
  byKey = {},
}

local totalWeight = 0

for i = 1, #BOSSES do
  local boss = BOSSES[i]
  M.byKey[boss.key] = boss
  totalWeight = totalWeight + boss.weight
end

--- Случайный босс с учётом весов.
-- @treturn table запись каталога
function M.pickRandom()
  local roll = math.random(1, totalWeight)

  for i = 1, #BOSSES do
    local boss = BOSSES[i]
    roll = roll - boss.weight

    if roll <= 0 then
      return boss
    end
  end

  return BOSSES[1]
end

return M
