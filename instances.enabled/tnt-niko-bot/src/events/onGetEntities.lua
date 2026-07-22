--- Событие получение сущностей.
--
local utf8 = require('utf8')
local bot = require('bot')
local config = require('conf.config')
local processCommand = require('bot.processes.processCommand')

-- Ex: /profile@niko_rp_bot
local PATTERN_BOT_CMD = '(/.+)@'..config.bot.username

--- Обработчик сообщений с сущностями: запуск команды по entity.
-- @tparam table ctx контекст обновления
local function onGetEntities(ctx)
  local entities = ctx:getEntities()
  local entity = entities and entities[1]

  -- Телеграм может прислать message с пустым entities - обрабатываем как
  -- обычное сообщение, а не команду.
  if entity == nil then
    if ctx.message.text then
      return bot.events.onGetMessageText(ctx)
    end

    return bot.events.onChatMessage(ctx)
  end

  -- Первое entity не bot_command. Это может быть текстовый алиас команды с
  -- аргументом-упоминанием ("мут @user 1m"): из-за @mention у сообщения
  -- появляется entity, и оно попадает сюда, хотя слэша нет.
  -- Поэтому пробуем разобрать как текстовую команду. onGetMessageText сам уведёт в
  -- onChatMessage (фильтры, антифлуд) и отсечёт форварды, если это не команда.
  if entity.type ~= 'bot_command' then
    return bot.events.onGetMessageText(ctx)
  end

  -- Скип пересланных команд (форварды команд не запускаем)
  if ctx.message.forward_from
    or ctx.message.forward_from_chat
    or ctx.message.forward_from_message_id
    or ctx.message.forward_signature
    or ctx.message.forward_sender_name
  then
    -- Форвард-команду не запускаем, но это реальное сообщение участника -
    -- учитываем и прогоняем через фильтры (вкл. deleteForwardMessage).
    return bot.events.onChatMessage(ctx)
  end

  if ctx.message.text:find(PATTERN_BOT_CMD) then
    local commandName, username = ctx.message.text:match('(/.+)@(.+)')
    commandName = utf8.lower(commandName)

    if username ~= config.bot.username then
      -- Команда адресована другому боту - для нас это обычное сообщение.
      return bot.events.onChatMessage(ctx)
    end

    return processCommand(ctx, {
      is_text_command = true,
      command = bot.commands[commandName],
    })
  end

  -- Голая команда без @: известную запускаем, неизвестную (просто текст с
  -- bot_command-entity) уводим в onChatMessage - учёт активности и фильтры.
  return bot.events.onGetMessageText(ctx)
end

return onGetEntities
