--- Рендер питомцев: список, карточка с параметрами, экраны управления.
-- Экраны - { image, caption, keyboard }: сообщение всегда фото.
--
local hdec = require('bot.libs.hdec')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')
local assets = require('src.pets.assets')
local catalog = require('src.pets.catalog')
local states = require('src.pets.states')
local petLogic = require('src.pets.petLogic')
local petsService = require('src.services.pets')

local LIST = ([[
⭐️ <b>Твои питомцы</b>
${sep}
Нажми на питомца, чтобы открыть карточку
]]):f({ sep = hdec.sep })

local MISSING = ([[
😭 <b>У тебя пока нет питомцев</b>
${sep}
Завести: <code>зоомагазин</code>
]]):f({ sep = hdec.sep })

local CARD = [[
<b>ID:</b> <code>${id}</code>
<b>Порода:</b> ${breed}
<b>Вид:</b> ${type}
${sep}
<b>Кличка:</b> ${name}
<b>Возраст:</b> ${age}
${sep}
🔋 <b>Энергия:</b> ${energy}%
❤️ <b>Здоровье:</b> ${health}%
🩵 <b>Психика:</b> ${mental}%
🍽 <b>Голод:</b> ${hunger}%
🛁 <b>Пора купать:</b> ${dirty}%
${sep}
📄 <b>Состояние:</b> ${state}
]]

local DELETED = '❌ Питомец удалён'
local GONE = 'ℹ️ Этого питомца больше нет'

local render = {}

-- Callback к cb_pet.
local function petcb(action, id)
  return { command = 'cb_pet', arguments = { action = action, pet = id } }
end

-- Кнопка возврата к списку.
local function backToListRow()
  return { { text = '⬅️ К списку', callback = petcb('list', 0) } }
end

-- Клавиатуры карточки по режиму.
local function careKeyboard(id)
  return inlineCallbackKeyboard({
    {
      { text = '🥕 Покормить', callback = petcb('feed', id) },
      { text = '🩺 Лечить', callback = petcb('heal', id) },
    },
    {
      { text = '🛁 Искупать', callback = petcb('bathe', id) },
      { text = '🎾 Играть', callback = petcb('play', id) },
    },
    {
      { text = '⬅️ К списку', callback = petcb('list', 0) },
      { text = '🪄 Управление', callback = petcb('manage', id) },
    },
  })
end

local function manageKeyboard(id)
  return inlineCallbackKeyboard({
    { { text = '✏️ Переименовать', callback = petcb('rename', id) } },
    { { text = '❌ Удалить питомца', callback = petcb('del', id) } },
    { { text = '◀️ Назад', callback = petcb('show', id) } },
  })
end

local function confirmKeyboard(id)
  return inlineCallbackKeyboard({
    { { text = '❌ ПОДТВЕРДИТЬ УДАЛЕНИЕ', callback = petcb('delyes', id) } },
    { { text = '◀️ Назад', callback = petcb('show', id) } },
  })
end

--- Список питомцев игрока: кнопка на каждого. { empty = true } если их нет.
-- @param owner_id (number)
-- @return[1] { empty } | { image, caption, keyboard }
-- @return[2] err
function render.list(owner_id)
  local pets, err = petsService.list(owner_id)
  if err then
    return nil, err
  end

  if #pets == 0 then
    return { empty = true }, nil
  end

  local rows = {}
  for _, pet in ipairs(pets) do
    local variant = catalog.get(pet.breed, pet.color)
    local emoji = variant and variant.emoji or '🐾'

    table.insert(rows, {
      { text = emoji..' | '..pet.name, callback = petcb('show', pet.id) }
    })
  end

  return {
    image = assets.checklist,
    caption = LIST,
    keyboard = inlineCallbackKeyboard(rows),
  }, nil
end

--- Сообщение "нет питомцев" (текст, для команды).
function render.missing()
  return MISSING
end

