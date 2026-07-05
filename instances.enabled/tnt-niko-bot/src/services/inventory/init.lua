--- Сервис инвентаря: хранение ресурсов (items) и инструментов (tools).
--
-- Чистый CRUD над двумя map. Денежные потоки (продажа/покупка/крафт) живут в
-- сервисе gathering, чтобы инвентарь не знал про баланс и был атомарным там.
--
local sql = require('bot.libs.sql')
local Inventory = require('src.models.Inventory')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')

local service = {}

--- Чтение инвентаря игрока.
-- @param user_id (number)
-- @return[1] model inventory | nil
-- @return[2] err
function service.read(user_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        user_inventory
      WHERE
        user_id = ${user_id}
    ]], {
      user_id = user_id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local inv, errs = Inventory(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return inv, nil
end

--- Вставка/обновление (меняет только переданные поля).
-- @param data (table) { user_id, items?, tools? }
-- @return[1] model inventory
-- @return[2] err
function service.upsert(data)
  local defaultInv, errs = Inventory(data, { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  local updateFields = {}
  for key in pairs(data) do
    updateFields[key] = defaultInv[key]
  end

  local _, err = sql.upsert('user_inventory', defaultInv, updateFields)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return service.read(defaultInv.user_id)
end

--- Начисление ресурсов в инвентарь.
-- @param user_id (number)
-- @param additions (array) [ { id, count }, ... ] (id могут повторяться)
-- @return[1] model inventory
-- @return[2] err
function service.addItems(user_id, additions)
  local existing, err = service.read(user_id)
  if err then
    return nil, err
  end

  local items = (existing and existing.items) or {}

  for _, add in ipairs(additions) do
    items[add.id] = (items[add.id] or 0) + add.count
  end

  return service.upsert({ user_id = user_id, items = items })
end

--- Установка инструмента (покупка/замена/починка): tools[toolId] = durability.
-- @param user_id (number)
-- @param toolId (string)
-- @param durability (number)
-- @return[1] model inventory
-- @return[2] err
function service.setTool(user_id, toolId, durability)
  local existing, err = service.read(user_id)
  if err then
    return nil, err
  end

  local tools = (existing and existing.tools) or {}
  tools[toolId] = durability

  return service.upsert({ user_id = user_id, tools = tools })
end

--- Износ инструмента на amount. Прочность <= 0 -> инструмент исчезает.
-- @param user_id (number)
-- @param toolId (string)
-- @param amount (number)
-- @return[1] number остаток прочности (0 = сломался)
-- @return[2] err
function service.useTool(user_id, toolId, amount)
  local existing, err = service.read(user_id)
  if err then
    return nil, err
  end

  local tools = (existing and existing.tools) or {}
  local left = (tools[toolId] or 0) - amount

  if left <= 0 then
    left = 0
    tools[toolId] = nil
  else
    tools[toolId] = left
  end

  local _, upErr = service.upsert({ user_id = user_id, tools = tools })
  if upErr then
    return nil, upErr
  end

  return left, nil
end

return service
