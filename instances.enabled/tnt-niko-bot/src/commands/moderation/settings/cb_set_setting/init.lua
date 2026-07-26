--- Старница с настройками.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local chatService = require('src.services.chats')
local vipUsersService = require('src.services.vip_users')

local showChatSettings = require(bot.subdir(1, ...)..'.pages.showChatSettings')
local showVipSettingsPage = require(bot.subdir(1, ...)..'.pages.showVipSettingsPage')
local showHelloMessagePage = require(bot.subdir(1, ...)..'.pages.showHelloMessagePage')
local arguments_dict = require(bot.subdir(1, ...)..'.arguments_dict')

local command = Command:new({
  commands = { 'cb_set_setting' },
  flags = {
    Command.enum.CALLBACK,
    Command.enum.ADMINISTRATIVE,
  },
  arguments_schema = { 'page', 'param', 'value' },
})

--- Текст всплывающего ответа при переключении настройки.
-- @tparam boolean flag новое значение настройки
-- @treturn string
local function mkAnswerText(flag)
  if flag then
    return '✅ Включили'
  end
  return '❎ Выключили'
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  -- Аргументы
  local arguments = command.arguments

  -- Значение параметра
  local value = arguments.value == 'true'

  -- VIP-настройки меняет только обладатель активного VIP.
  -- Без VIP - alert юзеру, ничего не сохраняем и UI не обновляем.
  --
  if arguments.page == arguments_dict.page.vip_settings then
    local isVip, vipErr = vipUsersService.isActive(command.user.id)

    if vipErr then
      log.error(vipErr)
      isVip = false
    end

    if not isVip then
      ctx:answer({ text = '👅 Эта настройка только для VIP', show_alert = true })
      return
    end
  end
  --

  -- Ответ на нажатие кнопки
  ctx:answer(mkAnswerText(value))

  local pChat = command.chat

  -- Общие настроки
  --
  if arguments.param == arguments_dict.param.has_enable_antiflood then
    pChat.settings.has_enable_antiflood = value

  elseif arguments.param == arguments_dict.param.has_enable_moderation_commands then
    pChat.settings.has_enable_moderation_commands = value

  elseif arguments.param == arguments_dict.param.has_enable_captcha then
    pChat.settings.has_enable_captcha = value
  end

  -- Приветственно сообщение
  --
  if arguments.param == arguments_dict.param.has_enable_hello_message then
    pChat.settings.has_enable_hello_message = value
  end

  -- VIP настройки
  --
  if arguments.param == arguments_dict.param.has_delete_links then
    pChat.settings.has_delete_links = value

  elseif arguments.param == arguments_dict.param.has_delete_forward_message then
    pChat.settings.has_delete_forward_message = value

  elseif arguments.param == arguments_dict.param.has_ban_sender_chat then
    pChat.settings.has_ban_sender_chat = value
  end

  -- Обновление настроек чата
  --
  local _, err = chatService.update({ settings = pChat.settings }, { id = pChat.id })

  if err then
    log.error(err)
  end
  --

  -- Обновить заданную страницу
  if arguments.page == arguments_dict.page.settings then
    showChatSettings(ctx, {
      page = arguments_dict.page.settings,
      action = arguments_dict.action.show,
    }, command.chat)

  elseif arguments.page == arguments_dict.page.vip_settings then
    showVipSettingsPage(ctx, {
      page = arguments_dict.page.vip_settings,
      action = arguments_dict.action.show,
    }, command.chat)

  elseif arguments.page == arguments_dict.page.hello_message then
    showHelloMessagePage(ctx, {
      page = arguments_dict.page.hello_message,
      action = arguments_dict.action.show,
    }, command.chat)
  end
end

return command
