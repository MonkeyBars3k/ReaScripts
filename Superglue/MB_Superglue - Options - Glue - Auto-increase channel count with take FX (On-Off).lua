-- @noindex


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"

local Superglue = require("MB_Superglue-Utils")

Superglue.initOptionToggle("auto_increase_channel_count_with_take_fx")