--- Тоггл привязки выбранного чата к этому модераторскому чату.
--
local log = require('log')
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local auth = require('src.auth')
local Command = require('bot.classes.Command')
local chatService = require('src.services.chats')
local userInChatService = require('src.services.user_in_chat')
local chat_member_status = require('bot.enums.chat_member_status')

local showChatList = require(bot.subdir(1, ...)..'.pages.showChatList')

local command = Command:new({
  commands = { 'cb_modlog' },
  flags = {
    Command.enum.CALLBACK,
    Command.enum.ADMINISTRATIVE,
  },
  arguments_schema = { 'chat_id' },
})

--- Футер о статусе бота в выбранном чате: получит ли бот логи модерации.
-- Без прав администратора Telegram не шлёт боту chat_member апдейты.
-- chat - модель Chat выбранного чата.
local function botStatusFooter(chat)
  local member, err = bot:getChatMember({
    chat_id = chat.id,
    user_id = bot:getBotId(),
  })

  if err then
    log.error(err)
    return nil
  end

  local statusLine
  if member.status == chat_member_status.ADMINISTRATOR then
    statusLine = '🤖 Статус бота: <b>Администратор</b>'
            .. '\n✅ Логи модерации будут приходить.'
  else
    statusLine = '🤖 Статус бота: <b>Не администратор!</b>'
            .. '\n❌ Выдайте боту права администратора (в выбранном чате), иначе логи приходить не будут.'
  end

  local title = '🏘 Чат: ' .. (
    (chat.title ~= nil and chat.title ~= '') and
    chat.title or
    tostring(chat.id)
  )

  return ('${sep}\n<b>${title}</b>\n${status}'):f({
    sep = hdec.sep,
    title = hdec.escape(title),
    status = statusLine,
  })
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local selectedId = tonumber(command.arguments.chat_id)

  if not selectedId then
    ctx:answer({ text = '⚠️ Не удалось определить чат', show_alert = true })
    return
  end

  -- Менять приёмник логов чата может только его владелец.
  -- callback_data не доверяем - сверяем статус заново.
  --
  if not auth.isBotOwner(command.user) then
    local uic, uicErr = userInChatService.read(selectedId, command.user.id)

    if uicErr then
      log.error(uicErr)
      return
    end

    if auth.roleOf(uic) ~= auth.roles.OWNER then
      ctx:answer({ text = '⚠️ Только владелец чата', show_alert = true })
      return
    end
  end
  --

  local selected, readErr = chatService.read(selectedId)

  if readErr then
    log.error(readErr)
    return
  end

  if selected == nil then
    ctx:answer({ text = '⚠️ Чат не найден', show_alert = true })
    return
  end

  -- Повторный тап по уже привязанному сюда чату - отвязка (moderation_chat_id = NULL).
  local willUnbind = selected.moderation_chat_id == command.chat.id

  local newValue
  if willUnbind then
    newValue = box.NULL
  else
    newValue = command.chat.id
  end

  local _, updErr = chatService.update({ moderation_chat_id = newValue }, { id = selectedId })

  if updErr then
    log.error(updErr)
    ctx:answer({ text = '⚠️ Не удалось сохранить', show_alert = true })
    return
  end

  if willUnbind then
    ctx:answer('❎ Отвязали')
  else
    ctx:answer('✅ Привязали')
  end

  -- Статус бота показываем только при привязке: для отвязанного чата
  -- строка "логи будут приходить" была бы ложной.
  local footer
  if not willUnbind then
    footer = botStatusFooter(selected)
  end

  showChatList(ctx, {
    action = 'edit',
    footer = footer,
  }, command)
end

return command
