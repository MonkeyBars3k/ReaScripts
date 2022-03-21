-- @description MB_Superglue - Option - Reglue - Looped source of Superitem determines Sizing Region bounds
-- @author MonkeyBars
-- @version 1.820
-- @changelog Inital upload
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

toggleOption("loop_source_sets_sizing_region_bounds_on_reglue")