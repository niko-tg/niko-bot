--- Уведомление админу о добавлении бота в чат.
--
-- Стреляет только когда бот реально был вне чата (LEFT/KICKED) и попал
-- внутрь. Простую смену роли member <-> admin не считаем - иначе
-- придёт дубль на каждое повышение/понижение.
--
local log = require('log')
local bot = require('bot')
local config = require('conf.config')
local hdec = require('bot.libs.hdec')
local chat_member_status = require('bot.enums.chat_member_status')

local TEMPLATE = ([[
<b>🏘 Добавили в чат</b>
${sep}
<b>Title:</b> ${title}
<b>Type:</b> ${type}
<b>ID:</b> <code>${id}</code>
<b>Username:</b> @${link}
${sep}
<b>Bot status:</b> ${bot_status}
${sep}
<b>Добавил</b>
[<code>${from_user_id}</code>]: ${from_user}
]]):f({ sep = hdec.sep })

--- @param ctx (table) my_chat_member context
local function botAddedToChat(ctx)
  local oldStatus = ctx:getOldChatMemberStatus()

  -- Был ли бот вне чата до этого
  --
  if oldStatus ~= chat_member_status.LEFT
    and oldStatus ~= chat_member_status.KICKED
  then
    return
  end

  local chat = ctx:getChat()
  local newChatMember = ctx:getNewChatMember()
  local userFrom = ctx:getUserFrom()

  local _, err = bot:sendMessage({
    chat_id = config.admin_id,
    text = TEMPLATE:f({
      title = hdec.escape(chat.title or ''),
      type = chat.type,
      id = chat.id,
      link = chat.username or 'nil',
      bot_status = newChatMember.status,
      from_user_id = userFrom.id,
      from_user = hdec.user(userFrom),
    }),
  })

  if err then
    log.error(err)
  end
end

return botAddedToChat
