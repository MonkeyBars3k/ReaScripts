-- @description MB Glue (Reversible) Utils: Tools for MB Glue (Reversible) functionality
-- @author MonkeyBars
-- @version 1.27
-- @changelog Refactor glueGroup() - new name initGlueReversible() (https://github.com/MonkeyBars3k/ReaScripts/issues/35); Add "Toggle Glue/Unglue (Reversible)" scripts (https://github.com/MonkeyBars3k/ReaScripts/issues/9)
-- @provides [nomain] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about # Glue (Reversible)
-- 
-- To use Glue (Reversible), simply select items or make a time selection with items inside and trigger the Glue (Reversible) script.
--
-- To edit your glued items, Unglue (Reversible) opens the created container item; the items inside are automatically grouped for you. You can see the container item created with Glue (Reversible), but the items inside are now visible and directly editable. Continue working with them as grouped items and/or reglue them again with Glue (Reversible).
--
-- You can Glue (Reversible) existing container items, nondestructively nesting container items. There is no limit in the code as to how many times you can nest.
--
-- Fork of matthewjumpsoffbuildings's Glue Groups scripts



local msg_change_selected_items = "Change the items selected and try again."



function initGlueReversible(obey_time_selection)
  local selected_item_count, glue_group, container, source_item, source_track, glued_item

  selected_item_count = doPreGlueChecks()
  if selected_item_count == false then return end

  prepareGlueState()
  
  -- refresh in case item selection changed
  selected_item_count = getSelectedItemsCount()
  if itemsAreSelected(selected_item_count) == false then return end

  -- find unglued item if present
  glue_group, container = checkSelectionForContainer(selected_item_count)

  source_item, source_track = getSourceSelections()
  if itemsOnMultipleTracksAreSelected(selected_item_count) == true or ungluedContainersAreInvalid(selected_item_count) == true or pureMIDIItemsAreSelected(selected_item_count, source_track) == true then return end

  groupSelectedItems()
  glued_item = triggerGlueReversible(glue_group, source_track, source_item, container, obey_time_selection)
  exclusiveSelectItem(glued_item)
  cleanUpGlueReversible("Glue (Reversible)")
end


function doPreGlueChecks()
  local selected_item_count

  if renderPathIsValid() == false then return false end
  selected_item_count = getSelectedItemsCount()  
  if itemsAreSelected(selected_item_count) == false then return false end

  return selected_item_count
end


function prepareGlueState()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  setResetItemSet(true)
  selectAllItemsInGroups()
end


function renderPathIsValid()
  local platform, proj_renderpath, is_win, is_win_absolute_path, is_nix_absolute_path

  platform = reaper.GetOS()
  proj_renderpath = reaper.GetProjectPath(0)
  is_win = string.match(platform, "^Win")
  is_win_absolute_path = string.match(proj_renderpath, "^%u:\\")
  is_nix_absolute_path = string.match(proj_renderpath, "^/")
  
  if (is_win and not is_win_absolute_path) or (not is_win and not is_nix_absolute_path) then
    reaper.ShowMessageBox("Set an absolute path in Project Settings > Media > Path or save your new project and try again.", "Glue (Reversible) needs a file render path.", 0)
    return false
  else
    return true
  end
end


function getSelectedItemsCount()
  return reaper.CountSelectedMediaItems(0)
end


function itemsAreSelected(selected_item_count)
  -- gluing single item is enabled. change to "< 2" to disable
  if not selected_item_count or selected_item_count < 1 then 
    return false
  else
    return true
  end
end


-- get unglued container info from selection
function checkSelectionForContainer(selected_item_count)

  local i, item, glue_group, new_glue_group, container

  for i = 0, selected_item_count-1 do
    item = reaper.GetSelectedMediaItem(0, i)
    new_glue_group = getGlueGroupFromItem(item)

    -- if glue group found on this item
    if new_glue_group then
      -- if this search has already found another container
      if glue_group then
        return false
      else
        container = item
        glue_group = new_glue_group
      end

    -- if we don't have a non-container item yet
    elseif not non_container_item then
      non_container_item = item
    end
  end

  -- make sure we have all 3 needed items
  if not glue_group or not container or not non_container_item then return end

  return glue_group, container
end


function getSourceSelections()
  source_item = getOriginalItem()
  source_track = getOriginalTrack(source_item)

  return source_item, source_track
end


function setResetItemSet(set)
  if set == true then
    -- save selected item set to slot 10
    reaper.Main_OnCommand(41238, 0)
  else
    -- reset item selection from selection set slot 10
    reaper.Main_OnCommand(41248, 0)
  end
end


function selectAllItemsInGroups()
  -- select all items in group (if in one)
  reaper.Main_OnCommand(40034, 0)
end


function itemsOnMultipleTracksAreSelected(selected_item_count)
  local itemsOnMultipleTracksDetected = detectItemsOnMultipleTracks(selected_item_count)

  if itemsOnMultipleTracksDetected == true then 
      reaper.ShowMessageBox(msg_change_selected_items, "Glue (Reversible) can only glue items on a single track.", 0)
      return true
  end
end


function detectItemsOnMultipleTracks(selected_item_count)
  local i, selected_items, item, item_track, prev_item_track, itemsOnMultipleTracksDetected

  selected_items = {}
  itemsOnMultipleTracksDetected = false

  for i = 0, selected_item_count-1 do
    selected_items[i] = reaper.GetSelectedMediaItem(0, i)
    item = selected_items[i]

    item_track = reaper.GetMediaItemTrack(item)
    itemsOnMultipleTracksDetected = isDifferent(item_track, prev_item_track)
    
    if itemsOnMultipleTracksDetected == true then
      return itemsOnMultipleTracksDetected
    end
    
    prev_item_track = item_track
  end
end


function isDifferent(value1, value2)
  if value1 and value2 and value1 ~= value2 then
    return true
  else
    return false
  end
end


function ungluedContainersAreInvalid(selected_item_count)
  local glued_containers, unglued_containers = getContainers(selected_item_count)

  if multipleUngluedContainersAreSelected(#unglued_containers) == true or recursiveContainerIsBeingGlued(glued_containers, unglued_containers) == true then
    return true
  end
end


function multipleUngluedContainersAreSelected(num_unglued_containers_selected)
  if num_unglued_containers_selected and num_unglued_containers_selected > 1 then
    reaper.ShowMessageBox(msg_change_selected_items, "Glue (Reversible) can only reglue one container at a time.", 0)
    setResetItemSet()
    return true
  else
    return false
  end
end


function getContainers(selected_item_count)
  local selected_items, glued_containers, unglued_containers, i

  selected_items = {}
  glued_containers = {}
  unglued_containers = {}

  for i = 0, selected_item_count-1 do
    selected_items[i] = reaper.GetSelectedMediaItem(0, i)
    item = selected_items[i]

    if isGluedOrUnglued(item) == "glued" then
      table.insert(glued_containers, item)
    end

    if isGluedOrUnglued(item) == "unglued" then
      table.insert(unglued_containers, item)
    end
  end

  return glued_containers, unglued_containers
end

function recursiveContainerIsBeingGlued(glued_containers, unglued_containers)
  local i, j, this_container_name, unglued_container_name_prefix, this_glued_container_num, glued_container_name_prefix

  for i = 1, #glued_containers do
    this_container_name = getSetItemName(glued_containers[i])
    unglued_container_name_prefix = "^gr:(%d+)"
    this_glued_container_num = string.match(this_container_name, unglued_container_name_prefix)

    j = 1
    for j = 1, #unglued_containers do
      this_container_name = getSetItemName(unglued_containers[j])
      glued_container_name_prefix = "^grc:(%d+)"
      this_unglued_container_num = string.match(this_container_name, glued_container_name_prefix)
      
      if this_glued_container_num == this_unglued_container_num then
        reaper.ShowMessageBox(msg_change_selected_items, "Glue (Reversible) can't glue a pooled, glued container item to an unglued copy of itself!", 0)
        setResetItemSet()
        return true
      end
    end
  end
end


function getOriginalItem()
  return reaper.GetSelectedMediaItem(0, 0)
end


function getOriginalTrack(source_item)
  return reaper.GetMediaItemTrack(source_item)
end


function pureMIDIItemsAreSelected(selected_item_count, source_track)
  local selected_items, item, track_has_virtual_instrument, this_item_is_MIDI, midi_item_is_selected, i

  selected_items = {}
  track_has_virtual_instrument = reaper.TrackFX_GetInstrument(source_track)
  midi_item_is_selected = false

  for i = 0, selected_item_count-1 do
    selected_items[i] = reaper.GetSelectedMediaItem(0, i)
    item = selected_items[i]

    this_item_is_MIDI = isMIDIItem(item)    
    if this_item_is_MIDI == true then
      midi_item_is_selected = true
    end
  end

  if midi_item_is_selected and track_has_virtual_instrument == -1 then
    reaper.ShowMessageBox("Add a virtual instrument to render audio into the glued container or try a different item selection.", "Glue (Reversible) can't glue pure MIDI without a virtual instrument.", 0)
    return true
  end
end


function isMIDIItem(item, item_glue_group)
  local active_take = reaper.GetActiveTake(item)

  if active_take and reaper.TakeIsMIDI(active_take) then
    return true
  else
    return false
  end
end


function groupSelectedItems()
  reaper.Main_OnCommand(40032, 0)
end


function triggerGlueReversible(glue_group, source_track, source_item, container, obey_time_selection)
  local glued_item

  if glue_group then
    glued_item = reglueReversible(source_track, source_item, glue_group, container, obey_time_selection)
  else
    glued_item = glueReversible(source_track, source_item, obey_time_selection)
  end

  return glued_item
end


function exclusiveSelectItem(item)
  if item then
    deselect()
    reaper.SetMediaItemSelected(item, true)
  end
end


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


function cleanUpGlueReversible(undo_block_string)
  refreshUI()
  reaper.Undo_EndBlock(undo_block_string, -1)
end



function refreshUI()
  reaper.PreventUIRefresh(-1)
  reaper.UpdateTimeline()
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(true)
end


function glueReversible(source_track, source_item, obey_time_selection, glue_group, existing_container, ignore_depends)

  local selected_item_count, original_items, is_nested_container, nested_container_label, item, item_states, container, glue_container, i, r, container_length, container_position, item_position, new_length, glued_item, item_glue_group, key, dependencies_table, dependencies, dependency, dependents, dependent, original_state_key, container_name, first_item_take, first_item_name, item_name_addl_count, glued_item_init_name

  -- make a new glue_group id from group id if this is a new group and name glue_track accordingly
  if not glue_group then
    r, last_glue_group = reaper.GetProjExtState(0, "GLUE_GROUPS", "last", '')
    if r > 0 and last_glue_group then
      last_glue_group = tonumber( last_glue_group )
      glue_group = math.floor(last_glue_group + 1)
    else
      glue_group = 1
    end
  end

  -- store this glue group id so next group can increment up
  reaper.SetProjExtState(0, "GLUE_GROUPS", "last", glue_group)


  -- count items to be added
  selected_item_count = reaper.CountSelectedMediaItems(0)
  
  original_items = {}
  is_nested_container = false
  i = 0
  while i < selected_item_count do
    original_items[i] = reaper.GetSelectedMediaItem(0, i)

    -- get first selected item name
    if i == 0 then
      first_item_take = reaper.GetActiveTake(original_items[i])
      first_item_name = reaper.GetTakeName(first_item_take)

      is_nested_container = string.match(first_item_name, "^grc:")

    -- in nested containers the 1st noncontainer item comes after the container
    elseif i == 1 and is_nested_container then
      first_item_take = reaper.GetActiveTake(original_items[i])
      first_item_name = reaper.GetTakeName(first_item_take)

    elseif i == 1 then
      -- if this item is to be a nested container, remove *its* first item name & item count
      nested_container_label = string.match(first_item_name, "^gr:%d+")
      if nested_container_label then
        first_item_name = nested_container_label
      end
    end

    i = i + 1
  end


  deselect()


  -- convert to audio takes, store state, and check for dependencies
  item_states = ''
  dependencies_table = {}
  has_non_container_items = false
  i = 0
  while i < selected_item_count do
    item = original_items[i]

    if item ~= existing_container then

      has_non_container_items = true

      setToAudioTake(item)
      
      item_states = item_states..getSetObjectState(item)
      item_states = item_states.."|||"

      item_glue_group = getGlueGroupFromItem(item, true)

      if item_glue_group then
        -- keep track of this items glue group to set up dependencies later
        dependencies_table[item_glue_group] = item_glue_group
      end
    end
    i = i + 1
  end

  -- if we're attempting to glue a bunch of containers and nothing else
  if not has_non_container_items then return end

  -- if we're regluing
  if existing_container then
    -- existing container will be used for state storage/resizing later
    container = existing_container

    -- store reference to a new empty container for gluing purposes only
    glue_container = reaper.AddMediaItemToTrack(source_track)
    
    -- select glue_container too; it will be absorbed in the glue
    reaper.SetMediaItemSelected(glue_container, true)
    
    -- resize and reposition new glue_container to match existing container
    container_length = reaper.GetMediaItemInfo_Value(container, "D_LENGTH")
    container_position = reaper.GetMediaItemInfo_Value(container, "D_POSITION")
    reaper.SetMediaItemInfo_Value(glue_container, "D_LENGTH", container_length)
    reaper.SetMediaItemInfo_Value(glue_container, "D_POSITION", container_position)
    
    -- does this container have a reference to an original state of item that was unglued?
    container_name = getSetItemName(container)
    original_state_key = string.match(container_name, "original_state:%d+:%d+")
    -- get rid of original state key from container, not needed anymore
    getSetItemName(container, "%s+original_state:%d+:%d+", -1)
  
  -- otherwise this is a new glue, create container that will be resized and stored after glue is done
  else
    container = reaper.AddMediaItemToTrack(source_track)
    -- set container's name to point to this glue group
    setItemGlueGroup(container, glue_group)
  end

  -- reselect
  i = 0
  while i < selected_item_count do
    reaper.SetMediaItemSelected(original_items[i], true)
    i = i + 1
  end

  -- deselect original container
  reaper.SetMediaItemSelected(container, false)

  -- glue selected items
  if obey_time_selection == true then
    reaper.Main_OnCommand(41588, 0)
  else
    reaper.Main_OnCommand(40362, 0)
  end
  
  
  -- store ref to new glued item
  glued_item = reaper.GetSelectedMediaItem(0, 0)

  -- store a reference to this glue group in glued item
  if item_name_addl_count and item_name_addl_count > 0 then
    item_name_addl_count = " +"..(selected_item_count-1).. " more"
  else
    item_name_addl_count = ""
  end 
  glued_item_init_name = glue_group.." [\u{0022}"..first_item_name.."\u{0022}"..item_name_addl_count.."]"
  setItemGlueGroup(glued_item, glued_item_init_name, true)

  -- make sure container is big enough
  new_length = reaper.GetMediaItemInfo_Value(glued_item, "D_LENGTH")
  reaper.SetMediaItemInfo_Value(container, "D_LENGTH", new_length)

  -- make sure container is aligned with start of items
  item_position = reaper.GetMediaItemInfo_Value(glued_item, "D_POSITION")
  reaper.SetMediaItemInfo_Value(container, "D_POSITION", item_position)

  -- add container to stored states
  item_states = item_states..getSetObjectState(container)

  -- insert stored states into ProjExtState
  reaper.SetProjExtState(0, "GLUE_GROUPS", glue_group, item_states)

  -- if being called from an 'updateSources' nested call, dependencies haven't been changed, so don't bother with this part
  if not ignore_depends then

    r, old_dependencies = reaper.GetProjExtState(0, "GLUE_GROUPS", glue_group..":dependencies", '')
    if r < 1 then old_dependencies = "" end

    dependencies = ""
    dependent = "|"..glue_group.."|"

    -- store a reference to this glue group for all the nested glue groups so if any of them get updated, they can check and update this group
    for item_glue_group, r in pairs(dependencies_table) do
      
      -- make a key for nested glue group to keep track of which groups are dependent on it
      key = item_glue_group..":dependents"
      -- see if nested glue group already has a list of dependents
      r, dependents = reaper.GetProjExtState(0, "GLUE_GROUPS", key, '')
      if r == 0 then dependents = "" end
      -- if this glue group isn't already in list, add it
      if not string.find(dependents, dependent) then
        dependents = dependents..dependent
        reaper.SetProjExtState(0, "GLUE_GROUPS", key, dependents)
      end

      -- now keep track of this glue groups dependencies
      dependency = "|"..item_glue_group.."|"
      dependencies = dependencies..dependency
      -- remove this dependency from old_dependencies string
      old_dependencies = string.gsub(old_dependencies, dependency, "")
    end

    -- store this glue groups dependencies list
    reaper.SetProjExtState(0, "GLUE_GROUPS", glue_group..":dependencies", dependencies)

    -- have the dependencies changed?
    if string.len(old_dependencies) > 0 then
      -- loop thru all the dependencies no longer needed
      for dependency in string.gmatch(old_dependencies, "%d+") do 
        -- remove this glue group from the other glue groups dependents list
        key = dependency..":dependents"
        r, dependents = reaper.GetProjExtState(0, "GLUE_GROUPS", key, '')
        if r > 0 and string.find(dependents, dependent) then
          dependents = string.gsub(dependents, dependent, "")
          reaper.SetProjExtState(0, "GLUE_GROUPS", key, dependents)
        end

      end
    end
  end

  reaper.DeleteTrackMediaItem(source_track, container)

  return glued_item, original_state_key, item_position, new_length
end


function reglueReversible(source_track, source_item, glue_group, container, obey_time_selection)

  local glued_item, new_src, original_state, pos, take, r, original_state_key, container_name
  -- get original state that unglued item was in
  -- TODO - use ExtState to store it and key it to a particular container that was inserted on unglue


  -- run doGlue, but this time with a glue_group and container
  glued_item, original_state_key, pos, length = glueReversible(source_track, source_item, obey_time_selection, glue_group, container)

  -- store updated src
  new_src = getItemWavSrc(glued_item)

  -- if there is a key in container's name, find it in ProjExtState and delete it from item
  if original_state_key then
    r, original_state = reaper.GetProjExtState(0, "GLUE_GROUPS", original_state_key, '')

    if r > 0 and original_state then
      -- reapply original state to glued item
      getSetObjectState(glued_item, original_state)

      -- reapply new src because original state would have old one
      take = reaper.GetActiveTake(glued_item)
      reaper.BR_SetTakeSourceFromFile2(take, new_src, false, true)

      -- set new position & length in case of differences from last glue
      reaper.SetMediaItemInfo_Value(glued_item, "D_POSITION", pos)
      reaper.SetMediaItemInfo_Value(glued_item, "D_LENGTH", length)

      -- remove original state data, not needed anymore
      reaper.SetProjExtState(0, "GLUE_GROUPS", original_state_key, '')
    end
  end

  -- calculate dependents, create an update_table with a nicely ordered sequence and re-insert the items of each glue group into temp tracks so they can be updated
  calculateUpdates(glue_group)
  -- sort dependents update_table by how nested they are
  sortUpdates()
  -- do actual updates now
  updateDependents(glue_group, new_src, length, obey_time_selection)

  return glued_item

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

        -- store ref to original active take for ungluing
        local active_take_number = reaper.GetMediaItemTakeInfo_Value(active_take, "IP_TAKENUMBER")
        -- convert active MIDI item to an audio take
        reaper.SetMediaItemSelected(item, 1)
        reaper.Main_OnCommand(40209, 0)

        reaper.SetActiveTake(reaper.GetTake(item, num_takes))
        active_take = reaper.GetActiveTake(item)
        
        local take_name = "glue_reversible_render:"..math.floor(active_take_number)

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
      
      local take_number = string.match(take_name, "glue_reversible_render:(%d+)")
      if take_number then
        
        -- delete rendered midi take wav
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


function setItemGlueGroup(item, item_name_ending, not_container)

  local key = "grc:"
  if not_container then key = "gr:" end

  local name = key..item_name_ending
  
  local take = reaper.GetActiveTake(item)

  if not take then take = reaper.AddTakeToMediaItem(item) end

  if not not_container then
    local source = reaper.PCM_Source_CreateFromType("")
    reaper.SetMediaItemTake_Source(take, source)
  end

  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true)

end


-- gets unglued container item name prefix
function getGlueGroupFromItem(item, not_container)

  local key, name, take

  key = "grc:(%d+)"
  if not_container then key = "gr:(%d+)" end
  
  take = reaper.GetActiveTake(item)
  if take then 
    name = reaper.GetTakeName(take)
  else
    return
  end

  return string.match(name, key)
end

function checkItemForGlueGroup(item)
  return getGlueGroupFromItem(item, true)
end

function isGluedOrUnglued(item)
  local name, take_name, is_unglued_container, is_glued_container

  take = reaper.GetActiveTake(item)
  if take then 
    name = reaper.GetTakeName(take)
  else
    return
  end

  is_unglued_container = "^grc:(%d+)"
  is_glued_container = "^gr:(%d+)"

  if string.match(name, is_unglued_container) then
    return "unglued"
  elseif string.match(name, is_glued_container) then
    return "glued"
  else
    return false
  end
end


function updateSource( item, glue_group_string, new_src, length)
  local take_name, current_src, take

  -- get take name and see if it matches currently updated glue group
  take_name, take = getSetItemName(item)

  if take_name and string.find(take_name, glue_group_string) then
    
    current_src = getItemWavSrc(item)

    if current_src ~= new_src then

      -- update src
      reaper.BR_SetTakeSourceFromFile2(take, new_src, false, true)

      -- update length
      reaper.SetMediaItemInfo_Value(item, "D_LENGTH", length)

      -- refresh peak display
      reaper.ClearPeakCache()

      return current_src

    end
  end
end


function updateSources(new_src, glue_group, length)

  deselect()

  local selected_item_count, glue_group_string, i, this_item, old_src, old_srcs

  glue_group_string = "gr:"..glue_group

  old_srcs = {}

  -- count all items
  selected_item_count = reaper.CountMediaItems(0)

  -- loop through and update wav srcs
  i = 0
  while i < selected_item_count do
    this_item = reaper.GetMediaItem(0, i)
    old_src = updateSource(this_item, glue_group_string, new_src, length)

    if old_src then old_srcs[old_src] = true end

    i = i + 1
  end

  -- delete old srcs, dont need em
  for old_src, i in pairs(old_srcs) do
    os.remove(old_src)
    os.remove(old_src..'.reapeaks')
  end

end


-- keys
update_table = {}
-- numeric version
iupdate_table = {}
--

function calculateUpdates(glue_group, nesting_level)

  if not update_table then update_table = {} end
  if not nesting_level then nesting_level = 1 end

  local r, dependents = reaper.GetProjExtState(0, "GLUE_GROUPS", glue_group..":dependents", '')

  if r > 0 and string.len(dependents) > 0 then

    local track, dependent_group, restored_items, item, container, glued_item, new_src, i, v, update_item, current_entry

    for dependent_group in string.gmatch(dependents, "%d+") do 

      dependent_group = math.floor(tonumber(dependent_group))

      -- check if an entry for this group already exists
      if update_table[dependent_group] then
        -- keep track of how deeply nested this item is
        update_table[dependent_group].nesting_level = math.max(nesting_level, update_table[dependent_group].nesting_level)

      else 
      -- this is the first time this group has come up. set up for update loop
        current_entry = {}
        current_entry.glue_group = dependent_group
        current_entry.nesting_level = nesting_level

        -- make track for this item's updates
        reaper.InsertTrackAtIndex(0, false)
        track = reaper.GetTrack(0, 0)

        -- restore items into newly made empty track
        item, container, restored_items = restoreItems(dependent_group, track, 0, true, true)

        -- store references to temp track and items
        current_entry.track = track
        current_entry.item = item
        current_entry.container = container
        current_entry.restored_items = restored_items

        -- store this item in update_table
        update_table[dependent_group] = current_entry

        -- check if this group also has dependents
        calculateUpdates(dependent_group, nesting_level + 1)
      end
    end
  end
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

      if string.find(val, "grc:") then 
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


-- convert update_table to a numeric array then sort by nesting value
function sortUpdates()
  
  local i, v

  for i,v in pairs(update_table) do
    table.insert(iupdate_table, v)
  end
  
  table.sort( iupdate_table, function(a, b) return a.nesting_level < b.nesting_level end)
end


-- do the actual updates of the dependent groups
function updateDependents( glue_group, src, length, obey_time_selection )

  -- update items with just one level of nesting now that they are exposed
  updateSources(src, glue_group, length)

  local glued_item, i, dependent, new_src

  -- loop thru dependents and update them in order
  for i, dependent in ipairs(iupdate_table) do

    deselect()

    reselect(dependent.restored_items)

    
    glued_item = glueReversible(dependent.track, dependent.item, obey_time_selection, dependent.glue_group, dependent.container, true)

    -- update all instances of this group, including any in other more deeply nested dependent groups which are exposed and waiting to be updated
    new_src = getItemWavSrc(glued_item)
    updateSources(new_src, dependent.glue_group, length)

    -- delete glue track
    reaper.DeleteTrack(dependent.track)
    
  end
end


function reselect( items )
  local i, item

  for i,item in pairs(items) do
    reaper.SetMediaItemSelected(item, true)
  end
end


function unglueReversible()
  local num_items, selected_items, num_containers_selected, noncontainers, i, glued_container, item_track, prev_item_track, item, multiitem_result, noncontainer_idx

  num_items = reaper.CountSelectedMediaItems(0)

 
  selected_items = {}
  num_containers_selected = 0
  noncontainers = {}
  msg_change_selected_items = "Change the items selected and try again."
  i = 0
  while i < num_items do
    selected_items[i] = reaper.GetSelectedMediaItem(0, i)
    glued_container = checkItemForGlueGroup(selected_items[i])
    
     -- check whether items glued/unglued
    if glued_container then
      num_containers_selected = num_containers_selected + 1
    else
      table.insert(noncontainers, i)
    end

    -- check for multitrack
    item_track = reaper.GetMediaItemTrack(selected_items[i])
    -- this item's track differs from the last?
    if item_track and prev_item_track and item_track ~= prev_item_track then
      -- display "OK" message and quit
      reaper.ShowMessageBox(msg_change_selected_items, "Unglue (Reversible) can only unglue items on a single track.", 0)
      return false
    end
    prev_item_track = item_track

    i = i + 1
  end

  -- Throw error if zero or multiple container items selected
  if num_containers_selected == 0 then
    reaper.ShowMessageBox(msg_change_selected_items, "Unglue (Reversible) can only unglue previously glued container items." , 0)
    return
  elseif num_containers_selected > 1 then
    multiitem_result = reaper.ShowMessageBox("Would you like to Unglue the first (earliest) selected container item only?", "Unglue (Reversible) can only unglue a single glued container item at a time.", 1)
    if multiitem_result == 2 then
      return
    end
  end

  -- deselect noncontainers
  i = 0
  while i < #noncontainers do
    -- LUA starts iteration at 1.
    noncontainer_idx = noncontainers[i+1]
    reaper.SetMediaItemSelected(selected_items[noncontainer_idx], false)
    i = i + 1
  end
  if #noncontainers > 0 then
    reaper.UpdateArrange()
  end


  -- only get first selected item. no unglue of multiple items (yet)
  item = reaper.GetSelectedMediaItem(0, 0)

  -- make sure we selected something that is a glued group instance
  if item then glue_group = checkItemForGlueGroup(item) end

  if glue_group and item then

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    -- store state of glued item
    original_state = getSetObjectState(item)
    original_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    original_track = reaper.GetMediaItemTrack(item)

    -- deselect all
    deselect()

    -- restore stored items
    _, container = restoreItems(glue_group, original_track, original_pos)

    -- create a unique key for original state, and store it in container's name, space it out of sight then store it in ProjExtState
    original_state_key = "original_state:"..glue_group..":"..os.time()*7
    getSetItemName(container, "                                                                                                      "..original_state_key, 1)
    reaper.SetProjExtState(0, "GLUE_GROUPS", original_state_key, original_state)

    --remove item from track
    reaper.DeleteTrackMediaItem(original_track, item)

    -- clean up
    reaper.PreventUIRefresh(-1)
    reaper.UpdateTimeline()
    reaper.UpdateArrange()
    reaper.TrackList_AdjustWindows(true)
    reaper.Undo_EndBlock("Unglue (Reversible)", -1)

  end
end


function initToggleGlueUnglueReversible(obey_time_selection)
  local selected_item_count, glue_group, glue_reversible_action, glue_abort_dialog

  selected_item_count = doPreGlueChecks()
  if selected_item_count == false then return end

  prepareGlueState()
  
  -- refresh in case item selection changed
  selected_item_count = getSelectedItemsCount()
  if itemsAreSelected(selected_item_count) == false then return end

  -- find unglued item if present
  glue_group = checkSelectionForContainer(selected_item_count)

  if ungluedContainersAreInvalid(selected_item_count) == true then return end

  if doGlueReversibleAction(selected_item_count, obey_time_selection) == false then 
    reaper.ShowMessageBox(msg_change_selected_items, "Toggle Glue/Unglue Reversible can't determine which script to run.", 0)
    setResetItemSet()
    return
  end

  reaper.Undo_EndBlock("Toggle Glue/Unglue (Reversible)", -1)
end


function getGlueReversibleAction(selected_item_count)
  local glued_containers, unglued_containers, num_noncontainers, singleGluedContainerIsSelected, noUngluedContainersAreSelected, noNoncontainersAreSelected, gluedContainersAreSelected, noGluedContainersAreSelected, singleUngluedContainerIsSelected

  glued_containers, unglued_containers, num_noncontainers = getNumSelectedItemsByType(selected_item_count)
  noGluedContainersAreSelected = #glued_containers == 0
  singleGluedContainerIsSelected = #glued_containers == 1
  gluedContainersAreSelected = #glued_containers > 0
  noUngluedContainersAreSelected = #unglued_containers == 0
  singleUngluedContainerIsSelected = #unglued_containers == 1
  noNoncontainersAreSelected = num_noncontainers == 0
  noncontainersAreSelected = num_noncontainers > 1

  if singleGluedContainerIsSelected and noUngluedContainersAreSelected and noNoncontainersAreSelected then
    return "unglue"
  elseif singleUngluedContainerIsSelected and gluedContainersAreSelected then
    return "glue/abort"
  elseif (noGluedContainersAreSelected and singleUngluedContainerIsSelected) or (gluedContainersAreSelected and noUngluedContainersAreSelected) or (noncontainersAreSelected and noGluedContainersAreSelected and noUngluedContainersAreSelected) then
    return "glue"
  end
end


function getNumSelectedItemsByType(selected_item_count)
  local glued_containers, unglued_containers, num_noncontainers = 0

  glued_containers, unglued_containers = getContainers(selected_item_count)
  num_noncontainers = selected_item_count - #glued_containers - #unglued_containers

  return glued_containers, unglued_containers, num_noncontainers
end


function doGlueReversibleAction(selected_item_count, obey_time_selection)
  glue_reversible_action = getGlueReversibleAction(selected_item_count)

  if glue_reversible_action == "unglue" then
    unglueReversible()
  elseif glue_reversible_action == "glue" then
    initGlueReversible(obey_time_selection)
  elseif glue_reversible_action == "glue/abort" then
    glue_abort_dialog = reaper.ShowMessageBox("Are you sure you want to glue them?", "You have selected both an unglued container and glued container(s).", 1)
    if glue_abort_dialog == 2 then
      setResetItemSet()
      return
    else
      initGlueReversible(obey_time_selection)
    end
  else
    return false
  end
end


-- function getTableSize(t)
--     local count = 0
--     for _, __ in pairs(t) do
--         count = count + 1
--     end
--     return count
-- end


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