--- Ежедневный бонус: раз в сутки случайная сумма на баланс (VIP - больше).
--
local log = require('log')
local Command = require('bot.classes.Command')
local config = require('conf.config')
local render = require('src.commands.public.bonus.render')
local usersService = require('src.services.users')
local vipUsersService = require('src.services.vip_users')
local userGameStatsService = require('src.services.user_game_stats')

local command = Command:new {
  commands = { '/bonus', 'бонус' },
  flags = {
    Command.enum.PUBLIC,
    Command.enum.NO_REPLY
  }
}

function command.call(ctx)
  local user = command.user
  local bonus = config.daily_bonus

  -- Заявка на дневной слот: штампит время выдачи, если кулдаун прошёл.
  local claim, claimErr = userGameStatsService.claimDailyBonus(user.id, bonus.cooldown)
  if claimErr then
    log.error(claimErr)
    return
  end

  -- Уже получал в текущем окне - показываем обратный отсчёт.
  if not claim.granted then
    ctx:reply(render.alreadyClaimed(claim.lastBonusAt + bonus.cooldown))
    return
  end

  -- VIP получает больше. Ошибку проверки трактуем как «не VIP».
  local isVip, vipErr = vipUsersService.isActive(user.id)
  if vipErr then
    log.error(vipErr)
    isVip = false
  end

  local lo = isVip and bonus.vip_min_amount or bonus.min_amount
  local hi = isVip and bonus.vip_max_amount or bonus.max_amount
  local amount = math.random(lo, hi)

  -- Слот уже занят выше, поэтому деньги начисляем после успешной заявки.
  local newBalance, creditErr = usersService.addBalance(user.id, amount)
  if creditErr then
    log.error(creditErr)
    return
  end

  -- Шанс получить кристалл сверху
  local crystals = 0
  if math.random(1, 10000) <= bonus.crystal_chance then
    crystals = 1

    local _, crystalErr = usersService.addCrystals(user.id, crystals)
    if crystalErr then
      log.error(crystalErr)
      crystals = 0
    end
  end

  ctx:reply(render.claimed(amount, newBalance, crystals))
end

return command
