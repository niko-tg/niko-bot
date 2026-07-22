--- Затухание параметров питомцев.
--
-- Раз в decay_interval обходит всех питомцев и применяет тик затухания
-- (голод/грязь растут, сон восстанавливает) - как в старом боте. Питомец без
-- ухода постепенно деградирует; параметры всегда в диапазоне 0..100.
--
-- Замечание на будущее: можно перейти на ленивое затухание (считать на чтении
-- по времени с последнего апдейта) - тогда фоновый обход не нужен.
--
local log = require('log')
local fiber = require('fiber')
local config = require('conf.config')
local petLogic = require('src.pets.petLogic')

local YIELD_EVERY = 500

--- Один проход: деградация показателей всех питомцев.
local function decayAll()
  local count = 0

  for _, tuple in box.space.pets:pairs() do
    count = count + 1

    -- Параметры из tuple в обычную таблицу, тик затухания, clamp.
    local pet = {
      energy = tuple.energy,
      health = tuple.health,
      mental_health = tuple.mental_health,
      hunger = tuple.hunger,
      dirty = tuple.dirty,
    }

    petLogic.updateParams(pet)
    petLogic.clampParams(pet)

    local ok, err = pcall(function()
      box.space.pets:update(tuple.id, {
        { '=', 'energy', pet.energy },
        { '=', 'health', pet.health },
        { '=', 'mental_health', pet.mental_health },
        { '=', 'hunger', pet.hunger },
        { '=', 'dirty', pet.dirty },
      })
    end)

    if not ok then
      log.error(err)
    end

    if count % YIELD_EVERY == 0 then
      fiber.yield()
    end
  end
end

--- Запуск фонового файбера деградации питомцев.
local function start()
  fiber.create(function()
    fiber.self():name('pets-decay')

    while true do
      local ok, runErr = pcall(decayAll)
      if not ok then
        log.error(runErr)
      end

      fiber.sleep(config.pets.decay_interval)
    end
  end)
end

return {
  start = start,
}
