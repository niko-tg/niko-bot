--- Рендер фермы: грядки с готовностью, посадка, магазин семян.
--
local hdec = require('bot.libs.hdec')
local items = require('src.gathering.items')
local crops = require('src.farm.crops')
local animals = require('src.farm.animals')
local separateNumbers = require('src.utils.separateNumbers')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local render = {}

local FARM_TEXT = [[
🌾 <b>Ферма</b> (уровень ${level})
${sep}
${lines}
${sep}
Свободно грядок: <b>${free}</b>]]

local SLOT_EMPTY = '⬜ Грядка ${n}: пусто'
local SLOT_GROWING = '🌱 Грядка ${n}: ${crop} (${left})'
local SLOT_READY = '✅ Грядка ${n}: ${crop} - готово!'

local PLANT_TEXT = [[
🌱 <b>Посадить культуру</b>
${sep}
Выбери, что посадить (нужны семена)]]

local SEED_TEXT = [[
🛒 <b>Семена</b>
${sep}
💵 Баланс: <b>${balance}</b>р
${sep}
Выбери семена для покупки]]

local ZOO_TEXT = [[
🐄 <b>Загон</b>
${sep}
${lines}]]

local ANIMAL_SHOP_TEXT = [[
🐄 <b>Купить животное</b>
${sep}
💵 Баланс: <b>${balance}</b>р
${sep}
Каждое животное даёт продукт по таймеру]]

--- Остаток до готовности как M:SS.
local function remaining(readyAt)
  local sec = readyAt - os.time()
  if sec < 0 then
    sec = 0
  end
  return ('%d:%02d'):format(math.floor(sec / 60), sec % 60)
end

--- Подпись культуры "эмодзи Имя".
local function cropLabel(cropId)
  local crop = crops.get(cropId)
  if crop == nil then
    return cropId
  end
  return crop.emoji .. ' ' .. crop.name
end

--- Главный экран фермы.
-- @param state (table) из farmService.state
function render.menu(state)
  local lines = {}
  local rows = {}

  for _, slot in ipairs(state.slots) do
    if slot.empty then
      table.insert(lines, SLOT_EMPTY:f({ n = slot.index }))
    elseif slot.ready then
      table.insert(lines, SLOT_READY:f({ n = slot.index, crop = cropLabel(slot.crop) }))
      table.insert(rows, {
        {
          text = ('✅ Собрать грядку %d'):format(slot.index),
          callback = {
            command = 'cb_farm',
            arguments = {
              action = 'collect',
              target = tostring(slot.index)
            }
          },
        },
      })
    else
      table.insert(lines, SLOT_GROWING:f({
        n = slot.index,
        crop = cropLabel(slot.crop),
        left = remaining(slot.ready_at)
      }))
    end
  end

  local actionRow = {}
  if state.free > 0 then
    table.insert(actionRow, {
      text = '🌱 Посадить',
      callback = {
        command = 'cb_farm',
        arguments = {
          action = 'plant_menu',
          target = '0'
        }
      },
    })
  end
  table.insert(actionRow, {
    text = '🛒 Семена',
    callback = {
      command = 'cb_farm',
      arguments = {
        action = 'shop',
        target = '0'
      }
    },
  })
  table.insert(actionRow, {
    text = '🐄 Загон',
    callback = {
      command = 'cb_farm',
      arguments = {
        action = 'zoo',
        target = '0'
      }
    },
  })
  table.insert(rows, actionRow)

  table.insert(rows, {
    {
      text = '🔄 Обновить',
      callback = {
        command = 'cb_farm',
        arguments = {
          action = 'refresh',
          target = '0'
        }
      },
    },
  })

  return {
    text = FARM_TEXT:f({
      sep = hdec.sep,
      lines = table.concat(lines, '\n'),
      free = state.free,
      level = state.level,
    }),
    keyboard = inlineCallbackKeyboard(rows),
  }
end

--- Меню выбора культуры для посадки (в первый свободный слот).
function render.plantMenu(level)
  local rows = {}

  for _, key in ipairs(crops.order) do
    local crop = crops[key]
    if level >= (crop.min_level or 1) then
      table.insert(rows, {
        {
          text = crop.emoji .. ' ' .. crop.name,
          callback = {
            command = 'cb_farm',
            arguments = {
              action = 'plant',
              target = crop.id
            }
          },
        },
      })
    else
      table.insert(rows, {
        {
          text = ('🔒 %s (ур. %d)'):format(crop.name, crop.min_level),
          callback = {
            command = 'cb_farm',
            arguments = {
              action = 'locked',
              target = crop.id
            }
          },
        },
      })
    end
  end

  table.insert(rows, {
    {
      text = '◀️ Назад',
      callback = {
        command = 'cb_farm',
        arguments = {
          action = 'refresh',
          target = '0'
        }
      },
    },
  })

  return {
    text = PLANT_TEXT:f({ sep = hdec.sep }),
    keyboard = inlineCallbackKeyboard(rows),
  }
