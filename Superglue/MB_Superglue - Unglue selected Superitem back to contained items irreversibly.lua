-- @description MB_Superglue - Unglue selected Superitem back to contained items irreversibly
-- @author MonkeyBars
-- @version 1.758
-- @changelog Change nomenclature
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

initEditUnglue("Unglue")