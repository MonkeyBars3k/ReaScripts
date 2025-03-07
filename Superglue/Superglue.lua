--@noindex


-- ==== SUPERGLUE SCRIPTS ARCHITECTURE NOTES ====
-- Superglue requires Reaper SWS plug-in extension v2.13.1.0+ (https://www.sws-extension.org/download/pre-release) and js_ReaScript_API (https://github.com/ReaTeam/Extensions/raw/master/index.xml) to be installed in Reaper.
-- Superglue uses the great GUI library Reaper Toolkit (rtk). (https://reapertoolkit.dev/).
-- Superglue uses Serpent, a serialization library for LUA, for table-string and string-table conversion. (https://github.com/pkulchenko/serpent).
-- Superglue uses Reaper's Master Track P_EXT to store project-wide script data because its changes are saved in Reaper's undo points, a feature that functions correctly since Reaper v6.43.
-- Script data is also stored in media items' & takes' P_EXT.


local script_path = string.match(({ reaper.get_action_context() })[2], "(.-)([^\\/]-%.?([^%.\\/]*))$")
package.path = package.path .. ";" .. script_path .. "?.lua"
package.path = package.path .. ";" .. script_path .. "lib/?.lua"
package.path = package.path .. ";" .. script_path .. "modules/?.lua"

local rtk = require("lib.rtk")
local serpent = require("lib.serpent")


local module_names = {"constant", "state", "util", "common", "data", "options", "init", "dev", "glue", "edit", "unglue", "depool", "lanes", "single", "multi", "iteminfo", "vi"}
local modules = {}

for _, name in ipairs(module_names) do
  modules[name] = require("modules." .. name)
end

local constant, state, util, common, data, options, init, dev, glue, edit, unglue, depool, lanes, single, multi, iteminfo, vi = table.unpack(modules, 1, #module_names)


dev.wrapFunctionsInTestLogs = (function()

  if not dev.config.test_logging_enabled then return end

  for _, name in ipairs(module_names) do
    modules[name] = dev.wrapWithLogging(modules[name], name)
  end
end)()



local Superglue = {}


function Superglue.initMainAction(action)
  local selected_item_count = init.setUpAction(action)

  if not selected_item_count then return end

  if action == "Glue" then
    init.doGlueAction(selected_item_count, action)

  elseif action == "Edit" or action == "Unglue" then
    init.doEditOrUnglueAction(selected_item_count, action)

  elseif action == "DePool" then
    init.doDePoolAction(selected_item_count, action)

  elseif action == "Smart Glue/Edit" or action == "Smart Glue/Unglue" then
    init.doSmartAction(selected_item_count, action)
  end
end


function Superglue.initUtilityAction(action)

  if action == "Open Superglue Options Window" then
    options.openOptionsWindow()

  elseif action == "Open Superglue Item Info Window" then
    iteminfo.openItemInfoWindow()

  elseif action == "Set All Superitems Color" then
    common.setAllSuperitemsColor(action)

  elseif action == "Log Superglue Project Data" then
    Superglue.logSuperglueProjectData()
  end
end


function Superglue.initOptionToggle(option_name)
  local active_option, current_val, new_val

  active_option = options.getActiveOption(option_name)

  if not active_option then return end

  current_val = reaper.GetExtState(constant.data.key.options.global_section, active_option.ext_state_key)

  if current_val == "false" then
    new_val = "true"

  elseif current_val == "true" then
    new_val = "false"

  elseif current_val == "always" then
    new_val = "ask"

  elseif current_val == "ask" then
    new_val = "no"

  elseif current_val == "no" then
    new_val = "always"
  end

  options.updateOptionValue(active_option, new_val)
end


function Superglue.logSuperglueProjectData()
  local master_track, retval, master_track_chunk

  master_track = reaper.GetMasterTrack(constant.api.current_project)
  retval, master_track_chunk = reaper.GetTrackStateChunk(master_track, "", false)

  dev.log(master_track_chunk)
end


return Superglue
