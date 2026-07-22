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

  --- Текущий сид генератора.
  -- @treturn number
  function rnd.getSeed()
    return seed
  end

  --- Установка нового сида.
  -- @tparam number newSeed сид
  function rnd.seed(newSeed)
    seed = newSeed
  end

  --- Следующее число последовательности в [0, 1).
  -- @treturn number
  function rnd.random()
    seed = (a * seed + c) % m
    return seed / m
  end

  --- Целое число из диапазона [min, max].
  -- @tparam number min нижняя граница
  -- @tparam number max верхняя граница
  -- @treturn number
  function rnd.range(min, max)
    seed = (a * seed + c) % m
    return math.floor((seed / m) * (max - min + 1)) + min
  end

  return rnd
end

return lcg
