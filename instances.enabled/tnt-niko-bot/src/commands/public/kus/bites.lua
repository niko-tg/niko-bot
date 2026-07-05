--- Данные укусов: тиры редкости (вес + сила + варианты анимаций) и выбор укуса.
-- Сила укуса (power) - сколько кусей прибавится кусающему.
--
local config = require('conf.config')

local ASSETS = config.bot.url_assets

-- Тиры от обычного к легендарному. weight - вес во взвешенном рандоме,
-- power - прибавка к счётчику. variants - описание (с эмодзи) + файл анимации.
local TIERS = {
  {
    tier = 'common',
    label = '🟢',
    weight = 70,
    power = 1,
    variants = {
      { description = 'Кусь | 🙈', media = 'kus/lite.mp4' },
      { description = 'Кусь за руку | 🫳', media = 'kus/hand.mp4' },
      { description = 'Кусюсюсь | 😸', media = 'kus/ops_kus.mp4' },
      { description = 'Я заяц КУСЬ! | 🐰', media = 'kus/cat_funny.mp4' },
    },
  },
  {
    tier = 'rare',
    label = '🔵',
    weight = 24,
    power = 2,
    variants = {
      { description = 'Лисий кусь | 🦊', media = 'kus/fox.mp4' },
      { description = 'Кусь за ногу | 🦵', media = 'kus/leg.mp4' },
      { description = 'Кусь за жЕпу! | 🍑', media = 'kus/ass.mp4' },
      { description = 'Больной кусь | 😖', media = 'kus/painful.mp4' },
    },
  },
  {
    tier = 'legendary',
    label = '🟣',
    weight = 6,
    power = 3,
    crit = true,
    variants = {
      { description = 'МЕГА КУСЬ! | 😈', media = 'kus/mega.mp4' },
      { description = 'Вампирский кусь | 🧛', media = 'kus/vampire.mp4' },
      { description = 'Кусь, офигеть можно | 😱', media = 'kus/head.mp4' },
    },
  },
}

local bites = {}

--- Случайный укус: сначала тир по весу, затем вариант внутри тира.
-- @return table { tier, label, power, crit, description, animation }
function bites.roll()
  local total = 0
  for _, tier in ipairs(TIERS) do
    total = total + tier.weight
  end

  local pick = math.random(1, total)
  local acc = 0
  local chosen = TIERS[1]

  for _, tier in ipairs(TIERS) do
    acc = acc + tier.weight
    if pick <= acc then
      chosen = tier
      break
    end
  end

  local variant = chosen.variants[math.random(#chosen.variants)]

  return {
    tier = chosen.tier,
    label = chosen.label,
    power = chosen.power,
    crit = chosen.crit == true,
    description = variant.description,
    animation = ASSETS .. variant.media,
  }
end

return bites
