--- Флоу капчи для новых участников чата.
--
-- start: рестрикт нового участника + картинка с символами + запись сессии.
-- Юзер должен нажать кнопки с символами картинки по порядку - одну кнопку
-- юзер-боты жмут сами, последовательность из картинки требует распознавания.
-- retry: новая картинка и ответ (после ошибки или по кнопке обновления).
-- expire: таймаут - кик (короткий бан, авто-снимается) + чистка.
-- cleanup: юзер вышел/кикнут во время капчи - убрать сообщение и сессию.
--
-- Обработка нажатий символов живёт в cb_captcha (init.lua).
--
local log = require('log')
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local captcha = require('cairo-luajit-ffi.ext.captcha')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')
local captchaService = require('src.services.captcha_sessions')
local userMention = require('src.render.userMention')
local missingRightsWarner = require('src.utils.missingRightsWarner')
local tgErrors = require('src.utils.tgErrors')

-- Сколько секунд даём на прохождение капчи
local CAPTCHA_TTL = 120 * 2

-- Рестрикт ставим с авто-снятием (TTL + запас на кик джобом):
-- Если юзер выйдет из чата посреди капчи и вернётся позже - не застрянет в муте.
local RESTRICT_TTL = CAPTCHA_TTL + 90

-- Длительность бана при таймауте: Telegram снимает его сам, юзер сможет зайти снова
-- и пройти капчу повторно (защита от false positive).
-- Заодно душит юзер-ботов с авто-перезаходом.
-- Не занижать: until_date меньше 30 сек от времени СЕРВЕРОВ Telegram - бан навсегда,
-- нужен запас на рассинхрон часов.
local KICK_BAN_SECONDS = 300

-- Попыток на прохождение: ошибка - минус попытка и новая картинка
local ATTEMPTS = 3

-- Символов в ответе капчи
local ANSWER_LENGTH = 3

-- Кнопок с символами на клавиатуре (ответ + приманки), сетка 3x3
local KEYBOARD_SIZE = 9

-- Кнопок в ряду клавиатуры
local KEYBOARD_ROW = 3

-- Алфавит без визуально похожих символов (0/O, 1/I) и без строчных:
-- на искажённой картинке S/s и C/c неразличимы, страдает человек, не бот
local ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'

-- Псевдо-символ кнопки обновления картинки (попытку не тратит)
local REFRESH = 'refresh'

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
Нажми <b>по порядку</b> символы с картинки.
Попыток: ${attempts}. Время: ${ttl} мин.
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

