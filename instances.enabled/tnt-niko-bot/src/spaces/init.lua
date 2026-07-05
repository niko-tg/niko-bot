--- Инициализация спейсов хранилища
--

local users = require('src.spaces.users')
local chats = require('src.spaces.chats')
local user_in_chat = require('src.spaces.user_in_chat')
local hello_message = require('src.spaces.hello_message')
local vip_users = require('src.spaces.vip_users')
local transactions = require('src.spaces.transactions')
local gaming_sessions = require('src.spaces.gaming_sessions')
local user_game_stats = require('src.spaces.user_game_stats')
local mine_sessions = require('src.spaces.mine_sessions')
local bot_stats_daily = require('src.spaces.bot_stats_daily')
local user_inventory = require('src.spaces.user_inventory')
local user_activity = require('src.spaces.user_activity')
local likes = require('src.spaces.likes')
local friends = require('src.spaces.friends')
local marriages = require('src.spaces.marriages')
local pets = require('src.spaces.pets')
local pet_supplies = require('src.spaces.pet_supplies')
local user_farm = require('src.spaces.user_farm')

return {
  users = users,
  chats = chats,
  user_in_chat = user_in_chat,
  hello_message = hello_message,
  vip_users = vip_users,
  transactions = transactions,
  gaming_sessions = gaming_sessions,
  user_game_stats = user_game_stats,
  mine_sessions = mine_sessions,
  bot_stats_daily = bot_stats_daily,
  user_inventory = user_inventory,
  user_activity = user_activity,
  likes = likes,
  friends = friends,
  marriages = marriages,
  pets = pets,
  pet_supplies = pet_supplies,
  user_farm = user_farm,
}
