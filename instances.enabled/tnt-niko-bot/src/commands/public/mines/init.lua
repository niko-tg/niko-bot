--- Мини-игра «Мины» (PVE): ставка -> меню риска -> доска с забором.
--
local log = require('log')
local hdec = require('bot.libs.hdec')
local config = require('conf.config')
local Command = require('bot.classes.Command')
local decodeMoneyString = require('src.utils.decodeMoneyString')
local mineSessionsService = require('src.services.mine_sessions')
local render = require('src.commands.public.mines.render')

local command = Command:new {
  commands = { '/mines', 'мины' },
  flags = { Command.enum.PUBLIC },
}

local USAGE = ([[
💣 <b>Мины</b>
${sep}
Открывай клетки и копи множитель, но не попади на мину!
Забрать выигрыш можно в любой момент.

Напиши: <code>мины 1000</code>
Минимальная ставка: <b>${min_bid}</b>р
]]):f({
  min_bid = config.mines.min_bid,
  sep = hdec.sep,
})

function command.call(ctx)
  local user = command.user

  -- Уже есть активная партия? Открываем её заново новым сообщением, а не
  -- отказом - старую доску могли удалить, и партия становилась недоступна.
  local existing = mineSessionsService.getByUser(user.id)
  if existing then
    local remaining = config.mines.ttl - (os.time() - existing.created.timestamp)
    local view = render.board(existing, remaining)

    local sent = ctx:replyToMessage({
      text = view.text,
      reply_markup = view.keyboard,
    })

    -- Привязываем партию к новой доске: на ней работают кнопки, её же гасит
    -- TTL-джоб. Старый message_id мог указывать на удалённое сообщение.
    if sent then
      existing.message_id = sent.message_id
      existing.chat_id = ctx:getChatId()

      local _, saveErr = mineSessionsService.save(existing)
      if saveErr then
        log.error(saveErr)
      end
    end

    return
  end

  local arg = ctx.message.text:match('^%S+%s+(%S+)')
  local bid = arg and decodeMoneyString(arg)

  if not bid then
    ctx:replyToMessage(USAGE)
    return
  end

  if bid < config.mines.min_bid then
    ctx:replyToMessage(('💸 Минимальная ставка: <b>${min_bid}</b>р'):f({
      min_bid = config.mines.min_bid
    }))

    return
  end

  if user.balance < bid then
    ctx:replyToMessage('💸 У тебя недостаточно средств')
    return
  end

  local view = render.riskMenu(bid)

  ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })
end

return command