end

--- Магазин семян: кнопки-семена с ценой, покупка по клику.
-- @param user (table) для показа баланса
function render.seedShop(user, level)
  local rows = {}

  for _, key in ipairs(crops.order) do
    local crop = crops[key]
    local seed = items.get(crop.seed)
    if level >= (crop.min_level or 1) then
      table.insert(rows, {
        {
          text = ('%s %s - %sр'):format(seed.emoji, seed.name, separateNumbers(seed.buy)),
          callback = {
            command = 'cb_farm',
            arguments = {
              action = 'buy',
              target = crop.seed
            }
          },
        },
      })
    else
      table.insert(rows, {
        {
          text = ('🔒 %s (ур. %d)'):format(seed.name, crop.min_level),
          callback = {
            command = 'cb_farm',
            arguments = {
              action = 'locked',
              target = crop.id
            }
          },
        },
      })
    end
  end

  table.insert(rows, {
    {
      text = '◀️ Назад',
      callback = {
        command = 'cb_farm',
        arguments = {
          action = 'refresh',
          target = '0'
        }
      },
    },
  })

  return {
    text = SEED_TEXT:f({
      sep = hdec.sep,
      balance = separateNumbers(user.balance),
    }),
    keyboard = inlineCallbackKeyboard(rows),
  }
end

--- Подэкран загона: купленные животные с готовностью продукта.
-- @param state (table) из farmService.animalState
function render.zoo(state)
  local lines = {}
  local rows = {}

  for _, entry in ipairs(state.list) do
    if entry.owned then
      local def = entry.def
      local product = items.label(def.product)
      if entry.ready then
        table.insert(lines, ('%s %s: %s - готово!'):format(def.emoji, def.name, product))
        table.insert(rows, {
          {
            text = ('✅ Собрать: %s'):format(def.name),
            callback = {
              command = 'cb_farm',
              arguments = {
                action = 'collect_animal',
                target = def.id
              }
            },
          },
        })
      else
        table.insert(lines, ('%s %s: %s через %s'):format(def.emoji, def.name, product, remaining(entry.ready_at)))
      end
    end
  end

  if #lines == 0 then
    lines = { 'Загон пуст. Купи первое животное.' }
  end

  table.insert(rows, {
    {
      text = '🛒 Купить животное',
      callback = {
        command = 'cb_farm',
        arguments = {
          action = 'animal_shop',
          target = '0'
        }
      },
    },
  })
  table.insert(rows, {
    {
      text = '◀️ Назад',
      callback = {
        command = 'cb_farm',
        arguments = {
          action = 'refresh',
          target = '0'
        }
      },
    },
  })

  return {
    text = ZOO_TEXT:f({ sep = hdec.sep, lines = table.concat(lines, '\n') }),
    keyboard = inlineCallbackKeyboard(rows),
  }
end

--- Магазин животных: доступные по уровню фермы, покупка по клику.
-- @param user (table) для показа баланса
-- @param level (number) уровень фермы (гейт)
function render.animalShop(user, level)
  local rows = {}

  for _, key in ipairs(animals.order) do
    local def = animals[key]
    if level >= (def.min_level or 1) then
      table.insert(rows, {
        {
          text = ('%s %s - %sр'):format(def.emoji, def.name, separateNumbers(def.buy)),
          callback = {
            command = 'cb_farm',
            arguments = {
              action = 'buy_animal',
              target = def.id
            }
          },
        },
      })
    else
      table.insert(rows, {
        {
          text = ('🔒 %s (ур. %d)'):format(def.name, def.min_level),
          callback = {
            command = 'cb_farm',
            arguments = {
              action = 'locked',
              target = def.id
            }
          },
        },
      })
    end
  end

  table.insert(rows, {
    {
      text = '◀️ Назад',
      callback = {
        command = 'cb_farm',
        arguments = {
          action = 'zoo',
          target = '0'
        }
      },
    },
  })

  return {
    text = ANIMAL_SHOP_TEXT:f({ sep = hdec.sep, balance = separateNumbers(user.balance) }),
    keyboard = inlineCallbackKeyboard(rows),
  }
end

return render
