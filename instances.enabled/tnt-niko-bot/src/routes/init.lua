--- Ручки.
--
local ping = require('src.routes.ping')
local getWebHookInfo = require('src.routes.getWebHookInfo')

local routes = {
  {
    path = '/v1/ping',
    method = 'GET',
    callback = ping,
  },
  {
    path = '/v1/getWebHookInfo',
    method = 'GET',
    callback = getWebHookInfo,
  },
}


return routes
