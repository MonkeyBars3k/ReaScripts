-- @description MB_Superglue - Time selection determines Superitem edges
-- @author MonkeyBars
-- @version 1.787
-- @changelog Name change for functionality change
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

toggleOption("time_selection_sets_superitem_edges")