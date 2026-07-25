--- Модель капча-сессии нового участника чата.
--
local datetime = require('datetime')
local Errors = require('src.models.Errors')

--- Конструктор модели CaptchaSession.
-- @tparam table data сырые поля (из запроса или из БД)
-- @tparam[opt] table opts опции { init = true } - инициализация всех полей
-- @treturn[1] table model
-- @treturn[2] table errs
local function CaptchaSession(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'captcha_sessions' })
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

  if tonumber(data.message_id) then
    model.message_id = tonumber(data.message_id)
  elseif init then
    model.message_id = 0
  end

  if data.greet ~= nil then
    model.greet = data.greet
  elseif init then
    model.greet = false
  end

  if data.created ~= nil then
    model.created = data.created
  elseif init then
    model.created = datetime.new({ timestamp = os.time() })
  end

  if errors:has_errors() then
    return nil, errors:get_compact()
  end

  return model, nil
end

return CaptchaSession
