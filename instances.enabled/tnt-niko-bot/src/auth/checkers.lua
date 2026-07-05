--- Атомарные чекеры прав.
--
-- Используются как из preCallCommand (entry-level) -
-- так и из самих команд (target-level для /ban, /mute, /promote и т.п.).
--
local config = require('conf.config')
local chat_member_status = require('bot.enums.chat_member_status')
local rolesMod = require('src.auth.roles')
local roleOfClassify = require('src.auth.roleOf')

local roles = rolesMod.roles
local rank = rolesMod.rank

--- Создатель бота (global, не chat-role).
local function isBotOwner(user)
  return user ~= nil and user.id == config.admin_id
end

--- Иерархическая роль пользователя в чате.
-- Если uic нет (бот не знает юзера в этом чате) -> MEMBER.
local function roleOf(uic)
  if uic == nil then
    return roles.MEMBER
  end

  return roleOfClassify(uic.status, uic.permissions)
end

--- Роль пользователя >= минимальной требуемой.
-- VOICE_MODERATOR в иерархии не участвует - для него см. isVoiceMod.
local function hasRoleAtLeast(uic, minRole)
  local userRank = rank[roleOf(uic)]
  local minRank = rank[minRole]

  if userRank == nil or minRank == nil then
    return false
  end

  return userRank >= minRank
end

--- Пользователь - voice-модератор (управляет видеочатами).
-- Отдельная ось, может комбинироваться с любой иерархической ролью.
local function isVoiceMod(uic)
  if uic == nil or uic.status ~= chat_member_status.ADMINISTRATOR then
    return false
  end

  local perms = uic.permissions or {}
  return perms.can_manage_video_chats == true
end

--- Проверка конкретного admin-права у пользователя в чате.
-- У creator-а все права true по определению Telegram.
local function hasPerm(uic, permName)
  if uic == nil then
    return false
  end

  if uic.status == chat_member_status.CREATOR then
    return true
  end

  if uic.status ~= chat_member_status.ADMINISTRATOR then
    return false
  end

  local perms = uic.permissions or {}

  return perms[permName] == true
end

--- Может ли actor выполнить действие над target.
-- Используется внутри команд типа /ban, /mute, /promote.
--
-- @param actorUic     UserInChat того, кто выполняет команду
-- @param targetUic    UserInChat того, на ком выполняется
-- @param requiredPerm admin-perm, которое нужно actor-у
local function canActOn(actorUic, targetUic, requiredPerm)
  if not hasPerm(actorUic, requiredPerm) then
    return false
  end

  -- Owner-а тронуть нельзя
  if targetUic and targetUic.status == chat_member_status.CREATOR then
    return false
  end

  -- Строго выше по рангу (равные не могут друг друга)
  local actorRank  = rank[roleOf(actorUic)]  or 0
  local targetRank = rank[roleOf(targetUic)] or 0

  return actorRank > targetRank
end

return {
  isBotOwner =isBotOwner,
  roleOf = roleOf,
  hasRoleAtLeast = hasRoleAtLeast,
  isVoiceMod = isVoiceMod,
  hasPerm = hasPerm,
  canActOn = canActOn,
}
