--- Модель чата
--
local datetime = require('datetime')
local Errors = require('src.models.Errors')

local DEFAULT_CHAT_SETTINGS = {
  -- Общие параметры
  has_enable_moderation_commands = true,
  has_enable_antiflood = false,
  has_enable_captcha = false,

  -- Параметры доступные VIP пользователям
  has_delete_links = false,
  has_delete_forward_message = false,
  has_ban_sender_chat = false,

  -- Приветственное сообщение
  has_enable_hello_message = false,
}

local function Chat(data, opts)
  local init = opts and opts.init

  local errors = Errors:new({ space = 'chats' })
  local model = {}

  -- Основная информация
  -- https://core.telegram.org/bots/api#chat
  --
  if tonumber(data.id) then
    model.id = tonumber(data.id)
  else
    errors:field_missing('id')
  end

  if data.username ~= nil and data.username ~= box.NULL then
    model.username = tostring(data.username):lower()
  else
    model.username = box.NULL
  end

  if data.type then
    model.type = tostring(data.type)
  else
    errors:field_missing('type')
  end

  if data.title then
    model.title = tostring(data.title)
  elseif init then
    model.title = ''
  end

  if data.is_forum ~= nil then
    model.is_forum = data.is_forum
  elseif init then
    model.is_forum = false
  end
  --

  -- Модераторский чат, привязывается к чату
  if tonumber(data.moderation_chat_id) then
    model.moderation_chat_id = tonumber(data.moderation_chat_id)
  elseif init then
    model.moderation_chat_id = box.NULL
  end

  -- Количество участников в чате
  if tonumber(data.members) then
    model.members = tonumber(data.members)
  elseif init then
    model.members = 0
  end

  -- Касса чата (джекпот слота /spin)
  if tonumber(data.casino_cashier) then
    model.casino_cashier = tonumber(data.casino_cashier)
  elseif init then
    model.casino_cashier = 0
  end

  -- Суммарная активность чата (для топа чатов)
  if tonumber(data.total_messages) then
    model.total_messages = tonumber(data.total_messages)
  elseif init then
    model.total_messages = 0
  end

  -- Дата, когда бота добавили в чат
  if data.bot_invited_date ~= nil then
    model.bot_invited_date = data.bot_invited_date
  elseif init then
    model.bot_invited_date = datetime.new({ timestamp = os.time() })
  end

  -- Маркер первичной синхронизации стафа из Telegram getChatAdministrators.
  -- false по умолчанию, true после первого успешного syncChatStaff.
  if data.staff_synced ~= nil then
    model.staff_synced = data.staff_synced
  elseif init then
    model.staff_synced = false
  end

  -- Настройки чата
  -- __serialize = 'map' гарантирует, что пустая таблица будет
  -- сохранена как map, а не как array
  if type(data.settings) == 'table' then
    model.settings = setmetatable(data.settings, { __serialize = 'map' })
  elseif init then
    model.settings = setmetatable(DEFAULT_CHAT_SETTINGS, { __serialize = 'map' })
  end

  if errors:has_errors() then
    return nil, errors:get_compact()
  end

  return model, nil
end

return Chat
