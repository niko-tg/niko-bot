--- Callback фермы: посадка, сбор, магазин семян. Ownership: дефолтный isSameUser.
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local items = require('src.gathering.items')
local crops = require('src.farm.crops')
local animals = require('src.farm.animals')
local usersService = require('src.services.users')
local farmService = require('src.services.farm')
local gatheringService = require('src.services.gathering')
local render = require('src.commands.public.farm.render')

local command = Command:new({
  commands = { 'cb_farm' },
  flags = { Command.enum.CALLBACK },
  arguments_schema = { 'action', 'target' },
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

--- Перерисовка главного экрана фермы актуальным состоянием.
local function refresh(ctx, user_id)
  local state, err = farmService.state(user_id)
  if err then
    log.error(err)
    return
  end

  edit(ctx, render.menu(state))
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local user = command.user
  local action = command.arguments.action
  local target = command.arguments.target

  if action == 'refresh' then
    ctx:answer()
    refresh(ctx, user.id)
    return
  end

  if action == 'plant_menu' then
    local state, err = farmService.state(user.id)
    if err then
      log.error(err)
      ctx:answer()
      return
    end

    ctx:answer()
    edit(ctx, render.plantMenu(state.level))
    return
  end

  if action == 'shop' then
    local fresh, err = usersService.read(user.id)
    if err then
      log.error(err)
      ctx:answer()
      return
    end

    local st = farmService.state(user.id)

    ctx:answer()
    edit(ctx, render.seedShop(fresh or user, st and st.level or 1))
    return
  end

  if action == 'plant' then
    local res, err = farmService.plant(user.id, target)
    if err then
      log.error(err)
      ctx:answer({ text = 'Ошибка, попробуй ещё', show_alert = true })
      return
    end

    if res.status == 'locked' then
      ctx:answer({ text = ('Культура откроется на уровне %d'):format(res.min_level or 1), show_alert = true })
      return
    end

    if res.status == 'no_seed' then
      ctx:answer({ text = 'Нет семян. Купи в разделе «Семена»', show_alert = true })
      return
    end

    if res.status == 'no_slot' then
      ctx:answer({ text = 'Нет свободных грядок', show_alert = true })
      return
    end

    if res.status ~= 'ok' then
      ctx:answer({ text = 'Не удалось посадить', show_alert = true })
      return
    end

    ctx:answer('🌱 Посажено!')
    refresh(ctx, user.id)
    return
  end

  if action == 'collect' then
    local res, err = farmService.collect(user.id, target)
    if err then
      log.error(err)
      ctx:answer({ text = 'Ошибка, попробуй ещё', show_alert = true })
      return
    end

    if res.status == 'not_ready' then
      ctx:answer({ text = 'Ещё растёт', show_alert = true })
      return
    end

    if res.status == 'full' then
      ctx:answer({ text = 'Рюкзак полон, продай ресурсы', show_alert = true })
      return
    end

    if res.status == 'empty' then
      ctx:answer()
      refresh(ctx, user.id)
      return
    end

    if res.status ~= 'ok' then
      ctx:answer({ text = 'Не удалось собрать', show_alert = true })
      return
    end

    ctx:answer(('✅ Собрано: %s x%d'):format(items.label(res.product), res.count))
    refresh(ctx, user.id)
    return
  end

  if action == 'buy' then
    local res, err = gatheringService.buy(user.id, target)
    if err then
      log.error(err)
      ctx:answer({ text = 'Ошибка покупки, попробуй ещё', show_alert = true })
      return
    end

    if res.status == 'funds' then
      ctx:answer({ text = 'Недостаточно средств', show_alert = true })
      return
    end

    if res.status ~= 'ok' then
      ctx:answer({ text = 'Товар недоступен', show_alert = true })
      return
    end

    local fresh = usersService.read(user.id)
    local st = farmService.state(user.id)
    ctx:answer('✅ Куплено!')
    edit(ctx, render.seedShop(fresh or user, st and st.level or 1))
    return
  end

  if action == 'zoo' then
    local state, err = farmService.animalState(user.id)
    if err then
      log.error(err)
      ctx:answer()
      return
    end

    ctx:answer()
    edit(ctx, render.zoo(state))
    return
  end

  if action == 'animal_shop' then
    local fresh, err = usersService.read(user.id)
    if err then
      log.error(err)
      ctx:answer()
      return
    end

    local st = farmService.animalState(user.id)

    ctx:answer()
    edit(ctx, render.animalShop(fresh or user, st and st.level or 1))
    return
  end

  if action == 'buy_animal' then
    local res, err = farmService.buyAnimal(user.id, target)
    if err then
      log.error(err)
      ctx:answer({ text = 'Ошибка покупки, попробуй ещё', show_alert = true })
      return
    end

    if res.status == 'locked' then
      ctx:answer({ text = ('Животное откроется на уровне %d'):format(res.min_level or 1), show_alert = true })
      return
    end

    if res.status == 'already' then
      ctx:answer({ text = 'Это животное уже есть', show_alert = true })
      return
    end

    if res.status == 'funds' then
      ctx:answer({ text = 'Недостаточно средств', show_alert = true })
      return
    end

    if res.status ~= 'ok' then
      ctx:answer({ text = 'Животное недоступно', show_alert = true })
      return
    end

    local fresh = usersService.read(user.id)
    local st = farmService.animalState(user.id)
    ctx:answer('✅ Куплено!')
    edit(ctx, render.animalShop(fresh or user, st and st.level or 1))
    return
  end

  if action == 'collect_animal' then
    local res, err = farmService.collectAnimal(user.id, target)
    if err then
      log.error(err)
      ctx:answer({ text = 'Ошибка, попробуй ещё', show_alert = true })
      return
    end

    if res.status == 'not_ready' then
      ctx:answer({ text = 'Ещё не готово', show_alert = true })
      return
    end

    if res.status == 'full' then
      ctx:answer({ text = 'Рюкзак полон, продай ресурсы', show_alert = true })
      return
    end

    if res.status ~= 'ok' then
      ctx:answer()
      local state = farmService.animalState(user.id)
      edit(ctx, render.zoo(state))
      return
    end

    ctx:answer(('✅ Собрано: %s x%d'):format(items.label(res.product), res.count))
    local state = farmService.animalState(user.id)
    edit(ctx, render.zoo(state))
    return
  end

  if action == 'locked' then
    local def = crops.get(target) or animals.get(target)
    ctx:answer({
      text = ('Откроется на уровне %d'):format(def and def.min_level or 1),
      show_alert = true,
    })
    return
  end

  ctx:answer()
end

return command
