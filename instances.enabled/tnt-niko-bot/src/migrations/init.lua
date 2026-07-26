--- Одноразовые миграции хранилища.
--
-- Каждая миграция - модуль { name, apply } и выполняется через box.once:
-- Имя фиксируется в системном спейсе _schema, повторный старт её не запускает.
-- Применяются по порядку списка, ДО бутстрапа спейсов -
-- дропнутый миграцией спейс бутстрап пересоздаст с актуальным форматом.
--
local log = require('log')

-- Список миграций в порядке применения
local migrations = {
  require('src.migrations.001_captcha_symbols'),
}

--- Применение всех ещё не выполненных миграций.
local function apply()
  for i = 1, #migrations do
    local migration = migrations[i]

    box.once(migration.name, function()
      migration.apply()
      log.info('Migration [%s] applied', migration.name)
    end)
  end
end

return {
  apply = apply,
}
