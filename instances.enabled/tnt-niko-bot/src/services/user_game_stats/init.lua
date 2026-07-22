--- Сервис игровой статистики (W/L и пр., хранится в map).
--
local sql = require('bot.libs.sql')
local UserGameStats = require('src.models.UserGameStats')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')

local service = {}

--- Чтение статистики игрока.
-- @tparam number user_id
-- @treturn[1] ?table модель user_game_stats
-- @treturn[2] table err
function service.read(user_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        user_game_stats
      WHERE
        user_id = ${user_id}
    ]], {
      user_id = user_id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local stats, errs = UserGameStats(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return stats, nil
end

--- Вставка/обновление (меняет только переданные поля).
-- @tparam table data { user_id, stats }
-- @treturn[1] table модель user_game_stats
-- @treturn[2] table err
function service.upsert(data)
  local defaultStats, errs = UserGameStats(data, { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  local updateFields = {}
  for key in pairs(data) do
    updateFields[key] = defaultStats[key]
  end

  local _, err = sql.upsert('user_game_stats', defaultStats, updateFields)
  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return service.read(defaultStats.user_id)
end

local OUTCOME_KEY = {
  win = 'wins',
  loss = 'losses',
  draw = 'draws',
}

--- Учёт исхода игры: инкремент счётчика исхода + games.
-- @tparam number user_id
-- @tparam string outcome 'win' | 'loss' | 'draw'
-- @treturn[1] table модель user_game_stats
-- @treturn[2] table err
function service.record(user_id, outcome)
  local existing, err = service.read(user_id)
  if err then
    return nil, err
  end

  local stats = (existing and existing.stats) or {}

  local key = OUTCOME_KEY[outcome]
  if key then
    stats[key] = (stats[key] or 0) + 1
  end

  stats.games = (stats.games or 0) + 1

  return service.upsert({ user_id = user_id, stats = stats })
end

--- Заявка на ежедневный бонус: если кулдаун прошёл - штампит время выдачи в map.
-- last_bonus_at - unix-секунды последнего получения (нет ключа = ни разу).
-- @tparam number user_id
-- @tparam number cooldown кулдаун в секундах
-- @treturn[1] table { granted = boolean, lastBonusAt = number }
-- @treturn[2] table err
function service.claimDailyBonus(user_id, cooldown)
  local existing, err = service.read(user_id)
  if err then
    return nil, err
  end

  local stats = (existing and existing.stats) or {}
  local last = stats.last_bonus_at or 0
  local now = os.time()

  if now - last < cooldown then
    return { granted = false, lastBonusAt = last }, nil
  end

  stats.last_bonus_at = now

  local _, upErr = service.upsert({ user_id = user_id, stats = stats })
  if upErr then
    return nil, upErr
  end

  return { granted = true, lastBonusAt = now }, nil
end

--- Заявка на укус: если кулдаун прошёл - штампит время укуса в map.
-- last_kus_at - unix-секунды последнего укуса (нет ключа = ни разу).
-- Штампим на каждую успешную заявку (в т.ч. перед промахом), чтобы анти-спам
-- не обходился рероллом.
-- @tparam number user_id
-- @tparam number cooldown кулдаун в секундах
-- @treturn[1] table { granted = boolean, lastKusAt = number }
-- @treturn[2] table err
function service.claimKus(user_id, cooldown)
  local existing, err = service.read(user_id)
  if err then
    return nil, err
  end

  local stats = (existing and existing.stats) or {}
  local last = stats.last_kus_at or 0
  local now = os.time()

  if now - last < cooldown then
    return { granted = false, lastKusAt = last }, nil
  end

  stats.last_kus_at = now

  local _, upErr = service.upsert({ user_id = user_id, stats = stats })
  if upErr then
    return nil, upErr
  end

  return { granted = true, lastKusAt = now }, nil
end

--- Активный пазл игрока + время следующего пазла (кулдаун).
-- @tparam number user_id
-- @treturn[1] table { active = table|nil, next = number }
-- @treturn[2] table err
function service.readPuzzle(user_id)
  local existing, err = service.read(user_id)
  if err then
    return nil, err
  end

  local stats = (existing and existing.stats) or {}

  return { active = stats.puzzle, next = stats.puzzle_next or 0 }, nil
end

--- Сохранить/обновить активный пазл в map.
-- @tparam number user_id
-- @tparam table puzzle { seq, pos, phase, win }
-- @treturn[1] table модель user_game_stats
-- @treturn[2] table err
function service.savePuzzle(user_id, puzzle)
  local existing, err = service.read(user_id)
  if err then
    return nil, err
  end

  local stats = (existing and existing.stats) or {}
  stats.puzzle = puzzle

  return service.upsert({ user_id = user_id, stats = stats })
end

--- Завершить пазл: убрать активный + поставить кулдаун (unix-секунды).
-- @tparam number user_id
-- @tparam number cooldownTs
-- @treturn[1] table модель user_game_stats
-- @treturn[2] table err
function service.finishPuzzle(user_id, cooldownTs)
  local existing, err = service.read(user_id)
  if err then
    return nil, err
  end

  local stats = (existing and existing.stats) or {}
  stats.puzzle = nil
  stats.puzzle_next = cooldownTs

  return service.upsert({ user_id = user_id, stats = stats })
end

return service
