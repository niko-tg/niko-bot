--- Привязка чата-источника к этому модераторскому чату.
-- Запускается в чате-приёмнике логов, выбор источника - из списка своих чатов.
--
local log = require('log')
local bot = require('bot')
local auth = require('src.auth')
local Command = require('bot.classes.Command')
local userInChatService = require('src.services.user_in_chat')

local showChatList = require(bot.subdir(0, ...)..'.pages.showChatList')

local command = Command:new({
  commands = { '/modlog' },
  flags = {
    Command.enum.IN_CHAT,
    Command.enum.ADMINISTRATIVE,
  },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  -- Назначать приёмник логов может только владелец этого чата.
  -- Флаг ADMINISTRATIVE пропускает всех админов, поэтому здесь сужаем до owner.
  --
  if not auth.isBotOwner(command.user) then
    local uic, uicErr = userInChatService.read(command.chat.id, command.user.id)

    if uicErr then
      log.error(uicErr)
      return
    end

    if auth.roleOf(uic) ~= auth.roles.OWNER then
      ctx:replyToMessage('⚠️ Эту команду может выполнить только владелец чата')
      return
    end
  end
  --

  showChatList(ctx, { action = 'reply' }, command)
end

return command
