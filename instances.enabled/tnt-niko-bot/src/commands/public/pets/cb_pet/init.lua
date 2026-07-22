--- Callback питомцев: карточка, уход (корм/лечение/купание/игра), удаление.
-- Всё над питомцами вызвавшего (command.user) - чужими не поуправляешь.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.pets.render')
local petsService = require('src.services.pets')

local command = Command:new({
  commands = { 'cb_pet' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action', 'pet' },
})

local CARE_ACTIONS = { feed = true, heal = true, bathe = true, play = true }

--- Показать экран (всегда фото) через editMessageMedia.
local function showView(ctx, view)
  if not view then
    return
  end

  local _, err = bot:editMessageMedia({
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    media = {
      type = 'photo',
      media = view.image,
      caption = view.caption,
      parse_mode = 'HTML',
    },
    reply_markup = view.keyboard,
  })

  if err then
    log.verbose(err)
  end
end

--- Показать карточку (или экран "питомца нет"). mode: nil|'manage'|'confirm'.
local function showCard(ctx, id, owner, mode)
  local view, err = render.card(id, owner, mode)
  if err then
    log.error(err)
    return
  end

  if view.gone then
    showView(ctx, render.gone())
  else
    showView(ctx, view)
  end
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local args = command.arguments
  local action = args.action
  local petId = tonumber(args.pet)
  local owner = command.user.id

  -- Возврат к списку.
  if action == 'list' then
    ctx:answer()

    local view, err = render.list(owner)
    if err then
      log.error(err)
      return
    end

    if view.empty then
      showView(ctx, render.emptyList())
    else
      showView(ctx, view)
    end
    return
  end

  if petId == nil then
    ctx:answer()
    return
  end

  -- Уход.
  if CARE_ACTIONS[action] then
    local result, err = petsService.care(petId, owner, action)
    if err then
      log.error(err)
      ctx:answer({ text = 'Ошибка, попробуй ещё', show_alert = true })
      return
    end

    ctx:answer({ text = render.careMessage(result), show_alert = true })

    if result.status == 'gone' then
      showView(ctx, render.gone())
      return
    end

    -- Параметры/состояние изменились - обновляем карточку.
    if result.status == 'ok' then
      showCard(ctx, petId, owner)
    end
    return
  end

  -- Управление и удаление.
  if action == 'manage' then
    ctx:answer()
    showCard(ctx, petId, owner, 'manage')
    return
  end

  -- Переименование: ввод имени идёт командой (callback текст не собирает),
  -- поэтому подсказываем готовую команду с ID питомца.
  if action == 'rename' then
    ctx:answer({
      text = 'Сменить кличку: отправь сообщением\n\nкличка '..petId..' Новое имя',
      show_alert = true,
    })
    return
  end

  if action == 'del' then
    ctx:answer()
    showCard(ctx, petId, owner, 'confirm')
    return
  end

  if action == 'delyes' then
    local _, err = petsService.delete(petId, owner)
    if err then
      log.error(err)
      ctx:answer()
      return
    end

    ctx:answer('❌ Удалён')
    showView(ctx, render.deleted())
    return
  end

  -- show и всё прочее - карточка.
  ctx:answer()
  showCard(ctx, petId, owner)
end

return command
