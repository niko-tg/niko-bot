--- Ручка пинга.
--

-- luacheck: ignore req
-- luacheck: ignore res
--- Обработчик GET /v1/ping: проверка живости инстанса.
-- @tparam table req запрос
-- @tparam table res ответ
-- @treturn table HTTP-ответ с телом pong
local function ping(req, res)
  return {
    status = 200,
    headers = {
      ['content-type'] = 'text/plain',
    },
    body = 'pong',
  }
end

return ping
