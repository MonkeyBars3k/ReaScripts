-- @description MB Glue (Reversible): Create container item from selected items, ignoring time selection
-- @author MonkeyBars
-- @version 1.30
-- @changelog Rename all scripts to MB_xxx for clarity (https://github.com/MonkeyBars3k/ReaScripts/issues/60)
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Glue-Reversible Utils")

initGlueReversible(false)
