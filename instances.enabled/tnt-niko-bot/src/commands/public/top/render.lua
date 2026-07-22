--- Рендер топов: меню выбора и страницы лидербордов.
--
local log = require('log')
local hdec = require('bot.libs.hdec')
local chat_type = require('bot.enums.chat_type')
local pagination = require('bot.utils.pagination')
local separateNumbers = require('src.utils.separateNumbers')
local timeToDays = require('src.utils.timeToDays')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')
local usersService = require('src.services.users')
local userMention = require('src.render.userMention')
local transactionsService = require('src.services.transactions')
local userInChatService = require('src.services.user_in_chat')
local chatsService = require('src.services.chats')
local marriagesService = require('src.services.marriages')

local PER_PAGE = 20
local MEDALS = { '🥇', '🥈', '🥉' }
local IS_GROUP = {
  [chat_type.GROUP] = true,
  [chat_type.SUPERGROUP] = true,
}

-- Кнопка возврата в меню топов.
local BACK_ROW = {
  {
    text = '⬅️ К топам',
    callback = {
      command = 'cb_top',
      arguments = {
        which = 'menu',
        page = 1,
      },
    },
  },
}

local render = {}

--- Имя юзера для строки топа (или плейсхолдер, если в БД его нет).
local function resolveName(userId)
  local user, err = usersService.read(userId)

  if err then
    log.error(err)
  end

  if user then
    return userMention(user)
  end

  return '<code>#'..userId..'</code>'
end

--- Имя чата для строки топа: ссылка t.me/<username> для публичных, иначе title.
local function resolveChatName(entry)
  local title = (entry.title ~= nil and entry.title ~= '') and entry.title
    or ('#'..tostring(entry.chat_id))

  if type(entry.username) == 'string' and entry.username ~= '' then
    return hdec.url('https://t.me/'..entry.username, title)
  end

  return hdec.escape(title)
end

--- Меню выбора топа. 'Активные' - только в группе.
function render.menu(chatType)
  local rows = {
    {
      {
        text = '🎮 Топ PVP игроков',
        callback = {
          command = 'cb_top',
          arguments = {
            which = 'players',
            page = 1,
          },
        },
      },
    },
    {
      {
        text = '🎰 Топ касс',
        callback = {
          command = 'cb_top',
          arguments = {
            which = 'cashbox',
            page = 1,
          },
        },
      },
    },
    {
      {
        text = '📈 Топ чатов',
        callback = {
          command = 'cb_top',
          arguments = {
            which = 'chats',
            page = 1,
          },
        },
      },
    },
    {
      {
        text = '💰 Топ донатов',
        callback = {
          command = 'cb_top',
          arguments = {
            which = 'donat',
            page = 1,
          },
        },
      },
    },
    {
      {
        text = '🧛 Топ кусак',
        callback = {
          command = 'cb_top',
          arguments = {
            which = 'kus',
            page = 1,
          },
        },
      },
    },
    {
      {
        text = '🤑 Топ богатых',
        callback = {
          command = 'cb_top',
          arguments = {
            which = 'rich',
            page = 1,
          },
        },
      },
    },
  }

  if IS_GROUP[chatType] then
    table.insert(rows, {
      {
        text = '💬 Топ активных',
        callback = {
          command = 'cb_top',
          arguments = {
            which = 'active',
            page = 1,
          },
        },
      },
    })

    table.insert(rows, {
      {
        text = '💍 Топ браков',
        callback = {
          command = 'cb_top',
          arguments = {
            which = 'marriages',
            page = 1,
          },
        },
      },
    })
  end

  return {
    text = '🏆 <b>Топы</b>\n'..hdec.sep..'\nВыбери, что показать',
    keyboard = inlineCallbackKeyboard(rows),
  }
end

--- Общий рендер страницы лидерборда.
-- @tparam string which для навигации; title; entries (строки топа); total; page; formatEntry
local function renderPage(which, title, entries, total, page, formatEntry, formatName)
  formatName = formatName or function(entry)
    return resolveName(entry.user_id)
  end

  local lines = { '🏆 <b>'..title..'</b> | стр. '..page, hdec.sep }

  if #entries == 0 then
    table.insert(lines, '\nПока пусто 🤷🏼‍♀️')
  else
    local offset = (page - 1) * PER_PAGE

    for index = 1, #entries do
      local entry = entries[index]
      local rank = offset + index
      local prefix = MEDALS[rank] or (rank..'.')

      table.insert(lines, ('%s %s | %s'):format(prefix, formatName(entry), formatEntry(entry)))
    end
  end

  local keyboard = pagination({
    total = total,
    page = page,
    per_page = PER_PAGE,
    command = 'cb_top',
    arguments = { which = which },
    footer = { BACK_ROW },
  })

  return { text = table.concat(lines, '\n'), keyboard = keyboard }
end

--- Топ донатов (глобально).
local function donat(page)
  local total, countErr = transactionsService.countDonors()
  if countErr then
    return nil, countErr
  end

  local rows, err = transactionsService.topByAmount(PER_PAGE, (page - 1) * PER_PAGE)
  if err then
    return nil, err
  end

  local entries = {}
  rows = rows or {}
  for i = 1, #rows do
    local row = rows[i]
    table.insert(entries, {
      user_id = row.user_id,
      value = row.total,
    })
  end

  return renderPage('donat', 'Топ донатов', entries, total, page, function(entry)
    return separateNumbers(entry.value)..' ⭐'
  end)
end

