-- @description MB Toggle Glue/Unglue (Reversible)
-- @author MonkeyBars
-- @version 1.0
-- @changelog initial commit
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB Glue (Reversible) Utils")

initToggleGlueUnglueReversible(true)