--- Лут-таблицы добычи (вместо magic random(30) старого бота).
--
-- base - пул базового улова: за сбор выпадает yield_min..yield_max штук,
--   каждая - случайный предмет из пула (для рыбалки/рудника пул из одного вида).
-- rare - весовой пул дополнительного дропа. Шанс выронить - rare_odds из config
--   (1 из N; mining = 1, т.е. материал падает всегда, как в старом боте).
--   min_level гейтит дроп по уровню навыка: редкости открываются с прокачкой.
--   jackpot - помечает «вкусный» дроп для отдельного сообщения.
--

return {
  fishing = {
    base = { 'fish' },
    rare = {
      { id = 'scrap_metal', weight = 20, min_level = 1 },
      { id = 'yellow_fish', weight = 8,  min_level = 1 },
      { id = 'blue_fish',   weight = 6,  min_level = 2 },
      { id = 'turtle',      weight = 3,  min_level = 2 },
      { id = 'snake',       weight = 3,  min_level = 2 },
      { id = 'bober',       weight = 3,  min_level = 3 },
      { id = 'red_fish',    weight = 3,  min_level = 3 },
      { id = 'gold_chain',  weight = 1,  min_level = 4, jackpot = true },
    },
  },

  mining = {
    base = { 'coal' },
    rare = {
      { id = 'gravel',     weight = 20, min_level = 1 },
      { id = 'granite',    weight = 16, min_level = 1 },
      { id = 'metal',      weight = 14, min_level = 1 },
      { id = 'tuff',       weight = 12, min_level = 1 },
      { id = 'cuprum',     weight = 10, min_level = 2 },
      { id = 'lazurite',   weight = 8,  min_level = 2 },
      { id = 'andesite',   weight = 8,  min_level = 2 },
      { id = 'diorite',    weight = 6,  min_level = 3 },
      { id = 'gold',       weight = 5,  min_level = 3 },
      { id = 'red_stone',  weight = 5,  min_level = 4 },
      { id = 'diamond',    weight = 4,  min_level = 4, jackpot = true },
      { id = 'emerald',    weight = 2,  min_level = 5, jackpot = true },
      { id = 'quartz',     weight = 2,  min_level = 5, jackpot = true },
      { id = 'deep_shale', weight = 1,  min_level = 6, jackpot = true },
    },
  },

  sawmill = {
    base = { 'oak', 'birch', 'spruce', 'bamboo', 'sawdust', 'bark', 'charcoal' },
    rare = {
      { id = 'vines',    weight = 12, min_level = 1 },
      { id = 'mushroom', weight = 10, min_level = 1 },
      { id = 'jungle',   weight = 8,  min_level = 2 },
      { id = 'acacia',   weight = 6,  min_level = 3 },
      { id = 'dark_oak', weight = 4,  min_level = 4 },
      { id = 'resin',    weight = 3,  min_level = 4, jackpot = true },
    },
  },
}
