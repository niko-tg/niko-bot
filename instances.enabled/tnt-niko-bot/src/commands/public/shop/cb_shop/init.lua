--- Callback магазина: меню -> раздел -> карточка -> покупка.
-- Ownership: дефолтный isSameUser-гейт.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local items = require('src.gathering.items')
local activities = require('src.gathering.activities')
local usersService = require('src.services.users')
local inventoryService = require('src.services.inventory')
local gatheringService = require('src.services.gathering')
local render = require('src.commands.public.shop.render')

local command = Command:new({
  commands = { 'cb_shop' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action', 'item' },
})

--- Перерисовка карточки на месте (правка исходного сообщения).
-- @tparam table ctx контекст обновления
-- @tparam table view { text, keyboard }
local function edit(ctx, view)
  bot:editMessageText({
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    text = view.text,
    reply_markup = view.keyboard,
  })
end

--- Карточка товара актуальным инвентарём (для строки 'у тебя').
local function showItem(ctx, user_id, itemId)
  local inv, err = inventoryService.read(user_id)
  if err then
    log.error(err)
    return
  end

  edit(ctx, render.item(itemId, inv))
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  -- Читаем до первого yield: command - общий объект (см. cb_mines).
  local user = command.user
  local action = command.arguments.action
  local item = command.arguments.item

  if action == 'menu' then
    local fresh, err = usersService.read(user.id)
    if err then
      log.error(err)
      ctx:answer()
      return
    end

    ctx:answer()
    edit(ctx, render.menu(fresh or user))
    return
  end

  if action == 'cat' then
    if activities[item] == nil then
      ctx:answer()
      return
    end

    ctx:answer()
    edit(ctx, render.category(item))
    return
  end

  if action == 'item' then
    local def = items.get(item)
    if def == nil or not (def.kind == 'tool' or def.kind == 'consumable') then
      ctx:answer()
      return
    end

    ctx:answer()
    showItem(ctx, user.id, item)
    return
  end

  if action == 'buy' then
    local result, err = gatheringService.buy(user.id, item)
    if err then
      log.error(err)

      ctx:answer({
        text = 'Ошибка покупки, попробуй ещё',
        show_alert = true,
      })

      return
    end

    if result.status == 'funds' then
      local what = (result.currency == 'crystals') and 'кристаллов' or 'средств'

      ctx:answer({
        text = 'Недостаточно ' .. what,
        show_alert = true,
      })

      return
    end

    if result.status ~= 'ok' then
      ctx:answer({
        text = 'Товар недоступен',
        show_alert = true,
      })
      return
    end

    ctx:answer('✅ Куплено!')
    showItem(ctx, user.id, item)
    return
  end

  ctx:answer()
end

return command
