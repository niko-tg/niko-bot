--- Упоминание пользователя с учётом приватности.
-- Если у модели is_private = true - возвращаем имя без ссылки (tg://user).
-- Для сырых Telegram-юзеров (нет поля is_private) ссылка показывается как обычно.
--
local hdec = require('bot.libs.hdec')

--- Упоминание пользователя с учётом флага приватности.
-- @tparam table user модель пользователя либо сырой Telegram-юзер
-- @treturn string готовая HTML-разметка
local function userMention(user)
  if user.is_private then
    return hdec.mono(hdec.user(user, { no_link = true }))
  end

  return hdec.user(user)
end

return userMention
