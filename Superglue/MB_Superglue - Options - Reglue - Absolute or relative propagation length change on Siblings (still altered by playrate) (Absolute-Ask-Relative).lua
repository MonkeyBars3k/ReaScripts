-- @noindex


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"

local Superglue = require("MB_Superglue-Utils")

require("Superglue").init("option."length_propagation_type_default")
