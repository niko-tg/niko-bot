--- Общий обработчик старта добычи для /fishing, /mining, /sawmill.
--
-- Не команда (не загружается commandLoader'ом) - переиспользуемый хендлер.
--
local log = require('log')
local vipUsersService = require('src.services.vip_users')
local userActivityService = require('src.services.user_activity')
local gatheringService = require('src.services.gathering')
local render = require('src.render.gather')

-- @tparam table ctx контекст команды
-- @tparam table command объект команды (command.user уже загружен)
-- @tparam string activityKey 'fishing' | 'mining' | 'sawmill'
return function(ctx, command, activityKey)
  local user = command.user

  -- Ошибку VIP-проверки трактуем как 'не VIP'.
  local isVip = vipUsersService.isActive(user.id) or false

  local res, err = gatheringService.begin(user.id, activityKey, ctx:getChatId(), isVip)
  if err then
    log.error(err)
    ctx:replyToMessage('⚠️ Не удалось начать, попробуй ещё')
    return
  end

  if res.status == 'busy' then
    ctx:replyToMessage(render.busyText())
    return
  end

  if res.status == 'no_tool' then
    ctx:replyToMessage(render.noToolText(activityKey))
    return
  end

  if res.status == 'full' then
    ctx:replyToMessage(render.fullText())
    return
  end

  -- Отправляем сообщение задачи и привязываем его message_id (для TTL-сбора).
  local view = render.inProgress(activityKey, res.until_date)
  local sent, sendErr = ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })

  if sendErr then
    log.error(sendErr)
    return
  end

  local messageId = sent and sent.message_id
  if messageId then
    userActivityService.setMessage(user.id, messageId)
  end
end