--- Карточка питомца. mode: nil (уход) | 'manage' | 'confirm'.
-- @param id (number)
-- @param owner_id (number)
-- @param mode (string|nil)
-- @return[1] { gone = true } | { image, caption, keyboard }
-- @return[2] err
function render.card(id, owner_id, mode)
  local pet, err = petsService.read(id)
  if err then
    return nil, err
  end

  if not pet or pet.owner_id ~= owner_id then
    return { gone = true }, nil
  end

  local timeType = petLogic.timeType()
  local petState = petLogic.parseState(pet)
  local variant = catalog.get(pet.breed, pet.color)

  local caption = CARD:f({
    sep = hdec.sep,
    id = pet.id,
    breed = variant and variant.name or pet.breed,
    type = catalog.types[pet.breed] and catalog.types[pet.breed].label or pet.breed,
    name = hdec.escape(pet.name),
    age = petLogic.parseAge(pet.created.timestamp),
    energy = pet.energy,
    health = pet.health,
    mental = pet.mental_health,
    hunger = pet.hunger,
    dirty = pet.dirty,
    state = states.info[petState] or petState,
  })

  local keyboard
  if mode == 'manage' then
    keyboard = manageKeyboard(id)
  elseif mode == 'confirm' then
    keyboard = confirmKeyboard(id)
  else
    keyboard = careKeyboard(id)
  end

  return {
    image = assets.pet(pet.breed, pet.color, timeType, petState),
    caption = caption,
    keyboard = keyboard,
  }, nil
end

--- Экран после удаления (пустая комната).
function render.deleted()
  local timeType = petLogic.timeType()

  return {
    image = assets.room(timeType),
    caption = DELETED,
    keyboard = inlineCallbackKeyboard({ backToListRow() }),
  }
end

--- Экран "питомца больше нет".
function render.gone()
  local timeType = petLogic.timeType()

  return {
    image = assets.room(timeType),
    caption = GONE,
    keyboard = inlineCallbackKeyboard({ backToListRow() }),
  }
end

--- Экран пустого списка (для callback "к списку", когда питомцев не осталось).
function render.emptyList()
  return {
    image = assets.checklist,
    caption = MISSING,
    keyboard = nil,
  }
end

-- Тексты ответа на уход: status -> сообщение (попап).
local CARE_TEXT = {
  ok = {
    feed  = '🍽 Питомец покушал',
    heal  = '🌡 Питомца подлечили',
    bathe = '🧴 Питомец снова чистый!',
    play  = '🎾 Поиграли! Энергия потрачена',
  },
  not_needed = {
    feed  = '🥕 Питомец не голоден',
    heal  = '❤️ Питомец и так здоров',
    bathe = '🧼 Питомец уже чистый',
  },
  no_supply = {
    food     = '⚠️ Нет корма для этого вида. Купи: зоомагазин',
    medicine = '⚠️ Нет лекарств для этого вида. Купи: зоомагазин',
    shampoo  = '⚠️ Нет шампуня для этого вида. Купи: зоомагазин',
  },
}

local SUPPLY_OF_ACTION = { feed = 'food', heal = 'medicine', bathe = 'shampoo' }

--- Текст попапа по результату ухода.
-- @param result (table) из petsService.care
function render.careMessage(result)
  local status = result.status

  if status == 'ok' then
    return CARE_TEXT.ok[result.action] or '✅ Готово'
  elseif status == 'not_needed' then
    return CARE_TEXT.not_needed[result.action] or 'ℹ️ Не требуется'
  elseif status == 'no_supply' then
    return CARE_TEXT.no_supply[SUPPLY_OF_ACTION[result.action]] or '⚠️ Нет нужного зоотовара'
  elseif status == 'sleeping' then
    return '😴 Спит, пусть отдыхает'
  elseif status == 'too_tired' then
    return '🪫 Устал и не хочет играть'
  elseif status == 'too_hungry' then
    return '👀 Слишком голодный для игры'
  elseif status == 'gone' then
    return GONE
  elseif status == 'not_owner' then
    return 'Это не твой питомец :)'
  end

  return '⛔️ Что-то пошло не так'
end

return render
