--- Каталог питомцев: виды (категории) и породы внутри них.
-- Порядок (typeOrder/colorOrder) задаёт стабильный вывод кнопок в магазине.
--
local catalog = {}

-- Категории в порядке показа.
catalog.typeOrder = { 'cats', 'dogs', 'hamsters', 'fantasy' }

catalog.types = {
  cats     = { label = 'Кошечка',        button = '🐈 Котики'      },
  dogs     = { label = 'Собачка',        button = '🐕 Собачки'     },
  hamsters = { label = 'Хомячок',        button = '🐹 Хомячки'     },
  fantasy  = { label = 'Фантастическая', button = '🐦‍🔥 Уникальные' },
}

-- Породы (цвета) внутри вида в порядке показа.
catalog.colorOrder = {
  cats     = { 'white', 'black', 'orange', 'star' },
  dogs     = { 'white', 'hasky', 'pink', 'rubin', 'diamond' },
  hamsters = { 'hamtaro' },
  fantasy  = { 'white', 'firefox' },
}

-- Данные пород: name (отображаемое имя), price, currency ('money'|'crystals'),
-- description, emoji.
catalog.pets = {
  dogs = {
    white = {
      name = 'Белая дворняжка',
      price = 5000,
      currency = 'money',
      description = 'Дружелюбная дворняжка с уравновешенным характером, подойдёт в качестве первого питомца',
      emoji = '🐕'
    },
    hasky = {
      name = 'Хаски',
      price = 15000,
      currency = 'money',
      description = 'Энергичный и выносливый пёс с выразительными глазами, любит активное внимание',
      emoji = '🐕'
    },
    pink = {
      name = 'Розовый Бигль',
      price = 100000,
      currency = 'money',
      description = 'Эксклюзивная порода с нежной шерстью, обладающая острым нюхом и дружелюбным нравом',
      emoji = '🐕'
    },
    rubin = {
      name = 'Рубиновая бася',
      price = 1,
      currency = 'crystals',
      description = 'Редкая мистическая порода с переливающейся шерстью, приносит своему хозяину удачу',
      emoji = '🐕'
    },
    diamond = {
      name = 'Бриллиантовая Бася',
      price = 5,
      currency = 'crystals',
      description = 'Уникальная порода с твёрдым, словно алмаз, характером и поразительной красотой',
      emoji = '🐕'
    }
  },

  cats = {
    white = {
      name = 'Белая дворняжка',
      price = 5000,
      currency = 'money',
      description = 'Спокойная и с мягким характером, легко адаптируется к любому дому',
      emoji = '🐈'
    },
    black = {
      name = 'Чёрная дворняжка',
      price = 5000,
      currency = 'money',
      description = 'Таинственная и независимая, любит уединённый отдых на солнечном подоконнике',
      emoji = '🐈'
    },
    orange = {
      name = 'Оранжевая дворняжка',
      price = 15000,
      currency = 'money',
      description = 'Активная и любознательная кошка с ярким окрасом и добродушным поведением',
      emoji = '🐈'
    },
    star = {
      name = 'Звёздный лорд',
      price = 3,
      currency = 'crystals',
      description = 'Уникальная космическая кошечка с синей шерстью, обладает врождённым чувством тайны и величия',
      emoji = '🐈'
    }
  },

  hamsters = {
    hamtaro = {
      name = 'Hamtaro',
      price = 1,
      currency = 'crystals',
      description = 'Маленький герой аниме, активный и дружелюбный',
      emoji = '🐹'
    }
  },

  fantasy = {
    white = {
      name = 'Белая Сапфира',
      price = 5,
      currency = 'crystals',
      description = 'Магический питомец, обладающий таинственными способностями и мудростью древних',
      emoji = '💠'
    },
    firefox = {
      name = 'Огнелис',
      price = 1000000,
      currency = 'money',
      description = 'Шкодный и свободолюбивый',
      emoji = '🔥'
    }
  }
}

--- Данные породы или nil, если вид/цвет неизвестны.
-- @param breed (string) вид (dogs/cats/hamsters/fantasy)
-- @param color (string) порода (цвет)
function catalog.get(breed, color)
  local byBreed = catalog.pets[breed]
  if not byBreed then
    return nil
  end

  return byBreed[color]
end

return catalog
