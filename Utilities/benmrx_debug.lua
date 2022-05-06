-- @noindex

-- https://forum.cockos.com/showthread.php?t=254149
--
--
-- If 'DebugType == 0' then messages will be sent to the console.
-- If 'DebugType == 1' then messages will be sent to a message box.
-- If 'DebugType < 0' then messages won't be sent anywhere.
-- =================================================================
--
-- local DebugType = 0 -- All messages sent to the console (change to 1 to send all messages to message boxes).

-- Debug("This is a message")

-- local value = 1
-- Debug("This is a message with a value", value)

-- Debug("This is a message with a value and space", value, 1)

-- Debug("This forces a messagebox", value, 0, true)

-- function DoStuff()
--      Debug("Enter", "DoStuff")

--      Do some stuff
--      Do more stuff
--      Do even more stuff

--      Debug("Exit", "DoStuff")
-- end


local DebugType = 0

function Debug(message, value, spacesToAdd, forceMsgBox)

    if DebugType < 0 then return end

    local text = ""

    local a = tostring(message)
    local b = tostring(value)
    
    if message ~= nil then text = a end
    if value ~= nil then text = text .. "\n" .. b end
    
    local space = ""
    
    if spacesToAdd ~= nil and spacesToAdd > 0 then 
    
        for i=1, spacesToAdd do space = space .. "\n" end
        
    end
    
    text = space .. text
    
    if forceMsgBox then reaper.ShowMessageBox(text, "DEBUG", 0) end
    
    if DebugType == 0 then reaper.ShowConsoleMsg(text .. "\n") return 
    elseif DebugType == 1 and not forceMsgBox then reaper.ShowMessageBox(text, "DEBUG", 0) return end

end