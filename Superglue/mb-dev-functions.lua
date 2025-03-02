-- @noindex

local _module_dev = {}


function _module_dev.updateSelectedItems()
  local i
  for i = 0, reaper.CountSelectedMediaItems(0)-1 do
    reaper.UpdateItemInProject(reaper.GetMediaItem(0,i))
  end
end

function _module_dev.log(...)
  local arg = {...}
  local msg = ""
  for i,v in ipairs(arg) do
    msg = msg..tostring(v)
  end
  msg = msg.."\n"
  reaper.ShowConsoleMsg(msg)
end

function _module_dev.logV(name, val)
  val = val or ""
  reaper.ShowConsoleMsg(name.." = "..val.."\n")
end


local log = _module_dev.log
local logV = _module_dev.logV


function _module_dev.logStr(val)
  reaper.ShowConsoleMsg(tostring(val)..", \n")
end

function _module_dev.logTable(t, name)
  local k,v
  if name then
    log("Iterate through table " .. name .. ":")
  end
  for k,v in pairs(t) do
    logV(k,tostring(v))
  end
end

function _module_dev.logTableR(t, name, depth)
  depth = depth or 0
  local indentStr = string.rep("  ", depth)
  
  if name then
    log(indentStr .. tostring(name) .. " = {")
  end
  
  if type(t) ~= "table" or next(t) == nil then
    log(indentStr .. "  " .. (type(t) ~= "table" and tostring(t) or "{}"))
  else
    for k, v in pairs(t) do
      local keyStr = tostring(k)
      if type(v) == "table" then
        if next(v) == nil then
          log(indentStr .. "  " .. keyStr .. " = {}")
        else
          log(indentStr .. "  " .. keyStr .. " = {")
          logTableR(v, nil, depth + 1)
          log(indentstr .. "  }")
        end
      else
        local valueStr = v == nil and "nil" or tostring(v)
        if valueStr == "" then valueStr = '""' end  -- Handle empty strings
        log(indentStr .. "  " .. keyStr .. " = " .. valueStr)
      end
    end
  end
  
  if name then
    log(indentStr .. "}")
  end
end

function _module_dev.logTableMediaItems(t, name)
  local k,v
  if name then
    log("Iterate through table " .. name .. ":")
  end
  for k,v in pairs(t) do
    logV(k,tostring(reaper.ValidatePtr(v, "MediaItem*")))
  end

end


local DebugType = 0

function _module_dev.Debug(message, value, spacesToAdd, forceMsgBox)
  updateSelectedItems()
  refreshUI()
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
        for i=1, spacesToAdd do space = space .. "\n" end      
    end
    text = space .. text
    if forceMsgBox then reaper.ShowMessageBox(text, "DEBUG", 0) end
    if DebugType == 0 then reaper.ShowConsoleMsg(text .. "\n") return 
    elseif DebugType == 1 and not forceMsgBox then reaper.ShowMessageBox(text, "DEBUG", 0) return end
  updateSelectedItems()
  refreshUI()
end



function _module_dev.wrapWithLogging(module_table, module_name, config)
  for func_name, func in pairs(module_table) do
    if type(func) == "function" then
      local full_name = module_name .. "." .. func_name
      module_table[func_name] = function(...)
        if config._test_logging_enabled and config._log_function_entry then
          _module_dev.log(full_name .. " - Entry")
        end

        local result = {func(...)} -- Execute the original function

        if config._test_logging_enabled and config._log_function_exit then
          _module_dev.log(full_name .. " - Exit")
        end

        return table.unpack(result)
      end
    elseif type(func) == "table" then
      -- Recursively wrap submodules
      _module_dev.wrapWithLogging(func, module_name .. "." .. func_name, config)
    end
  end
end



return _module_dev