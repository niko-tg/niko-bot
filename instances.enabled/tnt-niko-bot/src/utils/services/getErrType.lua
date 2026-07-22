--- Чтение метаполя с типизированной ошибкой (парное к setErrType).
--
local function getErrType(err)
  if err == nil then
    return nil
  end

  local mt = getmetatable(err)

  return mt and mt.__service_error_type or nil
end

return getErrType
