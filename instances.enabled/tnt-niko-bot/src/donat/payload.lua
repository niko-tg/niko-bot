--- Кодек payload'а доната.
-- Формат: "<type>-<count>" (напр. "vip-12"), кладётся в invoice и приходит
-- обратно в pre_checkout_query / successful_payment.
--
local donat_types = require('src.enums.donat_types')

-- Известные типы доната - для валидации.
local knownTypes = {}
for _, value in pairs(donat_types) do
  knownTypes[value] = true
end

local payload = {}

--- Разобрать payload. Возвращает type, count при корректном формате и
--- известном типе, иначе nil.
-- @param str (string|nil)
-- @return[1] type (string), count (number)
-- @return[2] nil
function payload.parse(str)
  local donatType, count = (str or ''):match('^(%a+)-(%d+)$')
  if not donatType or not knownTypes[donatType] then
    return nil
  end

  return donatType, tonumber(count)
end

return payload
