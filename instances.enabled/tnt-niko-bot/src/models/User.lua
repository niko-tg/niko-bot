--- Модель пользователя.
--
local datetime = require('datetime')
local Errors = require('src.models.Errors')

--- Конструктор модели User.
-- @tparam table data сырые поля (из запроса или из БД)
-- @tparam[opt] table opts опции { init = true } - инициализация всех полей
-- @treturn[1] table model
-- @treturn[2] table errs
local function User(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'users' })
  local model = {}

  -- Основная информация
  --
  if tonumber(data.id) then
    model.id = tonumber(data.id)
  else
    errors:field_missing('id')
  end

  if data.first_name then
    model.first_name = tostring(data.first_name)
  elseif init then
    model.first_name = ''
  end

  if data.last_name then
    model.last_name = tostring(data.last_name)
  elseif init then
    model.last_name = ''
  end

  if data.username ~= nil and data.username ~= box.NULL then
    model.username = tostring(data.username):lower()
  else
    model.username = box.NULL
  end

  if data.language_code then
    model.language_code = tostring(data.language_code)
  elseif init then
    model.language_code = 'ru'
  end
  --

  -- Игровая схема
  --
  if data.gender ~= box.NULL then
    model.gender = tostring(data.gender)
  elseif init then
    model.gender = box.NULL
  end

  if data.birthday_date ~= nil and data.birthday_date ~= box.NULL then
    model.birthday_date = datetime.parse(tostring(data.birthday_date))
  elseif init then
    model.birthday_date = box.NULL
  end

  if data.race ~= box.NULL then
    model.race = tostring(data.race)
  elseif init then
    model.race = box.NULL
  end

  if data.status then
    model.status = tostring(data.status)
  elseif init then
    local variants = {
      'картошкой', 'яичком',    'сыром',   'ванилью', 'капустой',
      'грибами',   'яблоками',  'вишнями', 'клубничкой',
      'карамелью', 'шоколадом', 'авокадо', 'творожком',
    }

    math.randomseed(os.time())

    model.status = 'Пирожочек с '
      ..variants[math.random(#variants)]
      .. ' :3'
  end

  if tonumber(data.balance) then
    model.balance = tonumber(data.balance)
  elseif init then
    model.balance = 10000
  end

  if tonumber(data.reserved_balance) then
    model.reserved_balance = tonumber(data.reserved_balance)
  elseif init then
    model.reserved_balance = 0
  end

  if tonumber(data.crystals) then
    model.crystals = tonumber(data.crystals)
  elseif init then
    model.crystals = 0
  end

  -- Счётчик команд юзера (для статистики)
  if tonumber(data.commands_count) then
    model.commands_count = tonumber(data.commands_count)
  elseif init then
    model.commands_count = 0
  end

  if tonumber(data.karma) then
    model.karma = tonumber(data.karma)
  elseif init then
    model.karma = 0
  end

  if tonumber(data.likes) then
    model.likes = tonumber(data.likes)
  elseif init then
    model.likes = 0
  end

  if tonumber(data.kuses) then
    model.kuses = tonumber(data.kuses)
  elseif init then
    model.kuses = 0
  end

  if tonumber(data.friends) then
    model.friends = tonumber(data.friends)
  elseif init then
    model.friends = 0
  end
  --

  if data.is_started_bot ~= nil then
    model.is_started_bot = data.is_started_bot
  elseif init then
    model.is_started_bot = false
  end

  -- Использует приватность или нет
  if data.is_private ~= nil then
    model.is_private = data.is_private
  elseif init then
    model.is_private = false
  end

  -- Система уровней и XP
  --
  if tonumber(data.level) then
    model.level = tonumber(data.level)
  elseif init then
    model.level = 0
  end

  if tonumber(data.xp) then
    model.xp = tonumber(data.xp)
  elseif init then
    model.xp = 0
  end

  if tonumber(data.xp_to_next) then
    model.xp_to_next = tonumber(data.xp_to_next)
  elseif init then
    model.xp_to_next = 10
  end

  if data.locked ~= nil then
    model.locked = data.locked
  elseif init then
    model.locked = false
  end

  if errors:has_errors() then
    return nil, errors:get_compact()
  end

  return model, nil
end

return User
