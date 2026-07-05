--- Установка статуса в профиле: /status [текст] (или "статус [текст]").
-- Статус - обычный текст (в профиле он экранируется), ссылки запрещены.
--
local log = require('log')
local utf8 = require('utf8')
local hdec = require('bot.libs.hdec')
local Command = require('bot.classes.Command')
local usersService = require('src.services.users')

local command = Command:new {
  commands = { '/status', 'статус' },
  flags = { Command.enum.PUBLIC },
}

-- Максимальная длина статуса, символов
local MAX_LEN = 75

local USAGE = ([[
🔆 <b>Статус</b>
${sep}
Задай статус для профиля: <code>статус Я люблю котиков :3</code>
До ${max} символов, без ссылок
]]):f({ sep = hdec.sep, max = MAX_LEN })

local STATUS_SET = [[
🔆 <b>Статус обновлён</b>
  ╰ ${status}
]]

local NO_LINKS = '🔗 Ссылки в статусе недопустимы'

local TOO_LONG = ([[
🤷🏼‍♀️ <b>Слишком длинный статус</b>
${sep}
Максимум ${max} символов
]]):f({ sep = hdec.sep, max = MAX_LEN })

-- Есть ли среди сущностей сообщения ссылка (url или встроенная text_link).
local function hasLink(entities)
  if not entities then
    return false
  end

  for _, entity in ipairs(entities) do
    if entity.type == 'url' or entity.type == 'text_link' then
      return true
    end
  end

  return false
end

function command.call(ctx)
  -- Всё после команды одним куском (статус может быть из нескольких слов).
  local raw = ctx.message.text:match('^%S+%s+(.+)$')

  -- Чистим: любые пробелы/переводы строк -> один пробел, обрезаем края.
  local status = raw and raw:gsub('%s+', ' '):gsub('^ +', ''):gsub(' +$', '') or ''

  if status == '' then
    ctx:replyToMessage(USAGE)
    return
  end

  if hasLink(ctx:getEntities()) then
    ctx:replyToMessage(NO_LINKS)
    return
  end

  if utf8.len(status) > MAX_LEN then
    ctx:replyToMessage(TOO_LONG)
    return
  end

  local _, err = usersService.upsert({
    id = command.user.id,
    status = status,
  })

  if err then
    log.error(err)
    ctx:replyToMessage('⚠️ Не удалось сохранить статус')
    return
  end

  -- Статус - пользовательский текст, в подтверждении экранируем (как в профиле).
  ctx:replyToMessage(STATUS_SET:f({
    status = hdec.escape(status),
  }))
end

return command
