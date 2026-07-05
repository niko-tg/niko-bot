--- РП-команды: действие над собеседником реплаем (или "<команда> @username").
-- Имя вызванной команды берём из ctx.__command. Род глагола - по полу вызвавшего.
--
local log = require('log')
local utf8 = require('utf8')
local Command = require('bot.classes.Command')
local hdec = require('bot.libs.hdec')
local rp = require('src.rp.actions')
local usersService = require('src.services.users')
local userMention = require('src.render.userMention')

local command = Command:new {
  commands = rp.names,
  flags = { Command.enum.IN_CHAT },
  info = 'РП-действия над собеседником реплаем: обнять, поцеловать, погладить, ударить и др.',
}

local UNKNOWN_USER = ([[
🤷‍♀️ Не знаю такого пользователя
${sep}
Проверь, правильно ли написан @юзернейм
]]):f({ sep = hdec.sep })

-- Суффикс рода глагола: обнял / обняла / обнял(а).
local function genderSuffix(user)
  if user.gender == 'woman' then
    return 'а'
  elseif user.gender == 'man' then
    return ''
  end

  return '(а)'
end

function command.call(ctx)
  -- [1] - имя вызванной команды (первый токен), [2] - аргумент (@username).
  -- processCommand резолвит команду так же: bot.commands[text:split(' ',1)[1]].
  local arguments = ctx:getArguments({ count = 2 })
  local name = utf8.lower(tostring(arguments[1]))

  local variants = rp.byName[name]
  if not variants then
    return
  end

  local userFrom = command.user
  local reply = ctx.message.reply_to_message
  local userReply = reply and reply.from

  -- Фолбэк: цель указана как "<команда> @username".
  if userReply == nil then
    local username = arguments[2] and arguments[2]:match('^@([%w_]+)$')

    -- Ни реплая, ни @username - молча выходим (это могло быть обычное слово).
    if not username then
      return
    end

    local found, err = usersService.readByUsername(string.lower(username))
    if err then
      log.error(err)
    end

    if not found then
      ctx:replyToMessage(UNKNOWN_USER)
      return
    end

    userReply = found
  end

  local text = variants[math.random(#variants)]:f({
    userFrom = userMention(userFrom),
    userReply = userMention(userReply),
    gender = genderSuffix(userFrom),
  })

  ctx:replyToMessage(text)
end

return command
