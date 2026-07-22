--- Сервис питомцев и зоотоваров. Объединён в один: уход атомарно тратит товар.
-- (map в pet_supplies) и меняет параметры питомца (числа в pets) - одна транзакция.
--
local sql = require('bot.libs.sql')
local config = require('conf.config')
local Pet = require('src.models.Pet')
local catalog = require('src.pets.catalog')
local supplies = require('src.pets.supplies')
local states = require('src.pets.states')
local petLogic = require('src.pets.petLogic')
local usersService = require('src.services.users')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')

local clamp = petLogic.clamp
local state = states.state

local service = {}

--- Поверхностная копия map (для правки tuple-полей перед записью).
local function copyMap(source)
  local out = {}
  if source then
    for key, value in pairs(source) do
      out[key] = value
    end
  end
  return out
end

--- Колонка валюты по строковому типу цены.
local function currencyColumn(currency)
  return currency == 'crystals' and 'crystals' or 'balance'
end

-- ----------------------------
-- Питомцы
-- ----------------------------

--- Список питомцев владельца (в порядке появления).
-- @tparam number owner_id
-- @treturn[1] table массив Pet
-- @treturn[2] table err
function service.list(owner_id)
  local rows, err = sql(
    [[
      SELECT *
      FROM pets
      WHERE owner_id = ${owner_id}
      ORDER BY id ASC
    ]], {
      owner_id = owner_id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  local list = {}
  rows = rows or {}
  for i = 1, #rows do
    local row = rows[i]
    local pet, errs = Pet(row, { init = true })
    if errs then
      return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
    end
    table.insert(list, pet)
  end

  return list, nil
end

--- Чтение питомца по id.
-- @tparam number id
-- @treturn[1] ?table Pet
-- @treturn[2] table err
function service.read(id)
  local item, err = sql(
    [[
      SELECT * FROM pets WHERE id = ${id}
    ]], {
      id = id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local pet, errs = Pet(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return pet, nil
end

--- Кол-во питомцев владельца (для проверки лимита).
-- @tparam number owner_id
-- @treturn[1] number
-- @treturn[2] table err
function service.count(owner_id)
  local rows, err = sql(
    [[
      SELECT COUNT(*) AS "cnt" FROM pets WHERE owner_id = ${owner_id}
    ]], {
      owner_id = owner_id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if rows and rows[1] then
    return rows[1].cnt, nil
  end

  return 0, nil
end

--- Покупка питомца: проверка лимита и средств, атомарное списание + создание.
-- @tparam number owner_id
-- @tparam string breed
-- @tparam string color
-- @tparam number maxPets лимит питомцев игрока (зависит от VIP)
-- @treturn[1] table { status = 'ok'|'unavailable'|'limit'|'funds', pet?, currency?, max? }
-- @treturn[2] table err
function service.buy(owner_id, breed, color, maxPets)
  local variant = catalog.get(breed, color)
  if variant == nil then
    return { status = 'unavailable' }, nil
  end

  local count, countErr = service.count(owner_id)
  if countErr then
    return nil, countErr
  end

  if count >= maxPets then
    return { status = 'limit', max = maxPets }, nil
  end

  -- Предчек средств (для понятного ответа; реальный гейт - unsigned-колонка).
  local user, readErr = usersService.read(owner_id)
  if readErr or user == nil then
    return { status = 'unavailable' }, nil
  end

  local column = currencyColumn(variant.currency)
  local funds = (column == 'crystals') and user.crystals or user.balance
  if funds < variant.price then
    return { status = 'funds', currency = variant.currency, price = variant.price }, nil
  end

  local id = box.sequence.pets_id_seq:next()

  local pet, errs = Pet({
    id = id,
    owner_id = owner_id,
    breed = breed,
    color = color,
  }, { init = true })

  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  local _, err = sql.atomic(function()
    sql.check(sql(
      ('UPDATE users SET %s = %s - ${price} WHERE id = ${user_id}')
        :format(column, column),
      { price = variant.price, user_id = owner_id }
    ))

    sql.check(sql.create('pets', pet))
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return { status = 'ok', pet = pet }, nil
end

--- Удаление питомца (только своего).
-- @tparam number id
-- @tparam number owner_id
-- @treturn[1] boolean true
-- @treturn[2] table err
function service.delete(id, owner_id)
  local _, err = sql(
    [[
      DELETE FROM pets WHERE id = ${id} AND owner_id = ${owner_id}
    ]], {
      id = id,
      owner_id = owner_id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Смена клички питомца (только своего). Имя должно быть уже провалидировано.
-- @tparam number id
-- @tparam number owner_id
-- @tparam string name
-- @treturn[1] table { status = 'ok'|'gone'|'not_owner' }
-- @treturn[2] table err
function service.rename(id, owner_id, name)
  local pet, readErr = service.read(id)
  if readErr then
    return nil, readErr
  end

  if pet == nil then
    return { status = 'gone' }, nil
  end

  if pet.owner_id ~= owner_id then
    return { status = 'not_owner' }, nil
  end

  local _, err = sql(
    [[
      UPDATE pets SET name = ${name} WHERE id = ${id}
    ]], {
      name = name,
      id = id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return { status = 'ok', name = name }, nil
end

--- Запись новых параметров питомца (числа), в т.ч. в составе транзакции ухода.
local function writePetStats(id, fields)
  local setParts = {}
  local params = { id = id }
  for key, value in pairs(fields) do
    table.insert(setParts, key..' = ${'..key..'}')
    params[key] = value
  end

  return sql(
    ('UPDATE pets SET %s WHERE id = ${id}'):format(table.concat(setParts, ', ')),
    params
  )
end

--- Списание одного зоотовара из pet_supplies (box: поле-map).
local function consumeSupply(user_id, supplyId)
  local row = box.space.pet_supplies:get(user_id)
  local items = row and copyMap(row.items) or {}

  items[supplyId] = (items[supplyId] or 0) - 1
  if items[supplyId] <= 0 then
    items[supplyId] = nil
  end

  items = setmetatable(items, { __serialize = 'map' })
  box.space.pet_supplies:upsert({ user_id, items }, { { '=', 'items', items } })
end

--- Уход за питомцем: покормить/полечить/искупать/поиграть.
-- Возвращает статус для ответа. На 'ok' параметры уже обновлены (и товар списан).
-- @tparam number id
-- @tparam number owner_id
-- @tparam string action 'feed'|'heal'|'bathe'|'play'
-- @treturn[1] table { status = 'ok'|'gone'|'not_owner'|'sleeping'|'not_needed'
--                    |'too_tired'|'too_hungry'|'no_supply', action?, supplyId? }
-- @treturn[2] table err
function service.care(id, owner_id, action)
  local pet, readErr = service.read(id)
  if readErr then
    return nil, readErr
  end

  if pet == nil then
    return { status = 'gone' }, nil
  end

  if pet.owner_id ~= owner_id then
    return { status = 'not_owner' }, nil
  end

  local petState = petLogic.parseState(pet)
  local care = config.pets.care

  -- Игра: без товара, тратит энергию, поднимает настроение.
  if action == 'play' then
    if petState == state.SLEEPING then
      return { status = 'sleeping' }, nil
    end
    if petState == state.HUNGRY then
      return { status = 'too_hungry' }, nil
    end
    if pet.energy < 10 then
      return { status = 'too_tired' }, nil
    end

    local value = math.random(care.play.energy_min, care.play.energy_max)
    local _, err = writePetStats(id, {
      energy = clamp(pet.energy - value, 0, 100),
      mental_health = clamp(pet.mental_health + value, 0, 100),
    })

    if err then
      return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
    end

    return { status = 'ok', action = action }, nil
  end

  -- Сон блокирует любой уход.
  if petState == state.SLEEPING then
    return { status = 'sleeping' }, nil
  end

  -- Порог "не нужно", требуемый товар и новые параметры по действию.
  local supplyKind
  local fields = {}

  if action == 'feed' then
    if pet.hunger < 10 then
      return { status = 'not_needed', action = action }, nil
    end
    supplyKind = 'food'
    fields.hunger = clamp(pet.hunger + care.feed.hunger, 0, 100)
    fields.mental_health = clamp(pet.mental_health + care.feed.mental_health, 0, 100)

  elseif action == 'heal' then
    if pet.health > 90 then
      return { status = 'not_needed', action = action }, nil
    end
    supplyKind = 'medicine'
    fields.health = clamp(pet.health + care.heal.health, 0, 100)
    fields.mental_health = clamp(pet.mental_health + care.heal.mental_health, 0, 100)

  elseif action == 'bathe' then
    if pet.dirty < 10 then
      return { status = 'not_needed', action = action }, nil
    end
    supplyKind = 'shampoo'
    fields.dirty = care.bathe.dirty
    fields.mental_health = clamp(pet.mental_health + care.bathe.mental_health, 0, 100)

  else
    return { status = 'gone' }, nil
  end

  -- Нужен товар по виду питомца.
  local supplyId = supplies.id(pet.breed, supplyKind)
  if service.supplyCount(owner_id, supplyId) <= 0 then
    return { status = 'no_supply', action = action, supplyId = supplyId }, nil
  end

  -- Атомарно: списать товар (map) + записать параметры питомца (числа).
  local _, err = sql.atomic(function()
    consumeSupply(owner_id, supplyId)
    sql.check(writePetStats(id, fields))
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return { status = 'ok', action = action }, nil
end

-- ----------------------------
-- Зоотовары
-- ----------------------------

--- Карта зоотоваров игрока (id -> количество).
-- @tparam number user_id
-- @treturn[1] table (может быть пустой)
-- @treturn[2] table err
function service.supplies(user_id)
  local item, err = sql(
    [[
      SELECT * FROM pet_supplies WHERE user_id = ${user_id}
    ]], {
      user_id = user_id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil or item[1] == nil then
    return {}, nil
  end

  return item[1].items or {}, nil
end

--- Количество конкретного зоотовара у игрока.
-- @tparam number user_id
-- @tparam string supplyId
-- @treturn number
function service.supplyCount(user_id, supplyId)
  local row = box.space.pet_supplies:get(user_id)
  if row == nil or row.items == nil then
    return 0
  end

  return row.items[supplyId] or 0
end

--- Покупка зоотовара: проверка средств, атомарное списание + начисление в map.
-- @tparam number user_id
-- @tparam string supplyId
-- @treturn[1] table { status = 'ok'|'unavailable'|'funds', currency?, count? }
-- @treturn[2] table err
function service.buySupply(user_id, supplyId)
  local item = supplies.get(supplyId)
  if item == nil then
    return { status = 'unavailable' }, nil
  end

  local user, readErr = usersService.read(user_id)
  if readErr or user == nil then
    return { status = 'unavailable' }, nil
  end

  local column = currencyColumn(item.currency)
  local funds = (column == 'crystals') and user.crystals or user.balance
  if funds < item.price then
    return { status = 'funds', currency = item.currency, price = item.price }, nil
  end

  local _, err = sql.atomic(function()
    sql.check(sql(
      ('UPDATE users SET %s = %s - ${price} WHERE id = ${user_id}')
        :format(column, column),
      { price = item.price, user_id = user_id }
    ))

    local row = box.space.pet_supplies:get(user_id)
    local items = row and copyMap(row.items) or {}
    items[supplyId] = (items[supplyId] or 0) + item.count
    items = setmetatable(items, { __serialize = 'map' })

    box.space.pet_supplies:upsert({ user_id, items }, { { '=', 'items', items } })
  end)

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return { status = 'ok', count = item.count }, nil
end

return service
