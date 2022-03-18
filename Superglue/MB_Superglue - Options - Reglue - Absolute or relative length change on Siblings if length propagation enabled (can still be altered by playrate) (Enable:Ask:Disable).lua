-- @description MB_Superglue - Options - Reglue - Absolute or relative length change on Siblings if length propagation enabled (can still be altered by playrate) (Enable/Ask/Disable)
-- @author MonkeyBars
-- @version 1.810
-- @changelog Initial upload
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

toggleOption("length_propagation_type_default")