--- Модель ошибок для валидации моделей.
--
local enum_errors = {
  REQUIRED_FIELD_MISSING = 'required_field_missing',
  INVALID_ENUM_VALUE = 'invalid_enum_value',
  INVALID_FIELD_TYPE = 'invalid_field_type',
  VALIDATION_ERROR = 'validation_error',
}

local Errors = {
  enum = enum_errors,
}
Errors.__index = Errors

--- Карта полей спейса: имя -> { type, is_nullable }.
-- @tparam table obj_space объект спейса box.space[...]
-- @treturn table карта полей
local function buildFormat(obj_space)
  local format = {}
  local spaceFormat = obj_space:format()
  for i = 1, #spaceFormat do
    local record = spaceFormat[i]
    format[record.name] = {
      type = record.type,
      is_nullable = record.is_nullable,
    }
  end

  return format
end

--- Новый объект ошибки.
-- @tparam[opt] table opts Таблица опций
-- @tparam string opts.space : Имя спейса
-- @treturn table obj
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
    format = buildFormat(objSpace),
  }

  setmetatable(obj, self)
  return obj
end

--- Добавление ошибки в коллекцию.
-- @tparam table data { field, details, code }
function Errors:add(data)
  self.count = self.count + 1

  table.insert(self.errors, {
    field = data.field,
    type = self.format[data.field].type,
    details = data.details,
    code = data.code or self.enum.VALIDATION_ERROR,
  })
end

--- Ошибка: обязательное поле не заполнено.
-- @tparam string field_name имя поля
function Errors:field_missing(field_name)
  self:add({
    field = field_name,
    code = self.enum.REQUIRED_FIELD_MISSING,
  })
end

--- Ошибка: значение поля вне допустимого перечисления.
-- @tparam string field_name имя поля
function Errors:invalid_enum(field_name)
  self:add({
    field = field_name,
    code = self.enum.INVALID_ENUM_VALUE,
  })
end

--- Ошибка валидации поля.
-- FIXME: пишет код INVALID_ENUM_VALUE вместо VALIDATION_ERROR.
-- @tparam string field_name имя поля
function Errors:validation_error(field_name)
  self:add({
    field = field_name,
    code = self.enum.INVALID_ENUM_VALUE,
  })
end

--- Есть ли накопленные ошибки.
-- @treturn boolean
function Errors:has_errors()
  return self.count > 0
end

--- Список накопленных ошибок.
-- @treturn table массив ошибок
function Errors:get_errors()
  return self.errors
end

--- Компактное представление коллекции ошибок.
-- @treturn table { errors, count }
function Errors:get_compact()
  return {
    errors = self.errors,
    count = self.count,
  }
end

--- Человекочитаемый список ошибок, по одной на строку.
-- @treturn string
function Errors:to_string()
  local result = {}

  for i = 1, #self.errors do
    local err = self.errors[i]
    table.insert(result, string.format(
      '[%s] %s: %s',
      err.code,
      err.field,
      err.details or 'Validation failed'
    ))
  end

  return table.concat(result, '\n')
end

return Errors
