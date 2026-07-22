--- Касса чата: текущий джекпот слота /spin.
--
local hdec = require('bot.libs.hdec')
local Command = require('bot.classes.Command')
local separateNumbers = require('src.utils.separateNumbers')

local command = Command:new({
  commands = { '/cashbox', 'касса', 'к' },
  flags = { Command.enum.IN_CHAT },
})

local TEMPLATE = [[
🏦 <b>Касса чата</b>
${sep}
В кассе: <b>${cashbox}</b>р
Сорви ДЖЕКПОТ в /spin - заберёшь всё!
]]

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local cashbox = (command.chat and command.chat.casino_cashier) or 0

  ctx:replyToMessage(TEMPLATE:f({
    cashbox = separateNumbers(cashbox),
    sep = hdec.sep,
  }))
end

return command
