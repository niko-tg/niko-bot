--- Синхронизация стафа чата из Telegram getChatAdministrators.
--
-- Делает три вещи:
--   1. Upsert юзеров (users) и uic для каждого admin/creator из ответа Telegram.
--   2. Reconciliation: тех, кого мы знали как admin/creator, но в ответе их нет,
--      помечаем status='unknown' и зануляем permissions. Точный статус
--      (member/left/kicked/restricted) придёт следующим chat_member event.
--   3. Ставит chat.staff_synced = true и сохраняет число участников (getChatMemberCount).
--
-- Ботов из ответа пропускаем (бот сам не должен числиться в стафе для UI).
--
local log = require('log')
local bot = require('bot')
local chat_member_status = require('bot.enums.chat_member_status')
local Permissions = require('src.models.Permissions')
local usersService = require('src.services.users')
local userInChatService = require('src.services.user_in_chat')
local chatService = require('src.services.chats')

--- Запускает sync. Result всегда non-nil (с пустыми массивами при ошибке).
-- @return result (table) { synced = {user, ...}, demoted = {user, ...} }
-- @return err    (table|nil)
local function syncChatStaff(chatId)
  local result = {
    synced  = {},  -- user-объекты из Telegram-ответа (свежие данные)
    demoted = {},  -- user-записи из БД (потерянные при data drift пропускаются)
  }

  -- Получение всех админов чата
  local response, err = bot:getChatAdministrators({ chat_id = chatId })

  if err then
    return result, err
  end

  local members = response.result or {}

  -- 1. Снимок текущих admin/owner в БД для reconciliation
  local existing = {}

  local owners, ownerErr = userInChatService.getByStatus(chatId, chat_member_status.CREATOR)
  if ownerErr then
    return result, ownerErr
  end

  local admins, adminErr = userInChatService.getByStatus(chatId, chat_member_status.ADMINISTRATOR)
  if adminErr then
    return result, adminErr
  end

  for _, uic in ipairs(owners or {}) do
    existing[uic.user_id] = true
  end

  for _, uic in ipairs(admins or {}) do
    existing[uic.user_id] = true
  end

  -- 2. Upsert актуальных
  local seen = {}

  for _, member in ipairs(members) do
    local user = member.user

    if user then
      -- Ботов тоже помечаем как seen, чтобы reconciliation их не демоутил.
      -- Статус бота поддерживается через on_bot_admin_promoted/demoted, sync его не трогает.
      seen[user.id] = true

      if not user.is_bot then
        -- Создание/обновление юзера
        local _, userErr = usersService.upsert(user)
        if userErr then
          log.error(userErr)
        end

        local _, uicErr = userInChatService.upsert({
          chat_id = chatId,
          user_id = user.id,
          status = member.status,
          permissions = Permissions(member),
        })

        if uicErr then
          log.error(uicErr)
        else
          table.insert(result.synced, user)
        end
      end
    end
  end

  -- 3. Reconciliation: тех, кого знали как admin/creator, но в ответе их нет,
  -- помечаем UNKNOWN - мы не знаем member они теперь, left, kicked или restricted.
  -- Уточнение придёт следующим chat_member event.
  local emptyPerms = setmetatable({}, { __serialize = 'map' })

  for userId in pairs(existing) do
    if not seen[userId] then
      local _, demoteErr = userInChatService.update(
        {
          status = chat_member_status.UNKNOWN,
          permissions = emptyPerms
        },
        {
          chat_id = chatId,
          user_id = userId
        }
      )

      if demoteErr then
        log.error(demoteErr)
      else
        -- Подтягиваем user-запись для отображения. Если её нет (data drift) - пропускаем.
        local userRecord, userReadErr = usersService.read(userId)

        if userReadErr then
          log.error(userReadErr)
        elseif userRecord then
          table.insert(result.demoted, userRecord)
        end
      end
    end
  end

  -- 4. Маркер первичной синхронизации + актуальное число участников чата.
  local memberCount
  local countResponse, countErr = bot:getChatMemberCount({ chat_id = chatId })
  if countErr then
    log.error(countErr)
  else
    memberCount = countResponse.result
  end

  local chatFields = { staff_synced = true }
  if memberCount ~= nil then
    chatFields.members = math.max(0, memberCount)
  end

  local _, updateErr = chatService.update(chatFields, { id = chatId })

  if updateErr then
    log.error(updateErr)
  end

  return result, nil
end

return syncChatStaff
