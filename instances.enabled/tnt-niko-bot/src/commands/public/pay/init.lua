--- Перевод валюты другому участнику ответом на его сообщение.
--
-- Ответ на сообщение + "дать 10к" -> переводит 10000 автору сообщения.
--
local log = require('log')
local hdec = require('bot.libs.hdec')
local Command = require('bot.classes.Command')
local separateNumbers = require('src.utils.separateNumbers')
local decodeMoneyString = require('src.utils.decodeMoneyString')
local usersService = require('src.services.users')

local command = Command:new {
  commands = { '/pay', 'дать' },
  flags = {
    Command.enum.IN_CHAT,
    Command.enum.REPLY
  }
}

local USAGE = ([[
ℹ️ <b>Перевод валюты</b>
${sep}
Ответь на сообщение и напиши: <code>дать 10к</code>
Это переведет 10.000 тому, на чьё сообщение ты ответил(а)
]]):f({ sep = hdec.sep })

local TEMPLATE = [[
${title}
  ╰ Сумма: <b>${value}</b>р
  ╰ От: ${user_from}
  ╰ Кому: ${user_reply}
]]

function command.call(ctx)
  local message = ctx.message
  local reply = message.reply_to_message

  -- Флаг REPLY в preCallCommand не enforced - проверяем здесь.
  if not reply or not reply.from then
    ctx:replyToMessage(USAGE)
    return
  end

  local sender = command.user
  local recipient = reply.from

  if recipient.is_bot then
    ctx:replyToMessage('Спасибо! Я и так богатая, потому что у меня есть ты ❤️')
    return
  end

  if recipient.id == sender.id then
    ctx:replyToMessage('🤷🏼‍♀️ Нельзя перевести самому себе')
    return
  end

  -- Сумма - второй токен ("дать 10к" -> "10к").
  local arg = message.text:match('^%S+%s+(%S+)')
  local amount = arg and decodeMoneyString(arg)

  if not amount or amount <= 0 then
    ctx:replyToMessage(USAGE)
    return
  end

  if sender.balance < amount then
    ctx:replyToMessage(
      'ℹ️ <b>Недостаточно средств</b>'
      .. '\n'
      .. '💵 Баланс: <b>'..separateNumbers(sender.balance)..'</b>р')
    return
  end

  -- Гарантируем запись получателя: мог писать только обычные сообщения,
  -- без команд (users-запись создаёт preCallCommand, а не onChatMessage).
  -- На update баланс не трогается (нет в data), на insert - дефолт.
  local _, ensureErr = usersService.upsert(recipient)
  if ensureErr then
    log.error(ensureErr)
    ctx:replyToMessage('⚠️ Ошибка перевода')
    return
  end

  amount = math.floor(amount)

  -- Атомарный перевод.
  local _, transferErr = usersService.transfer(sender.id, recipient.id, amount)
  if transferErr then
    log.error(transferErr)
    ctx:replyToMessage('⚠️ Не удалось выполнить перевод')
    return
  end

  ctx:replyToMessage(TEMPLATE:f({
    title = '💸 <b>Перевод выполнен</b>',
    value = separateNumbers(amount),
    user_from = hdec.user(sender),
    user_reply = hdec.user(recipient),
  }))
end

return command
