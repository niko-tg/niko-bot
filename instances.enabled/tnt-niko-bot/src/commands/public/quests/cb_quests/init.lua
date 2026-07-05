--- Callback контрактов: забрать награду / обновить. Ownership: дефолтный isSameUser.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local separateNumbers = require('src.utils.separateNumbers')
local gatheringService = require('src.services.gathering')
local render = require('src.commands.public.quests.render')

local command = Command:new {
  commands = { 'cb_quests' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action', 'quest' },
}

--- Перерисовка списка контрактов актуальным состоянием.
local function refresh(ctx, user_id)
  local state, err = gatheringService.questState(user_id)
  if err then
    log.error(err)
    return
  end

  local view = render.list(state)

  bot:editMessageText({
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    text = view.text,
    reply_markup = view.keyboard,
  })
end

--- Тост о полученной награде.
local function rewardToast(reward)
  if reward.crystals then
    return ('🎁 Награда: +%d💎'):format(reward.crystals)
  end
  return ('🎁 Награда: +%sр'):format(separateNumbers(reward.money))
end

function command.call(ctx)
  local user = command.user
  local action = command.arguments.action
  local questId = command.arguments.quest

  if action == 'claim' then
    local res, err = gatheringService.claimQuest(user.id, questId)
    if err then
      log.error(err)
      ctx:answer({ text = 'Ошибка, попробуй ещё', show_alert = true })
      return
    end

    if res.status == 'incomplete' then
      ctx:answer({ text = 'Контракт ещё не выполнен', show_alert = true })
      return
    end

    if res.status == 'claimed' then
      ctx:answer({ text = 'Награда уже забрана', show_alert = true })
      return
    end

    if res.status ~= 'ok' then
      ctx:answer({ text = 'Контракт недоступен', show_alert = true })
      return
    end

    ctx:answer({ text = rewardToast(res.reward), show_alert = true })
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
