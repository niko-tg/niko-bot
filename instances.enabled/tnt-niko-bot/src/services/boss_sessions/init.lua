--- Сервис боёв с рейд-боссом чата.
--
-- Ключевая операция - applyHit: кулдаун, урон и определение добивания в ОДНОЙ
-- транзакции, чтобы конкурентные удары не раздваивали killing blow и выплату.
-- Под MVCC конкурентные транзакции по одному кортежу конфликтуют - ретраим.
--
local log = require('log')
local sql = require('bot.libs.sql')
local BossSession = require('src.models.BossSession')
local BossHit = require('src.models.BossHit')

local services_error_type = require('src.enums.services.services_error_type')
local setErrType = require('src.utils.services.setErrType')
local retryTxnConflict = require('src.utils.services.retryTxnConflict')

local service = {}

--- Результаты applyHit/spawn (result.status).
service.result = {
  HIT      = 'hit',       -- урон нанесён, босс жив
  KILLED   = 'killed',    -- этот удар добил босса (выплату делает вызвавший)
  NO_BOSS  = 'no_boss',   -- активного боя нет (босс уже повержен/сбежал)
  COOLDOWN = 'cooldown',  -- личный кулдаун удара не прошёл (result.wait)
  EXISTS   = 'exists',    -- spawn: в чате уже идёт бой
  RESTING  = 'resting',   -- spawn: кулдаун призыва не прошёл (result.wait)
}

