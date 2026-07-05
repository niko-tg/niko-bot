--- Модуль проверки прав.
--
-- Использование:
--   local auth = require('src.auth')
--   auth.isBotOwner(user)
--   auth.hasRoleAtLeast(uic, auth.roles.MODERATOR)
--   auth.isVoiceMod(uic)
--   auth.hasPerm(uic, 'can_restrict_members')
--   auth.canActOn(actor_uic, target_uic, 'can_restrict_members')
--
local roles_mod = require('src.auth.roles')
local checkers = require('src.auth.checkers')

local M = {}

for k, v in pairs(checkers) do
  M[k] = v
end

M.roles = roles_mod.roles
M.rank  = roles_mod.rank

return M
