--- Рендер инвентаря: ресурсы, снаряжение, кнопки продажи.
--
local hdec = require('bot.libs.hdec')
local config = require('conf.config')
local items = require('src.gathering.items')
local separateNumbers = require('src.utils.separateNumbers')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local render = {}

local EMPTY_TEXT = [[
🎒 <b>Инвентарь</b>
${sep}
Пусто. Сходи на рыбалку, в рудник или на лесопилку!
]]

local HEADER = '🎒 <b>Инвентарь</b>\n' .. hdec.sep

local RES_LINE = '  ╰ ${label}: <b>${count}</b> | ${sum}р'
local TOOL_LINE = '  ╰ ${label}: прочность <b>${left}</b>'
local CONS_LINE = '  ╰ ${label}: <b>${count}</b>'

local FOOTER = [[
${sep}
🎒 Занято: <b>${used}</b> / ${cap}
💰 К продаже: <b>${total}</b>р
⬇️ Продать по виду: <code>/sell рыбу 10</code>]]

--- Строки ресурсов + суммарная стоимость продажи + занятое место (число ресурсов).
local function resourceBlock(itemsMap)
  local lines = {}
  local total = 0
  local weight = 0

  for _, id in ipairs(items.resourceOrder) do
    local count = itemsMap[id]

    if count and count > 0 then
      local sum = items.sell(id) * count
      total = total + sum
      weight = weight + count

      table.insert(lines, RES_LINE:f({
        label = items.label(id),
        count = count,
        sum = separateNumbers(sum)
      }))
    end
  end

  return lines, total, weight
end

--- Строки снаряжения: инструменты (с прочностью) + расходники.
local function gearBlock(itemsMap, toolsMap)
  local lines = {}

  for _, id in ipairs(items.toolOrder) do
    local left = toolsMap[id]
    if left then
      table.insert(lines, TOOL_LINE:f({
        label = items.label(id),
        left = left
      }))
    end
  end

  for _, id in ipairs(items.consumableOrder) do
    local count = itemsMap[id]
    if count and count > 0 then
      table.insert(lines, CONS_LINE:f({
        label = items.label(id),
        count = count
      }))
    end
  end

  return lines
end

--- Клавиатура: «продать всё» и «обновить». По одному ресурсу - через /sell.
local function buildKeyboard(hasSellable)
  if not hasSellable then
    return nil
  end

  return inlineCallbackKeyboard({
    {
      {
        text = '💰 Продать всё',
        callback = {
          command = 'cb_inv',
          arguments = {
            action = 'sellall',
            item = '0'
          }
        },
      },
    },
  })
end

--- Экран инвентаря.
-- @param inv (table|nil) модель инвентаря
-- @return table { text, keyboard }
function render.inventory(inv)
  local itemsMap = (inv and inv.items) or {}
  local toolsMap = (inv and inv.tools) or {}

  local resLines, total, weight = resourceBlock(itemsMap)
  local gearLines = gearBlock(itemsMap, toolsMap)

  if #resLines == 0 and #gearLines == 0 then
    return {
      text = EMPTY_TEXT:f({
        sep = hdec.sep
      }),
      keyboard = nil
    }
  end

  local parts = { HEADER }

  if #resLines > 0 then
    table.insert(parts, '<b>Ресурсы</b>\n' .. table.concat(resLines, '\n'))
  end

  if #gearLines > 0 then
    table.insert(parts, '<b>Снаряжение</b>\n' .. table.concat(gearLines, '\n'))
  end

  if total > 0 then
    table.insert(parts, FOOTER:f({
      sep = hdec.sep,
      used = weight,
      cap = config.gathering.capacity,
      total = separateNumbers(total),
    }))
  end

  return {
    text = table.concat(parts, '\n'),
    keyboard = buildKeyboard(total > 0),
  }
end

return render
