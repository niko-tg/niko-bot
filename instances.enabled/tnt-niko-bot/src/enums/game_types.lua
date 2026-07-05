--- Типы PVP мини-игр на Telegram dice.
--
local GAMES = {
  { key = 'football',   emoji = '⚽', name = 'Футбол' },
  { key = 'basketball', emoji = '🏀', name = 'Баскетбол' },
  { key = 'bowling',    emoji = '🎳', name = 'Боулинг' },
  { key = 'darts',      emoji = '🎯', name = 'Дартс' },
  { key = 'dice',       emoji = '🎲', name = 'Кубик' },
}

local M = {
  -- list - упорядочено для меню
  list = GAMES,
  MAX_STEPS = 3,
  SESSION_TTL = 5 * 60,
  -- byKey/byEmoji - для поиска
  byKey = {},
  byEmoji = {},
}

for _, game in ipairs(GAMES) do
  M.byKey[game.key] = game
  M.byEmoji[game.emoji] = game
end

return M
