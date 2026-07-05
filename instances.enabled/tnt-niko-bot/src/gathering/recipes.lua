--- Рецепты крафта: переработка сырья в более дорогой предмет (money sink).
--
-- Массив (порядок = вывод в меню). Крафт мгновенный: списать inputs, выдать output
-- атомарно в инвентаре. id рецепта совпадает с id выходного предмета.
--

return {
  {
    id = 'ingot',
    inputs = {
      { id = 'metal',  count = 2 },
      { id = 'coal',   count = 3 }
    },
    output = {
      id = 'ingot',
      count = 1
    },
  },
  {
    id = 'plank',
    inputs = {
      { id = 'oak', count = 3 }
    },
    output = {
      id = 'plank',
      count = 1
    },
  },
  {
    id = 'soup',
    inputs = {
      { id = 'fish',     count = 5 },
      { id = 'mushroom', count = 1 }
    },
    output = {
      id = 'soup',
      count = 1
    },
  },

  -- Готовка из урожая фермы
  {
    id = 'flour',
    inputs = {
      { id = 'wheat', count = 2 }
    },
    output = {
      id = 'flour',
      count = 1
    },
  },
  {
    id = 'bread',
    inputs = {
      { id = 'flour', count = 2 }
    },
    output = {
      id = 'bread',
      count = 1
    },
  },
  {
    id = 'veg_stew',
    inputs = {
      { id = 'carrot', count = 2 },
      { id = 'corn',   count = 1 }
    },
    output = {
      id = 'veg_stew',
      count = 1
    },
  },
  {
    id = 'pumpkin_pie',
    inputs = {
      { id = 'pumpkin', count = 1 },
      { id = 'flour',   count = 2 }
    },
    output = {
      id = 'pumpkin_pie',
      count = 1
    },
  },
  {
    id = 'pastry',
    inputs = {
      { id = 'flour', count = 2 },
      { id = 'egg',   count = 2 },
      { id = 'milk',  count = 1 }
    },
    output = {
      id = 'pastry',
      count = 1
    },
  },
}
