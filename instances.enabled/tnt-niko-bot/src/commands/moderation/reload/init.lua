--- Принудительная синхронизация стафа чата.
--
local log = require('log')
local Command = require('bot.classes.Command')
local hdec = require('bot.libs.hdec')
local syncChatStaff = require('src.utils.syncChatStaff')

local command = Command:new({
  commands = { '/reload' },
  flags = {
    Command.enum.IN_CHAT,
    Command.enum.MODERATION,
  },
})

--- Список пользователей построчно, без ссылок.
-- @tparam table users массив пользователей
-- @treturn string готовый текст
local function renderList(users)
  local lines = {}

  for i = 1, #users do
    local user = users[i]
    table.insert(lines, '   ╰ ' .. hdec.user(user, { no_link = true }))
  end

  return table.concat(lines, '\n')
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local chat = command.chat

  local result, err = syncChatStaff(chat.id)

  if err then
    log.error(err)
    ctx:replyToMessage('⚠️ Не удалось синхронизировать стаф чата')
    return
  end

  local syncedCount = #result.synced
  local demotedCount = #result.demoted

  if syncedCount == 0 and demotedCount == 0 then
    ctx:replyToMessage('🔄 <b>Стаф уже актуален</b>')
    return
  end

  local sections = { '🔄 <b>Стаф обновлён</b>' }

  if syncedCount > 0 then
    table.insert(sections,
      string.format('✅ <b>Загружено</b>: %d\n%s', syncedCount, renderList(result.synced)))
  end

  if demotedCount > 0 then
    table.insert(sections,
      string.format('⬇️ <b>Понижено</b>: %d\n%s', demotedCount, renderList(result.demoted)))
  end

  ctx:replyToMessage(table.concat(sections, '\n'..hdec.sep..'\n'))
end

return command
