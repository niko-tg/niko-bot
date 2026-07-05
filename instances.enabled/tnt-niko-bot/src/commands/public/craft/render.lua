--- Рендер крафта: список рецептов с пометкой доступности + кнопки.
--
local hdec = require('bot.libs.hdec')
local items = require('src.gathering.items')
local recipes = require('src.gathering.recipes')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local render = {}

--- Хватает ли входов рецепта.
local function canCraft(itemsMap, recipe)
  for _, input in ipairs(recipe.inputs) do
    if (itemsMap[input.id] or 0) < input.count then
      return false
    end
  end
  return true
end

local INPUT_FRAG = '${label} x${count}'
local RECIPE_LINE = '  ╰ ${output} x${count} = ${inputs} ${mark}'

local CRAFT_TEXT = [[
🛠 <b>Крафт</b>
${sep}
Переработка сырья в дорогие предметы.
${lines}]]

--- Экран крафта.
-- @param inv (table|nil) инвентарь игрока
-- @return table { text, keyboard }
function render.list(inv)
  local itemsMap = (inv and inv.items) or {}

  local lines = {}
  local rows = {}

  for _, recipe in ipairs(recipes) do
    local inputs = {}
    for _, input in ipairs(recipe.inputs) do
      table.insert(inputs, INPUT_FRAG:f({
        label = items.label(input.id),
        count = input.count
      }))
    end

    local mark = canCraft(itemsMap, recipe) and '✅' or '❌'
    table.insert(lines, RECIPE_LINE:f({
      output = items.label(recipe.output.id),
      count = recipe.output.count,
      inputs = table.concat(inputs, ' + '),
      mark = mark,
    }))

    table.insert(rows, {
      {
        text = 'Сделать ' .. items.label(recipe.output.id),
        callback = {
          command = 'cb_craft',
          arguments = {
            action = 'craft',
            recipe = recipe.id
          }
        },
      },
    })
  end

  table.insert(rows, {
    {
      text = '🔄 Обновить',
      callback = {
        command = 'cb_craft',
        arguments = {
          action = 'refresh',
          recipe = '0'
        }
      },
    },
  })

  local text = CRAFT_TEXT:f({
    sep = hdec.sep,
    lines = table.concat(lines, '\n')
  })

  return {
    text = text,
    keyboard = inlineCallbackKeyboard(rows),
  }
end

return render
