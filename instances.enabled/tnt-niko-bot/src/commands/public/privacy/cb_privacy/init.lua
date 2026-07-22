--- Переключение приватности (callback): флипает is_private владельца.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local usersService = require('src.services.users')
local render = require('src.commands.public.privacy.render')

local command = Command:new({
  commands = { 'cb_privacy' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'owner' },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local owner = tonumber(command.arguments.owner)

  -- Кнопка - только для владельца (command.user == нажавший).
  if command.user.id ~= owner then
    ctx:answer({
      text = 'Это не твоя кнопка 🙃',
      show_alert = true,
    })
    return
  end

  local user = command.user
  local newValue = not user.is_private

  local _, err = usersService.upsert({ id = owner, is_private = newValue })
  if err then
    log.error(err)

    ctx:answer({
      text = 'Не удалось изменить',
      show_alert = true,
    })

    return
  end

  user.is_private = newValue
  ctx:answer(newValue and 'Включено 🔒' or 'Выключено 🔓')

  local view = render.view(user)
  bot:editMessageText({
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    text = view.text,
    reply_markup = view.keyboard,
  })
end

return command
