--- Callback инвентаря: продать один ресурс / продать всё / обновить.
-- Ownership: одиночное взаимодействие, дефолтный isSameUser-гейт.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local separateNumbers = require('src.utils.separateNumbers')
local inventoryService = require('src.services.inventory')
local gatheringService = require('src.services.gathering')
local render = require('src.commands.public.inventory.render')

local command = Command:new({
  commands = { 'cb_inv' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action', 'item' },
})

--- Перерисовка экрана инвентаря актуальным состоянием.
local function refresh(ctx, user_id)
  local inv, err = inventoryService.read(user_id)
  if err then
    log.error(err)
    return
  end

  local view = render.inventory(inv)

  bot:editMessageText({
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    text = view.text,
    reply_markup = view.keyboard,
  })
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  -- Читаем до первого yield: command - общий объект (см. cb_mines).
  local user = command.user
  local action = command.arguments.action

  if action == 'sellall' then
    local result, err = gatheringService.sellAll(user.id)
    if err then
      log.error(err)
      ctx:answer({ text = 'Ошибка продажи, попробуй ещё', show_alert = true })
      return
    end

    if result.total > 0 then
      ctx:answer(('💰 Продано на %sр'):format(separateNumbers(result.total)))
    else
      ctx:answer('Нечего продавать')
    end

    refresh(ctx, user.id)
    return
  end

  ctx:answer()
end

return command
