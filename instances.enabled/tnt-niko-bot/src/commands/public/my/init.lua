--- Личное меню: "мой брак" / "мои друзья" / "мои питомцы". Диспетчер по второму
--- слову; переиспользует рендеры одноимённых команд.
--
local log = require('log')
local bot = require('bot')
local utf8 = require('utf8')
local Command = require('bot.classes.Command')
local marriageRender = require('src.commands.public.marriage.render')
local friendsRender = require('src.commands.public.friends.render')
local petsRender = require('src.commands.public.pets.render')

local command = Command:new {
  commands = { '/my', 'мой', 'мои' },
  flags = {
    Command.enum.PUBLIC,
    Command.enum.NO_REPLY
  },
}

-- Брак: карточка (как команда "брак").
local function showMarriage(ctx, userId)
  local view, err = marriageRender.card(userId)
  if err then
    log.error(err)
    return
  end

  if not view then
    return
  end

  ctx:replyToMessage({ text = view.text, reply_markup = view.keyboard })
end

-- Друзья: список (как команда "друзья").
local function showFriends(ctx, userId)
  local view, err = friendsRender.list(userId, 1)
  if err then
    log.error(err)
    return
  end

  if not view then
    return
  end

  ctx:replyToMessage({ text = view.text, reply_markup = view.keyboard })
end

-- Питомцы: фото-список (как команда "питомцы").
local function showPets(ctx, userId)
  local view, err = petsRender.list(userId)
  if err then
    log.error(err)
    return
  end

  if view.empty then
    ctx:replyToMessage(petsRender.missing())
    return
  end

  bot:sendPhoto({
    chat_id = ctx:getChatId(),
    photo = view.image,
    caption = view.caption,
    reply_markup = view.keyboard,
    reply_parameters = { message_id = ctx:getMessageId() },
  })
end

-- Подкоманда (второе слово) -> обработчик. Род слова не важен.
local DISPATCH = {
  ['брак']    = showMarriage,
  ['друзья']  = showFriends,
  ['питомцы'] = showPets,
}

function command.call(ctx)
  local what = ctx:getArguments({ count = 2 })[2]
  if not what then
    return
  end

  local handler = DISPATCH[utf8.lower(what)]

  -- Неизвестное второе слово - молча выходим: "мой"/"мои" частые слова,
  -- нельзя отвечать на обычные сообщения вроде "мои планы на день".
  if handler then
    handler(ctx, command.user.id)
  end
end

return command
