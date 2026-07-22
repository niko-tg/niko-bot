--- Дневные контракты: цель по добыче -> награда. Сброс раз в сутки (как /bonus).
--
-- goal.kind:
--   'item'     - собрать count штук предмета goal.item (растёт при сборе лута)
--   'activity' - собрать count чего угодно в активности goal.activity (при сборе лута)
--   'craft'    - скрафтить count штук предмета goal.item (растёт при крафте)
--   'farm'     - собрать count любого урожая на ферме (растёт при сборе с грядки)
--   'harvest'  - собрать count урожая goal.item (конкретная культура)
-- Награда выдаётся по нажатию 'Забрать'.
--

return {
  {
    id = 'fish_day',
    name = 'Рыбный день',
    emoji = '🐟',
    goal = {
      kind = 'item',
      item = 'fish',
      count = 30,
    },
    reward = { money = 20000 },
  },
  {
    id = 'miner',
    name = 'Шахтёр',
    emoji = '⛏️',
    goal = {
      kind = 'item',
      item = 'coal',
      count = 50,
    },
    reward = { money = 15000 },
  },
  {
    id = 'lumberjack',
    name = 'Лесоруб',
    emoji = '🪓',
    goal = {
      kind = 'activity',
      activity = 'sawmill',
      count = 40,
    },
    reward = { money = 15000 },
  },

  -- Цели на конкретный лут
  {
    id = 'red_fisher',
    name = 'Рыбак-профи',
    emoji = '🐡',
    goal = {
      kind = 'item',
      item = 'red_fish',
      count = 5,
    },
    reward = { money = 25000 },
  },
  {
    id = 'prospector',
    name = 'Старатель',
    emoji = '🪙',
    goal = {
      kind = 'item',
      item = 'gold',
      count = 8,
    },
    reward = { money = 20000 },
  },
  {
    id = 'mushroomer',
    name = 'Грибник',
    emoji = '🍄',
    goal = {
      kind = 'item',
      item = 'mushroom',
      count = 10,
    },
    reward = { money = 12000 },
  },
  {
    id = 'scrapper',
    name = 'Металлист',
    emoji = '♻️',
    goal = {
      kind = 'item',
      item = 'scrap_metal',
      count = 10,
    },
    reward = { money = 12000 },
  },
  {
    id = 'jeweler',
    name = 'Ювелир',
    emoji = '💎',
    goal = {
      kind = 'item',
      item = 'diamond',
      count = 1000,
    },
    reward = { crystals = 1 },
  },

  -- Крафт
  {
    id = 'blacksmith',
    name = 'Кузнец',
    emoji = '🔨',
    goal = {
      kind = 'craft',
      item = 'ingot',
      count = 3,
    },
    reward = { money = 18000 },
  },
  {
    id = 'cook',
    name = 'Повар',
    emoji = '🍲',
    goal = {
      kind = 'craft',
      item = 'soup',
      count = 2,
    },
    reward = { money = 15000 },
  },

  -- Ферма
  {
    id = 'gardener',
    name = 'Огородник',
    emoji = '🧺',
    goal = {
      kind = 'farm',
      count = 15,
    },
    reward = { money = 18000 },
  },
  {
    id = 'pumpkin_grower',
    name = 'Тыквовод',
    emoji = '🎃',
    goal = {
      kind = 'harvest',
      item = 'pumpkin',
      count = 5,
    },
    reward = { money = 22000 },
  },
  {
    id = 'baker',
    name = 'Пекарь',
    emoji = '🍞',
    goal = {
      kind = 'craft',
      item = 'bread',
      count = 3,
    },
    reward = { money = 16000 },
  },
}
