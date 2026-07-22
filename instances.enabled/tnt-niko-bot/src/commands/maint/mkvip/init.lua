--- Выдача / продление VIP подписки.
--
-- /mkvip user_id=123 date=2m
-- /mkvip username=@oxniko date=1w
--
-- Если запись уже есть и подписка ещё не истекла - продлеваем от
-- текущего until_date. Иначе отсчёт от os.time().
--
-- Суффиксы date через parseUnit('date'): d / w / m / y
--
local log = require('log')
local Command = require('bot.classes.Command')
local hdec = require('bot.libs.hdec')
local parseUnit = require('src.utils.parseUnit')
local resolveTargetUser = require('src.utils.resolveTargetUser')
local vipUsersService = require('src.services.vip_users')
local notifyVipActivated = require('src.notifications.vipActivated')

local command = Command:new({
  commands = { '/mkvip' },
  flags = { Command.enum.MAINTENANCE },
})

local USAGE = ([[
ℹ️ <b>Использование</b>
${sep}
<code>/mkvip user_id=123 date=2m</code>
<code>/mkvip username=@oxniko date=1w</code>

Суффиксы date: d (день), w (неделя), m (30 дней), y (год)
]]):f({ sep = hdec.sep })

local TEMPLATE = [[
✅ <b>VIP активен</b>
${sep}
👤 ${mention}
🆔 <code>${userId}</code>
⏳ До: <code>${untilDate}</code>
]]

--- Разбор аргументов вида key=value из текста команды.
-- @tparam string text текст сообщения
-- @treturn table пары ключ-значение
local function parseArgs(text)
  local args = {}

  for key, value in text:gmatch('([%w_]+)=(%S+)') do
    args[key] = value
  end

  return args
end

--- Условие поиска пользователя по разобранным аргументам.
-- @tparam table args пары ключ-значение
-- @treturn table { user_id, username }
local function buildQuery(args)
  return {
    user_id = args.user_id and tonumber(args.user_id) or nil,
    username = args.username and args.username:gsub('^@', ''):lower() or nil,
  }
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local args = parseArgs(ctx.message.text)

  -- Должен быть указан таргет и срок
  if (not args.user_id and not args.username) or not args.date then
    ctx:replyToMessage(USAGE)
    return
  end

  -- Требуем явный суффикс единицы, иначе parseUnit вернёт 'голое' число секунд
  if not args.date:match('^%d+[dwmyDWMY]$') then
    ctx:replyToMessage('🤷🏼‍♀️ Формат date: число + суффикс (d/w/m/y), напр. <code>2m</code>')
    return
  end

  local seconds = parseUnit(args.date, 'date')
  if not seconds or seconds <= 0 then
    ctx:replyToMessage('🤷🏼‍♀️ Не удалось распознать date='..args.date)
    return
  end

  -- Поиск целевого пользователя в БД
  local user, userErr = resolveTargetUser(buildQuery(args))

  if userErr then
    log.error(userErr)
    ctx:replyToMessage('⚠️ Ошибка чтения пользователя')
    return
  end

  if not user then
    ctx:replyToMessage('🤷🏼‍♀️ Пользователь не найден в БД (нужно, чтобы он хоть раз взаимодействовал с ботом)')
    return
  end

  -- Если подписка ещё активна - продлеваем от её конца, иначе от текущего момента
  local existing, vipErr = vipUsersService.read(user.id)

  if vipErr then
    log.error(vipErr)
    ctx:replyToMessage('⚠️ Ошибка чтения VIP')
    return
  end

  local now = os.time()
  local startFrom = (existing and existing.until_date > now) and existing.until_date or now
  local untilDate = startFrom + seconds

  local _, upsertErr = vipUsersService.upsert({
    user_id = user.id,
    until_date = untilDate,
  })

  if upsertErr then
    log.error(upsertErr)
    ctx:replyToMessage('⚠️ Не удалось сохранить VIP')
    return
  end

  notifyVipActivated(user, untilDate)

  ctx:replyToMessage(TEMPLATE:f({
    sep = hdec.sep,
    mention = hdec.user(user),
    userId = user.id,
    untilDate = os.date('%Y-%m-%d %H:%M:%S', untilDate),
  }))
end

return command
