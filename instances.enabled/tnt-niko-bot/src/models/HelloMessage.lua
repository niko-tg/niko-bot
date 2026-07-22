--- Модель приветственного сообщения чата.
--
-- text может содержать HTML-теги (b/i/u/code/etc) и плейсхолдеры
-- ${user}, ${chat} - разворачиваются при отправке.
--
-- file - { type='photo'|'animation'|'video', id=file_id } или пустой map.
--
local Errors = require('src.models.Errors')

--- Конструктор модели HelloMessage.
-- @tparam table data сырые поля (из запроса или из БД)
-- @tparam[opt] table opts опции { init = true } - инициализация всех полей
-- @treturn[1] table model
-- @treturn[2] table errs
local function HelloMessage(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'hello_message' })
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

  if data.text ~= nil then
    model.text = tostring(data.text)
  elseif init then
    model.text = ''
  end

  if type(data.file) == 'table' then
    model.file = setmetatable(data.file, { __serialize = 'map' })
  elseif init then
    model.file = setmetatable({}, { __serialize = 'map' })
  end

  if errors:has_errors() then
    return nil, errors:get_compact()
  end

  return model, nil
end

return HelloMessage
