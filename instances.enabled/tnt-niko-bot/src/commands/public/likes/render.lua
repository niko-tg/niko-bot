--- Рендер списка лайкнувших (пагинация).
--
local log = require('log')
local hdec = require('bot.libs.hdec')
local pagination = require('bot.utils.pagination')
local likesService = require('src.services.likes')
local usersService = require('src.services.users')
local userMention = require('src.render.userMention')

local PER_PAGE = 10

local TITLE = '❤️ <b>Кто лайкал: ${name}</b> | Всего: <b>${total}</b> | стр. ${page}'
local EMPTY = 'Пока никто не лайкал 🤷🏼‍♀️'
local ROW = '${rank}. ${name}'

local render = {}

--- Имя пользователя для строки (или плейсхолдер, если записи в БД нет).
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

--- Страница списка лайкнувших пользователя ownerId.
-- @tparam number ownerId чьи полученные лайки показываем
-- @tparam number page страница (с 1)
-- @treturn[1] table { text, keyboard }
-- @treturn[2] table err
function render.likers(ownerId, page)
  local total, countErr = likesService.countLikers(ownerId)
  if countErr then
    return nil, countErr
  end

  local rows, listErr = likesService.listLikers(ownerId, PER_PAGE, (page - 1) * PER_PAGE)
  if listErr then
    return nil, listErr
  end

  local likerIds = {}
  rows = rows or {}
  for i = 1, #rows do
    local row = rows[i]
    table.insert(likerIds, row.liking_id)
  end

  local lines = {
    TITLE:f({
      name = resolveName(ownerId),
      page = page,
      total = total,
    }),
    hdec.sep,
  }

  if #likerIds == 0 then
    table.insert(lines, '')
    table.insert(lines, EMPTY)
  else
    local offset = (page - 1) * PER_PAGE

    for index = 1, #likerIds do
      local likingId = likerIds[index]
      local rank = offset + index

      table.insert(lines, ROW:f({
        rank = rank,
        name = resolveName(likingId),
      }))
    end
  end

  local keyboard = pagination({
    total = total,
    page = page,
    per_page = PER_PAGE,
    command = 'cb_likes',
    arguments = { owner = ownerId },
  })

  return { text = table.concat(lines, '\n'), keyboard = keyboard }
end

return render
