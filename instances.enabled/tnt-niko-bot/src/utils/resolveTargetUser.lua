--- Поиск пользователя в БД по user_id или username.
--
-- Используется командами /mkvip, /mute и т.п. для разрешения таргета,
-- который пользователь указал в аргументах.
--
local usersService = require('src.services.users')

--- @tparam table query { user_id = number?, username = string? }
--   username ожидается без '@' и в нижнем регистре (нормализация на стороне вызывающего)
-- @treturn[1] table user, nil - найден
-- @treturn[2] table nil, nil - не передан таргет или пользователь отсутствует в БД
-- @treturn[3] table nil, err - ошибка чтения
local function resolveTargetUser(query)
  if query.user_id then
    return usersService.read(query.user_id)
  end

  if query.username then
    return usersService.readByUsername(query.username)
  end

  return nil, nil
end

return resolveTargetUser
