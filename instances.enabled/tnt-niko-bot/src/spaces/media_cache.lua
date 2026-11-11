--- Кэш file_id для локальных ассетов (assets/).
-- Файл загружается в Telegram один раз, дальше отправляется по file_id.
-- version - размер и mtime файла: при замене файла кэш сбрасывается сам.
--

--- Схема спейса.
local formatSpace = {
  {
    name = 'path',
    type = 'string',
  },
  {
    name = 'version',
    type = 'string',
  },
  {
    name = 'file_id',
    type = 'string',
  },
}

--- Индексы спейса.
local index = {
  {
    name = 'path',
    options = {
      parts = {'path'},
      unique = true,
      if_not_exists = true,
    },
  },
}

-- Экспорт модуля.
--
return {
  format_space = formatSpace,
  index = index,
}
