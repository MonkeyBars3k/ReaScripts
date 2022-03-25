-- @noindex

function updateSelectedItems()
  local i
  for i = 0, reaper.CountSelectedMediaItems(0)-1 do
    reaper.UpdateItemInProject(reaper.GetMediaItem(0,i))
  end
end

function log(...)
  local arg = {...}
  local msg = "", i, v
  for i,v in ipairs(arg) do
    msg = msg..v..", "
  end
  msg = msg.."\n"
  reaper.ShowConsoleMsg(msg)
end

function logV(name, val)
  val = val or ""
  reaper.ShowConsoleMsg(name.." = "..val.."\n")
end

function logStr(val)
  reaper.ShowConsoleMsg(tostring(val)..", \n")
end

function logTable(t, name)
  local k,v
  if name then
    log("Iterate through table " .. name .. ":")
  end
  for k,v in pairs(t) do
    logV(k,tostring(v))
  end
end

function logTableMediaItems(t, name)
  local k,v
  if name then
    log("Iterate through table " .. name .. ":")
  end
  for k,v in pairs(t) do
    logV(k,tostring(reaper.ValidatePtr(v, "MediaItem*")))
  end

end


local DebugType = 0

function Debug(message, value, spacesToAdd, forceMsgBox)
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