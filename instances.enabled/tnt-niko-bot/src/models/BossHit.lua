--- Модель урона участника по рейд-боссу.
--
local Errors = require('src.models.Errors')

--- Конструктор модели BossHit.
-- @tparam table data сырые поля (из запроса или из БД)
-- @tparam[opt] table opts опции { init = true } - инициализация всех полей
-- @treturn[1] table model
-- @treturn[2] table errs
local function BossHit(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'boss_hits' })
  local model = {}

  if tonumber(data.chat_id) then
    model.chat_id = tonumber(data.chat_id)
  else
    errors:field_missing('chat_id')
  end

  if tonumber(data.user_id) then
    model.user_id = tonumber(data.user_id)
  else
    errors:field_missing('user_id')
  end

  if type(data.name) == 'string' and data.name ~= '' then
    model.name = data.name
  elseif init then
    model.name = 'Аноним'
  else
    errors:field_missing('name')
  end

  if tonumber(data.damage) then
    model.damage = math.max(0, math.floor(tonumber(data.damage)))
  elseif init then
    model.damage = 0
  else
    errors:field_missing('damage')
  end

  if tonumber(data.hits) then
    model.hits = math.max(0, math.floor(tonumber(data.hits)))
  elseif init then
    model.hits = 0
  else
    errors:field_missing('hits')
  end

  if tonumber(data.last_hit_at) then
    model.last_hit_at = tonumber(data.last_hit_at)
  elseif init then
    model.last_hit_at = 0
  else
    errors:field_missing('last_hit_at')
  end

  if errors:has_errors() then
    return nil, errors:get_compact()
  end

  return model, nil
end

return BossHit
