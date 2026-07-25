--- Callback капчи: новый участник доказывает, что он не бот.
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
  arguments_schema = { 'user_id' },
})

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  local arguments = command.arguments
  local targetId = tonumber(arguments.user_id)
  local presser = command.user
  local chatId = ctx:getChatId()

  -- Кнопка адресована конкретному юзеру
  if not targetId or presser.id ~= targetId then
    ctx:answer({ text = '🤖 Эта кнопка не для вас', show_alert = true })
    return
  end

  -- Атомарно забираем сессию ДО unrestrict: job таймаута не должен
  -- кикнуть юзера, который успел нажать кнопку, а повторное нажатие
  -- (двойной клик) не должно обработаться дважды.
  local session, takeErr = captchaService.take(chatId, targetId)

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
    user_id = targetId,
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

return command
