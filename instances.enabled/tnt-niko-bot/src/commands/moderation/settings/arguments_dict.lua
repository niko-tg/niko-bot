-- Значения аргументов
--
local arguments_dict = {
  page = {
    main = 'main',
    settings = 'settings',
    vip_settings = 'vip_settings',
    hello_message = 'hello_message',
  },
  action = {
    show = 'show',
    edit = 'edit',
  },
  param = {
    has_enable_antiflood            = 'hea',
    has_enable_moderation_commands  = 'hemc',
    has_enable_hello_message        = 'hehm',
    -- VIP
    has_delete_links                = 'hdl',
    has_delete_forward_message      = 'hdfm',
    has_ban_sender_chat             = 'hbsc',
  },
}

return arguments_dict
