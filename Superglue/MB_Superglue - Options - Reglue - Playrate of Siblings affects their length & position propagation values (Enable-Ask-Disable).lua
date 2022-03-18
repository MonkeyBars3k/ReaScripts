-- @description MB_Superglue - Cycle option, Take playrate affects Superitem sibling propagation
-- @author MonkeyBars
-- @version 1.776
-- @changelog Initial upload
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

toggleOption("playrate_affects_propagation_by_default")