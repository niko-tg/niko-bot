--- Установка стандартных команд бота в меню Telegram (setMyCommands).
-- MAINTENANCE: только владелец. Запускается разово после деплоя.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')

local bot_command_scope = require('bot.enums.bot_command_scope')
local BotCommand = require('bot.types.BotCommand')
local BotCommandScope = require('bot.types.BotCommandScope')

local command = Command:new({
  commands = { '/defcmds' },
  flags = { Command.enum.MAINTENANCE },
})

-- Имена БЕЗ слеша - Telegram требует [a-z0-9_], слеш невалиден.
local PRIVATE_COMMANDS = {
  BotCommand({ 'donat',     '💎 ДОНАТ 💎' }),
  BotCommand({ 'profile',   '👤 Профиль' }),
  BotCommand({ 'balance',   '💵 Баланс' }),
  BotCommand({ 'top',       '🏆 Топы' }),
  BotCommand({ 'bonus',     '🎁 Бонус' }),
  BotCommand({ 'farm',      '🌾 Ферма' }),
  BotCommand({ 'quests',    '☘️ Квесты' }),
  BotCommand({ 'craft',     '🛠 Крафт' }),
  BotCommand({ 'mines',     '💣 Мины' }),
  BotCommand({ 'spin',      '🎰 Слот' }),
  BotCommand({ 'puzzle',    '🧩 Пазл' }),
  BotCommand({ 'fishing',   '🎣 Рыбалка' }),
  BotCommand({ 'mining',    '⛏ Рудник' }),
  BotCommand({ 'sawmill',   '🪓 Лесопилка' }),
  BotCommand({ 'pets',      '🐾 Мои питомцы' }),
  BotCommand({ 'friends',   '👫 Мои друзья' }),
  BotCommand({ 'likes',     '❤️ Мои лайки' }),
  BotCommand({ 'marriage',  '💍 Мой брак' }),
  BotCommand({ 'shop',      '🛒 Магазин' }),
  BotCommand({ 'zoo_shop',  '🛍 Зоомагазин' }),
  BotCommand({ 'setbday',   '🎂 День рождения' }),
  BotCommand({ 'privacy',   '🔕 Приватность' }),
  BotCommand({ 'commands',  '📜 Команды' }),
  BotCommand({ 'setrace',   '🧬 Сменить расу' }),
  BotCommand({ 'setgender', '🚻 Сменить пол' }),
  BotCommand({ 'help',      '🗺 Помощь' }),
}

local GROUP_COMMANDS = {
  BotCommand({ 'profile',   '👤 Профиль' }),
  BotCommand({ 'balance',   '💵 Баланс' }),
  BotCommand({ 'top',       '🏆 Топы' }),
  BotCommand({ 'bonus',     '🎁 Бонус' }),
  BotCommand({ 'farm',      '🌾 Ферма' }),
  BotCommand({ 'quests',    '☘️ Квесты' }),
  BotCommand({ 'mines',     '💣 Мины' }),
  BotCommand({ 'spin',      '🎰 Слот' }),
  BotCommand({ 'puzzle',    '🧩 Пазл' }),
  BotCommand({ 'fishing',   '🎣 Рыбалка' }),
  BotCommand({ 'mining',    '⛏ Рудник' }),
  BotCommand({ 'sawmill',   '🪓 Лесопилка' }),
  BotCommand({ 'pets',      '🐾 Мои питомцы' }),
  BotCommand({ 'friends',   '👫 Мои друзья' }),
  BotCommand({ 'marriage',  '💍 Мой брак' }),
  BotCommand({ 'game',      '⚔️ PVP-игра' }),
  BotCommand({ 'cashbox',   '💰 Касса чата' }),
  BotCommand({ 'shop',      '🛒 Магазин' }),
  BotCommand({ 'zoo_shop',  '🛍 Зоомагазин' }),
  BotCommand({ 'staff',     '🛡 Стафф' }),
  BotCommand({ 'commands',  '📜 Команды' }),
}

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  ctx:reply('Устанавливаю стандартные команды...')

  -- Чистим админ-скоп (его не используем).
  bot:deleteMyCommands({
    scope = BotCommandScope(bot_command_scope.ALL_CHAT_ADMINISTRATORS),
  })

  local _, errPrivate = bot:setMyCommands({
    commands = PRIVATE_COMMANDS,
    scope = BotCommandScope(bot_command_scope.ALL_PRIVATE_CHATS),
  })
  if errPrivate then
    log.error(errPrivate)
    ctx:reply('⚠️ Ошибка установки команд для ЛС')
    return
  end

  local _, errGroup = bot:setMyCommands({
    commands = GROUP_COMMANDS,
    scope = BotCommandScope(bot_command_scope.ALL_GROUP_CHATS),
  })
  if errGroup then
    log.error(errGroup)
    ctx:reply('⚠️ Ошибка установки команд для групп')
    return
  end

  ctx:reply('✅ Стандартные команды установлены')
end

return command
