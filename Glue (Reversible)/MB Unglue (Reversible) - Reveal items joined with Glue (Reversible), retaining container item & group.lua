-- @description MB Unglue (Reversible): Reveal constituent items of previously Glue (Reversible) container item, retaining group
-- @author MonkeyBars
-- @version 1.27
-- @changelog Move main function to Utils as part of Add "Toggle Glue/Unglue (Reversible)" scripts (https://github.com/MonkeyBars3k/ReaScripts/issues/9)
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB Glue (Reversible) Utils")

unglueReversible()