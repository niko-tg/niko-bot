--- Уведомление в ЛС юзеру: ему выдали или продлили VIP.
--
-- Используется из /mkvip и в будущем из донатов.
-- Если юзер заблокировал бота / чат не найден - пишем verbose, не error.
--
local log = require('log')
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local tgErrors = require('src.utils.tgErrors')

local TEMPLATE = ([[
👑 <b>Получен VIP статус!</b>
${sep}
⏳ Активен до: <code>${untilDate}</code>
]]):f({ sep = hdec.sep })

--- @param user (table) кому выдали VIP (нужен user.id)
--- @param untilDate (number) unix-timestamp окончания VIP
local function vipActivated(user, untilDate)
  local _, err = bot:sendMessage({
    chat_id = user.id,
    text = TEMPLATE:f({
      untilDate = os.date('%d.%m.%Y', untilDate),
    }),
  })

  if err then
    if tgErrors.isBotBlocked(err) or tgErrors.isChatNotFound(err) then
      log.verbose(err)
    else
      log.error(err)
    end
  end
end

return vipActivated
