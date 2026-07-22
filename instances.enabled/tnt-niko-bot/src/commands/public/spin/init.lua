--- Слот-машина 'Спин' (PVE): ставка -> барабаны -> выплата. Касса чата - джекпот.
--
local log = require('log')
local config = require('conf.config')
local chat_type = require('bot.enums.chat_type')
local Command = require('bot.classes.Command')
local decodeMoneyString = require('src.utils.decodeMoneyString')
local usersService = require('src.services.users')
local chatsService = require('src.services.chats')
local render = require('src.commands.public.spin.render')
local rng = require('src.commands.public.spin.rng')

local command = Command:new({
  commands = { '/spin', 'спин', 'казино' },
  flags = { Command.enum.PUBLIC },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local user = command.user
  local chatId = ctx:getChatId()
  local spin = config.spin

  -- В личке играть можно, но касса (джекпот) - только в группах.
  local chatType = ctx:getChatType()
  local isGroup = chatType == chat_type.GROUP or chatType == chat_type.SUPERGROUP

  local arg = ctx.message.text:match('^%S+%s+(%S+)')

  -- Без ставки -> касса + комбинации.
  if not arg then
    local cashbox = (command.chat and command.chat.casino_cashier) or 0
    ctx:replyToMessage(render.info(cashbox, isGroup))
    return
  end

  local bid = decodeMoneyString(arg)
  if not bid or bid < spin.min_bid then
    ctx:replyToMessage(('💸 Минимальная ставка: <b>${min_bid}</b>р'):f({ min_bid = spin.min_bid }))
    return
  end

  if user.balance < bid then
    ctx:replyToMessage('💸 У тебя недостаточно средств')
    return
  end

  local spinResult = rng.spin()
  local category = spinResult.category
  local result = {
    category = category,
    reels = spinResult.reels,
    cashboxWon = 0,
    gotCrystal = false,
  }

  if category == 'lose' then
    result.amount = bid

    local newBalance, err = usersService.addBalance(user.id, -bid)
    if err then
      log.error(err)
      ctx:replyToMessage('⚠️ Ошибка')
      return
    end
    result.balance = newBalance

    -- Часть проигрыша уходит в кассу чата (только в группах).
    if isGroup then
      local _, cbErr = chatsService.addCashbox(chatId, math.floor(bid * spin.cashbox_pc / 100))
      if cbErr then
        log.error(cbErr)
      end
    end

  elseif category == 'win2' then
    result.amount = (spin.win2_mult - 1) * bid

    local newBalance, err = usersService.addBalance(user.id, result.amount)
    if err then
      log.error(err)
      ctx:replyToMessage('⚠️ Ошибка')
      return
    end
    result.balance = newBalance

  else
    -- jackpot / ultra: множитель + ВСЯ касса чата.
    local mult = (category == 'ultra') and spin.ultra_mult or spin.jackpot_mult
    result.amount = (mult - 1) * bid

    -- Касса (джекпот) - только в группах.
    if isGroup then
      local taken, cbErr = chatsService.takeCashbox(chatId)
      if cbErr then
        log.error(cbErr)
      end
      result.cashboxWon = taken or 0
    end

    local newBalance, err = usersService.addBalance(user.id, result.amount + result.cashboxWon)
    if err then
      log.error(err)
      ctx:replyToMessage('⚠️ Ошибка')
      return
    end
    result.balance = newBalance

    -- Ультра + крупная ставка -> кристалл.
    if category == 'ultra' and bid >= spin.crystal_bid then
      result.gotCrystal = true

      local _, crystalErr = usersService.addCrystals(user.id, 1)
      if crystalErr then
        log.error(crystalErr)
      end
    end
  end

  ctx:replyToMessage(render.result(result))
end

return command
