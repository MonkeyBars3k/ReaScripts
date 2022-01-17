-- @description MB_Superglue - Explode superglued items back to original state irreversibly
-- @author MonkeyBars
-- @version 1.53
-- @changelog initial upload
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

initUnglueExplode("Explode")