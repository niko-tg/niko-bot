--- Ручка проверка статуса webhook
--
local bot = require('bot')
local json = require('json')
local http = require('http.client')

-- luacheck: ignore req
-- luacheck: ignore res
local getWebHookInfo = function(req, res)
  -- Request
  local urlFmt = bot.api_url..'%s/%s'
  local data = http.post(urlFmt:format(bot.token, 'getWebHookInfo'))

  local body = json.decode(data.body)
  if body == nil then
    return {
      status = 200,
      headers = {
        ['content-type'] = 'text/plain'
      },
      body = 'Error decode body'
    }
  end

  -- Hide url
  if body.result and body.result.url then
    body.result.url = '<secret>'
  end

  return {
    status = 200,
    headers = {
      ['content-type'] = 'text/plain'
    },
    body = json.encode(body)
  }
end

return getWebHookInfo
