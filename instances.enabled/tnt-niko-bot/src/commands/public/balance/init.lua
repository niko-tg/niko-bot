--- Баланс пользователя.
--
local Command = require('bot.classes.Command')
local separateNumbers = require('src.utils.separateNumbers')

local command = Command:new({
  commands = { '/balance', 'баланс', 'б' },
  flags = {
    Command.enum.PUBLIC,
    Command.enum.NO_REPLY,
  },
})

local TEMPLATE = [[
💵 Баланс: <b>${balance}</b>р
🏦 Ререзрв: <b>${reserved_balance}</b>р
💎 Кристаллы: <b>${crystals}</b>
]]

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  ctx:reply(TEMPLATE:f({
    balance = separateNumbers(command.user.balance),
    reserved_balance = separateNumbers(command.user.reserved_balance),
    crystals = separateNumbers(command.user.crystals),
  }))
end

return command
