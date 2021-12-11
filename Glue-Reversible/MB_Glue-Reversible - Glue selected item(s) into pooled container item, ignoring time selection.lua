-- @description MB_Glue-Reversible - Glue selected item(s) into pooled container item, ignoring time selection
-- @author MonkeyBars
-- @version 1.33
-- @changelog metadata update
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Glue-Reversible Utils")

initGlue(false)