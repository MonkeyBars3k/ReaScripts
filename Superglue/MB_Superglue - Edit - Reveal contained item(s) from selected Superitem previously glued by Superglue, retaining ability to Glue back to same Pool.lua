-- @noindex


local _, script_file = reaper.get_action_context()
local script_dir = script_file:match("^(.*[/\\])")

package.path = package.path .. ";" .. script_dir .. "?.lua"

require("Superglue").init("main.Edit")
