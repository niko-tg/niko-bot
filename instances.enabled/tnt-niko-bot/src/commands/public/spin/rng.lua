--- RNG слота /spin: LCG с подобранными сидами (управляемый баланс ~43% побед).
-- Каждый сид даёт наперёд просчитанный расклад.
-- Реролл сида раз в reseed_every прокрутов.
--
local lcg = require('src.utils.lcg')
local config = require('conf.config')

local generator = lcg()
local plays = 0

--- Случайный сид из пула good_seeds.
local function reseed()
  local seeds = config.spin.good_seeds
  generator.seed(seeds[math.random(#seeds)])
end

reseed()

local rng = {}

--- Прокрут: 3 барабана через LCG, категория исхода по числу совпадений.
-- @treturn table { category = 'lose'|'win2'|'jackpot'|'ultra', reels = string }
function rng.spin()
  plays = plays + 1
  if plays >= config.spin.reseed_every then
    plays = 0
    reseed()
  end

  local symbols = config.spin.symbols
  local n = #symbols

  local idx = { generator.range(1, n), generator.range(1, n), generator.range(1, n) }

  -- Самый частый символ среди трёх барабанов.
  local counts = {}
  for k = 1, #idx do
    local i = idx[k]
    counts[i] = (counts[i] or 0) + 1
  end

  local maxCount, maxIdx = 0, idx[1]
  for i, count in pairs(counts) do
    if count > maxCount then
      maxCount = count
      maxIdx = i
    end
  end

  local category
  if maxCount == 3 then
    category = (symbols[maxIdx] == config.spin.crystal) and 'ultra' or 'jackpot'
  elseif maxCount == 2 then
    category = 'win2'
  else
    category = 'lose'
  end

  local reelArr = {}
  for k = 1, #idx do
    local i = idx[k]
    table.insert(reelArr, symbols[i])
  end

  return { category = category, reels = table.concat(reelArr, ' | ') }
end

return rng
