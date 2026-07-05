--- Рендер статистики бота: шаблон + дельты к снапшоту.
--
local hdec = require('bot.libs.hdec')
local separateNumbers = require('src.utils.separateNumbers')

local TEMPLATE = [[
📊 <b>Статистика бота</b>
  ╰ <i>${date}</i>
${sep}
<b>👥 Аудитория</b>
  ╰ Юзеров: <b>${users}</b> | ${dUsers}
  ╰ Запустили бота: <b>${started}</b> | ${dStarted}
  ╰ Чатов: <b>${chats}</b> | ${dChats}
  ╰ Участников: <b>${members}</b> | ${dMembers}
${sep}
<b>✉️ Активность</b>
  ╰ Сообщений: <b>${messages}</b> | ${dMessages}
  ╰ Команд: <b>${commands}</b> | ${dCommands}
  ╰ Активны сегодня: <b>${activeToday}</b>
${sep}
<b>💰 Экономика</b>
  ╰ Баланс в обороте: <b>${balance}</b>р | ${dBalance}
  ╰ Кристаллов: <b>${crystals}</b> | ${dCrystals}
  ╰ Кассы казино: <b>${cashbox}</b>р | ${dCashbox}
  ╰ Донатов: <b>${donations}</b> ⭐ | ${dDonations}
${sep}
<b>🎮 Сейчас</b>
  ╰ Активных игр: <b>${liveGames}</b>
  ╰ Активных VIP: <b>${vip}</b>
]]

--- cdata/nil -> number.
local function num(value)
  if type(value) == 'number' then
    return value
  end
  return tonumber(value) or 0
end

--- Знаковая дельта: +N / -N / 0.
local function fmtDelta(delta)
  if delta > 0 then
    return '+'..separateNumbers(delta)
  end
  if delta < 0 then
    return '-'..separateNumbers(-delta)
  end
  return '0'
end

local render = {}

--- Текст статистики: текущее + дельты к снапшоту (latest может быть nil = всё «новое»).
-- @param current (table) computeCurrent
-- @param latest (table|nil) последний снапшот
-- @return string
function render.report(current, latest)
  latest = latest or {}

  local function d(field)
    return fmtDelta(num(current[field]) - num(latest[field]))
  end

  return TEMPLATE:f({
    date = os.date('%d.%m.%Y %H:%M'),
    sep = hdec.sep,

    users = separateNumbers(current.users_total),
    dUsers = d('users_total'),
    started = separateNumbers(current.started_total),
    dStarted = d('started_total'),
    chats = separateNumbers(current.chats_total),
    dChats = d('chats_total'),
    members = separateNumbers(current.members_total),
    dMembers = d('members_total'),

    messages = separateNumbers(current.messages_total),
    dMessages = d('messages_total'),
    commands = separateNumbers(current.commands_total),
    dCommands = d('commands_total'),
    activeToday = separateNumbers(current.active_today),

    balance = separateNumbers(current.balance_total),
    dBalance = d('balance_total'),
    crystals = separateNumbers(current.crystals_total),
    dCrystals = d('crystals_total'),
    cashbox = separateNumbers(current.cashbox_total),
    dCashbox = d('cashbox_total'),
    donations = separateNumbers(current.donations_total),
    dDonations = d('donations_total'),

    liveGames = separateNumbers(current.live_games),
    vip = separateNumbers(current.vip_users),
  })
end

return render
