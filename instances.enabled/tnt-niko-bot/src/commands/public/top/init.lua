--- Топы: меню выбора (/top) или прямой топ по аргументу (/top донатов).
--
local log = require('log')
local utf8 = require('utf8')
local Command = require('bot.classes.Command')
local render = require('src.commands.public.top.render')

local command = Command:new({
  commands = { '/top', 'топ' },
  flags = { Command.enum.PUBLIC },
})

-- Алиасы аргумента -> which.
local ALIASES = {
  ['донатов']  = 'donat',
  ['донаты']   = 'donat',
  ['донат']    = 'donat',
  ['donat']    = 'donat',
  ['активных'] = 'active',
  ['активные'] = 'active',
  ['актив']    = 'active',
  ['active']   = 'active',
  ['игроков']  = 'players',
  ['игроки']   = 'players',
  ['игрок']    = 'players',
  ['players']  = 'players',
  ['касс']     = 'cashbox',
  ['кассы']    = 'cashbox',
  ['касса']    = 'cashbox',
  ['cashbox']  = 'cashbox',
  ['чатов']    = 'chats',
  ['чаты']     = 'chats',
  ['чат']      = 'chats',
  ['chats']    = 'chats',
  ['браков']   = 'marriages',
  ['браки']    = 'marriages',
  ['брак']     = 'marriages',
  ['marriages'] = 'marriages',
  ['кусак']    = 'kus',
  ['кусаки']   = 'kus',
  ['кусей']    = 'kus',
  ['кусь']     = 'kus',
  ['kus']      = 'kus',
  ['богатых']  = 'rich',
  ['богатые']  = 'rich',
  ['богачей']  = 'rich',
  ['богачи']   = 'rich',
  ['богач']    = 'rich',
  ['деньги']   = 'rich',
  ['rich']     = 'rich',
}

--- Точка входа команды.
-- @tparam table ctx контекст обновления
function command.call(ctx)
  -- Второй токен после команды: "/top донатов" -> "донатов".
  local arg = ctx.message.text:match('^%S+%s+(%S+)')
  local which = arg and ALIASES[utf8.lower(arg)]

  local view, err
  if which then
    view, err = render.top(which, 1, ctx:getChatType(), ctx:getChatId())
  else
    view = render.menu(ctx:getChatType())
  end

  if err then
    log.error(err)
    return
  end

  if not view then
    return
  end

  ctx:replyToMessage({
    text = view.text,
    reply_markup = view.keyboard,
  })
end

return command
