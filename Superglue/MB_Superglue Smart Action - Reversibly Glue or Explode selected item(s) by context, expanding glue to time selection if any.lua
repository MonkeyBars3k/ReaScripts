-- @description MB_Superglue Smart Action - Reversibly Glue or Explode selected item(s) by context, expanding glue to time selection if any
-- @author MonkeyBars
-- @version 1.53
-- @changelog Initial upload
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

initSmartAction("Explode", true)