--- Обработчик не-команд сообщений в групповых чатах.
--
-- Делает chatService.upsert (актуальные settings + cold-start sync) и
-- прогоняет message через цепочку фильтров. Первый фильтр, который вернул
-- true (consume сообщение), останавливает цепочку.
--
local log = require('log')
local chat_type = require('bot.enums.chat_type')
local chatService = require('src.services.chats')
local userInChatService = require('src.services.user_in_chat')
local usersService = require('src.services.users')
local syncChatStaff = require('src.utils.syncChatStaff')
local tgErrors = require('src.utils.tgErrors')
local antifloodCheck = require('src.utils.antifloodCheck')
local retryTxnConflict = require('src.utils.services.retryTxnConflict')
local banSenderChat = require('src.utils.messageFilters.banSenderChat')
local deleteLinks = require('src.utils.messageFilters.deleteLinks')
local deleteForwardMessage = require('src.utils.messageFilters.deleteForwardMessage')

local IS_GROUP = {
  [chat_type.GROUP] = true,
  [chat_type.SUPERGROUP] = true,
}

-- Кулдаун повторного cold-start sync после ошибки: иначе в чате, где Telegram
-- не отдаёт список админов (скрытые участники и т.п.), getChatAdministrators
-- дёргался бы на каждое сообщение.
local SYNC_RETRY_COOLDOWN = 300
local staffSyncRetryAt = {}  -- chat_id -> os.time(), после которого можно повторить

--- Лог ошибки счётчиков активности.
-- Счётчики - горячие кортежи: кортеж чата и кортеж юзера пишет каждое
-- сообщение. Под MVCC конкурентные апдейты конфликтуют, сервисы их ретраят,
-- но на пике ретраи исчерпываются. Потерянный +1 в счётчике - не сбой,
-- в error-лог такое не пишем.
-- @tparam table|string|cdata err ошибка сервиса
local function logCounterErr(err)
  if retryTxnConflict.isConflict(err) then
    log.verbose(err)
    return
  end

  log.error(err)
end

--- Обработчик не-командных сообщений чата: фильтры и антифлуд.
-- @tparam table ctx контекст обновления
local function onChatMessage(ctx)
  local chat = ctx:getChat()

  if not IS_GROUP[chat.type] then
    return
  end

  -- Подтягиваем актуальный chatItem (settings, staff_synced)
  --
  local chatItem, chatErr = chatService.upsert(chat)

  if chatErr then
    log.error(chatErr)
    return
  end

  if not chatItem then
    return
  end
  --

  -- Учёт активности: считаем сообщение автору (реальный юзер, не бот/канал/аноним).
  local author = ctx:getUserFrom()
  if author and not author.is_bot and not ctx:getSenderChat() then
    local _, incErr = userInChatService.incMessages(chat.id, author.id)
    if incErr then
      logCounterErr(incErr)
    end

    local _, chatIncErr = chatService.incTotalMessages(chat.id)
    if chatIncErr then
      logCounterErr(chatIncErr)
    end

    local _, touchErr = usersService.touchActivity(author.id)
    if touchErr then
      logCounterErr(touchErr)
    end
  end

  -- Cold-start: если стаф ещё не подтягивали, делаем синхронно перед фильтрами,
  -- чтобы role-check фильтров нашёл uic. Ошибку не считаем фатальной.
  --
  if not chatItem.staff_synced then
    local retryAt = staffSyncRetryAt[chat.id]

    if retryAt == nil or os.time() >= retryAt then
      local _, syncErr = syncChatStaff(chat.id)

      if syncErr then
        staffSyncRetryAt[chat.id] = os.time() + SYNC_RETRY_COOLDOWN

        -- Скрытый список участников - ограничение Telegram, не сбой.
        if tgErrors.isMemberListInaccessible(syncErr) then
          log.verbose(syncErr)
        else
          log.error(syncErr)
        end
      else
        staffSyncRetryAt[chat.id] = nil
        chatItem.staff_synced = true
      end
    end
  end
  --

  -- Антифлуд первым: restrict отнимает у юзера право писать,
  -- дальше можно не тратить ресурсы на фильтры.
  if antifloodCheck(ctx, chatItem) then
    return
  end

  -- Цепочка фильтров. Каждый возвращает true если consume-нул сообщение.
  -- Порядок: бан канала идёт первым - это самое жёсткое действие, нет
  -- смысла дальше анализировать сообщение, если канал забанен.
  if banSenderChat(ctx, chatItem) then
    return
  end

  if deleteLinks(ctx, chatItem) then
    return
  end

  if deleteForwardMessage(ctx, chatItem) then
    return
  end
end

return onChatMessage
