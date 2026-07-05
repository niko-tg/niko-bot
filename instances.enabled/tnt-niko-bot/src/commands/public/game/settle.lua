--- Расчёт исхода партии по очкам: деньги, XP, статистика.
-- Равные очки (вкл. 0:0) -> возврат ставок и ничья обоим.
-- Иначе -> победителю обе ставки + XP, проигравшему списание + статистика.
--
local usersService = require('src.services.users')
local userGameStatsService = require('src.services.user_game_stats')

--- @param session (table) сессия игры
-- @param data (table) состояние { [user_id] = { score, steps } }
-- @return[1] outcome { draw=bool, winnerId, loserId } | nil
-- @return[2] err (если деньги не перевелись -> сессию НЕ трогаем)
local function settle(session, data)
  local player1Id = session.player1_id
  local player2Id = session.player2_id
  local score1 = (data[player1Id] and data[player1Id].score) or 0
  local score2 = (data[player2Id] and data[player2Id].score) or 0

  if score1 == score2 then
    local _, err = usersService.refundGame(player1Id, player2Id, session.bid)
    if err then
      return nil, err
    end

    userGameStatsService.record(player1Id, 'draw')
    userGameStatsService.record(player2Id, 'draw')

    return { draw = true }, nil
  end

  local winnerId, loserId
  if score1 > score2 then
    winnerId, loserId = player1Id, player2Id
  else
    winnerId, loserId = player2Id, player1Id
  end

  local _, err = usersService.settleGame(winnerId, loserId, session.bid)
  if err then
    return nil, err
  end

  usersService.addXP(winnerId, 10)
  userGameStatsService.record(winnerId, 'win')
  userGameStatsService.record(loserId, 'loss')

  return { draw = false, winnerId = winnerId, loserId = loserId }, nil
end

return settle
