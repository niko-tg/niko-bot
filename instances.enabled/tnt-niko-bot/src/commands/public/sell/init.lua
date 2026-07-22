--- Продажа ресурсов: всё сразу или по виду (с учётом склонений, как в старом боте).
--
local log = require('log')
local utf8 = require('utf8')
local hdec = require('bot.libs.hdec')
local config = require('conf.config')
local Command = require('bot.classes.Command')
local items = require('src.gathering.items')
local separateNumbers = require('src.utils.separateNumbers')
local usersService = require('src.services.users')
local gatheringService = require('src.services.gathering')

local command = Command:new({
  commands = { '/sell', 'продать' },
  flags = { Command.enum.PUBLIC },
})

local USAGE = ([[
💰 <b>Продажа</b>
${sep}
Продать всё: <code>продать всё</code>
По виду: <code>продать рыбу 10</code>
Кристаллы: <code>продать кристаллы 5</code>
Без количества - продаётся весь стак.
]]):f({ sep = hdec.sep })

-- Слова, означающие 'продать всё'.
local ALL_WORDS = {
  ['всё'] = true,
  ['все'] = true,
  ['all'] = true,
}

-- Слова-синонимы кристаллов (премиум-валюта, не ресурс из инвентаря).
local CRYSTAL_WORDS = {
  ['кристалл']   = true,
  ['кристаллы']  = true,
  ['кристалла']  = true,
  ['кристаллов'] = true,
  ['crystal']    = true,
  ['crystals']   = true,
}

local SOLD_ALL = '💰 Продал ресурсы на <b>${total}р</b>'
local SOLD_ITEM = '💰 Продал ${label} x${count} на <b>${total}р</b>'
local NOT_IN_INV = '🎒 ${label} - нет в инвентаре'

local SOLD_CRYSTALS = '💎 Продал ${count} 💎 на <b>${total}р</b>'
local NOT_ENOUGH_CRYSTALS = ([[
💎 У тебя нет столько кристаллов
${sep}
Есть: <b>${have}</b> 💎
]]):f({ sep = hdec.sep })

local NEED_COUNT = ([[
💎 Сколько продать?
${sep}
Например: <code>продать кристаллы 5</code>
]]):f({ sep = hdec.sep })

local NOT_FOUND = [[
🤔 Не понял что продать: ${query}
Название бери из /inv]]

--- Аргументы команды без самого слова-команды.
local function parseArgs(text)
  local tokens = {}
  for word in text:gmatch('%S+') do
    table.insert(tokens, word)
  end
  table.remove(tokens, 1)
  return tokens
end

--- Продать всё.
local function sellAll(ctx, user_id)
  local result, err = gatheringService.sellAll(user_id)
  if err then
    log.error(err)
    ctx:replyToMessage('⚠️ Не удалось продать, попробуй ещё')
    return
  end

  if result.total > 0 then
    ctx:replyToMessage(SOLD_ALL:f({ total = separateNumbers(result.total) }))
  else
    ctx:replyToMessage('🎒 Нечего продавать. Сначала добудь ресурсы!')
  end
end

--- Продать кристаллы (премиум-валюта -> баланс).
local function sellCrystals(ctx, user_id, count)
  if count == nil then
    ctx:replyToMessage(NEED_COUNT)
    return
  end

  local result, err = usersService.sellCrystals(user_id, count, config.sell.crystals)
  if err then
    log.error(err)
    ctx:replyToMessage('⚠️ Не удалось продать, попробуй ещё')
    return
  end

  if result.status == 'funds' then
    ctx:replyToMessage(NOT_ENOUGH_CRYSTALS:f({ have = separateNumbers(result.have) }))
    return
  end

  if result.status ~= 'ok' then
    ctx:replyToMessage('⚠️ Не удалось продать, попробуй ещё')
    return
  end

  ctx:replyToMessage(SOLD_CRYSTALS:f({
    count = separateNumbers(result.sold),
    total = separateNumbers(result.total),
  }))
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local user = command.user

  local tokens = parseArgs(ctx.message.text)
  if #tokens == 0 then
    ctx:replyToMessage(USAGE)
    return
  end

  if #tokens == 1 and ALL_WORDS[utf8.lower(tokens[1])] then
    sellAll(ctx, user.id)
    return
  end

  -- Последний токен - количество, если число.
  local count
  local lastNumber = tonumber(tokens[#tokens])
  if #tokens > 1 and lastNumber then
    count = math.floor(lastNumber)
    table.remove(tokens)
  end

  if count ~= nil and count < 1 then
    ctx:replyToMessage(USAGE)
    return
  end

  -- Кристаллы - не инвентарный ресурс, продаём отдельной веткой.
  if #tokens == 1 and CRYSTAL_WORDS[utf8.lower(tokens[1])] then
    sellCrystals(ctx, user.id, count)
    return
  end

  -- Остаток токенов - название ресурса (склонения учитываем).
  local id, phrase = items.resolveResource(tokens)
  if id == nil then
    ctx:replyToMessage(NOT_FOUND:f({ query = phrase }))
    return
  end

  local result, err = gatheringService.sellItem(user.id, id, count)
  if err then
    log.error(err)
    ctx:replyToMessage('⚠️ Не удалось продать, попробуй ещё')
    return
  end

  if result.sold > 0 then
    ctx:replyToMessage(SOLD_ITEM:f({
      label = items.label(id),
      count = result.sold,
      total = separateNumbers(result.total),
    }))
  else
    ctx:replyToMessage(NOT_IN_INV:f({
      label = items.label(id),
    }))
  end
end

return command
