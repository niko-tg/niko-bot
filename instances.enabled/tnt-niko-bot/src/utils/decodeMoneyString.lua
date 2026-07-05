--- Парсинг строки с юнитом валюты: 10 -> 10, 10к -> 10000, 10кк -> 10000000.
-- Каждый суффикс к/k умножает на 1000 (10^3).
--
local utf8 = require('utf8')

-- Максимум к-суффиксов: 10ккк = 10 млрд.
local MAX_UNITS = 3

local function decodeMoneyString(str)
  if str == nil then
    return nil
  end

  str = utf8.lower(str)

  -- Весь токен: цифры + опц. суффиксы к/k. Мусор после ("10к5") не проходит.
  local number, unit = str:match('^(%d+)([kк]*)$')
  if not number then
    return nil
  end

  local step = utf8.len(unit)
  if step > MAX_UNITS then
    return nil
  end

  return math.floor(tonumber(number) * (1000 ^ step))
end

return decodeMoneyString
