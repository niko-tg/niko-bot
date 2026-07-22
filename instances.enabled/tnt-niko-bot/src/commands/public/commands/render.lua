--- Рендер справочника команд: меню категорий + страница категории.
-- Команды берутся из bot.commands (авто-обнаружение), описания - из словаря.
--
local bot = require('bot')
local hdec = require('bot.libs.hdec')
local F = require('bot.enums.command_flags')
local commandsInfo = require('src.dict.commandsInfo')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

-- Категории по приоритету флагов + заголовок и примечание.
local CATEGORIES = {
  public = {
    title = '📋 Публичные',
    note = nil,
  },
  moderation = {
    title = '🛡 Модераторские',
    note = 'Работают в группах, нужна роль модератора или админа',
  },
  private = {
    title = '🔐 Личные',
    note = 'Работают в личке с ботом',
  },
  maint = {
    title = '🔧 Обслуживание',
    note = 'Только для владельца бота',
  },
}

local MENU_ORDER = { 'public', 'moderation', 'private' }

--- Категория команды по её флагам.
-- @tparam table cmd описание команды
-- @treturn string ключ категории
local function categoryOf(cmd)
  if cmd:hasFlag(F.MAINTENANCE) then
    return 'maint'
  end

  if cmd:hasFlag(F.MODERATION) or
    cmd:hasFlag(F.ADMINISTRATIVE)
  then
    return 'moderation'
  end

  if cmd:hasFlag(F.PRIVATE) then
    return 'private'
  end

  return 'public'
end

--- Уникальные команды (bot.commands ключуется каждым алиасом) по категориям, без callback.
local function collect()
  local seen = {}
  local groups = {
    public = {},
    moderation = {},
    private = {},
    maint = {},
  }

  for _, cmd in pairs(bot.commands) do
    if type(cmd) == 'table' and cmd.commands and cmd.hasFlag
      and not cmd:hasFlag(F.CALLBACK) and not seen[cmd]
    then
      seen[cmd] = true
      table.insert(groups[categoryOf(cmd)], cmd)
    end
  end

  return groups
end

--- Бейдж к команде в зависимости от категории (scope для публичных, роль для модераторских).
local function badge(cmd, catKey)
  if catKey == 'public' and cmd:hasFlag(F.IN_CHAT) then
    return ' | <i>в группе</i>'
  end
  if catKey == 'moderation' then
    if cmd:hasFlag(F.ADMINISTRATIVE) then
      return ' | <i>админ+</i>'
    end

    if cmd:hasFlag(F.MODERATION) then
      return ' | <i>модератор+</i>'
    end
  end
  return ''
end

--- Кнопка перехода в категорию.
-- @tparam string catKey ключ категории
-- @treturn table описание кнопки
local function catButton(catKey)
  return {
    text = CATEGORIES[catKey].title,
    callback = {
      command = 'cb_commands',
      arguments = {
        action = catKey,
      },
    },
  }
end

local render = {}

--- Главное меню категорий. isOwner -> добавляет 'Обслуживание'.
function render.menu(isOwner)
  local rows = {}
  for i = 1, #MENU_ORDER do
    local key = MENU_ORDER[i]
    table.insert(rows, { catButton(key) })
  end
  if isOwner then
    table.insert(rows, { catButton('maint') })
  end

  return {
    text = '<b>📚 Команды бота</b>\n'..hdec.sep..'\nВыбери категорию',
    keyboard = inlineCallbackKeyboard(rows),
  }
end

--- Страница категории. maint доступна только владельцу (isOwner).
-- @treturn ?table { text, keyboard } (нет доступа/категории)
function render.category(catKey, isOwner)
  local meta = CATEGORIES[catKey]
  if not meta or (catKey == 'maint' and not isOwner) then
    return nil
  end

  local list = collect()[catKey]
  table.sort(list, function(a, b) return a.commands[1] < b.commands[1] end)

  local lines = { '<b>'..meta.title..'</b>' }
  if meta.note then
    table.insert(lines, '<i>'..meta.note..'</i>')
  end
  table.insert(lines, hdec.sep)

  for idx = 1, #list do
    local cmd = list[idx]
    local primary = cmd.commands[1]

    -- info на самой команде = самодостаточное описание.
    -- Такие команды (напр. РП с десятками имён) не вываливают весь список алиасов.
    local aliasStr = ''
    if not cmd.info then
      local aliases = {}
      for i = 2, #cmd.commands do
        table.insert(aliases, cmd.commands[i])
      end
      aliasStr = #aliases > 0 and (' <i>('..table.concat(aliases, ', ')..')</i>') or ''
    end

    table.insert(lines, '<code>'..primary..'</code>'..aliasStr)

    local desc = cmd.info or commandsInfo[primary] or 'Без описания'
    table.insert(lines, '  ╰ '..desc..badge(cmd, catKey))
  end

  local keyboard = inlineCallbackKeyboard({
    {
      {
        text = '◀️ Назад',
        callback = {
          command = 'cb_commands',
          arguments = {
            action = 'menu',
          },
        },
      },
    },
  })

  return {
    text = table.concat(lines, '\n'),
    keyboard = keyboard,
  }
end

return render
