--- Callback крафта: сделать рецепт / обновить. Ownership: дефолтный isSameUser.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local inventoryService = require('src.services.inventory')
local gatheringService = require('src.services.gathering')
local render = require('src.commands.public.craft.render')

local command = Command:new({
  commands = { 'cb_craft' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action', 'recipe' },
})

--- Перерисовка списка крафта актуальным инвентарём.
local function refresh(ctx, user_id)
  local inv, err = inventoryService.read(user_id)
  if err then
    log.error(err)
    return
  end

  local view = render.list(inv)

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
  local user = command.user
  local action = command.arguments.action
  local recipeId = command.arguments.recipe

  if action == 'craft' then
    local res, err = gatheringService.craft(user.id, recipeId)
    if err then
      log.error(err)

      ctx:answer({
        text = 'Ошибка крафта, попробуй ещё',
        show_alert = true,
      })
      return
    end

    if res.status == 'missing' then
      ctx:answer({
        text = 'Не хватает ресурсов',
        show_alert = true,
      })
      return
    end

    if res.status ~= 'ok' then
      ctx:answer({
        text = 'Рецепт недоступен',
        show_alert = true,
      })
      return
    end

    ctx:answer('🛠 Готово!')
    refresh(ctx, user.id)
    return
  end

  if action == 'refresh' then
    ctx:answer()
    refresh(ctx, user.id)
    return
  end

  ctx:answer()
end

return command
