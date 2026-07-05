--- Команда отображения администрации чата
--
local log = require('log')
local Command = require('bot.classes.Command')
local hdec = require('bot.libs.hdec')
local auth = require('src.auth')
local userInChatService = require('src.services.user_in_chat')
local usersService = require('src.services.users')
local chat_member_status = require('bot.enums.chat_member_status')

local command = Command:new {
  commands = { '/staff', 'стаф' },
  flags = { Command.enum.IN_CHAT }
}

local HEADER = '👮🏻 Главные по чатику'
local FOOTER = '╭ Обновления стафа\n┊\n╰ Команда /reload'

--- Получает имя пользователя для отображения.
-- Возвращает nil если юзера нет в БД (например, бот сам или ещё не виделся).
local function fetchName(userId)
  local user, err = usersService.read(userId)

  if err then
    log.error(err)
    return nil
  end

  if user == nil then
    return nil
  end

  return hdec.user(user)
end

--- Собирает имена администрации чата по 4 категориям.
-- Анонимные (is_anonymous == true) пропускаются.
-- groups возвращается всегда (даже пустой), err - только если БД упала.
local function collect(chatId)
  local groups = {
    owner = {},
    admin = {},
    moderator = {},
    voiceMod = {},
  }

  local owners, ownerErr = userInChatService.getByStatus(chatId, chat_member_status.CREATOR)
  if ownerErr then
    return groups, ownerErr
  end

  local admins, adminErr = userInChatService.getByStatus(chatId, chat_member_status.ADMINISTRATOR)
  if adminErr then
    return groups, adminErr
  end

  for _, uic in ipairs(owners or {}) do
    local perms = uic.permissions or {}

    if not perms.is_anonymous then
      local name = fetchName(uic.user_id)

      if name then
        table.insert(groups.owner, name)
      end
    end
  end

  for _, uic in ipairs(admins or {}) do
    local perms = uic.permissions or {}

    if not perms.is_anonymous then
      local name = fetchName(uic.user_id)

      if name then
        local role = auth.roleOf(uic)

        if role == auth.roles.ADMIN then
          table.insert(groups.admin, name)

        elseif role == auth.roles.MODERATOR then
          table.insert(groups.moderator, name)

        elseif auth.isVoiceMod(uic) then
          table.insert(groups.voiceMod, name)
        end
      end
    end
  end

  return groups
end

--- Рендер одной секции. Возвращает nil если имён нет.
local function renderSection(emoji, title, names)
  if #names == 0 then
    return nil
  end

  local lines = { emoji .. ' ' .. title }

  for _, name in ipairs(names) do
    table.insert(lines, '   ╰ ' .. name)
  end

  return table.concat(lines, '\n')
end

local SECTION_SEPARATOR = '\n'..hdec.sep..'\n'

function command.call(ctx)
  local chat = command.chat

  local groups, err = collect(chat.id)
  if err then
    log.error(err)
    ctx:replyToMessage('⚠️ Не удалось получить администрацию чата')
    return
  end

  local sections = {}

  local owner = renderSection('💎', 'Владелец', groups.owner)
  if owner then
    table.insert(sections, owner)
  end

  local admin = renderSection('⭐️', 'Админы', groups.admin)
  if admin then
    table.insert(sections, admin)
  end

  local moderator = renderSection('⭐️', 'Модераторы', groups.moderator)
  if moderator then
    table.insert(sections, moderator)
  end

  local voiceMod = renderSection('🎤', 'Войс-модераторы', groups.voiceMod)
  if voiceMod then
    table.insert(sections, voiceMod)
  end

  if #sections == 0 then
    ctx:replyToMessage('🤷🏼‍♀️ Пока не знаю про администрацию чата.\nОбновить: /reload')
    return
  end

  local body = table.concat(sections, SECTION_SEPARATOR)

  ctx:replyToMessage(
       HEADER
    .. SECTION_SEPARATOR
    .. body
    .. SECTION_SEPARATOR
    .. FOOTER
  )
end

return command
