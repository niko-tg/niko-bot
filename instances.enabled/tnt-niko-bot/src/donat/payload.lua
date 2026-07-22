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

--- Разобрать payload доната.
-- Возвращает тип и количество при корректном формате и известном типе,
-- иначе nil.
-- @tparam ?string str строка payload вида '<type>-<count>'
-- @treturn ?string тип доната
-- @treturn ?number количество
function payload.parse(str)
  local donatType, count = (str or ''):match('^(%a+)-(%d+)$')
  if not donatType or not knownTypes[donatType] then
    return nil
  end

  return donatType, tonumber(count)
end

return payload
