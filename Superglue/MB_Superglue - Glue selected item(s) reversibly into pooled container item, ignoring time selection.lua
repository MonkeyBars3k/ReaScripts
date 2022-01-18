-- @description MB_Superglue - Reversibly Glue selected item(s) into pooled container item, ignoring time selection
-- @author MonkeyBars
-- @version 1.54
-- @changelog Change script name
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

initSuperglue(false)