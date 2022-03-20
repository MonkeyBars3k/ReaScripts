-- @description MB_Superglue - Display Superglue project data
-- @author MonkeyBars
-- @version 1.815
-- @changelog Change script name
-- @provides [nomain] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")


logSuperglueProjectData()