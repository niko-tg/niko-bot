--- Сменился владелец чата.
--- В payload по доке только new_owner (User), старого id в событии нет.
--
local log = require('log')
local chat_member_status = require('bot.enums.chat_member_status')
local uicService = require('src.services.user_in_chat')

local function on_chat_owner_changed(ctx)
  log.verbose('[event] %s', 'on_chat_owner_changed')

  local chat = ctx:getChat()
  local new_owner = ctx.message.chat_owner_changed.new_owner

  -- TODO: гипотеза - при передаче овнерства Telegram дополнительно
  -- шлёт chat_member update для старого владельца с его новым статусом.
  -- Доками не подтверждено, нужно проверить эмпирически.
  -- Если гипотеза не подтвердится - старого овнера здесь находить
  -- через uicService.getByStatus(chat.id, chat_member_status.CREATOR)
  -- и явно даунгрейдить (вероятный целевой статус - administrator).

  local _, err = uicService.upsert({
    chat_id = chat.id,
    user_id = new_owner.id,
    status = chat_member_status.CREATOR,
    permissions = {},
  })

  if err then
    log.error(err)
  end
end

return on_chat_owner_changed
