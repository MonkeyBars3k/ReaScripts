-- @noindex

local Dev = {

  config = {
    test_logging_enabled = true,
    log_function_entry = false,
    log_function_exit = false
  }
}

local _setup = require("modules.setup")



function Dev.updateSelectedItems()
  for i = 0, reaper.CountSelectedMediaItems(0)-1 do
    reaper.UpdateItemInProject(reaper.GetMediaItem(0,i))
  end
end

function _log(...)
  local arg = {...}
  local msg = ""
  for _,v in ipairs(arg) do
    msg = msg..tostring(v)
  end
  msg = msg.."\n"
  reaper.ShowConsoleMsg(msg)
end

function Dev.logV(name, val)
  val = val or ""
  reaper.ShowConsoleMsg(name.." = "..val.."\n")
end


local _log = Dev.log
local _logV = Dev.logV


function Dev.logStr(val)
  reaper.ShowConsoleMsg(tostring(val)..", \n")
end

function Dev.logTable(t, name)
  if name then
    _log("Iterate through table " .. name .. ":")
  end
  for k,v in pairs(t) do
    _logV(k,tostring(v))
  end
end

function Dev.logTableR(t, name, depth)
  depth = depth or 0
  local indentStr = string.rep("  ", depth)

  if name then
    _log(indentStr .. tostring(name) .. " = {")
  end

  if type(t) ~= "table" or next(t) == nil then
    _log(indentStr .. "  " .. (type(t) ~= "table" and tostring(t) or "{}"))
  else
    for k, v in pairs(t) do
      local keyStr = tostring(k)
      if type(v) == "table" then
        if next(v) == nil then
          _log(indentStr .. "  " .. keyStr .. " = {}")
        else
          _log(indentStr .. "  " .. keyStr .. " = {")
          Dev.logTableR(v, nil, depth + 1)
          _log(indentStr .. "  }")
        end
      else
        local valueStr = v == nil and "nil" or tostring(v)
        if valueStr == "" then valueStr = '""' end  -- Handle empty strings
        _log(indentStr .. "  " .. keyStr .. " = " .. valueStr)
      end
    end
  end

  if name then
    _log(indentStr .. "}")
  end
end

function Dev.logTableMediaItems(t, name)
  if name then
    _log("Iterate through table " .. name .. ":")
  end
  for k,v in pairs(t) do
    _logV(k,tostring(reaper.ValidatePtr(v, "MediaItem*")))
  end

end


local DebugType = 0

function Dev.Debug(message, value, spacesToAdd, forceMsgBox)
  local _init = _setup.load("init")
  Dev.updateSelectedItems()
  _init.refreshUI()
    if DebugType < 0 then return end
    local text = ""
    local a = tostring(message)
    local b = tostring(value)
    if message ~= nil then text = a end
    if value ~= nil then
      if value ~= "" then text = text .. " = " .. b
      elseif value == "" then text = text .. b
      end
    end
    local space = ""
    if spacesToAdd ~= nil and spacesToAdd > 0 then
        for _, spacesToAdd do space = space .. "\n" end
    end
    text = space .. text
    if forceMsgBox then reaper.ShowMessageBox(text, "DEBUG", 0) end
    if DebugType == 0 then reaper.ShowConsoleMsg(text .. "\n") return
    elseif DebugType == 1 and not forceMsgBox then reaper.ShowMessageBox(text, "DEBUG", 0) return end
  Dev.updateSelectedItems()
  _init.refreshUI()
end



function Dev.logSuperglueProjectData()
  local master_track, _constant, master_track_chunk

  _constant = _setup.load("constant")
  master_track = reaper.GetMasterTrack(_constant.api.current_project)
  _, master_track_chunk = reaper.GetTrackStateChunk(master_track, "", false)

  _log(master_track_chunk)
end



function Dev.wrapWithLogging(module_table, module_name, config)

  for func_name, func in pairs(module_table) do
    if type(func) == "function" then
      local full_name = module_name .. "." .. func_name
      module_table[func_name] = function(...)
        if config._test_logging_enabled and config._log_function_entry then
          _log(full_name .. " - Entry")
        end

        local result = {func(...)} -- Execute the original function

        if config._test_logging_enabled and config._log_function_exit then
          _log(full_name .. " - Exit")
        end

        return table.unpack(result)
      end
    elseif type(func) == "table" then
      -- Recursively wrap submodules
      Dev.wrapWithLogging(func, module_name .. "." .. func_name, config)
    end
  end
end


return Dev
