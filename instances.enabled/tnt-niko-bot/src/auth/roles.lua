--- Роли пользователя в чате
--
-- OWNER/ADMIN/MODERATOR/MEMBER образуют иерархию (см. rank).
-- VOICE_MODERATOR - отдельная ось, не сравнивается через rank,
-- проверяется через checkers.isVoiceMod.
--
local roles = {
  OWNER           = 'owner',
  ADMIN           = 'admin',
  MODERATOR       = 'moderator',
  MEMBER          = 'member',
  VOICE_MODERATOR = 'voice_moderator',
}

local rank = {
  [roles.OWNER]     = 4,
  [roles.ADMIN]     = 3,
  [roles.MODERATOR] = 2,
  [roles.MEMBER]    = 1,
}

return {
  roles = roles,
  rank  = rank,
}
