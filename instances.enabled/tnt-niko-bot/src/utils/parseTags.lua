--- Разбор HTML-разметки Telegram: валидация и вырезание тегов.
--
local utf8 = require('utf8')

local html_tags = {
  ['b'] = true,
  ['i'] = true,
  ['u'] = true,
  ['s'] = true,
  ['del'] = true,
  ['em'] = true,
  ['ins'] = true,
  ['code'] = true,
  ['pre'] = true,
  ['strike'] = true,
  ['strong'] = true,
  ['tg-spoiler'] = true,
}

--- Валидация HTML-разметки Telegram в тексте.
-- @tparam string text проверяемый текст
-- @tparam[opt=5000] number max_text_size максимальная длина текста
-- @tparam[opt=100] number tags_limit максимальное число тегов
-- @treturn table массив найденных ошибок разметки
local function parseTags(text, max_text_size, tags_limit)
  local errs = {}
  local tagStack = {}
  local tags_count = 0

  max_text_size = max_text_size or 5000
  tags_limit = tags_limit or 100

  for raw in string.gmatch(text, '<(.-)>') do
    local isClosing = raw:sub(1, 1) == '/'
    local tagName = isClosing and raw:sub(2) or raw

    tags_count = tags_count + 1
    if tags_count > tags_limit then
      table.insert(errs, 'Нельзя использовать больше '..tags_limit..' тегов')

      return false, errs
    end

    -- проверка допустимого имени
    if not html_tags[tagName] then
      local disp = #tagName > 10
        and (tagName:sub(1,3)..' ... '..tagName:sub(-3))
        or tagName

      table.insert(errs, 'Недопустимый тег <'..disp..'>')

      return false, errs
    end

    if not isClosing then
      -- открывающий тег
      table.insert(tagStack, tagName)
    else
      -- закрывающий
      local top = tagStack[#tagStack]
      if not top then
        table.insert(errs, 'Отсутствует открывающий тег для </'..tagName..'>')

        return false, errs
      end

      if top ~= tagName then
        table.insert(errs,
          'Ожидался закрывающий тег </'..top..'>, найден </'..tagName..'>'
        )

        return false, errs
      end

      table.remove(tagStack)  -- корректно закрыли
    end
  end

  if #tagStack > 0 then
    for i = 1, #tagStack do
      local unclosed = tagStack[i]
      table.insert(errs, 'Отсутствует закрывающий тег для <'..unclosed..'>')
    end

    return false, errs
  end

  -- Удаляем корректные пары тегов и проверяем оставшийся текст
  local reduced = text
  local pattern = '<(.-)>(.-)</%1>'
  local count
  repeat
    reduced, count = string.gsub(reduced, pattern, '%2', 1)
  until count == 0

  if reduced == '' then
    table.insert(errs, 'Отсутствует текст между тегами')

    return false, errs
  end

  if utf8.len(reduced) > max_text_size then
    table.insert(errs, 'Допустимая длина: '..max_text_size..' символов')

    return false, errs
  end

  if reduced:find('[<>]') then
    table.insert(errs,
      'Некорректно составлены теги. Символы < и > внутри текста запрещены'
    )

    return false, errs
  end

  -- если нет ошибок
  return true, nil
end

return parseTags
