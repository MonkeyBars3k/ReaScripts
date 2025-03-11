--@noindex

-- ==== SUPERGLUE SCRIPTS CODE NOTES ====
-- Superglue uses the great GUI library Reaper Toolkit (rtk). (https://reapertoolkit.dev/).
-- Superglue uses Serpent, a serialization library for LUA, for table-string and string-table conversion. (https://github.com/pkulchenko/serpent).
-- Superglue uses Reaper's Master Track P_EXT to store project-wide script data because its changes are saved in Reaper's undo points, a feature that functions correctly since Reaper v6.43.
-- Script data is also stored in media items' & takes' P_EXT.


local Superglue = {}

local _common, _constant, _dev, _init, _iteminfo, _options


function Superglue.init(type_action)
  Superglue.bootstrap()
  Superglue.loadDependencies()
  Superglue.initDependencies()
  Superglue.routeAction(type_action)
end


function Superglue.loadDependencies()
  _common = require("modules.common")
  _constant = require("modules.constant")
  _dev = require("modules.dev")
  _init = require("modules.init")
  _iteminfo = require("modules.iteminfo")
  _options = require("modules.options")
end


function Superglue.bootstrap()
  local script_dir = Superglue.getScriptPath()

  Superglue.setPackageVals(script_dir)

  return script_dir
end


function Superglue.getScriptPath()
  local _, script_file = reaper.get_action_context()
  local script_dir = Superglue.extractDirectoryPath(script_file)

  return script_dir
end


function Superglue.extractDirectoryPath(filePath)
  local directory = filePath:match("^(.*[/\\])")

  return directory
end


function Superglue.setPackageVals(script_dir)
  local libPath = script_dir .. "lib/?.lua"
  local modulesPath = script_dir .. "modules/?.lua"

  package.path = package.path .. ";" .. libPath  .. ";" .. modulesPath
  package.preload["sg_paths"] = Superglue.returnPaths(script_dir)
end


function Superglue.returnPaths(script_dir)

  return {
    script_dir = script_dir,

    join = function(...)
      local parts = {...}

      return table.concat(parts, "/")
    end
  }
end


function Superglue.initDependencies()
  _options.populateOptionsDefaults()
end


function Superglue.routeAction(type_action)
  local type, action = string.match(type_action, "(%w+)%.(.+)")

  if not type or not action then
    reaper.ShowMessageBox("Invalid action string format. Expected 'type.action'", "Superglue Error", 0)

    return
  end

  if type == "main" then
    Superglue.routeMainAction(action)

  elseif type == "utility" then
    Superglue.routeUtilityAction(action)

  elseif type == "option" then
    Superglue.routeOptionToggle(action)

  else
    reaper.ShowMessageBox("Unknown action type: " .. type, "Superglue Error", 0)
  end
end


function Superglue.routeMainAction(action)
  local selected_item_count = _init.setUpAction(action)

  if not selected_item_count then return end

  if action == "Glue" then
    _init.doGlueAction(selected_item_count, action)

  elseif action == "Edit" or action == "Unglue" then
    _init.doEditOrUnglueAction(selected_item_count, action)

  elseif action == "DePool" then
    _init.doDePoolAction(selected_item_count, action)

  elseif action == "Smart Glue/Edit" or action == "Smart Glue/Unglue" then
    _init.doSmartAction(selected_item_count, action)
  end
end


function Superglue.routeUtilityAction(action)
  _common, _options, _dev, _iteminfo = _setup.load("common, options, dev, iteminfo")

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


function Superglue.routeOptionToggle(option_name)
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
