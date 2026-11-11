--- Пути картинок питомцев относительно assets/ (отправка - через src.media).
-- При замене файла кэш file_id сбрасывается сам (по размеру и mtime).
--
local assets = {}

-- Витрина магазина и обложка списка питомцев.
assets.shop = 'pets/shop.jpg'
assets.checklist = 'pets/checklist.jpg'

--- Картинка питомца: порода/цвет/время суток/состояние.
-- @tparam string breed
-- @tparam string color
-- @tparam string timeType day/evening/night
-- @tparam string state состояние питомца (имя файла)
function assets.pet(breed, color, timeType, state)
  return ('pets/${breed}/${color}/room-${timeType}/${state}.jpg'):f({
    breed = breed,
    color = color,
    timeType = timeType,
    state = state,
  })
end

--- Пустая комната (для экрана после удаления питомца).
-- @tparam string timeType day/evening/night
function assets.room(timeType)
  return ('pets/backgrounds/room-${timeType}.jpg'):f({
    timeType = timeType,
  })
end

return assets
