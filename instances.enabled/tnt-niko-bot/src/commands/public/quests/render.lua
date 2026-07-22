--- Рендер контрактов: список целей дня, прогресс, кнопки 'Забрать'.
--
local hdec = require('bot.libs.hdec')
local separateNumbers = require('src.utils.separateNumbers')
local inlineCallbackKeyboard = require('bot.middlewares.inlineCallbackKeyboard')

local render = {}

--- Награда в читаемый вид.
local function rewardLabel(reward)
  if reward.crystals then
    return reward.crystals .. '💎'
  end
  return separateNumbers(reward.money) .. 'р'
end

--- Остаток до сброса как HH:MM:SS (ASCII).
local function countdown(sec)
  if sec < 0 then
    sec = 0
  end
  return ('%02d:%02d:%02d'):format(math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60)
end

local QUEST_LINE = '  ╰ ${emoji} ${name}: ${status} | 🎁 ${reward}'
local CLAIM_BTN = 'Забрать ${emoji} ${name} (+${reward})'

local QUESTS_TEXT = [[
🎯 <b>Квесты дня</b>
${sep}
${lines}
${sep}
Обновление через <b>${countdown}</b>]]

--- Экран контрактов.
-- @tparam table state из gathering.questState
-- @treturn table { text, keyboard }
function render.list(state)
  local lines = {}
  local rows = {}

  for i = 1, #state.list do
    local entry = state.list[i]
    local def = entry.def

    local status
    if entry.claimed then
      status = '💰 забрано'
    elseif entry.complete then
      status = ('[☑️ %d/%d]'):format(entry.progress, def.goal.count)
    else
      status = ('%d/%d'):format(entry.progress, def.goal.count)
    end

    table.insert(lines, QUEST_LINE:f({
      emoji = def.emoji,
      name = def.name,
      status = status,
      reward = rewardLabel(def.reward),
    }))

    if entry.complete and not entry.claimed then
      table.insert(rows, {
        {
          text = CLAIM_BTN:f({
            emoji = def.emoji,
            name = def.name,
            reward = rewardLabel(def.reward),
          }),
          callback = {
              command = 'cb_quests',
              arguments = {
              action = 'claim',
              quest = def.id,
            },
          },
        },
      })
    end
  end

  table.insert(rows, {
    {
      text = '🔄 Обновить',
      callback = {
        command = 'cb_quests',
        arguments = {
          action = 'refresh',
          quest = '0',
        },
      },
    },
  })

  local text = QUESTS_TEXT:f({
    sep = hdec.sep,
    lines = table.concat(lines, '\n'),
    countdown = countdown(state.next_reset - os.time()),
  })

  return {
    text = text,
    keyboard = inlineCallbackKeyboard(rows),
  }
end

return render
