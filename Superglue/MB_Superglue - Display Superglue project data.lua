-- @description MB_Superglue - Display Superglue project data
-- @author MonkeyBars
-- @version 1.789
-- @changelog Initial upload
-- @provides [nomain] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

-- This is a utility script for dev that just dumps the master track chunk

viewSuperglueProjectData()