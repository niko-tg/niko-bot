--- Точка входа инстанса бота.
--
-- Порядок инициализации: пути -> конфиг -> схема хранилища -> события ->
-- команды -> фоновые задачи -> запуск (long polling в dev, webhook в prod).
--

-- ----------------------------
-- Пути поиска модулей
-- ----------------------------
package.cpath = package.cpath .. ';.rocks/lib/tarantool/?.so;.rocks/lib/lua/5.1/?.so'
package.path = package.path .. ';.rocks/share/lua/5.1/?.lua'
package.path = package.path .. ';.rocks/share/lua/5.1/?/init.lua'

-- luacheck: ignore
-- Глобальная установка fstring
string.f = require('src.utils.fstring')

local log = require('log')
local datetime = require('datetime')
local config = require('conf.config')
local bot = require('bot')
local commandLoader = require('bot.utils.commandLoader')
local routes = require('src.routes')

-- Сид рандома один раз на старте (дальше math.random без переинициализации)
math.randomseed(os.time())

-- ----------------------------
-- Конфигурирование бота
-- ----------------------------
do
  bot:cfg({
    token = os.getenv('BOT_TOKEN'),
    username = config.bot.username,
  })
end

-- ----------------------------
-- Хранилище
-- ----------------------------
do
  local spaces = require('src.spaces')

  for spaceName, space in pairs(spaces) do
    local formatSpace = space.format_space

    -- Создание схемы
    local schema = box.schema.create_space(spaceName, {
      format = formatSpace,
      if_not_exists = true,
    })

    -- Создание индексов
    for _, index in pairs(space.index) do
      schema:create_index(index.name, index.options)
    end

    -- Создание последовательности (если задана)
    if space.sequence then
      box.schema.sequence.create(space.sequence, { if_not_exists = true })
      log.info('Sequence [%s] inited', space.sequence)
    end

    log.info('Space [%s] inited', spaceName)
  end
  --
end

-- ----------------------------
-- События
-- ----------------------------
bot.events.onGetUpdate = require('src.events.onGetUpdate')
-- Обработка чатов
bot.events.onChatMember = require('src.events.onChatMember')
bot.events.onMyChatMember = require('src.events.onMyChatMember')
-- Сервисные сообщения (миграции и т.п.)
bot.events.onMessageService = require('src.events.onMessageService')
-- Обработка команд и кнопок
bot.events.onGetEntities = require('src.events.onGetEntities')
bot.events.onCallbackQuery = require('src.events.onCallbackQuery')
bot.events.onGetMessageText = require('src.events.onGetMessageText')
bot.events.onDice = require('src.events.onDice')
-- Обработка не-команд сообщений в чатах (фильтры, антифлад и т.п.)
bot.events.onChatMessage = require('src.events.onChatMessage')

-- Обработчик до выполнения команды
bot.events.preCallCommand = require('src.events.preCallCommand')

-- Обработка платежей в звездах
bot.events.preCheckoutQuery = require('src.events.preCheckoutQuery')
bot.events.successfulPayment = require('src.events.successfulPayment')

-- ----------------------------
-- Команды
-- ----------------------------
commandLoader.setPath('src.commands')

commandLoader({
  private = {
    start = { callback_commands = { 'cb_start_guide' } },
    help = {},
    donat = { callback_commands = { 'cb_donat' } },
  },
  public = {
    niko = {},
    profile = { callback_commands = { 'cb_set_race', 'cb_set_gender' } },
    my = {},
    staff = {},
    setrace = {},
    setgender = {},
    setbday = {},
    status = {},
    privacy = { callback_commands = { 'cb_privacy' } },
    top = { callback_commands = { 'cb_top' } },
    balance = {},
    bonus = {},
    pay = {},
    like = {},
    likes = { callback_commands = { 'cb_likes' } },
    infriends = { callback_commands = { 'cb_infriends' } },
    friends = { callback_commands = { 'cb_friends' } },
    marry = { callback_commands = { 'cb_marry' } },
    marriage = {},
    braki = {},
    divorce = { callback_commands = { 'cb_divorce' } },
    kus = {},
    zoo = { callback_commands = { 'cb_zoo' } },
    pets = { callback_commands = { 'cb_pet' } },
    petname = {},
    rp = {},
    game = { callback_commands = { 'cb_game' } },
    mines = { callback_commands = { 'cb_mines' } },
    boss = { callback_commands = { 'cb_boss' } },
    puzzle = { callback_commands = { 'cb_puzzle' } },
    spin = {},
    cashbox = {},
    commands = { callback_commands = { 'cb_commands' } },
    inventory = { callback_commands = { 'cb_inv' } },
    sell = {},
    shop = { callback_commands = { 'cb_shop' } },
    fishing = {},
    mining = {},
    sawmill = {},
    collect = { callback_commands = { 'cb_collect' } },
    skills = {},
    craft = { callback_commands = { 'cb_craft' } },
    quests = { callback_commands = { 'cb_quests' } },
    farm = { callback_commands = { 'cb_farm' } },
  },
  moderation = {
    settings = { callback_commands = { 'cb_settings', 'cb_set_setting' } },
    modlog = { callback_commands = { 'cb_modlog' } },
    reload = {},
    mkhello = {},
    rmhello = {},
    gethello = {},
    mute = {},
    unmute = {},
    ban = {},
    unban = {},
    report = {},
  },
  maint = {
    chatinfo = {},
    delchat = {},
    mkvip = {},
    uid = {},
    refund = {},
    botstats = {},
    defcmds = {},
    advusers = {},
    advchats = {},
  },
})

-- ----------------------------
-- Фоновые задачи
-- ----------------------------
require('src.jobs.vipReminder').start()
require('src.jobs.gameTimeout').start()
require('src.jobs.mineTimeout').start()
require('src.jobs.bossTimeout').start()
require('src.jobs.dailyStats').start()
require('src.jobs.petsDecay').start()

-- ----------------------------
-- Запуск
-- ----------------------------
local BOT_MODE = os.getenv('BOT_MODE')
local ALLOWED_UPDATES = {
  bot.enums.allowed_updates.MESSAGE,
  bot.enums.allowed_updates.CHAT_MEMBER,
  bot.enums.allowed_updates.MY_CHAT_MEMBER,
  bot.enums.allowed_updates.CALLBACK_QUERY,
  bot.enums.allowed_updates.PRE_CHECKOUT_QUERY,
}

if BOT_MODE == 'dev' then
  log.info('[Long Polling] Bot running in DEV mode')

  bot:debugRoutes({
    routes = routes,
    host = config.server.host,
    port = config.server.port,
  })

  bot:startLongPolling({
    allowed_updates = ALLOWED_UPDATES,
  })

  return
end

log.info('[WebHook] Bot running in PROD mode')

bot:sendMessage({
  chat_id = config.admin_id,
  text = 'Started at: ' .. tostring(datetime.now()),
})

local _, err = bot:startWebHook({
  url = config.bot.url_webhook,
  path = '/updates/',
  drop_pending_updates = true,
  allowed_updates = ALLOWED_UPDATES,

  -- Server setup
  routes = routes,
  host = config.server.host,
  port = config.server.port,
})

if err then
  log.error(err)
end
