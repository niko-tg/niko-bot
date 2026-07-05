--- Парсит until_date, unit
--
local utf8 = require('utf8')

local DEFAULT_UNTIL_SEC = 60 * 5

local function parseUntilDate(str)
  if str == nil then
    return os.time() + DEFAULT_UNTIL_SEC, (DEFAULT_UNTIL_SEC/60)..' минут'
  end

  str = utf8.lower(str)

  local number = str:match('^(%d+)')
  local unit = str:match('([мдmdчh]+)$')

  number = number and tonumber(number)

  if not number and not unit then
    return nil, nil
  elseif number and not unit then
    local until_time = number * 60
    return os.time() + until_time, (until_time/60)..' минут'
  end

  -- Если number не спарсился
  if not number then
    return os.time() + DEFAULT_UNTIL_SEC, (DEFAULT_UNTIL_SEC/60)..' минут'
  end

  local raw_number = number

  if unit == 'м' or unit == 'm' then
    number = number * 60
  elseif unit == 'ч' or unit == 'h' then
    number = number * 3600
  elseif unit == 'д' or unit == 'd' then
    number = number * 86400
  end

  return os.time() + number, raw_number..unit
end

return parseUntilDate
