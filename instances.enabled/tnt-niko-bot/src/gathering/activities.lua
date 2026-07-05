--- Структурное описание активностей добычи.
--
-- Только структура (id, подпись, подходящие инструменты). Числовые параметры
-- (таймеры, выход, шансы) лежат в conf/config.lua -> gathering, лут - в loot.lua.
--
-- tools - инструменты по возрастанию класса; стартовать можно любым, что есть
-- в инвентаре. bait (если задан) - расходник, ускоряющий задачу.
--

local activities = {
  fishing = {
    id = 'fishing',
    name = 'Рыбалка',
    emoji = '🎣',
    tools = { 'rod', 'rod_pro' },
    bait = 'bait',
  },
  mining = {
    id = 'mining',
    name = 'Рудник',
    emoji = '⛏️',
    tools = { 'pick_wood', 'pick_metal', 'pick_pro' },
  },
  sawmill = {
    id = 'sawmill',
    name = 'Лесопилка',
    emoji = '🪓',
    tools = { 'axe_wood', 'saw_hand', 'saw_pro' },
  },
}

-- Порядок для меню/перечислений.
activities.order = { 'fishing', 'mining', 'sawmill' }

return activities
