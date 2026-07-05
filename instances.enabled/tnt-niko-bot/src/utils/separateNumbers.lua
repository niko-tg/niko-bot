--- Adding a separator to a number 1000000 -> 1.000.000
-- @param value (number | string)
-- @param[optchain] opts (table) options
-- @param[optchain] opts.separator (string) separator
-- @return string
local function separateNumbers(value, opts)
  if value == nil then
    return 'nil'
  end

  opts = opts or {}

  if value < 1000 then
    if opts.sign then
      if value >= 0 then
        return '+' .. tostring(value)
      end
    end

    return value
  end

  value = tostring(value)

  local len = #value
  if len <= 3 then
    return value
  end

  local num, minus = value:gsub('^%-', '')

  local result = ''
  local sepCount = 0
  local sep = opts.separator or '.'

  for i = len, 1, -1 do
    if sepCount == 3 then
      result = sep .. result
      sepCount = 0
    end

    result = num:sub(i, i) .. result
    sepCount = sepCount + 1
  end

  if minus >= 1 then
    return '-' .. result
  end

  if opts.sign then
    return '+' .. result
  end

  return result
end

return separateNumbers
