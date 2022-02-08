-- @description MB_Superglue - Toggle option, item background images
-- @author MonkeyBars
-- @version 1.758
-- @changelog Inital upload
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

toggleOption("depool_all_siblings_on_reglue")