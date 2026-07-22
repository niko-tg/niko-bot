--- Смена клички питомца: "кличка <id> <новое имя>" (или /petname). ID виден в
-- карточке питомца. Кличка - обычный текст (в карточке экранируется), без ссылок.
--
local log = require('log')
local utf8 = require('utf8')
local hdec = require('bot.libs.hdec')
local Command = require('bot.classes.Command')
local petsService = require('src.services.pets')

local command = Command:new({
  commands = { '/petname', 'кличка' },
  flags = { Command.enum.PUBLIC },
})

-- Максимальная длина клички, символов.
local MAX_LEN = 24

local USAGE = ([[
✏️ <b>Кличка питомца</b>
${sep}
Смена клички: <code>кличка ID новое имя</code>
Например: <code>кличка 42 Барсик</code>
ID питомца виден в его карточке (команда: <code>питомцы</code>)
]]):f({ sep = hdec.sep })

local TOO_LONG = ([[
🤷🏼‍♀️ <b>Слишком длинная кличка</b>
${sep}
Максимум ${max} символов
]]):f({ sep = hdec.sep, max = MAX_LEN })

local NO_LINKS = '🔗 Ссылки в кличке недопустимы'
local NOT_FOUND = '🤷🏼‍♀️ Питомец не найден или это не твой питомец'

local RENAMED = [[
✏️ <b>Кличка обновлена</b>
  ╰ ${name}
]]

--- Есть ли среди сущностей сообщения ссылка (url или встроенная text_link).
local function hasLink(entities)
  if not entities then
    return false
  end

  for i = 1, #entities do
    local entity = entities[i]
    if entity.type == 'url' or entity.type == 'text_link' then
      return true
    end
  end

  return false
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  -- "кличка <id> <имя...>": первый токен - команда, второй - id, остальное - имя.
  local idStr, rawName = ctx.message.text:match('^%S+%s+(%S+)%s+(.+)$')
  local id = tonumber(idStr)

  if not id or not rawName then
    ctx:replyToMessage(USAGE)
    return
  end

  -- Чистим: любые пробелы/переводы строк -> один пробел, обрезаем края.
  local name = rawName:gsub('%s+', ' '):gsub('^ +', ''):gsub(' +$', '')

  if name == '' then
    ctx:replyToMessage(USAGE)
    return
  end

  if hasLink(ctx:getEntities()) then
    ctx:replyToMessage(NO_LINKS)
    return
  end

  if utf8.len(name) > MAX_LEN then
    ctx:replyToMessage(TOO_LONG)
    return
  end

  local result, err = petsService.rename(id, command.user.id, name)
  if err then
    log.error(err)
    ctx:replyToMessage('⚠️ Не удалось сменить кличку')
    return
  end

  if result.status ~= 'ok' then
    ctx:replyToMessage(NOT_FOUND)
    return
  end

  -- Кличка - пользовательский текст, в подтверждении экранируем (как в карточке).
  ctx:replyToMessage(RENAMED:f({ name = hdec.escape(name) }))
end

return command
