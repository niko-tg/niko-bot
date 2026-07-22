--- Callback сбора: 'Собрать' готовой задачи и 'Повторить' после завершения.
-- Ownership: одиночное взаимодействие, дефолтный isSameUser-гейт.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local vipUsersService = require('src.services.vip_users')
local userActivityService = require('src.services.user_activity')
local gatheringService = require('src.services.gathering')
local render = require('src.render.gather')

local command = Command:new({
  commands = { 'cb_collect' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action', 'activity' },
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

--- Запустить ту же активность заново прямо в этом сообщении.
local function repeatActivity(ctx, user_id, activityKey)
  local isVip = vipUsersService.isActive(user_id) or false

  local res, err = gatheringService.begin(user_id, activityKey, ctx:getChatId(), isVip)
  if err then
    log.error(err)

    ctx:answer({
      text = 'Ошибка, попробуй ещё',
      show_alert = true,
    })
    return
  end

  if res.status == 'busy' then
    ctx:answer({
      text = 'У тебя уже идёт добыча',
      show_alert = true,
    })
    return
  end

  if res.status == 'no_tool' then
    ctx:answer({
      text = 'Нет инструмента - загляни в /shop',
      show_alert = true,
    })
    return
  end

  if res.status == 'full' then
    ctx:answer({
      text = 'Рюкзак полон - продай ресурсы',
      show_alert = true,
    })
    return
  end

  ctx:answer()
  edit(ctx, render.inProgress(activityKey, res.until_date))
  userActivityService.setMessage(user_id, ctx:getMessageId())
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local user = command.user
  local action = command.arguments.action
  local activity = command.arguments.activity

  if action == 'repeat' then
    repeatActivity(ctx, user.id, activity)
    return
  end

  -- Сбор готовой задачи.
  local res, err = gatheringService.collect(user.id)
  if err then
    log.error(err)

    ctx:answer({
      text = 'Ошибка сбора, попробуй ещё',
      show_alert = true,
    })
    return
  end

  if res.status == 'none' then
    ctx:answer({
      text = 'Уже собрано',
      show_alert = true,
    })
    return
  end

  if res.status == 'not_ready' then
    ctx:answer({
      text = 'Ещё не готово: ' .. render.clock(res.remaining),
      show_alert = true,
    })

    edit(ctx, render.inProgress(res.activity, os.time() + res.remaining))
    return
  end

  ctx:answer('🧺 Собрано!')
  edit(ctx, render.result(res))
end

return command
