-- @description MB Toggle Glue/Unglue (Reversible), ignoring time selection
-- @author MonkeyBars
-- @version 1.30
-- @changelog Rename "Toggle Glug/Unglue" scripts to "Smart Glue-Unglue" (https://github.com/MonkeyBars3k/ReaScripts/issues/59)
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Glue-Reversible Utils")

initSmartAction(false)