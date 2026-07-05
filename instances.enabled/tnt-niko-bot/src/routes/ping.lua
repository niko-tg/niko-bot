--- Ручка пинга
--

-- luacheck: ignore req
-- luacheck: ignore res
local ping = function(req, res)
  return {
    status = 200,
    headers = {
      ['content-type'] = 'text/plain'
    },
    body = 'pong'
  }
end

return ping
