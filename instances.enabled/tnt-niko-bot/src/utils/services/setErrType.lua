--- Установка метаполя с типизированной ошибкой.
--
local function setErrType(err, type)
  if err == nil then
    return nil
  end

  local mt = getmetatable(err)
  if mt == nil then
    setmetatable(err, { __service_error_type = type })
    return err
  end

  mt.__service_error_type = type

  return err
end

return setErrType
