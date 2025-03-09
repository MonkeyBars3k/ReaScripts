-- @noindex


local _, script_file = reaper.get_action_context()
local script_dir = reaper.JS_ReaScript_GetPathToFolder(script_file)

package.path = package.path .. ";" .. script_dir .. "/?.lua"

require("Superglue").init("main.Edit")
