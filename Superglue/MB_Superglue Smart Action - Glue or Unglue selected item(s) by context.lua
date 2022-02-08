-- @description MB_Superglue Smart Action - Glue or Unglue selected item(s) by context
-- @author MonkeyBars
-- @version 1.758
-- @changelog Change nomenclature
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

initSmartAction("Unglue", false)