-- @noindex


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"

local Superglue = require("MB_Superglue-Utils")

Superglue.initOptionToggle("loop_source_sets_sizing_region_bounds_on_reglue")