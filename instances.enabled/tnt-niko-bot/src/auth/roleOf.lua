--- Классификация пользователя в иерархическую роль.
--
-- Возвращает одну из: OWNER / ADMIN / MODERATOR / MEMBER.
-- VOICE_MODERATOR здесь не возвращается - это отдельная ось,
-- см. checkers.isVoiceMod.
--
-- Принцип: чем больше прав, тем выше роль.
-- Пробелы (admin-статус без значимых прав, e.g. только can_invite_users) -> MEMBER.
--
local chat_member_status = require('bot.enums.chat_member_status')
local roles = require('src.auth.roles').roles

local function roleOf(status, perms)
  if status == chat_member_status.CREATOR then
    return roles.OWNER
  end

  if status ~= chat_member_status.ADMINISTRATOR then
    return roles.MEMBER
  end

  perms = perms or {}

  if perms.can_restrict_members then
    return roles.ADMIN
  end

  if perms.can_manage_chat then
    return roles.MODERATOR
  end

  return roles.MEMBER
end

return roleOf
