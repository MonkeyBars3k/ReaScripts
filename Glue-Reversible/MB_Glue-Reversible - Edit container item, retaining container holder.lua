-- @description MB_Glue-Reversible - Edit container item, retaining container holder
-- @author MonkeyBars
-- @version 1.34
-- @changelog version fix
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Glue-Reversible Utils")

initEditGluedContainer()
