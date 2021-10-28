-- @description MB Toggle Glue/Unglue (Reversible); expand glue to time selection if any
-- @author MonkeyBars
-- @version 1.30
-- @changelog Refactor doUnglue() new name initUnglueReversible() (https://github.com/MonkeyBars3k/ReaScripts/issues/49)
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB Glue (Reversible) Utils")

initSmartGlueUnglueReversible(true)