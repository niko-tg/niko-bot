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
${sep}
<b>⚙️ Включено в чатах</b>
${chatSettings}
]]

-- Подписи настроек чата в порядке вывода (ключи - как в settings map).
local SETTINGS_LABELS = {
  { key = 'has_enable_moderation_commands', label = 'Модераторские команды' },
  { key = 'has_enable_antiflood',           label = 'Антифлуд' },
  { key = 'has_enable_captcha',             label = 'Капча' },
  { key = 'has_delete_links',               label = 'Удаление ссылок' },
  { key = 'has_delete_forward_message',     label = 'Запрет пересылки' },
  { key = 'has_ban_sender_chat',            label = 'Запрет писать от лица чатов' },
  { key = 'has_enable_hello_message',       label = 'Приветственное сообщение' },
}

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

--- Строки секции настроек: известные - с подписью по порядку,
-- неизвестные ключи (настройка есть, подпись забыли) - сырым именем в хвост.
-- @tparam ?table counts { имя_настройки = кол-во } из countChatSettings
-- @treturn string
local function fmtChatSettings(counts)
  counts = counts or {}

  local lines = {}
  local known = {}

  for i = 1, #SETTINGS_LABELS do
    local item = SETTINGS_LABELS[i]
    known[item.key] = true
    table.insert(lines, ('  ╰ %s: <b>%s</b>'):format(
      item.label, separateNumbers(num(counts[item.key]))
    ))
  end

  local extra = {}
  for key in pairs(counts) do
    if not known[key] then
      table.insert(extra, key)
    end
  end
  table.sort(extra)

  for i = 1, #extra do
    table.insert(lines, ('  ╰ %s: <b>%s</b>'):format(
      extra[i], separateNumbers(num(counts[extra[i]]))
    ))
  end

  return table.concat(lines, '\n')
end

local render = {}

--- Текст статистики: текущее + дельты к снапшоту (latest может быть nil = всё 'новое').
-- @tparam table current computeCurrent
-- @tparam ?table latest последний снапшот
-- @treturn string
function render.report(current, latest)
  latest = latest or {}

  --- Дельта поля относительно прошлого снапшота.
  -- @tparam string field имя поля
  -- @treturn string отформатированная дельта
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

    chatSettings = fmtChatSettings(current.chat_settings),
  })
end

return render
