-- @description MB_Superglue - Glue selected item(s) reversibly into pooled container item, expanding to time selection if any
-- @author MonkeyBars
-- @version 1.55
-- @changelog Change script name
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

initSuperglue(true)
