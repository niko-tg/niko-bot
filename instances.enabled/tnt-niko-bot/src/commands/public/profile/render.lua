--- Рендер профиля: текст + клавиатуры установки/смены расы (с превью).
--
local log = require('log')
local hdec = require('bot.libs.hdec')
local config = require('conf.config')
local races = require('src.dict.races')
local items = require('src.gathering.items')
local chat_type = require('bot.enums.chat_type')
local separateNumbers = require('src.utils.separateNumbers')
local timeToDays = require('src.utils.timeToDays')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')
local userInChatService = require('src.services.user_in_chat')
local inventoryService = require('src.services.inventory')
local vipUsersService = require('src.services.vip_users')
local marriagesService = require('src.services.marriages')
local usersService = require('src.services.users')
local userMention = require('src.render.userMention')

local VIP_PREFIX = ([[
👑 <b>VIP USER</b> 👑
${sep}
]]):f({ sep = hdec.sep })

-- TODO: 🔮 Карма: <b>${karma}</b>
local PROFILE_TEMPLATE = [[
🔆 ${status}
${sep}
💡 Уровень: <b>${level}</b>
⚡️ Опыт: <b>${xp}</b> / <b>${xp_to_next}</b>
${sep}
💎 Кристаллы: <b>${crystals}</b>
💵 Баланс: <b>${balance}р</b>
🏦 Ререзрв: <b>${reserved_balance}р</b>
${sep}
${race_emoji} Раса: <b>${race}</b>
🕰️ Возраст: <b>${age}</b>
🎒 Инвентарь: <b>${inv_used}</b> / ${inv_cap}
🎭 Друзей: <b>${friends_count}</b>
❤️‍🔥 Лайки: <b>${likes}</b>
${vampire_emoji} Кусей: <b>${kuses}</b>
💍 Брак: ${marriage}
]]

-- Приглашение команды смены расы (и при «назад» из превью в режиме change).
local CHANGE_PROMPT = ([[
🧬 <b>Смена расы</b>
${sep}
Выбери новую расу
]]):f({ sep = hdec.sep })

-- Приглашение команды смены пола.
local GENDER_CHANGE_PROMPT = ([[
🚻 <b>Смена пола</b>
${sep}
Выбери пол
]]):f({ sep = hdec.sep })

local womanVampireEmoji = "🧛‍♀️"
local manVampireEmoji = "🧛"

-- Порядок рас для кнопок выбора (anonymous из dict - не раса).
local RACE_ORDER = { 'wizard', 'elf', 'human', 'demon' }

local RACE_SET = {}
for _, key in ipairs(RACE_ORDER) do
  RACE_SET[key] = true
end

local render = {}

render.CHANGE_PROMPT = CHANGE_PROMPT
render.GENDER_CHANGE_PROMPT = GENDER_CHANGE_PROMPT

--- Известна ли раса (для валидации в callback).
function render.isRace(key)
  return RACE_SET[key] == true
end

--- Известен ли пол (для валидации в callback).
-- Пол: значение в БД -> подпись и эмодзи.
local GENDERS = {
  man = { label = 'Парень', emoji = '👨' },
  woman = { label = 'Девушка', emoji = '👩' },
}

function render.isGender(key)
  return GENDERS[key] ~= nil
end

--- Подпись пола (для сообщения о смене).
function render.genderLabel(key)
  return GENDERS[key] and GENDERS[key].label
end
--

-- Полных лет по дате рождения (datetime).
local function ageInYears(birthday)
  local now = os.date('*t')
  local born = os.date('*t', birthday.timestamp)

  local years = now.year - born.year
  if now.month < born.month or (now.month == born.month and now.day < born.day) then
    years = years - 1
  end

  return years
end

-- Русское склонение: 1 год / 2 года / 5 лет.
local function yearsWord(n)
  local mod10 = n % 10
  local mod100 = n % 100

  if mod10 == 1 and mod100 ~= 11 then
    return 'год'
  elseif mod10 >= 2 and mod10 <= 4 and (mod100 < 12 or mod100 > 14) then
    return 'года'
  end

  return 'лет'
