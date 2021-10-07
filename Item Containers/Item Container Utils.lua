-- @description Tools for Item Container functionality – adapted from matthewjumpsoffbuildings's Glue Groups scripts
-- @author MonkeyBars
-- @version 1.03
-- @noindex
-- @provides [nomain] Item Container Utils.lua
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about 
-- # Item Containers
-- 
-- matthewjumpsoffbuildings created the "Glue Groups" actions to create a sort of item container that is a basically a combination of item gluing and grouping. 
-- 
-- MonkeyBars continues the effort under a more generic, clear name: **Item Containers**.
-- 
-- - Currently item containers only work on a **single track**.
-- - Future improvements include:
--      - Adding **explode** action to completely remove item container

function deselect()
  local num = reaper.CountSelectedMediaItems(0)
  
  if not num or num < 1 then return end
  
  local i = 0
  while i < num do
    reaper.SetMediaItemSelected( reaper.GetSelectedMediaItem(0, 0), false)
    i = i + 1
  end

  num = reaper.CountSelectedMediaItems(0)

end

function reselect( items )
  local i, item
  for i,item in pairs(items) do
    reaper.SetMediaItemSelected(item, true)
  end
end

function duplicateItem( item, selected)
  local track = reaper.GetMediaItemTrack(item)
  local state = getSetObjectState(item)
  local duplicate = reaper.AddMediaItemToTrack(track)
  getSetObjectState(duplicate, state)
  if selected then reaper.SetMediaItemSelected(duplicate, true) end
  return duplicate
end

function getSetObjectState(obj, state, minimal)

  minimal = minimal or false

  local fastStr = reaper.SNM_CreateFastString(state)
  
  local set = false
  if state and string.len(state) > 0 then set = true end
  
  reaper.SNM_GetSetObjectState(obj, fastStr, set, minimal)

  local state = reaper.SNM_GetFastString(fastStr)
  reaper.SNM_DeleteFastString(fastStr)
  
  return state

end

function getSetItemName(item, name, add_or_remove)

  if reaper.GetMediaItemNumTakes(item) < 1 then return end

  local take = reaper.GetActiveTake(item)

  if take then
    local current_name = reaper.GetTakeName(take)

    if name then
      if add_or_remove == 1 then
        name = current_name.." "..name
      elseif add_or_remove == -1 then
        name = string.gsub(current_name, name, "")
      end

      reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true)

      return name, take
    else
      return current_name, take
    end
  end
end

function getItemWavSrc(item, take)
  take = take or reaper.GetActiveTake(item)
  local source = reaper.GetMediaItemTake_Source(take)
  local filename = reaper.GetMediaSourceFileName(source, '')
  if string.len(filename) > 0 then return filename end
end

function setToAudioTake(item)
  
  local num_takes = reaper.GetMediaItemNumTakes(item)
  if num_takes > 0 then
    
    local active_take = reaper.GetActiveTake(item)
    if active_take then

      if reaper.TakeIsMIDI(active_take) then

        -- store ref to the original active take for unglueing
        local active_take_number = reaper.GetMediaItemTakeInfo_Value(active_take, "IP_TAKENUMBER")
        -- convert the active MIDI item to an audio take
        reaper.SetMediaItemSelected(item, 1)
        reaper.Main_OnCommand(40209, 0)

        reaper.SetActiveTake(reaper.GetTake(item, num_takes))
        active_take = reaper.GetActiveTake(item)
        
        local take_name = "item_container_render:"..math.floor(active_take_number)

        reaper.GetSetMediaItemTakeInfo_String(active_take, "P_NAME", take_name, true)
        reaper.SetMediaItemSelected(item, 0)

        cleanNullTakes(item)
      end
    end
  end
end

function restoreOriginalTake(item)

  local num_takes = reaper.GetMediaItemNumTakes(item)
  
  if num_takes > 0 then
    
    local active_take = reaper.GetActiveTake(item)
    if active_take then

      local take_name =  reaper.GetTakeName(active_take)
      
      local take_number = string.match(take_name, "item_container_render:(%d+)")
      if take_number then
        
        -- delete the rendered midi take wav
        local old_src = getItemWavSrc(item)
        os.remove(old_src)
        os.remove(old_src..'.reapeaks')

        -- delete this take
        reaper.SetMediaItemSelected(item, true)
        reaper.Main_OnCommand(40129, 0)
        
        -- reselect original active take
        local original_take = reaper.GetTake(item, take_number)
        if original_take then reaper.SetActiveTake(original_take) end

        reaper.SetMediaItemSelected(item, false)

        cleanNullTakes(item)
      end
    end
  end