--- Бой чата (активный или завершённый) либо nil.
-- @tparam number chat_id
-- @treturn[1] ?table модель boss_session
-- @treturn[2] table err
function service.getByChat(chat_id)
  local item, err = sql(
    [[
      SELECT *
      FROM
        boss_sessions
      WHERE
        chat_id = ${chat_id}
    ]], {
      chat_id = chat_id,
    })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  if item == nil then
    return nil, nil
  end

  local session, errs = BossSession(item[1], { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.INTERNAL_VALIDATION_ERROR)
  end

  return session, nil
end

--- Призыв босса. Атомарно: гонка двух /boss не создаст второй бой, кулдаун
-- призыва проверяется по finished_at прежней записи. Хвосты урона прошлого
-- боя чистятся тут же (на случай упавшей выплаты).
-- @tparam table data chat_id, boss_id, hp, hp_max, message_id
-- @tparam table opts { spawn_cooldown = сек, now = unix-ts }
-- @treturn[1] table result { status = EXISTS|RESTING|'spawned', wait?, session? }
-- @treturn[2] table err
function service.spawn(data, opts)
  local session, errs = BossSession(data, { init = true })
  if errs then
    return nil, setErrType(errs, services_error_type.VALIDATION_ERROR)
  end

  local now = opts.now or os.time()
  local result

  return retryTxnConflict(function()
    result = nil

    local _, err = sql.atomic(function()
      local rows = sql.check(sql([[
        SELECT status, finished_at
        FROM boss_sessions
        WHERE chat_id = ${chat_id}
      ]], {
        chat_id = session.chat_id,
      }))

      local existing = rows and rows[1]

      if existing and existing.status == 'active' then
        result = { status = service.result.EXISTS }
        return
      end

      if existing and existing.finished_at ~= nil then
        local readyAt = existing.finished_at + opts.spawn_cooldown

        if now < readyAt then
          result = { status = service.result.RESTING, wait = readyAt - now }
          return
        end
      end

      -- Хвосты прошлого боя (упавшая выплата и т.п.)
      sql.check(sql([[
        DELETE FROM boss_hits
        WHERE chat_id = ${chat_id}
      ]], {
        chat_id = session.chat_id,
      }))

      -- Перезапись finished-записи прошлого боя (upsert - box-операция,
      -- внутри box.atomic она в той же транзакции).
      local fields = {}
      for key, value in pairs(session) do
        fields[key] = value
      end
      fields.finished_at = nil

      sql.check(sql.upsert('boss_sessions', session, fields))

      -- finished_at прошлого боя надо занулить явно: upsert не пишет nil.
      sql.check(sql([[
        UPDATE boss_sessions
        SET finished_at = NULL
        WHERE chat_id = ${chat_id}
      ]], {
        chat_id = session.chat_id,
      }))

      result = { status = 'spawned', session = session }
    end)

    if err then
      return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
    end

    return result, nil
  end)
end

--- Привязка боя к новой карточке (перепост /boss).
-- @tparam number chat_id
-- @tparam number message_id
-- @treturn[1] table res
-- @treturn[2] table err
function service.saveMessageId(chat_id, message_id)
  local res, err = sql([[
    UPDATE boss_sessions
    SET message_id = ${message_id}
    WHERE chat_id = ${chat_id}
  ]], {
    chat_id = chat_id,
    message_id = message_id,
  })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return res, nil
end

--- Удар по боссу: кулдаун + урон + добивание одной транзакцией.
-- Добивание переводит бой в finished прямо в транзакции - ровно один удар
-- получает KILLED, его вызвавший делает выплату.
-- @tparam number chat_id
-- @tparam number user_id
-- @tparam string name снапшот имени для карточки
-- @tparam number damage готовый урон (формула - на вызывающем)
-- @tparam table opts { hit_cooldown = сек, now = unix-ts }
-- @treturn[1] table result { status, hp?, hp_max?, wait?, total_damage? }
-- @treturn[2] table err
function service.applyHit(chat_id, user_id, name, damage, opts)
  local now = opts.now or os.time()
  local result

  return retryTxnConflict(function()
    result = nil

    local _, err = sql.atomic(function()
      local rows = sql.check(sql([[
        SELECT hp, hp_max, status
        FROM boss_sessions
        WHERE chat_id = ${chat_id}
      ]], {
        chat_id = chat_id,
      }))

      local session = rows and rows[1]

      if session == nil or session.status ~= 'active' then
        result = { status = service.result.NO_BOSS }
        return
      end

      -- Личный кулдаун удара.
      local hitRows = sql.check(sql([[
        SELECT damage, hits, last_hit_at
        FROM boss_hits
        WHERE chat_id = ${chat_id} AND user_id = ${user_id}
      ]], {
        chat_id = chat_id,
        user_id = user_id,
      }))

      local hit = hitRows and hitRows[1]

      if hit and now - hit.last_hit_at < opts.hit_cooldown then
        result = {
          status = service.result.COOLDOWN,
          wait = opts.hit_cooldown - (now - hit.last_hit_at),
        }
        return
      end

      -- Урон (кламп до 0) + добивание.
      local newHp = math.max(0, session.hp - damage)
      local killed = newHp == 0

      if killed then
        sql.check(sql([[
          UPDATE boss_sessions
          SET hp = 0, status = 'finished', finished_at = ${now}
          WHERE chat_id = ${chat_id}
        ]], {
          chat_id = chat_id,
          now = now,
        }))
      else
        sql.check(sql([[
          UPDATE boss_sessions
          SET hp = ${hp}
          WHERE chat_id = ${chat_id}
        ]], {
          hp = newHp,
          chat_id = chat_id,
        }))
      end

      -- Учёт урона участника.
      local totalDamage = (hit and hit.damage or 0) + damage

      local hitModel = BossHit({
        chat_id = chat_id,
        user_id = user_id,
        name = name,
        damage = totalDamage,
        hits = (hit and hit.hits or 0) + 1,
        last_hit_at = now,
      }, { init = true })

      sql.check(sql.upsert('boss_hits', hitModel, hitModel))

      result = {
        status = killed and service.result.KILLED or service.result.HIT,
        hp = newHp,
        hp_max = session.hp_max,
        total_damage = totalDamage,
      }
    end)

    if err then
      return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
    end

    return result, nil
  end)
end

--- Завершение боя без победы (побег по TTL). Только активные.
-- @tparam number chat_id
-- @tparam number now unix-ts
-- @treturn[1] boolean true
-- @treturn[2] table err
function service.finish(chat_id, now)
  local _, err = sql([[
    UPDATE boss_sessions
    SET status = 'finished', finished_at = ${now}
    WHERE chat_id = ${chat_id} AND status = 'active'
  ]], {
    chat_id = chat_id,
    now = now or os.time(),
  })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return true, nil
end

--- Участники боя по убыванию урона.
-- @tparam number chat_id
-- @treturn[1] table массив моделей boss_hit (может быть пустым)
-- @treturn[2] table err
function service.listHits(chat_id)
  local rows, err = sql([[
    SELECT *
    FROM boss_hits
    WHERE chat_id = ${chat_id}
    ORDER BY damage DESC
  ]], {
    chat_id = chat_id,
  })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  local hits = {}
  rows = rows or {}
  for i = 1, #rows do
    local row = rows[i]
    local hit, errs = BossHit(row, { init = true })
    if errs then
      log.error(errs)
    else
      table.insert(hits, hit)
    end
  end

  return hits, nil
end

--- Чистка урона боя (после выплаты или побега).
-- @tparam number chat_id
-- @treturn[1] table res
-- @treturn[2] table err
function service.deleteHits(chat_id)
  local res, err = sql([[
    DELETE FROM boss_hits
    WHERE chat_id = ${chat_id}
  ]], {
    chat_id = chat_id,
  })

  if err then
    return nil, setErrType({ err }, services_error_type.STORAGE_ERROR)
  end

  return res, nil
end

--- Протухшие активные бои (created старше ttlSec) - для TTL-джобы побега.
-- created - datetime, SQL-сравнения по нему нет -> box-скан + .timestamp.
-- @tparam number ttlSec
-- @treturn[1] table массив boss_session
-- @treturn[2] table err
function service.listExpired(ttlSec)
  local cutoff = os.time() - ttlSec

  local list = {}
  local ok, res = pcall(function()
    for _, tuple in box.space.boss_sessions:pairs() do
      if tuple.status == 'active' and tuple.created.timestamp <= cutoff then
        table.insert(list, tuple:tomap({ names_only = true }))
      end
    end
  end)

  if not ok then
    return nil, setErrType({ res }, services_error_type.STORAGE_ERROR)
  end

  local sessions = {}
  for i = 1, #list do
    local item = list[i]
    local session, errs = BossSession(item, { init = true })
    if errs then
      log.error(errs)
    else
      table.insert(sessions, session)
    end
  end

  return sessions, nil
end

return service
