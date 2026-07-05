--- Установка пола (callback): меню выбора, одноразовый коммит. По образцу cb_set_race.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local usersService = require('src.services.users')
local render = require('src.commands.public.profile.render')

local command = Command:new {
  commands = { 'cb_set_gender' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action', 'gender', 'owner' },
}

-- Редактирует текущее сообщение в переданный view { text, keyboard }.
local function editView(ctx, view)
  bot:editMessageText({
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    text = view.text,
    reply_markup = view.keyboard,
  })
end

function command.call(ctx)
  local arguments = command.arguments
  local owner = tonumber(arguments.owner)

  -- Кнопки - только для владельца (command.user == нажавший).
  if command.user.id ~= owner then
    ctx:answer({
      text = 'Это не твой профиль 🙃',
      show_alert = true
    })
    return
  end

  local user = command.user

  -- Показать выбор пола.
  if arguments.action == 'menu' then
    ctx:answer()
    editView(ctx, render.profile(user, ctx:getChat(), { genderChoice = true }))
    return
  end

  -- Вернуться к профилю.
  if arguments.action == 'back' then
    ctx:answer()
    editView(ctx, render.profile(user, ctx:getChat()))
    return
  end

  -- Установка пола - ОДНОРАЗОВАЯ (как раса).
  if arguments.action == 'set' then
    if user.gender ~= box.NULL then
      ctx:answer({
        text = 'Пол уже установлен 🔒',
        show_alert = true
      })

      editView(ctx, render.profile(user, ctx:getChat()))
      return
    end

    if not render.isGender(arguments.gender) then
      ctx:answer({
        text = 'Неизвестный пол',
        show_alert = true
      })

      return
    end

    local _, err = usersService.update({ gender = arguments.gender }, { id = owner })
    if err then
      log.error(err)

      ctx:answer({
        text = 'Не удалось сохранить пол',
        show_alert = true
      })

      return
    end

    user.gender = arguments.gender
    ctx:answer('Пол установлен ✅')
    editView(ctx, render.profile(user, ctx:getChat()))
    return
  end

  -- Команда смены пола: перезапись разрешена.
  if arguments.action == 'change' then
    if not render.isGender(arguments.gender) then
      ctx:answer({
        text = 'Неизвестный пол',
        show_alert = true
      })

      return
    end

    local _, err = usersService.update({ gender = arguments.gender }, { id = owner })
    if err then
      log.error(err)

      ctx:answer({
        text = 'Не удалось сохранить пол',
        show_alert = true
      })

      return
    end

    ctx:answer('Пол изменён ✅')

    bot:editMessageText({
      chat_id = ctx:getChatId(),
      message_id = ctx:getMessageId(),
      text = '✅ <b>Пол изменён:</b> '..(render.genderLabel(arguments.gender) or arguments.gender),
    })
    return
  end
end

return command
