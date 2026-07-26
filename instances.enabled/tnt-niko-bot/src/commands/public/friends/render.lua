--- Рендер друзей: список с кнопками, карточка друга, удаление с подтверждением.
--
local log = require('log')
local utf8 = require('utf8')
local hdec = require('bot.libs.hdec')
local separateNumbers = require('src.utils.separateNumbers')
local timeToDays = require('src.utils.timeToDays')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')
local friendsService = require('src.services.friends')
local usersService = require('src.services.users')
local chatsService = require('src.services.chats')

local PER_PAGE = 10
local BUTTON_NAME_MAX = 25

local LIST_HEADER = [[
🫂 <b>Друзья</b> | стр. ${page}
${sep}
Всего: <b>${count}</b>
${sep}
Нажми на друга, чтобы открыть карточку
]]

local EMPTY = ([[
🫂 <b>Друзья</b>
${sep}
У тебя пока нет друзей 😔
Добавить: ответь на сообщение и напиши <code>вдрузья</code>
]]):f({ sep = hdec.sep })

local CARD = [[
🍞 <b>Карточка друга</b>
${sep}
Друг: ${friend}
Дата рождения: <code>${birthday}</code>
Из чата: ${chat}
Дружите: <b>${days}</b> дн.
]]

local CONFIRM = [[
⁉️ Точно удалить ${friend} из друзей?
]]

local DELETED = '✅ Удалён из друзей'

local render = {}

--- Имя пользователя для строки (или плейсхолдер, если записи в БД нет).
local function resolveName(userId)
  local user, err = usersService.read(userId)

  if err then
    log.error(err)
  end

  if user then
    return hdec.user(user)
  end

  return '<code>#'..userId..'</code>'
end

--- Имя для подписи кнопки: чистый текст, в кнопках разметка не парсится.
local function resolveButtonName(userId)
  local user, err = usersService.read(userId)

  if err then
    log.error(err)
  end

  if user then
    local name = user.first_name or user.username or 'Аноним'
    return utf8.sub(name, 1, BUTTON_NAME_MAX)
  end

  return '#'..userId
end

--- Дата рождения друга: ДД.ММ.ГГГГ или плейсхолдер, если не указана.
local function formatBirthday(user)
  if not user or user.birthday_date == box.NULL then
    return 'Не указано'
  end

  return os.date('%d.%m.%Y', user.birthday_date.timestamp)
end

--- Имя чата: ссылка t.me/<username> для публичных, иначе title, иначе #id.
local function resolveChatName(chatId)
  local chat, err = chatsService.read(chatId)

  if err then
    log.error(err)
  end

  if chat then
    local title = (chat.title ~= nil and chat.title ~= '') and chat.title
      or ('#'..tostring(chatId))

    if type(chat.username) == 'string' and chat.username ~= '' then
      return hdec.url('https://t.me/'..chat.username, title)
    end

    return hdec.escape(title)
  end

  return '<code>#'..chatId..'</code>'
end

--- Кнопка возврата к списку (на ту же страницу).
local function backToListRow(page)
  return {
    {
      text = '⬅️ К списку',
      callback = {
        command = 'cb_friends',
        arguments = { action = 'page', friend = 0, page = page },
      },
    },
  }
end

--- Страница списка друзей пользователя ownerId: кнопка на друга + навигация.
-- @tparam number ownerId
-- @tparam number page
-- @treturn[1] table { text, keyboard }
-- @treturn[2] table err
function render.list(ownerId, page)
  local total, countErr = friendsService.countFriends(ownerId)
  if countErr then
    return nil, countErr
  end

  if total == 0 then
    return { text = EMPTY, keyboard = nil }, nil
  end

  local rows, listErr = friendsService.listFriends(ownerId, PER_PAGE, (page - 1) * PER_PAGE)
  if listErr then
    return nil, listErr
  end

  -- Кнопки: по другу в ряд.
  local keyboardRows = {}
  rows = rows or {}
  for i = 1, #rows do
    local row = rows[i]
    table.insert(keyboardRows, {
      {
        text = resolveButtonName(row.friend_id),
        callback = {
          command = 'cb_friends',
          arguments = {
            action = 'view',
            friend = row.friend_id,
            page = page,
          },
        },
      },
    })
  end

  -- Ряд навигации.
  local totalPages = math.ceil(total / PER_PAGE)
  local nav = {}

  if page > 1 then
    table.insert(nav, {
      text = '◀️ '..(page - 1),
      callback = {
        command = 'cb_friends',
        arguments = {
          action = 'page',
          friend = 0,
          page = page - 1,
        },
      },
    })
  end

  if page < totalPages then
    table.insert(nav, {
      text = (page + 1)..' ▶️',
      callback = {
        command = 'cb_friends',
        arguments = {
          action = 'page',
          friend = 0,
          page = page + 1,
        },
      },
    })
  end

  if #nav > 0 then
    table.insert(keyboardRows, nav)
  end

  local text = LIST_HEADER:f({
    sep = hdec.sep,
    page = page,
    count = separateNumbers(total),
  })

  return {
    text = text,
    keyboard = inlineCallbackKeyboard(keyboardRows),
  }, nil
end

--- Карточка друга: упоминание, чат, сколько дней дружат + кнопки.
-- Если дружбы уже нет (удалили в другом окне) - возвращаем список.
-- @tparam number ownerId
-- @tparam number friendId
-- @tparam number page
-- @treturn[1] table { text, keyboard }
-- @treturn[2] table err
function render.card(ownerId, friendId, page)
  local friendship, err = friendsService.read(ownerId, friendId)
  if err then
    return nil, err
  end

  if not friendship then
    return render.list(ownerId, page)
  end

  local friend, readErr = usersService.read(friendId)
  if readErr then
    log.error(readErr)
  end

  local friendMention = friend and hdec.user(friend) or ('<code>#'..friendId..'</code>')

  local text = CARD:f({
    sep = hdec.sep,
    friend = friendMention,
    birthday = formatBirthday(friend),
    chat = resolveChatName(friendship.chat_id),
    days = timeToDays(friendship.created.timestamp),
  })

  local keyboard = inlineCallbackKeyboard({
    {
      {
        text = '❌ Удалить из друзей',
        callback = {
          command = 'cb_friends',
          arguments = {
            action = 'del',
            friend = friendId,
            page = page,
          },
        },
      },
    },
    backToListRow(page),
  })

  return {
    text = text,
    keyboard = keyboard,
  }, nil
end

--- Подтверждение удаления друга.
-- @tparam number friendId
-- @tparam number page
-- @treturn[1] table { text, keyboard }
-- @treturn[2] table err
function render.confirmDelete(friendId, page)
  local text = CONFIRM:f({ friend = resolveName(friendId) })

  local keyboard = inlineCallbackKeyboard({
    {
      {
        text = '💔 Да, удалить',
        callback = {
          command = 'cb_friends',
          arguments = {
            action = 'delyes',
            friend = friendId,
            page = page,
          },
        },
      },
      {
        text = '🩵 Нет',
        callback = {
          command = 'cb_friends',
          arguments = {
            action = 'view',
            friend = friendId,
            page = page,
          },
        },
      },
    },
  })

  return { text = text, keyboard = keyboard }, nil
end

--- Друг удалён: текст + возврат к списку.
-- @tparam number page
-- @treturn[1] table { text, keyboard }
-- @treturn[2] table err
function render.deleted(page)
  local keyboard = inlineCallbackKeyboard({ backToListRow(page) })

  return {
    text = DELETED,
    keyboard = keyboard,
  }, nil
end

return render