--- Топ активных (текущий чат).
local function active(page, chatId)
  local total, countErr = userInChatService.countActive(chatId)
  if countErr then
    return nil, countErr
  end

  local rows, err = userInChatService.topByMessages(chatId, PER_PAGE, (page - 1) * PER_PAGE)
  if err then
    return nil, err
  end

  local entries = {}
  rows = rows or {}
  for i = 1, #rows do
    local row = rows[i]
    table.insert(entries, {
      user_id = row.user_id,
      value = row.count_messages,
    })
  end

  return renderPage('active', 'Топ активных', entries, total, page, function(entry)
    return separateNumbers(entry.value)..' сообщ.'
  end)
end

--- Топ браков чата: пары, где оба супруга в этом чате. Старейшие браки выше.
-- Брак глобальный, чат задаёт лишь видимость (оба должны быть участниками).
local function marriages(page, chatId)
  local total, countErr = marriagesService.countInChat(chatId)
  if countErr then
    return nil, countErr
  end

  local rows, err = marriagesService.topInChat(chatId, PER_PAGE, (page - 1) * PER_PAGE)
  if err then
    return nil, err
  end

  local entries = {}
  rows = rows or {}
  for i = 1, #rows do
    local row = rows[i]
    table.insert(entries, {
      user_id = row.user_id,
      partner_id = row.partner_id,
      created = row.created,
    })
  end

  return renderPage('marriages', 'Топ браков', entries, total, page, function(entry)
    return timeToDays(entry.created.timestamp)..' дн.'
  end, function(entry)
    return resolveName(entry.user_id)..' 💍 '..resolveName(entry.partner_id)
  end)
end

--- Топ игроков по опыту (глобально). Ранг по уровню, затем по XP внутри уровня.
local function players(page)
  local total, countErr = usersService.countPlayers()
  if countErr then
    return nil, countErr
  end

  local rows, err = usersService.topByXP(PER_PAGE, (page - 1) * PER_PAGE)
  if err then
    return nil, err
  end

  local entries = {}
  rows = rows or {}
  for i = 1, #rows do
    local row = rows[i]
    table.insert(entries, {
      user_id = row.id,
      level = row.level,
      xp = row.xp,
      xp_to_next = row.xp_to_next,
    })
  end

  return renderPage('players', 'Топ игроков', entries, total, page, function(entry)
    return entry.level..' ур. | '..separateNumbers(entry.xp)..' | '..entry.xp_to_next..' XP'
  end)
end

--- Топ кусак по числу сделанных укусов (глобально).
local function kus(page)
  local total, countErr = usersService.countByKuses()
  if countErr then
    return nil, countErr
  end

  local rows, err = usersService.topByKuses(PER_PAGE, (page - 1) * PER_PAGE)
  if err then
    return nil, err
  end

  local entries = {}
  rows = rows or {}
  for i = 1, #rows do
    local row = rows[i]
    table.insert(entries, {
      user_id = row.id,
      value = row.kuses,
    })
  end

  return renderPage('kus', 'Топ кусак', entries, total, page, function(entry)
    return separateNumbers(entry.value)..' укусов'
  end)
end

--- Топ богатых по балансу (глобально).
local function rich(page)
  local total, countErr = usersService.countByBalance()
  if countErr then
    return nil, countErr
  end

  local rows, err = usersService.topByBalance(PER_PAGE, (page - 1) * PER_PAGE)
  if err then
    return nil, err
  end

  local entries = {}
  rows = rows or {}
  for i = 1, #rows do
    local row = rows[i]
    table.insert(entries, {
      user_id = row.id,
      value = row.balance,
    })
  end

  return renderPage('rich', 'Топ богатых', entries, total, page, function(entry)
    return separateNumbers(entry.value)..'р'
  end)
end

--- Топ касс: чаты по casino_cashier (глобально).
local function cashbox(page)
  local total, countErr = chatsService.countByCashbox()
  if countErr then
    return nil, countErr
  end

  local rows, err = chatsService.topByCashbox(PER_PAGE, (page - 1) * PER_PAGE)
  if err then
    return nil, err
  end

  local entries = {}
  rows = rows or {}
  for i = 1, #rows do
    local row = rows[i]
    table.insert(entries, {
      chat_id = row.id,
      title = row.title,
      username = row.username,
      value = row.casino_cashier,
    })
  end

  return renderPage('cashbox', 'Топ касс', entries, total, page, function(entry)
    return separateNumbers(entry.value)..'р'
  end, resolveChatName)
end

--- Топ чатов: чаты по активности total_messages (глобально).
local function chats(page)
  local total, countErr = chatsService.countByMessages()
  if countErr then
    return nil, countErr
  end

  local rows, err = chatsService.topByMessages(PER_PAGE, (page - 1) * PER_PAGE)
  if err then
    return nil, err
  end

  local entries = {}
  rows = rows or {}
  for i = 1, #rows do
    local row = rows[i]
    table.insert(entries, {
      chat_id = row.id,
      title = row.title,
      username = row.username,
      value = row.total_messages,
    })
  end

  return renderPage('chats', 'Топ чатов', entries, total, page, function(entry)
    return separateNumbers(entry.value)..' сообщ.'
  end, resolveChatName)
end

--- Диспетчер топа по which. Неизвестный/недоступный -> меню.
-- @treturn[1] table { text, keyboard }
-- @treturn[2] table err
function render.top(which, page, chatType, chatId)
  if which == 'donat' then
    return donat(page)

  elseif which == 'players' then
    return players(page)

  elseif which == 'cashbox' then
    return cashbox(page)

  elseif which == 'chats' then
    return chats(page)

  elseif which == 'kus' then
    return kus(page)

  elseif which == 'rich' then
    return rich(page)

  elseif which == 'active' and IS_GROUP[chatType] then
    return active(page, chatId)

  elseif which == 'marriages' and IS_GROUP[chatType] then
    return marriages(page, chatId)
  end

  return render.menu(chatType)
end

return render
