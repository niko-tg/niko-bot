--- Логика питомцев: время суток, возраст, состояние, затухание параметров.
-- Параметры (energy/health/mental_health/hunger/dirty) - числа 0..100.
--
local states = require('src.pets.states')

local state = states.state

--- Ограничение значения диапазоном.
-- @tparam number value значение
-- @tparam number low нижняя граница
-- @tparam number high верхняя граница
-- @treturn number
local function clamp(value, low, high)
  if value < low then
    return low
  elseif value > high then
    return high
  end

  return value
end

--- Русское склонение: 1 X / 2 Y / 5 Z.
local function plural(n, one, few, many)
  local mod10 = n % 10
  local mod100 = n % 100

  if mod10 == 1 and mod100 ~= 11 then
    return one
  elseif mod10 >= 2 and mod10 <= 4 and (mod100 < 12 or mod100 > 14) then
    return few
  end

  return many
end

local petLogic = {}

local dayPart = {
  DAY = 'day',
  EVENING = 'evening',
  NIGHT = 'night',
}

--- Время суток для выбора картинки и поведения: day/evening/night.
function petLogic.timeType()
  local hour = tonumber(os.date('%H', os.time()))

  if hour > 6 and hour <= 17 then
    return dayPart.DAY
  elseif hour >= 18 and hour < 22 then
    return dayPart.EVENING
  end

  return dayPart.NIGHT
end

--- Возраст питомца строкой: "X лет, Y дней" или "Y дней".
-- @tparam number createdTs unix-секунды рождения
function petLogic.parseAge(createdTs)
  local timeSec = os.time() - createdTs

  if timeSec <= 0 then
    return '0 дней'
  end

  local secondsInDay = 86400
  local secondsInYear = secondsInDay * 365

  local years = math.floor(timeSec / secondsInYear)
  local days = math.floor((timeSec % secondsInYear) / secondsInDay)

  local daysText = plural(days, 'день', 'дня', 'дней')

  if years == 0 then
    return days..' '..daysText
  end

  return years..' '..plural(years, 'год', 'года', 'лет')..', '..days..' '..daysText
end

--- Состояние питомца из его параметров и времени суток.
-- Порядок проверок - от высшего приоритета к низшему (сон/болезнь/голод/грязь/настроение).
function petLogic.parseState(pet)
  local timeState = petLogic.timeType()

  -- Ночь: питомец спит, если не полон энергии.
  if timeState == dayPart.NIGHT then
    if pet.energy < 100 then
      return state.SLEEPING
    end
  end

  -- День/вечер: глубокий сон при низкой энергии, иначе сонный.
  if timeState == dayPart.DAY or timeState == dayPart.EVENING then
    if pet.energy < 10 then
      return state.SLEEPING
    elseif pet.energy < 30 then
      return state.SLEEPY
    end
  end

  -- Физиология (высокий приоритет).
  if pet.health < 30 then
    return state.SICK
  end

  if pet.hunger > 70 then
    return state.HUNGRY
  end

  if pet.dirty > 30 then
    return state.DIRTY
  end

  -- Психология и здоровье (средний приоритет).
  if pet.mental_health < 30 then
    return state.BORED
  end

  if pet.health < 60 then
    return state.SICK
  end

  if pet.hunger > 50 then
    return state.HUNGRY
  end

  if pet.dirty > 50 then
    return state.DIRTY
  end

  if pet.mental_health < 50 then
    return state.BORED
  end

  -- Позитивные состояния (низкий приоритет).
  if timeState ~= dayPart.NIGHT then
    if pet.energy > 60 and pet.mental_health > 70 then
      return state.PLAYING
    end
  end

  if pet.energy > 80
    and pet.mental_health > 80
    and pet.health > 80
    and pet.hunger < 30
    and (pet.dirty > 0 and pet.dirty < 70)
  then
    return state.JOYFUL
  end

  return state.NEUTRAL
end

--- Затухание параметров за один тик (фоновая задача).
-- Мутирует pet на месте.
-- Ночью/во сне восстанавливает, днём растит голод/грязь и штрафует при запущенности.
function petLogic.updateParams(pet)
  local timeState = petLogic.timeType()
  local petState = petLogic.parseState(pet)

  -- Ночь: сон восстанавливает.
  if timeState == dayPart.NIGHT then
    if petState == state.SLEEPING then
      pet.energy = pet.energy + 4
      pet.health = pet.health + 1
      pet.mental_health = pet.mental_health + 1
    end

    return pet
  end

  -- Дневной/вечерний сон: восстановление слабее.
  if timeState == dayPart.DAY or timeState == dayPart.EVENING then
    if petState == state.SLEEPING then
      pet.energy = pet.energy + 2
      pet.health = pet.health + 1
      pet.mental_health = pet.mental_health + 1

      return pet
    end
  end

  -- Бодрствование: растёт голод, падает чистота.
  pet.hunger = pet.hunger + math.random(1, 3)
  pet.dirty = pet.dirty + 1

  -- Сильный голод бьёт по психике, очень сильный - по энергии и здоровью.
  if pet.hunger > 95 then
    pet.mental_health = pet.mental_health - 1
    pet.energy = pet.energy - 2
    pet.health = pet.health - 1
  elseif pet.hunger > 80 then
    pet.mental_health = pet.mental_health - 1
  end

  -- Запущенность (грязь + голод + плохая психика) бьёт по здоровью и энергии.
  if pet.mental_health < 50 and pet.dirty > 70 and pet.hunger > 50 then
    pet.health = pet.health - 1
    pet.energy = pet.energy - 1
  end

  return pet
end

--- Привести все параметры в диапазон 0..100. Мутирует pet на месте.
function petLogic.clampParams(pet)
  pet.energy = clamp(pet.energy, 0, 100)
  pet.health = clamp(pet.health, 0, 100)
  pet.mental_health = clamp(pet.mental_health, 0, 100)
  pet.hunger = clamp(pet.hunger, 0, 100)
  pet.dirty = clamp(pet.dirty, 0, 100)

  return pet
end

petLogic.clamp = clamp

return petLogic
