--- Проверяет является ли сообщение форвардом.
--
-- Покрывает и legacy-поля (forward_from / forward_from_chat / ...),
-- и новое forward_origin (Bot API 7.0+).
-- @see https://core.telegram.org/bots/api#messageorigin
--
local function isForward(message)
  if message == nil then
    return false
  end

  return message.forward_from ~= nil
    or message.forward_from_chat ~= nil
    or message.forward_from_message_id ~= nil
    or message.forward_signature ~= nil
    or message.forward_sender_name ~= nil
    or message.forward_origin ~= nil
end

return isForward
