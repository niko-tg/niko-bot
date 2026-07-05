--- Сборка URL картинок питомцев. База - config.bot.url_assets (с / на конце).
-- ?v - обход кэша CDN Telegram при обновлении ассетов.
--
local config = require('conf.config')

local BASE = config.bot.url_assets

local assets = {}

-- Витрина магазина и обложка списка питомцев.
assets.shop = BASE..'pets/shop.jpg'
assets.checklist = BASE..'pets/checklist.jpg'

--- Картинка питомца: порода/цвет/время суток/состояние.
-- @param breed (string)
-- @param color (string)
-- @param timeType (string) day/evening/night
-- @param state (string) состояние питомца (имя файла)
function assets.pet(breed, color, timeType, state)
  return ('${base}pets/${breed}/${color}/room-${timeType}/${state}.jpg?v=2'):f({
    base = BASE,
    breed = breed,
    color = color,
    timeType = timeType,
    state = state,
  })
end

--- Пустая комната (для экрана после удаления питомца).
-- @param timeType (string) day/evening/night
function assets.room(timeType)
  return ('${base}pets/backgrounds/room-${timeType}.jpg?v=1'):f({
    base = BASE,
    timeType = timeType,
  })
end

return assets
