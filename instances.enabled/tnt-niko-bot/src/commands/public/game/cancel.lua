--- Принудительная отмена игровой сессии игрока в конкретном чате
-- (игрока замутили/забанили). Возврат ставок обоим, без победителя.
--
local log = require('log')
local bot = require('bot')
local gamingService = require('src.services.gaming_sessions')
local usersService = require('src.services.users')
local tgErrors = require('src.utils.tgErrors')
local render = require('src.commands.public.game.render')

--- @param chatId (number) чат, где сработала причина отмены
-- @param actor (table) telegram-объект игрока (для упоминания)
-- @param verb (string) причина: 'замучен' | 'забанен'
local function cancelForUser(chatId, actor, verb)
  local session, err = gamingService.getByPlayer(actor.id)
  if err then
    log.error(err)
    return
  end

  -- Игрок не в игре либо его сессия в другом чате -> не трогаем.
  if not session or session.chat_id ~= chatId then
    return
  end

  local _, refundErr = usersService.refundGame(
    session.player1_id, session.player2_id, session.bid)

  -- Деньги не вернулись -> сессию НЕ удаляем (TTL-job подберёт позже).
  if refundErr then
    log.error(refundErr)
    return
  end

  gamingService.delete(session.player1_id)

  local player1 = usersService.read(session.player1_id) or { id = session.player1_id }
  local player2 = usersService.read(session.player2_id) or { id = session.player2_id }

  local _, sendErr = bot:sendMessage({
    chat_id = session.chat_id,
    text = render.gameCancelled(session, player1, player2, actor, verb).text,
  })

  if sendErr then
    if tgErrors.isBotBlocked(sendErr) or tgErrors.isChatNotFound(sendErr) then
      log.verbose(sendErr)
    else
      log.error(sendErr)
    end
  end
end

return cancelForUser
