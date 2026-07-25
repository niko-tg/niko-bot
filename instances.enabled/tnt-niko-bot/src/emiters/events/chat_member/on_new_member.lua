--- Новый участник чата.
--
-- 1. Upsert uic для записи факта членства.
-- 2. Ensure chat (на случай если чат был ранее неизвестен).
-- 3. Если включена капча (has_enable_captcha) и юзер пришёл извне -
--    рестрикт + кнопка "Я не бот" (см. commands/moderation/captcha).
-- 4. Если в чате включено приветствие (has_enable_hello_message) и
--    есть запись в hello_message - отправляем его, НО только реально
--    новым юзерам (см. ниже про определение). При активной капче
--    приветствие откладывается до её прохождения (шлёт cb_captcha).
--
-- Кого считаем "реально новым":
--   * old.status == 'left' (Telegram использует left и для впервые
--     добавленного, и для вернувшегося)
--   * И в нашей БД до этого события не было uic для этого юзера в этом чате
-- Если хоть одно условие не выполнено - юзер уже был, приветствие не шлём.
--
-- Капча же ловит любой вход извне (left/kicked -> member): вернувшийся
-- юзер-бот ничем не лучше нового. Переходы внутри чата (unmute:
-- restricted -> member тоже эмитит NEW_MEMBER) капчу не трогают.
--
local log = require('log')
local chat_member_status = require('bot.enums.chat_member_status')
local uicService = require('src.services.user_in_chat')
local chatService = require('src.services.chats')
local sendHelloMessage = require('src.utils.sendHelloMessage')
local captchaFlow = require('src.commands.moderation.captcha.flow')

-- luacheck: ignore ctx
--- Новый участник чата.
-- @tparam table ctx контекст обновления
local function onNewMember(ctx)
  log.verbose('[event] %s', 'on_new_member')

  local chat = ctx:getChat()
  local newChatMember = ctx:getNewChatMember()
  local user = newChatMember.user
  local oldStatus = ctx:getOldChatMemberStatus()

  -- Снимок: была ли у нас запись до этого события (нужно ДО upsert)
  local existingUic, existingErr = uicService.read(chat.id, user.id)

  if existingErr then
    log.error(existingErr)
  end

  -- Запись user_in_chat
  --
  local _, err = uicService.upsert({
    chat_id = chat.id,
    user_id = user.id,
    status = newChatMember.status,
    permissions = {},
  })

  if err then
    log.error(err)
  end
  --

  -- На случай если чат был ранее неизвестен
  --
  local chatItem, chatErr = chatService.ensure(chat)

  if chatErr then
    log.error(chatErr)
    return
  end
  --

  -- Ботов не трогаем: капчу они не пройдут (добавил их админ),
  -- приветствие им не шлём
  if user.is_bot then
    return
  end

  local settings = chatItem and chatItem.settings or {}

  -- Пришёл извне (реальный вход, а не unmute и т.п.)
  local joinedFromOutside = oldStatus == chat_member_status.LEFT
    or oldStatus == chat_member_status.KICKED

  -- "Реально новый": Telegram говорит, что юзера не было (left), и
  -- у нас в БД его тоже не было. Иначе - вернулся / был и т.п.
  local isReallyNew = oldStatus == chat_member_status.LEFT
    and existingUic == nil

  -- Приветствие положено только реально новым (и если включено)
  local shouldGreet = settings.has_enable_hello_message == true
    and isReallyNew

  -- Капча: рестрикт + кнопка. Если запустилась - приветствие отложено
  -- до прохождения (его отправит cb_captcha по флагу greet сессии).
  if settings.has_enable_captcha and joinedFromOutside then
    local started = captchaFlow.start(chat, user, shouldGreet)

    if started then
      return
    end
  end

  if not shouldGreet then
    return
  end

  sendHelloMessage(chat, user)
end

return onNewMember
