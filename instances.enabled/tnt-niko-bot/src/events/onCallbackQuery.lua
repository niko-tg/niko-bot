--- Событие обработки кнопок с колбэком
--
local log = require('log')
local bot = require('bot')
local fiber = require('fiber')
local tgErrors = require('src.utils.tgErrors')
local chat_type = require('bot.enums.chat_type')
local command_flags = require('bot.enums.command_flags')
local processCommand = require('bot.processes.processCommand')

-- Текст ответа на слишком частые нажатия. ${sec} - сколько ждать.
local TOO_FAST_TEXT = '⏳ Часто жмёшь! Подожди ${sec} сек'

-- Текст когда сам Telegram не дал изменить сообщение (flood). ${sec} - его retry_after.
local TG_FLOOD_TEXT = '⏳ Телеграм просит подождать ${sec} сек'

-- Ответ на слишком частые нажатия кнопки
-- cache_time просит клиент Telegram какое-то время отдавать -
-- этот ответ из своего кэша и не слать новый запрос на повторные нажатия той же кнопки -
-- так бот не заваливает Telegram запросами и кнопка перестаёт «зависать»
-- wait приходит сверху: примерно столько секунд до следующего разрешённого нажатия.
local function antiflood_answer(ctx, wait)
  local seconds = math.max(1, math.ceil(wait or 1))

  ctx:answer({
    text = TOO_FAST_TEXT:f({ sec = seconds }),
    show_alert = false,
    cache_time = seconds,
  })
end

-- Есть ли в ответе осмысленный текст попапа («БУМ», «Забрал»...), а не пустой
-- ack, который просто гасит «часики» на кнопке.
local function hasText(fields)
  if type(fields) == 'string' then
    return fields ~= ''
  end

  if type(fields) == 'table' then
    return fields.text ~= nil and fields.text ~= ''
  end

  return false
end

-- Подменяем ctx:answer на время обработки одного колбэка:
--   * осмысленный попап - отправляем сразу;
--   * пустой ack - откладываем. Вдруг правка сообщения упрётся во flood и нам
--     нужно будет показать таймер вместо пустого ответа (ответить можно один раз).
local function instrumentAnswer(ctx)
  local rawAnswer = ctx.answer

  ctx._floodState = {
    answered = false,
    ackPending = false,
    rawAnswer = rawAnswer,
  }

  ctx.answer = function(self, fields)
    if hasText(fields) then
      self._floodState.answered = true
      return rawAnswer(self, fields)
    end

    self._floodState.ackPending = true
  end
end

-- После обработки: если никто так и не ответил, но хендлер просил погасить
-- «часики» - досылаем отложенный пустой ack.
local function flushAnswer(ctx)
  local state = ctx._floodState

  if not state.answered and state.ackPending then
    state.rawAnswer(ctx)
  end
end

-- Когда Telegram ответил 429 на правку сообщения (частое при быстрых нажатиях),
-- сама правка не прошла. Чтобы кнопка не «зависала», отвечаем активному колбэку
-- этого fiber'а таймером с реальным retry_after от Telegram. cache_time просит
-- клиент не слать повторные нажатия той же кнопки на это время.
local function answerFlood(ctx, err)
  local seconds = tgErrors.retryAfter(err)

  ctx:answer({
    text = TG_FLOOD_TEXT:f({ sec = seconds }),
    show_alert = false,
    cache_time = seconds,
  })
end

-- Один раз оборачиваем методы правки, чтобы ловить flood централизованно -
-- без правок в каждом хендлере.
-- Активный колбэк берём из storage этого fiber'а  (каждый апдейт обрабатывается в своём fiber'е).
-- Не-колбэчные правки (рассылка) идут в чужих fiber'ах, где storage пуст - там обёртка ничего не делает.
local guardInstalled = false

local function installFloodGuard()
  if guardInstalled then
    return
  end

  guardInstalled = true

  local function wrap(method)
    local raw = bot[method]

    if type(raw) ~= 'function' then
      return
    end

    bot[method] = function(self, fields, opts)
      local res, err = raw(self, fields, opts)

      if tgErrors.isFloodWait(err) then
        local ctx = fiber.self().storage.callback

        if ctx and ctx._floodState and not ctx._floodState.answered then
          answerFlood(ctx, err)
        end
      end

      return res, err
    end
  end

  wrap('editMessageText')
  wrap('editMessageMedia')
end

-- Колбэк, чью кнопку может жать НЕ автор исходного сообщения (PVP-игры: оппонент
-- принимает инвайт). Такая команда помечает себя флагом MULTI_USER, а ownership
-- проверяет внутри хендлера - поэтому общий isSameUser-гейт для неё пропускаем.
local function isMultiUserCallback(ctx)
  local commandName = ctx:getArguments({ count = 1 })[1]
  local command = bot.commands[commandName]

  return command ~= nil and command:hasFlag(command_flags.MULTI_USER)
end

local function dispatch(ctx)
  -- Попытка выолнить команду от лица чата
  --
  if ctx:getSenderChat() then
    ctx:answer('Лее куда жмёшь кнопки от лица чата...')
    return
  end
  --

  local chatType = ctx:getChatType()

  -- В приватном чате безусловно обрабытываем нажатия
  --
  if chatType == chat_type.PRIVATE then
    processCommand(ctx, { antiflood_answer = antiflood_answer })
    return
  end

  -- Иначе проверка, что нажимает тот, на чьё сообщение был ответ.
  -- Multi-user колбэки (игры) пропускаем - они сами проверяют, кто жмёт.
  if not isMultiUserCallback(ctx) and not ctx:isSameUser() then
    ctx:answer('Это не твоя кнопка ващет!!')
    return
  end

  processCommand(ctx, { antiflood_answer = antiflood_answer })
end

local function onCallbackQuery(ctx)
  installFloodGuard()
  instrumentAnswer(ctx)
  fiber.self().storage.callback = ctx

  local ok, err = pcall(dispatch, ctx)

  flushAnswer(ctx)
  fiber.self().storage.callback = nil

  if not ok then
    log.error(err)
  end
end

return onCallbackQuery