end

--- Текст профиля (с VIP-префиксом и строкой «В чате», если уместно).
local function buildProfileText(user, chat)
  local isVip, err = vipUsersService.isActive(user.id)
  if err then
    log.error(err)
    isVip = false
  end

  local race
  local raceEmoji

  if user.race ~= box.NULL then
    race = races[user.race].description

    if user.gender ~= box.NULL then
      raceEmoji = races[user.race][user.gender]
    else
      raceEmoji = races[user.race]['man']
    end
  else
    race = 'Не указано'
    raceEmoji = races.anonymous
  end

  local age
  if user.birthday_date == box.NULL then
    age = 'Не указано'
  else
    local years = ageInYears(user.birthday_date)
    age = years .. ' ' .. yearsWord(years)
  end

  local vampireEmoji
  if user.gender ~= box.NULL then
    if user.gender == 'man' then
      vampireEmoji = manVampireEmoji
    else
      vampireEmoji = womanVampireEmoji
    end
  else
    vampireEmoji = manVampireEmoji
  end

  -- Брак: партнёр (с учётом приватности) и дни вместе, или «свободен».
  local marriageStatus = 'свободен'
  local marriage, marriageErr = marriagesService.read(user.id)
  if marriageErr then
    log.error(marriageErr)
  elseif marriage then
    local partner, partnerErr = usersService.read(marriage.partner_id)
    if partnerErr then
      log.error(partnerErr)
    end

    local partnerMention = partner and userMention(partner)
      or ('<code>#'..marriage.partner_id..'</code>')

    marriageStatus = partnerMention..' | <b>'..timeToDays(marriage.created.timestamp)..'</b> дн.'
  end

  -- Занятость инвентаря считаем вживую из user_inventory (единый источник правды).
  local invUsed = 0
  local inv, invErr = inventoryService.read(user.id)
  if invErr then
    log.error(invErr)
  elseif inv then
    invUsed = items.resourceWeight(inv.items)
  end

  local profileText = PROFILE_TEMPLATE:f({
    sep = hdec.sep,
    status = hdec.escape(user.status),
    level = separateNumbers(user.level),
    xp = separateNumbers(user.xp),
    xp_to_next = separateNumbers(user.xp_to_next),
    race_emoji = raceEmoji,
    race = race,
    age = age,
    crystals = separateNumbers(user.crystals),
    balance = separateNumbers(user.balance),
    reserved_balance = separateNumbers(user.reserved_balance),
    inv_used = separateNumbers(invUsed),
    inv_cap = separateNumbers(config.gathering.capacity),
    friends_count = separateNumbers(user.friends),
    likes = separateNumbers(user.likes),
    karma = separateNumbers(user.karma),
    vampire_emoji = vampireEmoji,
    kuses = user.kuses,
    marriage = marriageStatus,
  })

  if chat.type ~= chat_type.PRIVATE then
    local uic, uicErr = userInChatService.read(chat.id, user.id)
    if uicErr then
      log.error(uicErr)
    elseif uic and uic.joined_date then
      -- uic.joined_date это datetime-объект, .timestamp - unix-секунды
      local daysInChat = timeToDays(uic.joined_date.timestamp)

      profileText = profileText
        .. hdec.sep
        .. '\n'
        .. '⏰ В чате: <b>' .. daysInChat .. ' дн.</b>\n'
    end
  end

  if isVip then
    return VIP_PREFIX .. profileText
  end

  return profileText
end

-- Кнопка «Установить расу» (из профиля, ведёт в выбор). owner - id владельца.
local function setRaceButton(owner)
  return {
    text = '🧬 Установить расу',
    callback = {
      command = 'cb_set_race',
      arguments = {
        action = 'menu',
        race = '_',
        owner = owner,
        mode = 'set'
      }
    },
  }
end

