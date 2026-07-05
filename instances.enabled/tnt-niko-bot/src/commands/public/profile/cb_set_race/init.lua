--- Установка/смена расы (callback): меню, превью с описанием, коммит.
--
local log = require('log')
local bot = require('bot')
local races = require('src.dict.races')
local Command = require('bot.classes.Command')
local usersService = require('src.services.users')
local render = require('src.commands.public.profile.render')

local command = Command:new {
  commands = { 'cb_set_race' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action', 'race', 'owner', 'mode' },
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

-- Экран выбора расы для режима: change -> приглашение команды, иначе профиль.
local function choiceView(ctx, user, mode)
  if mode == 'change' then
    return {
      text = render.CHANGE_PROMPT,
      keyboard = render.raceChoiceKeyboard(user.id, 'change'),
    }
  end

  return render.profile(user, ctx:getChat(), { raceChoice = true })
end

-- Запись расы. true при успехе, иначе отвечает алертом.
local function saveRace(ctx, owner, raceKey)
  if not render.isRace(raceKey) then
    ctx:answer({ text = 'Неизвестная раса', show_alert = true })
    return false
  end

  local _, err = usersService.update({ race = raceKey }, { id = owner })
  if err then
    log.error(err)
    ctx:answer({ text = 'Не удалось сохранить расу', show_alert = true })
    return false
  end

  return true
end

function command.call(ctx)
  local arguments = command.arguments
  local owner = tonumber(arguments.owner)
  local mode = arguments.mode

  -- Кнопки - только для владельца (command.user == нажавший).
  if command.user.id ~= owner then
    ctx:answer({ text = 'Это не твой профиль 🙃', show_alert = true })
    return
  end

  local user = command.user

  -- Показать выбор расы (из профиля) либо вернуться к нему из превью.
  if arguments.action == 'menu' or arguments.action == 'back' then
    ctx:answer()
    editView(ctx, choiceView(ctx, user, mode))
    return
  end

  -- Превью расы (промежуточный экран с описанием).
  if arguments.action == 'preview' then
    if not render.isRace(arguments.race) then
      ctx:answer({ text = 'Неизвестная раса', show_alert = true })
      return
    end

    ctx:answer()
    editView(ctx, render.racePreview(arguments.race, owner, mode))
    return
  end

  -- Профиль: первичная установка - ОДНОРАЗОВАЯ (раса неизменяема).
  if arguments.action == 'set' then
    if user.race ~= box.NULL then
      ctx:answer({ text = 'Раса уже установлена 🔒', show_alert = true })
      editView(ctx, render.profile(user, ctx:getChat()))
      return
    end

    if not saveRace(ctx, owner, arguments.race) then
      return
    end

    user.race = arguments.race
    ctx:answer('Раса установлена ✅')
    editView(ctx, render.profile(user, ctx:getChat()))
    return
  end

  -- Команда смены расы: перезапись разрешена.
  if arguments.action == 'change' then
    if not saveRace(ctx, owner, arguments.race) then
      return
    end

    user.race = arguments.race
    ctx:answer('Раса изменена ✅')

    bot:editMessageText({
      chat_id = ctx:getChatId(),
      message_id = ctx:getMessageId(),
      text = '✅ <b>Раса изменена:</b> '..races[arguments.race].description,
    })
    return
  end
end

return command
