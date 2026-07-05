--- Модель ошибок для валидации моделей
--
local enum_errors = {
  REQUIRED_FIELD_MISSING = 'required_field_missing',
  INVALID_ENUM_VALUE = 'invalid_enum_value',
  INVALID_FIELD_TYPE = 'invalid_field_type',
  VALIDATION_ERROR = 'validation_error'
}

local Errors = {
  enum = enum_errors
}
Errors.__index = Errors

local function buildFormat(obj_space)
  local format = {}
  for _, record in ipairs(obj_space:format()) do
    format[record.name] = {
      type = record.type,
      is_nullable = record.is_nullable
    }
  end

  return format
end

--- Новый объект ошибки
-- @param[optchain] opts (table) Таблица опций
-- @param opts.space (string): Имя спейса
-- @return obj
function Errors:new(opts)
  opts = opts or {}

  if not opts.space then
    error('Required option not passed: space', 1)
  end

  local objSpace = box.space[opts.space]
  if not objSpace then
    error('Invalid space name: ' .. opts.space, 1)
  end

  local obj = {
    errors = {},
    count = 0,
    format = buildFormat(objSpace)
  }

  setmetatable(obj, self)
  return obj
end

function Errors:add(data)
  self.count = self.count + 1

  table.insert(self.errors, {
    field = data.field,
    type = self.format[data.field].type,
    details = data.details,
    code = data.code or self.enum.VALIDATION_ERROR
  })
end

function Errors:field_missing(field_name)
  self:add {
    field = field_name,
    code = self.enum.REQUIRED_FIELD_MISSING
  }
end

function Errors:invalid_enum(field_name)
  self:add {
    field = field_name,
    code = self.enum.INVALID_ENUM_VALUE
  }
end

function Errors:validation_error(field_name)
  self:add {
    field = field_name,
    code = self.enum.INVALID_ENUM_VALUE
  }
end

function Errors:has_errors()
  return self.count > 0
end

function Errors:get_errors()
  return self.errors
end

function Errors:get_compact()
  return {
    errors = self.errors,
    count = self.count
  }
end

function Errors:to_string()
  local result = {}

  for _, err in ipairs(self.errors) do
    table.insert(result, string.format(
      "[%s] %s: %s",
      err.code,
      err.field,
      err.details or 'Validation failed'
    ))
  end

  return table.concat(result, '\n')
end

return Errors