-- Кнопка «Указать пол» (из профиля, ведёт в выбор).
local function setGenderButton(owner)
  return {
    text = '👫 Указать пол',
    callback = {
      command = 'cb_set_gender',
      arguments = {
        action = 'menu',
        gender = '_',
        owner = owner
      }
    },
  }
end

-- Кнопки выбора пола. action = 'set' (профиль, одноразово) | 'change' (команда).
-- withBack добавляет «Назад» (нужно в профиле, не в команде смены).
local function genderChoiceKeyboard(owner, action, withBack)
  local rows = {
    {
      {
        text = '👨 Парень',
        callback = {
          command = 'cb_set_gender',
          arguments = {
            action = action,
            gender = 'man',
            owner = owner
          }
        },
      },
      {
        text = '👩 Девушка',
        callback = {
          command = 'cb_set_gender',
          arguments = {
            action = action,
            gender = 'woman',
            owner = owner
          }
        },
      },
    },
  }

  if withBack then
    table.insert(rows, {
      {
        text = '◀️ Назад',
        callback = {
          command = 'cb_set_gender',
          arguments = {
            action = 'back',
            gender = '_',
            owner = owner
          }
        },
      },
    })
  end

  return inlineCallbackKeyboard(rows)
end

render.genderChoiceKeyboard = genderChoiceKeyboard

-- Кнопки выбора расы (2 в ряд). Клик -> превью (action='preview').
-- mode - что делать после подтверждения: 'set' (профиль) | 'change' (команда).
local function raceChoiceKeyboard(owner, mode)
  local rows = {}
  local row = {}

  for _, key in ipairs(RACE_ORDER) do
    local race = races[key]

    table.insert(row, {
      text = race.man .. ' ' .. race.description,
      callback = {
        command = 'cb_set_race',
        arguments = {
          action = 'preview',
          race = key,
          owner = owner,
          mode = mode
        }
      },
    })

    if #row == 2 then
      table.insert(rows, row)
      row = {}
    end
  end

  if #row > 0 then
    table.insert(rows, row)
  end

  return inlineCallbackKeyboard(rows)
end

render.raceChoiceKeyboard = raceChoiceKeyboard

--- Превью расы: описание + кнопки «Выбрать» (action=mode) и «Назад».
function render.racePreview(raceKey, owner, mode)
  local race = races[raceKey]

  local text = race.man .. ' <b>' .. race.description .. '</b>\n'
    .. hdec.sep .. '\n'
    .. (race.about or 'Описание скоро появится.')

  local keyboard = inlineCallbackKeyboard({
    {
      {
        text = '✅ Выбрать: ' .. race.description,
        callback = {
          command = 'cb_set_race',
          arguments = {
            action = mode,
            race = raceKey,
            owner = owner,
            mode = mode
          }
        },
      },
    },
    {
      {
        text = '◀️ Назад',
        callback = {
          command = 'cb_set_race',
          arguments = {
            action = 'back',
            race = '_',
            owner = owner,
            mode = mode
          }
        },
      },
    },
  })

  return { text = text, keyboard = keyboard }
end

--- Профиль -> { text, keyboard }.
-- opts.raceChoice = true -> кнопки выбора расы; opts.genderChoice = true -> выбор пола.
-- Иначе: для незаданных расы/пола - кнопки «Установить расу» / «Указать пол».
function render.profile(user, chat, opts)
  local text = buildProfileText(user, chat)
  local keyboard

  if opts and opts.raceChoice then
    keyboard = raceChoiceKeyboard(user.id, 'set')

  elseif opts and opts.genderChoice then
    keyboard = genderChoiceKeyboard(user.id, 'set', true)

  else
    -- Кнопки настройки: раса и пол - каждая, пока не задана.
    local rows = {}

    if user.race == box.NULL then
      table.insert(rows, { setRaceButton(user.id) })
    end

    if user.gender == box.NULL then
      table.insert(rows, { setGenderButton(user.id) })
    end

    if #rows > 0 then
      keyboard = inlineCallbackKeyboard(rows)
    end
  end

  return { text = text, keyboard = keyboard }
end

return render
