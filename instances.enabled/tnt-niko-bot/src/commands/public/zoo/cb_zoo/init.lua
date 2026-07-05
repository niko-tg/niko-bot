--- Callback зоомагазина: навигация по экранам + покупки питомцев и зоотоваров.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local config = require('conf.config')
local render = require('src.commands.public.zoo.render')
local petsService = require('src.services.pets')
local vipUsersService = require('src.services.vip_users')

local command = Command:new {
  commands = { 'cb_zoo' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action', 'a', 'b' },
}

-- Показать экран (всегда фото) через editMessageMedia.
local function showView(ctx, view)
  if not view then
    return
  end

  local _, err = bot:editMessageMedia({
    chat_id = ctx:getChatId(),
    message_id = ctx:getMessageId(),
    media = {
      type = 'photo',
      media = view.image,
      caption = view.caption,
      parse_mode = 'HTML',
    },
    reply_markup = view.keyboard,
  })

  -- "message is not modified" при двойном тапе и т.п. - не шумим.
  if err then
    log.verbose(err)
  end
end

-- Покупка питомца.
local function buyPet(ctx, user, breed, color)
  local isVip, vipErr = vipUsersService.isActive(user.id)
  if vipErr then
    log.error(vipErr)
    isVip = false
  end

  local maxPets = isVip and config.pets.count_vip or config.pets.count_default

  local result, err = petsService.buy(user.id, breed, color, maxPets)
  if err then
    log.error(err)
    ctx:answer({ text = 'Ошибка покупки, попробуй ещё', show_alert = true })
    return
  end

  if result.status == 'limit' then
    ctx:answer({
      text = 'Достигнут лимит питомцев ('..result.max..').\nVIP даёт больше - /donat',
      show_alert = true
    })
    return
  end

  if result.status == 'funds' then
    local what = result.currency == 'crystals' and 'кристаллов' or 'средств'
    ctx:answer({ text = 'Недостаточно '..what..' :<\nДонат: /donat', show_alert = true })
    return
  end

  if result.status ~= 'ok' then
    ctx:answer({ text = 'Питомец недоступен', show_alert = true })
    return
  end

  ctx:answer('⭐️ Поздравляем с питомцем!')
  showView(ctx, render.petBought())
end

-- Покупка зоотовара.
local function buySupply(ctx, user, supplyId)
  local result, err = petsService.buySupply(user.id, supplyId)
  if err then
    log.error(err)
    ctx:answer({ text = 'Ошибка покупки, попробуй ещё', show_alert = true })
    return
  end

  if result.status == 'funds' then
    local what = result.currency == 'crystals' and 'кристаллов' or 'средств'
    ctx:answer({ text = 'Недостаточно '..what..' :<', show_alert = true })
    return
  end

  if result.status ~= 'ok' then
    ctx:answer({ text = 'Товар недоступен', show_alert = true })
    return
  end

  ctx:answer('✅ Куплено!')
  showView(ctx, render.supplyBought(supplyId))
end

-- Навигация без побочных эффектов: action -> экран.
local NAV = {
  menu  = function() return render.menu() end,
  pets  = function() return render.petCategories() end,
  breed = function(a) return render.petColors(a) end,
  view  = function(a, b) return render.petDetail(a, b) end,
  items = function() return render.supplyCategories() end,
  cat   = function(a) return render.supplyList(a) end,
  sview = function(a) return render.supplyDetail(a) end,
}

function command.call(ctx)
  local args = command.arguments
  local action = args.action
  local user = command.user

  local nav = NAV[action]
  if nav then
    ctx:answer()
    showView(ctx, nav(args.a, args.b))
    return
  end

  if action == 'buy' then
    buyPet(ctx, user, args.a, args.b)
    return
  end

  if action == 'sbuy' then
    buySupply(ctx, user, args.a)
    return
  end

  ctx:answer()
end

return command
