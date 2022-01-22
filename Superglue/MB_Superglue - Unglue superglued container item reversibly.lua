-- @description MB_Superglue - Unglue superglued container item
-- @author MonkeyBars
-- @version 1.70
-- @changelog Refresh ReaPack
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

initUnglueExplode("Unglue")