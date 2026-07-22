--- Модель питомца.
--
local datetime = require('datetime')
local Errors = require('src.models.Errors')
local catalog = require('src.pets.catalog')
local states = require('src.pets.states')

--- Конструктор модели Pet.
-- @tparam table data сырые поля (из запроса или из БД)
-- @tparam[opt] table opts опции { init = true } - инициализация всех полей
-- @treturn[1] table model
-- @treturn[2] table errs
local function Pet(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'pets' })
  local model = {}

  -- Идентификатор (выдаёт sequence в сервисе).
  if tonumber(data.id) then
    model.id = tonumber(data.id)
  else
    errors:field_missing('id')
  end

  -- Владелец.
  if tonumber(data.owner_id) then
    model.owner_id = tonumber(data.owner_id)
  else
    errors:field_missing('owner_id')
  end

  -- Вид и порода.
  if data.breed then
    model.breed = tostring(data.breed)
  else
    errors:field_missing('breed')
  end

  if data.color then
    model.color = tostring(data.color)
  else
    errors:field_missing('color')
  end

  -- Когда заведён.
  if data.created ~= nil then
    model.created = data.created
  elseif init then
    model.created = datetime.new({ timestamp = os.time() })
  end

  -- Кличка (по умолчанию - название породы из каталога).
  if data.name then
    model.name = tostring(data.name)
  elseif init then
    local variant = catalog.get(model.breed, model.color)
    model.name = variant and variant.name or 'Питомец'
  end

  -- Параметры состояния (0..100).
  if tonumber(data.health) then
    model.health = tonumber(data.health)
  elseif init then
    model.health = 100
  end

  if tonumber(data.mental_health) then
    model.mental_health = tonumber(data.mental_health)
  elseif init then
    model.mental_health = 100
  end

  if tonumber(data.energy) then
    model.energy = tonumber(data.energy)
  elseif init then
    model.energy = 100 - math.random(0, 50)
  end

  if tonumber(data.hunger) then
    model.hunger = tonumber(data.hunger)
  elseif init then
    model.hunger = math.random(0, 50)
  end

  if tonumber(data.dirty) then
    model.dirty = tonumber(data.dirty)
  elseif init then
    model.dirty = math.random(0, 100)
  end

  -- Статус существования.
  if data.status then
    model.status = tostring(data.status)
  elseif init then
    model.status = states.status.ALIVE
  end

  if errors:has_errors() then
    return nil, errors:get_compact()
  end

  return model, nil
end

return Pet
