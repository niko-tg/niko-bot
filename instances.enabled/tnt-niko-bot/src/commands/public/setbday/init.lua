--- Установка дня рождения: /setbday 15.03.1990 (или "др 15.03.1990").
--
local log = require('log')
local hdec = require('bot.libs.hdec')
local datetime = require('datetime')
local Command = require('bot.classes.Command')
local usersService = require('src.services.users')

local command = Command:new {
  commands = { '/setbday', 'др' },
  flags = { Command.enum.PUBLIC },
}

local USAGE = ([[
🎂 <b>День рождения</b>
${sep}
Укажи дату: <code>др 25.05.2005</code>
Формат: ДД.ММ.ГГГГ
]]):f({ sep = hdec.sep })

local BDAY_SET = [[
🎂 <b>День рождения установлен</b>
  ╰ <code>${birthday}</code>
]]

local INVALID_DATE = ([[
🤷🏼‍♀️ <b>Не похоже на дату</b>
${sep}
Формат: <code>ДД.ММ.ГГГГ</code> (напр. 25.05.2005)
]]):f({ sep = hdec.sep })

-- Парсит "ДД.ММ.ГГГГ" (разделитель . - /) в datetime или nil.
local function parseBirthday(str)
  local d, m, y = str:match('^(%d%d?)[%.%-/](%d%d?)[%.%-/](%d%d%d%d)$')
  if not d then
    return nil
  end

  d, m, y = tonumber(d), tonumber(m), tonumber(y)

  local nowYear = tonumber(os.date('%Y'))
  if y < 1900 or y > nowYear or m < 1 or m > 12 or d < 1 or d > 31 then
    return nil
  end

  local ok, dt = pcall(datetime.new, { year = y, month = m, day = d })
  if not ok or not dt then
    return nil
  end

  -- Нормализация (напр. 31.02) -> дата нереальна.
  if dt.day ~= d or dt.month ~= m or dt.year ~= y then
    return nil
  end

  -- Не в будущем.
  if dt.timestamp > os.time() then
    return nil
  end

  return dt
end

function command.call(ctx)
  local arg = ctx.message.text:match('^%S+%s+(%S+)')
  if not arg then
    ctx:replyToMessage(USAGE)
    return
  end

  local birthday = parseBirthday(arg)
  if not birthday then
    ctx:replyToMessage(INVALID_DATE)
    return
  end

  local _, err = usersService.upsert({
    id = command.user.id,
    birthday_date = birthday
  })

  if err then
    log.error(err)
    ctx:replyToMessage('⚠️ Не удалось сохранить дату')
    return
  end

  ctx:replyToMessage(BDAY_SET:f({
    birthday = os.date('%d.%m.%Y', birthday.timestamp)
  }))
end

return command
