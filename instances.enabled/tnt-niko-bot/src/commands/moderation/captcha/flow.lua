--- Флоу капчи для новых участников чата.
--
-- start: рестрикт нового участника + сообщение с кнопкой + запись сессии.
-- expire: таймаут - кик (короткий бан, авто-снимается) + чистка.
-- cleanup: юзер вышел/кикнут во время капчи - убрать сообщение и сессию.
--
-- Прохождение (unrestrict по нажатию кнопки) живёт в cb_captcha (init.lua).
--
local log = require('log')
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')
local captchaService = require('src.services.captcha_sessions')
local userMention = require('src.render.userMention')
local missingRightsWarner = require('src.utils.missingRightsWarner')
local tgErrors = require('src.utils.tgErrors')

-- Сколько секунд даём на прохождение капчи
local CAPTCHA_TTL = 120

-- Рестрикт ставим с авто-снятием (TTL + запас на кик джобом): если юзер
-- выйдет из чата посреди капчи и вернётся позже - не застрянет в муте.
local RESTRICT_TTL = CAPTCHA_TTL + 90

-- Длительность бана при таймауте: Telegram снимает его сам, юзер сможет
-- зайти снова и пройти капчу повторно (защита от false positive).
-- Заодно душит юзер-ботов с авто-перезаходом. Не занижать: until_date
-- меньше 30 сек от времени СЕРВЕРОВ Telegram - бан навсегда, нужен
-- запас на рассинхрон часов.
local KICK_BAN_SECONDS = 300

local READ_ONLY_PERMS = {
  can_send_messages = false,
  can_send_audios = false,
  can_send_documents = false,
  can_send_photos = false,
  can_send_videos = false,
  can_send_video_notes = false,
  can_send_voice_notes = false,
  can_send_polls = false,
  can_send_other_messages = false,
  can_add_web_page_previews = false,
  can_change_info = false,
  can_invite_users = false,
  can_pin_messages = false,
  can_manage_topics = false,
}

local FULL_PERMS = {
  can_send_messages = true,
  can_send_audios = true,
  can_send_documents = true,
  can_send_photos = true,
  can_send_videos = true,
  can_send_video_notes = true,
  can_send_voice_notes = true,
  can_send_polls = true,
  can_send_other_messages = true,
  can_add_web_page_previews = true,
  can_change_info = true,
  can_invite_users = true,
  can_pin_messages = true,
  can_manage_topics = true,
}

local CAPTCHA_TEMPLATE = [[
🤖 <b>Проверка на бота</b>
${sep}
${user}, добро пожаловать!
Нажми кнопку ниже в течение ${ttl} мин, иначе я тебя выгоню.
]]

--- Удаление сообщения с капчей (ошибки тихо: могли удалить руками).
local function deleteCaptchaMessage(chatId, messageId)
  if not messageId or messageId == 0 then
    return
  end

  local _, err = bot:deleteMessage({
    chat_id = chatId,
    message_id = messageId,
  })

  if err then
    log.verbose(err)
  end
end

local M = {
  CAPTCHA_TTL = CAPTCHA_TTL,
  FULL_PERMS = FULL_PERMS,
  deleteCaptchaMessage = deleteCaptchaMessage,
}

--- Запуск капчи для нового участника: рестрикт + кнопка + сессия.
-- @tparam table chat сырой Telegram-чат
-- @tparam table user новый участник
-- @tparam boolean greet слать ли приветствие после прохождения
-- @treturn boolean true - капча запущена (приветствие отложить до прохождения)
function M.start(chat, user, greet)
  -- Защита от повторной доставки апдейта (retry вебхука и т.п.):
  -- по юзеру уже висит свежая капча - вторую не шлём. Протухшую
  -- (job мог не успеть) перезапускаем заново.
  local existing, readErr = captchaService.read(chat.id, user.id)

  if readErr then
    log.error(readErr)
  end

  if existing and (os.time() - existing.created.timestamp) < CAPTCHA_TTL then
    return true
  end

  -- Сначала рестрикт: если не вышло (нет прав, юзер - админ) -
  -- капча без ограничения бессмысленна, сообщение не шлём.
  local _, restrictErr = bot:restrictChatMember({
    chat_id = chat.id,
    user_id = user.id,
    permissions = READ_ONLY_PERMS,
    until_date = os.time() + RESTRICT_TTL,
  })

  if restrictErr then
    log.verbose(restrictErr)
    missingRightsWarner.handleApiError(restrictErr, chat.id)
    return false
  end

  local keyboard = inlineCallbackKeyboard({
    {
      text = '✅ Я не бот',
      callback = {
        command = 'cb_captcha',
        arguments = {
          user_id = tostring(user.id),
        },
      },
    },
  })

  local sent, sendErr = bot:sendMessage({
    chat_id = chat.id,
    text = CAPTCHA_TEMPLATE:f({
      sep = hdec.sep,
      user = userMention(user),
      ttl = math.floor(CAPTCHA_TTL / 60),
    }),
    reply_markup = keyboard,
  })

  if sendErr then
    -- Сообщение не ушло - юзер не сможет пройти капчу. Снимаем рестрикт,
    -- иначе он застрянет замученным навсегда.
    log.error(sendErr)

    bot:restrictChatMember({
      chat_id = chat.id,
      user_id = user.id,
      permissions = FULL_PERMS,
    })

    return false
  end

  local _, upsertErr = captchaService.upsert({
    chat_id = chat.id,
    user_id = user.id,
    message_id = sent.message_id,
    greet = greet == true,
  })

  if upsertErr then
    log.error(upsertErr)
  end

  return true
end

--- Таймаут капчи: кик (короткий бан) + удаление сообщения и сессии.
-- @tparam table session модель captcha_session
function M.expire(session)
  -- Атомарно забираем сессию ПЕРЕД киком: если её уже нет - юзер успел
  -- нажать кнопку между listExpired и этим вызовом, банить нельзя.
  -- Заодно если кик не удастся (нет прав), не долбим Telegram на каждом
  -- тике - юзер останется замученным до истечения рестрикта.
  local taken, takeErr = captchaService.take(session.chat_id, session.user_id)

  if takeErr then
    log.error(takeErr)
    return
  end

  if not taken then
    return
  end

  deleteCaptchaMessage(session.chat_id, session.message_id)

  local _, banErr = bot:banChatMember({
    chat_id = session.chat_id,
    user_id = session.user_id,
    until_date = os.time() + KICK_BAN_SECONDS,
  })

  if banErr then
    log.verbose(banErr)

    if tgErrors.isIgnorable(banErr) then
      return
    end

    missingRightsWarner.handleApiError(banErr, session.chat_id)
  end
end

--- Юзер вышел/кикнут во время капчи: убрать сообщение и сессию.
-- @tparam number chatId id чата
-- @tparam number userId id пользователя
function M.cleanup(chatId, userId)
  local session, takeErr = captchaService.take(chatId, userId)

  if takeErr then
    log.error(takeErr)
    return
  end

  if not session then
    return
  end

  deleteCaptchaMessage(chatId, session.message_id)
end

return M