--- Генерация задания: ответ и клавиатура символов.
-- Из алфавита берутся KEYBOARD_SIZE уникальных символов, первые
-- ANSWER_LENGTH - ответ. На кнопках те же символы, перемешанные заново.
-- @tparam number userId id проверяемого (уходит в callback кнопок)
-- @treturn string ответ - символы, которые нужно нажать по порядку
-- @treturn table inline-клавиатура
local function makeChallenge(userId)
  -- Частичный Фишер-Йетс: первые KEYBOARD_SIZE символов уникальны
  local chars = {}
  for i = 1, #ALPHABET do
    chars[i] = ALPHABET:sub(i, i)
  end
  for i = 1, KEYBOARD_SIZE do
    local j = math.random(i, #chars)
    chars[i], chars[j] = chars[j], chars[i]
  end

  local answer = table.concat(chars, '', 1, ANSWER_LENGTH)

  -- Кнопки: те же символы, перемешанные отдельно -
  -- иначе первые кнопки клавиатуры совпадали бы с ответом
  local buttons = {}
  for i = 1, KEYBOARD_SIZE do
    buttons[i] = chars[i]
  end
  for i = 1, KEYBOARD_SIZE do
    local j = math.random(i, KEYBOARD_SIZE)
    buttons[i], buttons[j] = buttons[j], buttons[i]
  end

  local layout = {}
  local row
  for i = 1, KEYBOARD_SIZE do
    if (i - 1) % KEYBOARD_ROW == 0 then
      row = {}
      table.insert(layout, row)
    end

    table.insert(row, {
      text = buttons[i],
      callback = {
        command = 'cb_captcha',
        arguments = {
          user_id = tostring(userId),
          symbol = buttons[i],
        },
      },
    })
  end

  table.insert(layout, {
    {
      text = '🔄 Другая картинка',
      callback = {
        command = 'cb_captcha',
        arguments = {
          user_id = tostring(userId),
          symbol = REFRESH,
        },
      },
    },
  })

  return answer, inlineCallbackKeyboard(layout)
end

--- Отправка сообщения капчи: картинка + клавиатура символов.
-- @tparam number chatId id чата
-- @tparam table user проверяемый юзер
-- @tparam number attempts оставшиеся попытки (для текста)
-- @treturn[1] table sent отправленное сообщение
-- @treturn[1] string answer ответ капчи
-- @treturn[2] nil, nil, table err
local function sendCaptchaMessage(chatId, user, attempts)
  local answer, keyboard = makeChallenge(user.id)

  local image = captcha.new({ text = answer })
  local png = image:pngString()
  image:destroy()

  local sent, err = bot.sendImage({
    chat_id = chatId,
    photo = {
      data = png,
      filename = 'captcha.png',
    },
    caption = CAPTCHA_TEMPLATE:f({
      sep = hdec.sep,
      user = userMention(user),
      attempts = attempts,
      ttl = math.floor(CAPTCHA_TTL / 60),
    }),
    reply_markup = keyboard,
  })

  if err then
    return nil, nil, err
  end

  return sent, answer
end

local M = {
  CAPTCHA_TTL = CAPTCHA_TTL,
  ATTEMPTS = ATTEMPTS,
  REFRESH = REFRESH,
  FULL_PERMS = FULL_PERMS,
  deleteCaptchaMessage = deleteCaptchaMessage,
}

--- Запуск капчи для нового участника: рестрикт + картинка + сессия.
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

  local sent, answer, sendErr = sendCaptchaMessage(chat.id, user, ATTEMPTS)

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
    answer = answer,
    progress = 0,
    attempts = ATTEMPTS,
  })

  if upsertErr then
    log.error(upsertErr)
  end

  return true
end

--- Новая картинка и ответ: после ошибки либо по кнопке обновления.
-- created сессии не трогается - обновлениями капчу не продлить.
-- @tparam number chatId id чата
-- @tparam table user проверяемый юзер
-- @tparam table session текущая модель captcha_session
-- @tparam number attempts оставшиеся попытки
-- @treturn boolean true - картинка заменена
function M.retry(chatId, user, session, attempts)
  local sent, answer, sendErr = sendCaptchaMessage(chatId, user, attempts)

  if sendErr then
    log.error(sendErr)
    return false
  end

  local updated, updateErr = captchaService.update(chatId, user.id, {
    message_id = sent.message_id,
    answer = answer,
    progress = 0,
    attempts = attempts,
  })

  if updateErr then
    log.error(updateErr)
  end

  -- Сессию уже забрали (успех/таймаут) - новое сообщение осиротело
  if not updated then
    deleteCaptchaMessage(chatId, sent.message_id)
    return false
  end

  deleteCaptchaMessage(chatId, session.message_id)

  return true
end

--- Наказание за непройденную капчу: удаление сообщения + кик (короткий бан).
-- Вызывается с уже забранной (take) сессией.
-- @tparam table session модель captcha_session
function M.punish(session)
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

--- Таймаут капчи: кик (короткий бан) + удаление сообщения и сессии.
-- @tparam table session модель captcha_session
function M.expire(session)
  -- Атомарно забираем сессию ПЕРЕД киком: если её уже нет - юзер успел пройти капчу
  -- между listExpired и этим вызовом, банить нельзя.
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

  M.punish(taken)
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
