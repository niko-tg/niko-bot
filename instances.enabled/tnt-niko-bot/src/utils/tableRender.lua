--- Простой рендер таблиц для быстрой диагностики
--
local datetime = require('datetime')

local TAB_SYMBOL = '╰ '

local tokinaze
function tokinaze(t, res, seen)
  local res = res or {}
  local seen = seen or { [t] = true }
  for k,v in pairs(t) do
    if type(v) == 'table' then
      if not seen[v] then
        seen[v] = true
      else
        table.insert(res, { k, '<cycle>' })
        break
      end

      res[k] = res[k] or {}
      tokinaze(v, res[k], seen)
    else
      if type(v) == 'cdata' then
        if v == box.NULL then
          v = 'null'
        elseif datetime.is_datetime(v) then
          v = v:format('%d.%m.%y %H:%M')
        end
      end
      table.insert(res, { k, tostring(v) })
    end
  end

  return res
end

local render
function render(tokens, deep)
  local res = {}
  local keys = {}
  local deep = deep or 0
  for token, value in pairs(tokens) do
    if type(token) == 'string' then
      table.insert(keys, { token, deep })
      goto continue
    end

    if deep > 0 then
      table.insert(res,
        string.rep(' ', deep)..TAB_SYMBOL..table.concat(value, ': '))
    else
      table.insert(res, table.concat(value, ': '))
    end
    ::continue::
  end

  for i = 1, #keys do
    local token = keys[i][1]
    local tokenDeep = keys[i][2] or 0
    local value = tokens[token]

    table.insert(res, string.rep(' ', tokenDeep) .. token..':')
    if tokenDeep > 0 then
      table.insert(res, render(value, tokenDeep + deep))
    else
      table.insert(res, render(value, 2))
    end
  end

  return table.concat(res, '\n')
end

return function(t)
  return render(tokinaze(t))
end
