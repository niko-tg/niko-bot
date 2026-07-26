--- Капча с символами: у captcha_sessions добавились answer/progress/attempts.
-- create_space с if_not_exists формат существующего спейса не обновляет.
-- Сессии эфемерны (TTL пара минут) - дроп, бутстрап спейсов пересоздаст его с актуальным форматом.
return {
  name = '001_captcha_symbols',

  apply = function()
    if box.space.captcha_sessions then
      box.space.captcha_sessions:drop()
    end
  end,
}
