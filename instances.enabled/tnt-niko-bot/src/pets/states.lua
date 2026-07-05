--- Состояния питомца (вычисляются из параметров и времени суток) и их описания.
-- Имя состояния совпадает с именем файла картинки: .../<state>.jpg
--
local M = {}

M.state = {
  BORED    = 'bored',
  DIRTY    = 'dirty',
  HUNGRY   = 'hungry',
  JOYFUL   = 'joyful',
  NEUTRAL  = 'neutral',
  PLAYING  = 'playing',
  SICK     = 'sick',
  SLEEPING = 'sleeping',
  SLEEPY   = 'sleepy',
}

-- Описание состояния для карточки.
M.info = {
  [M.state.BORED]    = 'чем-то недоволен',
  [M.state.DIRTY]    = 'чувствует себя грязнулей',
  [M.state.HUNGRY]   = 'хочет кушать',
  [M.state.JOYFUL]   = 'настроение отличное',
  [M.state.NEUTRAL]  = 'всё хорошо',
  [M.state.PLAYING]  = 'играет',
  [M.state.SICK]     = 'очень болезненно',
  [M.state.SLEEPY]   = 'сонный',
  [M.state.SLEEPING] = 'спит',
}

-- Статус существования питомца.
M.status = {
  ALIVE = 'alive',
  DEAD  = 'dead',
}

return M
