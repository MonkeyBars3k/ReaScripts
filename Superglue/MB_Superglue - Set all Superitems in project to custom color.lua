-- @descriptionMB_Superglue - Set all Superitems in project to custom color
-- @author MonkeyBars
-- @version 1.763
-- @changelog Change script + function name
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

setAllSuperitemsColor()