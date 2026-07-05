--- Старница с настройками
--
local bot = require('bot')
local Command = require('bot.classes.Command')

local showMainPage = require(bot.subdir(1, ...)..'.pages.showMainPage')
local showChatSettings = require(bot.subdir(1, ...)..'.pages.showChatSettings')
local showVipSettingsPage = require(bot.subdir(1, ...)..'.pages.showVipSettingsPage')
local showHelloMessagePage = require(bot.subdir(1, ...)..'.pages.showHelloMessagePage')

local arguments_dict = require(bot.subdir(1, ...)..'.arguments_dict')

local command = Command:new {
  commands = { 'cb_settings' },
  flags = {
    Command.enum.CALLBACK,
    Command.enum.ADMINISTRATIVE
  },
  arguments_schema = { 'page', 'action' }
}

function command.call(ctx)
  -- Ответ на нажатие кнопки
  ctx:answer()

  -- Аргументы
  local arguments = command.arguments

  if arguments.page == arguments_dict.page.main then
    showMainPage(ctx, arguments)

  elseif arguments.page == arguments_dict.page.settings then
    showChatSettings(ctx, arguments, command.chat)

  elseif arguments.page == arguments_dict.page.vip_settings then
    showVipSettingsPage(ctx, arguments, command.chat)

  elseif arguments.page == arguments_dict.page.hello_message then
    showHelloMessagePage(ctx, arguments, command.chat)
  end
end

return command
