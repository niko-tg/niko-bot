--- Формула урона по рейд-боссу.
--
-- dmg = rand(dmg_min, dmg_max) * (1 + уровень) * (1 + питомец) [* крит]
--
-- Уровень: +level_coef за уровень игрока, выше level_cap не растёт.
-- Питомец: лучший живой питомец даёт до pet_max_bonus при идеальном состоянии -
-- ухоженный питомец наконец полезен в бою.
--
local log = require('log')
local config = require('conf.config')
local petsService = require('src.services.pets')
local petStates = require('src.pets.states')

local damage = {}

--- Бонус лучшего живого питомца, доля 0..pet_max_bonus.
-- Состояние = среднее по health / сытость / mental_health / energy (0..1).
-- @tparam number user_id
-- @treturn number
function damage.petBonus(user_id)
  local pets, err = petsService.list(user_id)

  if err then
    log.error(err)
    return 0
  end

  local best = 0

  pets = pets or {}
  for i = 1, #pets do
    local pet = pets[i]
    if pet.status == petStates.status.ALIVE then
      local condition = (
        (pet.health or 0)
        + (100 - (pet.hunger or 100))
        + (pet.mental_health or 0)
        + (pet.energy or 0)
      ) / 4 / 100

      if condition > best then
        best = condition
      end
    end
  end

  return best * config.boss.pet_max_bonus
end

--- Урон одного удара.
-- @tparam table user модель юзера (нужен level)
-- @treturn[1] number урон
-- @treturn[2] boolean крит
function damage.roll(user)
  local cfg = config.boss

  local base = math.random(cfg.dmg_min, cfg.dmg_max)
  local levelMult = 1 + math.min(user.level or 0, cfg.level_cap) * cfg.level_coef
  local petMult = 1 + damage.petBonus(user.id)

  local isCrit = math.random(cfg.crit_odds) == 1
  local total = base * levelMult * petMult

  if isCrit then
    total = total * cfg.crit_mult
  end

  return math.max(1, math.floor(total)), isCrit
end

return damage
