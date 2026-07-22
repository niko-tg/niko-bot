--- Антифлуд сообщений в чате (для каждого пользователя отдельно).
--
-- Когда детектор сообщает что юзер флудит - ограничиваем его в чате
-- на время, которое растёт с каждым нарушением:
--   1-е нарушение - 1 минута
--   2-е           - 5 минут
--   3-е           - 15 минут
--   4+            - 1 час
-- Если за 24 часа новых нарушений не было - счётчик сбрасывается.
--
-- Кого не трогаем:
--   * настройка чата выключена
--   * сообщение от имени канала (нет обычного юзера) - этим занимается
--     отдельный фильтр has_ban_sender_chat
--   * боты
--   * создатель бота
--   * админы чата по статусу телеграма (creator/administrator) -
--     даже если наша роль ниже, телеграм всё равно не даст их ограничить
--   * альбомы из нескольких фото (media_group) - юзер один раз
--     выбрал N картинок, это не флуд
--
local log = require('log')
local bot = require('bot')
local fiber = require('fiber')
local hdec = require('bot.libs.hdec')
local auth = require('src.auth')
local chat_member_status = require('bot.enums.chat_member_status')
local userInChatService = require('src.services.user_in_chat')
local antifloodLimiter = require('src.utils.antifloodLimiter')
local missingRightsWarner = require('src.utils.missingRightsWarner')
local tgErrors = require('src.utils.tgErrors')

local DECAY_SECONDS = 24 * 60 * 60
local DURATIONS = { 60, 5 * 60, 15 * 60, 60 * 60 }
local DURATION_LABELS = { '1 мин', '5 мин', '15 мин', '1 ч' }

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

local NOTIFICATION_TEMPLATE = [[
⚠️ Ограничение чата
${sep}
${user} [<code>${user_id}</code>] | Антифлуд, доступ ограничен на <b>${duration}</b>.
]]

--- Возвращает короткую "подпись" сообщения для проверки одинакового
-- содержимого (3 одинаковых стикера/фото/текста подряд = флуд).
-- nil - если не получилось определить (тогда работает только обычный счёт).
local function extractSignature(message)
  if message.sticker then
    return 'sticker:'..message.sticker.file_unique_id
  end

  if message.animation then
    return 'animation:'..message.animation.file_unique_id
  end

  if message.photo then
    return 'photo:'..message.photo[#message.photo].file_unique_id
  end

  if message.video then
    return 'video:'..message.video.file_unique_id
  end

  if message.voice then
    return 'voice:'..message.voice.file_unique_id
  end

  if message.audio then
    return 'audio:'..message.audio.file_unique_id
  end

  if message.document then
    return 'document:'..message.document.file_unique_id
  end

  local text = message.text or message.caption
  if text then
    return 'text:'..text:sub(1, 32)
  end

  return nil
end

--- Возвращает true если юзера ограничили в чате - дальше другие
-- фильтры/обработчики делать не нужно, сообщение и так не пройдёт.
local function antifloodCheck(ctx, chatItem)
  local settings = chatItem.settings or {}

  if not settings.has_enable_antiflood then
    return false
  end

  -- Альбом из нескольких фото приходит как несколько сообщений
  -- с одинаковым media_group_id - это не флуд.
  if ctx.message.media_group_id then
    return false
  end

  -- Если нет обычного юзера (пишет канал) - этим занимается
  -- другой фильтр has_ban_sender_chat. Ботов тоже пропускаем.
  local user = ctx:getUserFrom()
  if not user or user.is_bot then
    return false
  end

  if auth.isBotOwner(user) then
    return false
  end

  local chat = ctx:getChat()

  local uic, uicErr = userInChatService.read(chat.id, user.id)

  if uicErr then
    log.error(uicErr)
    return false
  end

  -- Админов чата (creator/administrator) не трогаем - их статус в
  -- телеграме главнее нашей внутренней роли. Даже если по нашим
  -- правилам он считается простым участником, телеграм всё равно
  -- не даст ограничить админа.
  if uic and (uic.status == chat_member_status.CREATOR
    or uic.status == chat_member_status.ADMINISTRATOR) then
    return false
  end

  -- Передаём в детектор время отправки от телеграма (message.date) -
  -- если использовать os.time() обработки, медленный бот даст юзеру
  -- больше окна, чем должен. Подпись (signature) включает второй
  -- признак: 3 одинаковых сообщения за 5 секунд = флуд, даже если
  -- в 1-секундное окно по количеству они не уложились.
  local limiterKey = chat.id..':'..user.id
  local signature = extractSignature(ctx.message)

  if not antifloodLimiter.hit(limiterKey, ctx.message.date, signature) then
    return false
  end

  -- Срабатывание. Растим счётчик нарушений, но если прошлое было
  -- давно (>24ч назад) - начинаем с единицы.
  --
  local now = os.time()
  local prev = uic and uic.antiflood_violations or 0
  local lastTs = uic and uic.antiflood_last_violation or 0

  local violations
  if lastTs > 0 and (now - lastTs) < DECAY_SECONDS then
    violations = prev + 1
  else
    violations = 1
  end

  local durationIdx = math.min(violations, #DURATIONS)
  local duration = DURATIONS[durationIdx]
  local label = DURATION_LABELS[durationIdx]

  -- Сохраняем счётчик в БД. Если запись не пройдёт - ограничение всё
  -- равно ставим, просто следующее нарушение посчитается как первое.
  local _, updErr = userInChatService.update(
    {
      antiflood_violations = violations,
      antiflood_last_violation = now,
    },
    { chat_id = chat.id, user_id = user.id }
  )

  if updErr then
    log.error(updErr)
  end
  --

  -- Запрещаем юзеру писать в чат на нужное время.
  --
  local untilDate = os.time() + duration

  local _, restrictErr = bot:restrictChatMember({
    chat_id = chat.id,
    user_id = user.id,
    permissions = READ_ONLY_PERMS,
    until_date  = untilDate,
  })

  if restrictErr then
    if tgErrors.isIgnorable(restrictErr) then
      log.verbose(restrictErr)
    else
      log.verbose(restrictErr)
      missingRightsWarner.handleApiError(restrictErr, chat.id)
    end

    return false
  end
  --

  -- Шлём уведомление в чат
  --
  fiber.sleep(1)

  bot:sendMessage({
    chat_id = chat.id,
    text = NOTIFICATION_TEMPLATE:f({
      user = hdec.user(user),
      user_id = user.id,
      duration = label,
      sep = hdec.sep,
    }),
  })
  --

  return true
end

return antifloodCheck
