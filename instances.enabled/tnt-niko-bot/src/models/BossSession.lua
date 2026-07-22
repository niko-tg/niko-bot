--- Модель боя с рейд-боссом чата.
--
local datetime = require('datetime')
local Errors = require('src.models.Errors')

local STATUSES = {
  active = true,
  finished = true,
}

--- Конструктор модели BossSession.
-- @tparam table data сырые поля (из запроса или из БД)
-- @tparam[opt] table opts опции { init = true } - инициализация всех полей
-- @treturn[1] table model
-- @treturn[2] table errs
local function BossSession(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'boss_sessions' })
  local model = {}

  if tonumber(data.chat_id) then
    model.chat_id = tonumber(data.chat_id)
  else
    errors:field_missing('chat_id')
  end

  if type(data.boss_id) == 'string' and data.boss_id ~= '' then
    model.boss_id = data.boss_id
  else
    errors:field_missing('boss_id')
  end

  if tonumber(data.hp) then
    model.hp = math.max(0, math.floor(tonumber(data.hp)))
  else
    errors:field_missing('hp')
  end

  if tonumber(data.hp_max) then
    model.hp_max = math.floor(tonumber(data.hp_max))
  else
    errors:field_missing('hp_max')
  end

  if tonumber(data.message_id) then
    model.message_id = tonumber(data.message_id)
  else
    errors:field_missing('message_id')
  end

  if STATUSES[data.status] then
    model.status = data.status
  elseif init then
    model.status = 'active'
  else
    errors:field_missing('status')
  end

  if data.created ~= nil then
    model.created = data.created
  elseif init then
    model.created = datetime.new({ timestamp = os.time() })
  end

  -- finished_at nullable: есть только у завершённых боёв.
  if tonumber(data.finished_at) then
    model.finished_at = tonumber(data.finished_at)
  end

  if errors:has_errors() then
    return nil, errors:get_compact()
  end

  return model, nil
end

return BossSession
