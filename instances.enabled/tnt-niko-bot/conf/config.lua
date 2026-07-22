--- Конфиг.
--

local SUBDOMAIN = 'niko'
local DOMAIN = 'niko-bot.ru'
local HOST = ('https://%s.%s'):format(SUBDOMAIN, DOMAIN)

local config = {
  admin_id = os.getenv('BOT_ADMIN_ID'),

  bot = {
    username = 'Niko_rp_bot',

    -- Ссылка на ассеты с экранированием
    url_assets = HOST .. '/assets/',
    -- Webhook url
    url_webhook = HOST .. '/updates/',
  },

  server = {
    host = os.getenv('BOT_SERVER_HOST') or '0.0.0.0',
    port = os.getenv('BOT_SERVER_PORT') or 9091,
  },

  -- Ссылки для /help (чат, новости, гайды)
  links = {
    chat = 'https://t.me/niko_room',
    news = 'https://t.me/niko_bot_news',

    guide     = 'https://niko-bot.ru/pages/commands-guide',
    mod_guide = 'https://niko-bot.ru/pages/mod-commands-guide',
  },

  -- Донат
  donat = {
    -- Минимальная сумма доната в Telegram Stars
    min_stars_amount = 10,
    -- Количество игровой валюты за базовую сумму доната
    currency_per_min_stars = 10000000,

    -- Цена одного кристалла в Stars
    one_crystal_price_stars = 15,
    -- Цена пяти кристалла в Stars
    five_crystals_price_stars = 70,

    -- Цена VIP на 1 месяца
    vip_1m_price_stars = 10,

    -- Цена VIP на 1 год
    vip_1y_price_stars = 100,
  },

  -- Продажа
  sell = {
    -- Цена за 1 кристалл при продаже, в игровой валюте
    crystals = 13333333,
  },

  -- Ежедневный бонус
  daily_bonus = {
    -- Диапазон выплаты обычному пользователю
    min_amount = 15000,
    max_amount = 55000,

    -- Диапазон выплаты VIP-пользователю
    vip_min_amount = 55000,
    vip_max_amount = 99999,

    -- Кулдаун между получениями, в секундах
    cooldown = 24 * 60 * 60,

    -- Шанс выронить кристалл при получении бонуса, из 10000 (100 = 1%)
    crystal_chance = 200,
  },

  -- Команда 'Кусь'
  kus = {
    -- Кулдаун между укусами, секунды (анти-спам)
    cooldown = 5,

    -- Шанс промаха, из 100 (укус не засчитывается, счётчик не растёт)
    miss_chance = 8,
  },

  -- Питомцы
  pets = {
    -- Лимит питомцев на игрока
    count_default = 2,
    count_vip = 10,

    -- Период тика фоновой задачи затухания, секунды
    decay_interval = 15 * 60,

    -- Эффекты ухода (применяются к параметрам, затем clamp 0..100)
    care = {
      feed  = { hunger = -15, mental_health = 15 },   -- покормить (нужен корм)
      heal  = { health = 15, mental_health = 15 },    -- лечить (нужно лекарство)
      bathe = { dirty = 0, mental_health = 15 },      -- искупать (нужен шампунь), dirty -> 0
      play  = { energy_min = 10, energy_max = 20 },   -- играть: energy -rand, mental_health +rand
    },
  },

  -- Мини-игра 'Мины' (PVE)
  mines = {
    -- Всего клеток и сколько кнопок в ряд (4x4)
    cells = 16,
    cols = 4,

    -- Уровни риска (число мин) для меню выбора
    risk = { 3, 7, 9 },

    -- Минимальная ставка
    min_bid = 1000,

    -- Доля, на которую урезается честный множитель (house edge)
    house_edge = 0.10,

    -- Протухание брошенной партии, секунды
    ttl = 10 * 60,

    -- XP за победу: max(xp_min, floor(ставка / xp_per))
    xp_per = 1000,
    xp_min = 5,
  },

  -- Мини-игра 'Пазл' (память, PVE)
  puzzle = {
    -- Набор различимых эмодзи для последовательностей
    emojis = { '🍎', '🍌', '🍇', '🍊', '🍋', '🍉', '🍓', '🥝', '🍒', '🥥', '🍑', '🍍' },

    -- Сложности (длина последовательности) для меню
    lengths = { 4, 6, 8 },

    -- Награда: reward = rand(len*win_min_per, len*win_max_per)
    win_min_per = 1000,
    win_max_per = 2000,

    -- XP за победу = длина * xp_per_len
    xp_per_len = 2,

    -- Кулдаун между попытками, секунды
    cooldown = 60 * 60,

    -- Множитель выигрыша для VIP
    vip_multiplier = 2,
  },

  -- Слот-машина 'Спин' (касса чата - прогрессивный джекпот)
  spin = {
    -- Минимальная ставка
    min_bid = 1000,

    -- Символы барабанов (💎 последний - ультра). Сиды подобраны под этот набор
    symbols = {
      '🍎',  -- Яблоко
      '🍇',  -- Виноград
      '🍓',  -- Клубника
      '🍒',  -- Вишня
      '🍉',  -- Арбуз
      '🍊',  -- Апельсин
      '🍍',  -- Ананас`
      '🍑',  -- Персик
      '🍋',  -- Лимон
      '💎',  -- X4
      '🥭',  -- Манго
      '🥝',  -- Киви
      '🫐',  -- Черника
    },
    -- Ультра-джекпот: три кристалла
    crystal = '💎',

    good_seeds = {
      463405,
      3214752,
      497087,
      186131,
    },
    reseed_every = 100,

    -- Множители выплат
    win2_mult = 2,
    jackpot_mult = 3,
    ultra_mult = 4,

    -- Процент проигранной ставки в кассу чата
    cashbox_pc = 20,

    -- Ультра даёт +1 кристалл, если ставка >= crystal_bid
    crystal_bid = 50000,
  },

  -- Добыча: рыбалка / рудник / лесопилка (числовые параметры; структура в src/gathering)
  gathering = {
    -- Период проверки протухших задач в TTL-джобе (авто-сбор), секунды
    job_tick = 30,

    -- Нижний предел длительности задачи после всех сокращений (VIP/прикормка), секунды
    min_time = 30,

    -- Вместимость рюкзака: суммарное число ресурсов (инструменты/прикормка не в счёт).
    -- Полно -> новую добычу начать нельзя, надо продать.
    capacity = 500,

    -- Сколько XP навыка даёт один сбор
    xp_per_gather = 8,

    -- Кривая уровня навыка: порог следующего уровня = level_base * level
    level_base = 50,

    -- Контракты
    quests = {
      cooldown = 24 * 60 * 60,
    },

    -- Параметры активностей. yield_* - диапазон базового улова за сбор;
    -- rare_odds - 1 шанс из N выронить доп. дроп (mining = 1: всегда).
    fishing = {
      time = 180,
      bait_reduce = 60,
      vip_reduce = 30,
      yield_min = 2,
      yield_max = 20,
      rare_odds = 4,
    },
    mining  = {
      time_min = 60,
      time_max = 120,
      vip_reduce = 30,
      yield_min = 2,
      yield_max = 20,
      rare_odds = 1,
    },
    sawmill = {
      time_min = 60,
      time_max = 180,
      vip_reduce = 30,
      yield_min = 1,
      yield_max = 20,
      rare_odds = 3,
    },
    --
  },

  -- Рейд-босс чата (PVE, кооператив). Каталог боссов - src/dict/bosses.lua.
  boss = {
    -- Побег босса: время жизни боя, секунды
    ttl = 45 * 60,

    -- Период проверки протухших боёв TTL-джобой, секунды
    job_tick = 30,

    -- Кулдаун призыва нового босса в чате после конца боя, секунды
    spawn_cooldown = 2 * 60 * 60,

    -- Личный кулдаун удара, секунды
    hit_cooldown = 90,

    -- Базовый урон за удар: rand(dmg_min, dmg_max)
    dmg_min = 80,
    dmg_max = 140,

    -- Бонус уровня: +level_coef за уровень, уровни выше level_cap не считаются
    level_coef = 0.04,
    level_cap = 50,

    -- Максимальный бонус лучшего питомца (при идеальном состоянии), доля
    pet_max_bonus = 0.25,

    -- Крит: шанс 1 из crit_odds, множитель crit_mult
    crit_odds = 10,
    crit_mult = 2,

    -- Бонус добившему: доля от пула сверх его доли за урон
    killer_bonus_pc = 10,

    -- XP за бой: max(xp_min, floor(личная выплата / xp_per))
    xp_per = 1000,
    xp_min = 5,
  },

  -- Ферма: грядки (выращивание). Культуры (время роста/урожай/min_level) в src/farm/crops.lua.
  farm = {
    slots = 4,            -- базовое число грядок (на 1 уровне)
    max_slots = 8,        -- потолок грядок при росте уровня
    slots_per_level = 2,  -- +1 грядка за каждые N уровней фермы
    xp_per_harvest = 10,  -- XP уровня фермы за один сбор (кривая - config.gathering.level_base)
  },
}

return config