end

function cleanNullTakes(item, force)

  state = getSetObjectState(item)

  if string.find(state, "TAKE NULL") or force then
    state = string.gsub(state, "TAKE NULL", "")
    reaper.getSetObjectState(item, state)
  end
end


function setItemGlueGroup(item, glue_group, not_container)

  local key = "[container]:"
  if not_container then key = "[]:" end

  local name = key..glue_group
  
  local take = reaper.GetActiveTake(item)

  if not take then take = reaper.AddTakeToMediaItem(item) end

  if not not_container then
    local source = reaper.PCM_Source_CreateFromType("")
    reaper.SetMediaItemTake_Source(take, source)
  end

  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true)

end


function getGlueGroupFromItem(item, not_container)

  local key, name, take

  key = "[container]:(%d+)"
  if not_container then key = "[]:(%d+)" end
  
  take = reaper.GetActiveTake(item)
  if take then 
    name = reaper.GetTakeName(take)
  else
    return
  end

  return string.match(name, key) 
end

function checkSelectionForContainer(num_items)

  local i = 0, item, glue_group, non_container_item, container, new_glue_group

  while i < num_items do
    item = reaper.GetSelectedMediaItem(0, i)
    new_glue_group = getGlueGroupFromItem(item)

    -- if a glue group has been found on this item
    if new_glue_group then
      -- if this search has already found another container
      if glue_group then
        log("Item Container: Error: The selected items contain 2 different [container]s, unable to proceed.")
        return
      else
        container = item
        glue_group = new_glue_group
      end
    -- if we dont have a non-container item yet
    elseif not non_container_item then
      non_container_item = item
    end

    i = i + 1
  end

  -- make sure we have all 3 needed items
  if not glue_group or not container or not non_container_item then return end

  return glue_group, container, non_container_item
end

function checkItemForGlueGroup(item)
  return getGlueGroupFromItem(item, true)
end

function restoreItems( glue_group, track, position, dont_restore_take, dont_offset )

  deselect()

  -- get stored items
  local r, stored_items = reaper.GetProjExtState(0, "GLUE_GROUPS", glue_group, '')

  local splits = string.split(stored_items, "|||")

  local restored_items = {}
  local key, val, restored_item, container, item, return_item, left_most, pos, i

  for key,val in ipairs(splits) do

    if val then

      restored_item = reaper.AddMediaItemToTrack(track)
      getSetObjectState(restored_item, val)

      if string.find(val, "[container]:") then 
        container = restored_item
      elseif not return_item then
        return_item = restored_item
      end

      if not dont_restore_take then restoreOriginalTake(restored_item) end

      reaper.SetMediaItemInfo_Value(restored_item, "I_GROUPID", 0)

      if not left_most then 
        left_most = reaper.GetMediaItemInfo_Value(restored_item, "D_POSITION")
      else
        left_most = math.min(reaper.GetMediaItemInfo_Value(restored_item, "D_POSITION"), left_most)
      end

      restored_items[key] = restored_item
    end
  end

  offset = position - left_most

  for i, item in ipairs(restored_items) do
    reaper.SetMediaItemSelected(item, true)

    if not dont_offset then
      pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") + offset
      reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos)
    end
  end

  -- Group Items
  reaper.Main_OnCommand(40032, 0)

  return return_item, container, restored_items
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
  reaper.ShowConsoleMsg(name.."="..val.."\n")
end


function string:split(sSeparator, nMax, bRegexp)
  assert(sSeparator ~= '')
  assert(nMax == nil or nMax >= 1)

  local aRecord = {}

  if self:len() > 0 then
    local bPlain = not bRegexp
    nMax = nMax or -1

    local nField=1 nStart=1
    local nFirst,nLast = self:find(sSeparator, nStart, bPlain)
    while nFirst and nMax ~= 0 do
      aRecord[nField] = self:sub(nStart, nFirst-1)
      nField = nField+1
      nStart = nLast+1
      nFirst,nLast = self:find(sSeparator, nStart, bPlain)
      nMax = nMax-1
    end
    aRecord[nField] = self:sub(nStart)
  end

  return aRecord
end
