-- @description MB Unglue (Reversible): Reveal constituent items of previously Glue (Reversible) container item, retaining group
-- @author MonkeyBars
-- @version 1.30
-- @changelog Change nomenclature from Unglue to Edit (https://github.com/MonkeyBars3k/ReaScripts/issues/64)
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Glue-Reversible Utils")

initEditGlueReversible()