-- @noindex


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"

local Superglue = require("MB_Superglue-Utils")

require("Superglue").init("option."auto_increase_channel_count_with_take_fx")
