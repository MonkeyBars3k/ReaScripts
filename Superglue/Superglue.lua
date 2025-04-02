--@noindex

-- ==== SUPERGLUE SCRIPTS CODE NOTES ====
-- Superglue uses the great GUI library Reaper Toolkit (rtk). (https://reapertoolkit.dev/).
-- Superglue uses Serpent, a serialization library for LUA, for table-string and string-table conversion. (https://github.com/pkulchenko/serpent).
-- Superglue uses Reaper's Master Track P_EXT to store project-wide script data because its changes are saved in Reaper's undo points, a feature that functions correctly since Reaper v6.43.
-- Script data is also stored in media items' & takes' P_EXT.


local Superglue = {}


local loadDependencies, bootstrap, getScriptPath, setPackageVals, returnPaths, initDependencies, routeAction, routeMainAction, routeUtilityAction, routeOptionToggle

local _common, _constant, _dev, _init, _iteminfo, _options



function Superglue.init(type_action)
  bootstrap()
  loadDependencies()
  initDependencies()
  routeAction(type_action)
end


loadDependencies = function()
  _common = require("modules.common")
  _constant = require("modules.constant")
  _dev = require("modules.dev")
  _init = require("modules.init")
  _iteminfo = require("modules.iteminfo")
  _options = require("modules.options")
end


bootstrap = function()
  local script_dir = getScriptPath()

  setPackageVals(script_dir)

  return script_dir
end


getScriptPath = function()
  local _, script_file = reaper.get_action_context()
  local script_dir = extractDirectoryPath(script_file)

  return script_dir
end


extractDirectoryPath = function(filePath)
  local directory = filePath:match("^(.*[/\\])")

  return directory
end


setPackageVals = function(script_dir)
  local libPath = script_dir .. "lib/?.lua"
  local modulesPath = script_dir .. "modules/?.lua"

  package.path = package.path .. ";" .. libPath  .. ";" .. modulesPath
  package.preload["sg_paths"] = returnPaths(script_dir)
end


returnPaths = function(script_dir)

  return {
    script_dir = script_dir,

    join = function(...)
      local parts = {...}

      return table.concat(parts, "/")
    end
  }
end


initDependencies = function()
  _options.populateOptionsDefaults()
end


routeAction = function(type_action)
  local type, action = string.match(type_action, "(%w+)%.(.+)")

  if not type or not action then
    reaper.ShowMessageBox("Invalid action string format. Expected 'type.action'", "Superglue Error", 0)

    return
  end

  if type == "main" then
    routeMainAction(action)

  elseif type == "utility" then
    routeUtilityAction(action)

  elseif type == "option" then
    routeOptionToggle(action)

  else
    reaper.ShowMessageBox("Unknown action type: " .. type, "Superglue Error", 0)
  end
end


routeMainAction = function(action)
  local selected_item_count = _init.setUpAction(action)

  if not selected_item_count then return end

  if action == "Glue" then
    _init.doGlueAction(selected_item_count, action)

  elseif action == "Edit" or action == "Unglue" then
    _init.doEditOrUnglueAction(selected_item_count, action)

  elseif string.find(action, "DePool") then
    _init.doDePoolAction(selected_item_count, action)

  elseif action == "Smart Glue/Edit" or action == "Smart Glue/Unglue" then
    _init.doSmartAction(selected_item_count, action)
  end
end


routeUtilityAction = function(action)

  if action == "Open Superglue Options Window" then
    _options.openOptionsWindow()

  elseif action == "Open Superglue Item Info Window" then
    _iteminfo.openItemInfoWindow()

  elseif action == "Set All Superitems Color" then
    _common.setAllSuperitemsColor(action)

  elseif action == "Log Superglue Project Data" then
    _dev.logSuperglueProjectData()
  end
end


routeOptionToggle = function(option_name)
  _options = _setup.load("options")

  local active_option, current_val, new_val

  active_option = _options.getActiveOption(option_name)

  if not active_option then return end

  current_val = reaper.GetExtState(_constant.data.key.options.global_section, active_option.ext_state_key)

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

  _options.updateOptionValue(active_option, new_val)
end


return Superglue
