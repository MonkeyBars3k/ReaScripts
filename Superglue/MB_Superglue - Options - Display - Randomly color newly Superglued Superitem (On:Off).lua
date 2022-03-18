-- @description MB_Superglue - Set new Superitem glue to random color
-- @author MonkeyBars
-- @version 1.776
-- @changelog Initial upload
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

toggleOption("new_superglue_random_color")