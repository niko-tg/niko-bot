--- UnixTime в число дней
--
local function timeToDays(time)
  return math.floor((os.time() - time) / 86400)
end

return timeToDays
