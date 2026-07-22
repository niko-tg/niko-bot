--- Lua format string.
-- @param text text
-- @param args table
local function fstring(text, args)
  local res, _ = string.gsub(text, '%${([%w_]+)}', args)
  return res
end

-- Example
--[[
string.f = require('fstring')
local str = '${name}, hello!'
print(
  str:f({ name = 'uriid1' })
) -- Uriid1, hello!
]]

return fstring
