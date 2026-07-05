--- Новый участник чата.
--
-- 1. Upsert uic для записи факта членства.
-- 2. Ensure chat (на случай если чат был ранее неизвестен).
-- 3. Если в чате включено приветствие (has_enable_hello_message) и
--    есть запись в hello_message - отправляем его, НО только реально
--    новым юзерам (см. ниже про определение).
--
-- Кого считаем "реально новым":
--   * old.status == 'left' (Telegram использует left и для впервые
--     добавленного, и для вернувшегося)
--   * И в нашей БД до этого события не было uic для этого юзера в этом чате
-- Если хоть одно условие не выполнено - юзер уже был, приветствие не шлём.
--
local log = require('log')
local bot = require('bot')
local chat_member_status = require('bot.enums.chat_member_status')
local uicService = require('src.services.user_in_chat')
local chatService = require('src.services.chats')
local helloMessageService = require('src.services.hello_message')
local formatHelloMessage = require('src.utils.formatHelloMessage')

-- luacheck: ignore ctx
local function on_new_member(ctx)
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

  -- Ботам приветствие не шлём
  if user.is_bot then
    return
  end

  -- Проверка флага в настройках чата
  local settings = chatItem and chatItem.settings or {}

  if not settings.has_enable_hello_message then
    return
  end

  -- "Реально новый": Telegram говорит, что юзера не было (left), и
  -- у нас в БД его тоже не было. Иначе - вернулся / был и т.п.
  local isReallyNew = oldStatus == chat_member_status.LEFT
    and existingUic == nil

  if not isReallyNew then
    return
  end

  -- Чтение приветствия
  --
  local hello, helloErr = helloMessageService.read(chat.id)

  if helloErr then
    log.error(helloErr)
    return
  end

  if not hello then
    return
  end
  --

  -- Отправка
  --
  local method, payload = formatHelloMessage(hello, user, chat)

  local _, sendErr = bot[method](bot, payload)

  if sendErr then
    -- sendMessage/sendPhoto/etc не требует admin-прав, поэтому warner
    -- здесь не нужен. Ошибки тихо: бот мог быть кикнут, флуд-лимит и т.п.
    log.verbose(sendErr)
  end
  --
end

return on_new_member
