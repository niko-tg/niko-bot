--- Мини-игра «Пазл» (память, PVE): запомни порядок эмодзи и повтори.
--
local log = require('log')
local Command = require('bot.classes.Command')
local userGameStatsService = require('src.services.user_game_stats')
local vipUsersService = require('src.services.vip_users')
local render = require('src.commands.public.puzzle.render')

local command = Command:new {
  commands = { '/puzzle', 'пазл' },
  flags = { Command.enum.PUBLIC },
}

function command.call(ctx)
  local user = command.user

  local state, err = userGameStatsService.readPuzzle(user.id)
  if err then
    log.error(err)
    return
  end

  -- Кулдаун активен -> отсчёт.
  if os.time() < state.next then
    ctx:replyToMessage(render.cooldown(state.next))
    return
  end

  -- Есть активный пазл -> возобновляем (тот же, не реролл).
  if state.active then
    local view = render.resume(state.active)

    ctx:replyToMessage({
      text = view.text,
      reply_markup = view.keyboard
    })

    return
  end

  -- Иначе меню сложности (VIP видит увеличенную награду).
  local isVip, vipErr = vipUsersService.isActive(user.id)
  if vipErr then
    log.error(vipErr)
    isVip = false
  end

  local view = render.menu(isVip)
  ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard
  })
end

return command
