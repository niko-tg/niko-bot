--- Линейный конгруэнтный генератор: детерминированная последовательность по сиду.
-- Параметры из Numerical Recipes. Слот /spin крутит им барабаны для управляемого
-- баланса (сиды подобраны под нужный % побед).
--
local function lcg(seed)
  local a = 1664525
  local c = 1013904223
  local m = 2 ^ 32

  seed = seed or os.time()

  local rnd = {}

  function rnd.getSeed()
    return seed
  end

  function rnd.seed(newSeed)
    seed = newSeed
  end

  function rnd.random()
    seed = (a * seed + c) % m
    return seed / m
  end

  function rnd.range(min, max)
    seed = (a * seed + c) % m
    return math.floor((seed / m) * (max - min + 1)) + min
  end

  return rnd
end

return lcg
