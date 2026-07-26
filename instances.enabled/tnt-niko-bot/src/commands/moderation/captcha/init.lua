--- Callback капчи: новый участник доказывает, что он не бот.
--
-- Сообщение капчи - картинка с символами и клавиатура: юзер нажимает
-- символы с картинки по порядку. Ошибка - минус попытка и новая картинка,
-- попытки кончились - кик. Кнопка обновления даёт новую картинку бесплатно.
--
-- Нажать может только сам проверяемый: чужие нажатия - alert.
-- При успехе: снимаем рестрикт, удаляем сообщение капчи и, если в чате
-- включено приветствие, шлём его (при активной капче приветствие
-- откладывается до прохождения - см. on_new_member).
--
local log = require('log')
local bot = require('bot')
local Command = require('bot.classes.Command')
local captchaService = require('src.services.captcha_sessions')
local sendHelloMessage = require('src.utils.sendHelloMessage')
local missingRightsWarner = require('src.utils.missingRightsWarner')
local flow = require(bot.subdir(0, ...)..'.flow')

-- MULTI_USER: сообщение капчи отправлено ботом (не reply на сообщение
-- нажимающего), дефолтный isSameUser-гейт в onCallbackQuery его срежет.
-- Ownership проверяем сами: кнопка сработает только для проверяемого юзера.
local command = Command:new({
  commands = { 'cb_captcha' },
  flags = { Command.enum.CALLBACK, Command.enum.MULTI_USER },
  arguments_schema = { 'user_id', 'symbol' },
})

--- Успешное прохождение: атомарно забрать сессию, снять рестрикт,
-- убрать сообщение и отправить отложенное приветствие.
-- @tparam table ctx контекст обновления
-- @tparam number chatId id чата
-- @tparam table presser прошедший проверку юзер
local function pass(ctx, chatId, presser)
  -- Атомарно забираем сессию ДО unrestrict: job таймаута не должен
  -- кикнуть юзера, который успел пройти, а повторное нажатие
  -- (двойной клик) не должно обработаться дважды.
  local session, takeErr = captchaService.take(chatId, presser.id)

  if takeErr then
    log.error(takeErr)
    ctx:answer({ text = '⚠️ Ошибка, попробуйте ещё раз', show_alert = true })
    return
  end

  -- Сессии нет: капча уже пройдена либо протухла (job вот-вот кикнет)
  if not session then
    ctx:answer()
    return
  end

  local _, restrictErr = bot:restrictChatMember({
    chat_id = chatId,
    user_id = presser.id,
    permissions = flow.FULL_PERMS,
  })

  if restrictErr then
    log.verbose(restrictErr)
    missingRightsWarner.handleApiError(restrictErr, chatId)
  end

  ctx:answer('✅ Добро пожаловать!')

  flow.deleteCaptchaMessage(chatId, session.message_id)

  -- Отложенное приветствие: флаг greet выставлен при старте капчи,
  -- только если юзер реально новый и приветствие в чате включено
  if session.greet then
    sendHelloMessage(ctx:getChat(), presser)
  end
end

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local arguments = command.arguments
  local targetId = tonumber(arguments.user_id)
  local symbol = arguments.symbol
  local presser = command.user
  local chatId = ctx:getChatId()

  -- Кнопка адресована конкретному юзеру
  if not targetId or presser.id ~= targetId then
    ctx:answer({ text = '🤖 Эта кнопка не для вас', show_alert = true })
    return
  end

  local session, readErr = captchaService.read(chatId, targetId)

  if readErr then
    log.error(readErr)
    ctx:answer({ text = '⚠️ Ошибка, попробуйте ещё раз', show_alert = true })
    return
  end

  -- Сессии нет: капча уже пройдена либо протухла (job вот-вот кикнет)
  if not session then
    ctx:answer()
    return
  end

  -- Сессия старого формата (кнопка "Я не бот") - пройдено одним нажатием
  if session.answer == '' then
    pass(ctx, chatId, presser)
    return
  end

  -- Новая картинка по запросу: попытку не тратит, прогресс сбрасывается
  if symbol == flow.REFRESH then
    if flow.retry(chatId, presser, session, session.attempts) then
      ctx:answer('🔄 Новая картинка')
    else
      ctx:answer()
    end
    return
  end

  local expected = session.answer:sub(session.progress + 1, session.progress + 1)

  -- Верный символ: последний - пройдено, иначе двигаем прогресс
  if symbol == expected then
    if session.progress + 1 >= #session.answer then
      pass(ctx, chatId, presser)
      return
    end

    local updated, updateErr = captchaService.update(chatId, targetId, {
      progress = session.progress + 1,
    })

    if updateErr then
      log.error(updateErr)
    end

    if updated then
      ctx:answer(('✅ %d/%d'):format(updated.progress, #session.answer))
    else
      ctx:answer()
    end
    return
  end

  -- Ошибка: минус попытка; кончились - кик, иначе новая картинка
  local attemptsLeft = session.attempts - 1

  if attemptsLeft <= 0 then
    local taken, takeErr = captchaService.take(chatId, targetId)

    if takeErr then
      log.error(takeErr)
    end

    if taken then
      ctx:answer({ text = '❌ Попытки закончились', show_alert = true })
      flow.punish(taken)
    else
      ctx:answer()
    end
    return
  end

  flow.retry(chatId, presser, session, attemptsLeft)
  ctx:answer({
    text = ('❌ Неверно. Осталось попыток: %d'):format(attemptsLeft),
    show_alert = true,
  })
end

return command
