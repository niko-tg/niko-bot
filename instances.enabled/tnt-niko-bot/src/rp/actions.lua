--- РП-команды: действия над собеседником (реплаем). Шаблоны с подстановкой.
-- ${userFrom} / ${userReply} / ${gender} (суффикс рода глагола: '', 'а', '(а)').
-- Категории нужны только для группировки; вызов идёт по имени команды.
--
local categories = {
  -- Любовь
  love = {
    ['обнять'] = {
      '${userFrom} обнял${gender} ${userReply} | 💖',
      '${userFrom} крепко обнял${gender} ${userReply} | 💖',
      '${userFrom} нежно обнял${gender} ${userReply} | 💖',
    },
    ['обнимашки'] = {
      '${userFrom} нежно обнял${gender} ${userReply} | 💖',
    },
    ['заобнимать'] = {
      '${userFrom} заобнимал${gender} ${userReply} | 💖',
    },
    ['прижать'] = {
      '${userFrom} прижал${gender} к себе ${userReply} | 🥵',
    },
    ['расцеловать'] = {
      '${userFrom} расцеловал${gender} ${userReply} | 🫦',
    },
    ['целовать'] = {
      '${userFrom} расцеловал${gender} ${userReply} | 🫦',
    },
    ['чмок'] = {
      '${userFrom} чмокнул${gender} ${userReply} | 🫦',
    },
    ['поцеловать'] = {
      '${userFrom} поцеловал${gender} ${userReply} | 🫦',
      '${userFrom} нежно поцеловал${gender} ${userReply} | 🫦',
    },
    ['зацеловать'] = {
      '${userFrom} зацеловал${gender} ${userReply} | 🫦',
    },
    ['секс'] = {
      '${userFrom} принудил${gender} к интиму ${userReply} | 🍌',
      '${userFrom} предложил${gender} заняться любовью ${userReply} | 🍌',
    },
    ['выебать'] = {
      '${userFrom} принудил${gender} к интиму ${userReply} | 🍌',
    },
    ['погладить'] = {
      '${userFrom} погладил${gender} ${userReply} | 🐈',
    },
    ['раздеть'] = {
      '${userFrom} раздел${gender} ${userReply} | 😏',
    },
    ['отлизать'] = {
      '${userFrom} о*л**ал${gender} ${userReply} | 🌸',
    },
    ['отсосать'] = {
      '${userFrom} отс**ал${gender} у ${userReply} | 🍌',
    },
    ['отшлёпать'] = {
      '${userFrom} отшлепал${gender} ${userReply} | 🍑',
    },
    ['отдаться'] = {
      '${userFrom} отдал${gender} себя ${userReply} | ❤️‍🔥',
    },
    ['няшиться'] = {
      '💗 | ${userFrom} и ${userReply} поняшились | 💗',
    },
    ['ласкать'] = {
      '${userFrom} ласково погладил${gender} ${userReply} по волосам | 🌸',
      '${userFrom} приласкал${gender} ${userReply} | 🌸',
    },
    ['шептать'] = {
      '${userFrom} шепчет${gender} нежные слова ${userReply} | 🤫',
      '${userFrom} тихо прошептал${gender} ${userReply} комплимент | 🤫',
    },
    ['подмигнуть'] = {
      '${userFrom} подмигнул${gender} ${userReply} | 😉',
    },
    ['улыбнуться'] = {
      '${userFrom} улыбнулся${gender} ${userReply} | 😊',
    },
    ['влюбиться'] = {
      '${userFrom} признался${gender} в любви ${userReply} | ❤️',
    },
    ['прижаться'] = {
      '${userFrom} прижался${gender} к ${userReply} | 🥰',
    },
  },

  -- Действия
  action = {
    ['лизнуть'] = {
      '${userFrom} лизнул${gender} ${userReply} | 👅',
    },
    ['понюхать'] = {
      '${userFrom} понюхал${gender} ${userReply} | 👃',
    },
    ['ущипнуть'] = {
      '${userFrom} ущипнул${gender} ${userReply} | 🤏',
    },
    ['извиниться'] = {
      '${userFrom} просит прощения у ${userReply} | 🥺',
    },
    ['покурить'] = {
      '${userFrom} покурил${gender} с ${userReply} | 🚬',
    },
    ['поздравить'] = {
      '${userFrom} поздравил${gender} ${userReply} | 🎁',
    },
    ['выпить'] = {
      '${userFrom} выпил${gender} с ${userReply} | 🥴🥂',
    },
    ['потрогать'] = {
      '${userFrom} потрогал${gender} ${userReply} | ✊',
    },
    ['покормить'] = {
      '${userFrom} покормил${gender} ${userReply} | 🍔',
    },
    ['похвалить'] = {
      '${userFrom} похвалил${gender} ${userReply} | 👏',
    },
    ['танцевать'] = {
      '${userFrom} танцует вместе с ${userReply} | 💃🕺',
    },
    ['прыгать'] = {
      '${userFrom} подпрыгнул${gender} рядом с ${userReply} | 🤸',
    },
    ['смеяться'] = {
      '${userFrom} смеётся вместе с ${userReply} | 😆',
    },
    ['плакать'] = {
      '${userFrom} расплакался${gender} от трогательного момента с ${userReply} | 😢',
    },
    ['читать'] = {
      '${userFrom} читает вслух для ${userReply} | 📖',
    },
    ['скушать'] = {
      '${userFrom} угостил${gender} ${userReply} вкусняшкой | 🍪',
    },
    ['рисовать'] = {
      '${userFrom} рисует портрет ${userReply} | 🎨',
    },
    ['фотографировать'] = {
      '${userFrom} сделал${gender} фотографию ${userReply} | 📸',
    },
    ['съесть'] = {
      '${userFrom} съел${gender} ${userReply} | 🍩',
    },
  },

  -- Насилие
  violence = {
    ['сжечь'] = {
      '${userFrom} спалил${gender} ${userReply} | 🔥',
      '${userFrom} спалил${gender} к х*ям ${userReply} | 🔥',
    },
    ['расстрелять'] = {
      '${userFrom} расстрелял${gender} ${userReply} | 🔫',
    },
    ['уебать'] = {
      '${userFrom} у**ал${gender} ${userReply} | 👊🖕',
    },
    ['ударить'] = {
      '${userFrom} ударил${gender} ${userReply} | 👊',
    },
    ['кастрировать'] = {
      '${userFrom} кастрировал${gender} ${userReply} | ✂️🥚',
    },
    ['пнуть'] = {
      '${userFrom} пнул${gender} ${userReply} | 🦵',
    },
    ['отравить'] = {
      '${userFrom} отравил${gender} ${userReply} | 🧪',
    },
    ['испугать'] = {
      '${userFrom} испугал${gender} ${userReply} | ⚰️',
    },
    ['послать'] = {
      '${userFrom} послал${gender} ${userReply} | 🤬',
      '${userFrom} послал${gender} н*х*й ${userReply} | 🤬',
      '${userFrom} послал${gender} в о*ко ${userReply} | 🤬',
      '${userFrom} послал${gender} в 3.15зду ${userReply} | 🤬',
    },
    ['изнасиловать'] = {
      '${userFrom} изн*с*л*вал${gender} ${userReply} | 🍆',
    },
    ['избить'] = {
      '${userFrom} избил${gender} ${userReply} | 👊',
    },
    ['сбить'] = {
      '${userFrom} сбил${gender} ${userReply} с ног | 🤕',
    },
    ['удушить'] = {
      '${userFrom} душит${gender} ${userReply} | 🪢',
    },
    ['проклясть'] = {
      '${userFrom} проклял${gender} ${userReply} | 🧙',
    },
    ['бомбануть'] = {
      '${userFrom} взорвал${gender} ${userReply} | 💣',
    },
    ['обокрасть'] = {
      '${userFrom} обчистил${gender} ${userReply} карманы | 🕵️',
    },
    ['забить'] = {
      '${userFrom} забил${gender} стрелу ${userReply} | 🔨',
    },
    ['раздробить'] = {
      '${userFrom} и ${userReply} отправились в Питер | 🪓',
    },
  },
}

-- Плоская карта имя -> варианты.
local byName = {}
for _, group in pairs(categories) do
  for name, variants in pairs(group) do
    byName[name] = variants
  end
end

-- Список имён для регистрации. 'обнять' первым (он же primary в /commands),
-- остальные отсортированы для стабильности.
local REPRESENTATIVE = 'обнять'

local names = { REPRESENTATIVE }
local rest = {}
for name in pairs(byName) do
  if name ~= REPRESENTATIVE then
    table.insert(rest, name)
  end
end
table.sort(rest)
for i = 1, #rest do
  local name = rest[i]
  table.insert(names, name)
end

return {
  byName = byName,
  names = names,
}
