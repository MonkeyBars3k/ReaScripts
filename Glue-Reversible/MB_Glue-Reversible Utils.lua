-- @description MB Glue-Reversible Utils: Tools for MB Glue-Reversible functionality
-- @author MonkeyBars
-- @version 1.39
-- @changelog Ungrouping contained items breaks Glue-Reversible [4] (https://github.com/MonkeyBars3k/ReaScripts/issues/69)
-- @provides [nomain] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Code for Glue-Reversible scripts



local msg_change_selected_items = "Change the items selected and try again."


function initGlueReversible(obey_time_selection)
  local selected_item_count, this_container_num, container, source_item, source_track, glued_item

  selected_item_count = initAction("glue")
  if selected_item_count == false then return end

  -- find open container item if present
  this_container_num, container = checkSelectionForContainer(selected_item_count)

  source_item, source_track = getSourceSelections()

  if itemsOnMultipleTracksAreSelected(selected_item_count) == true or openContainersAreInvalid(selected_item_count) == true or pureMIDIItemsAreSelected(selected_item_count, source_track) == true then return end

  markSelectedItemsToPool(this_container_num, selected_item_count)
  glued_item = triggerGlueReversible(this_container_num, source_track, source_item, container, obey_time_selection)
  exclusiveSelectItem(glued_item)
  cleanUpAction("Glue-Reversible")
end


function initAction(action)
  local selected_item_count

  selected_item_count = doPreGlueChecks()
  if selected_item_count == false then return false end

  prepareGlueState(action)
  
  -- refresh in case item selection changed
  selected_item_count = getSelectedItemsCount()
  if itemsAreSelected(selected_item_count) == false then return false end

  return selected_item_count
end


function doPreGlueChecks()
  local selected_item_count

  if renderPathIsValid() == false then return false end
  selected_item_count = getSelectedItemsCount()  
  if itemsAreSelected(selected_item_count) == false then return false end

  return selected_item_count
end


function getSelectedItemsCount()
  return reaper.CountSelectedMediaItems(0)
end


function prepareGlueState(action)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  if action == "glue" then
    setResetItemSelectionSet(true)
  end
end


function renderPathIsValid()
  local platform, proj_renderpath, is_win, is_win_absolute_path, is_nix_absolute_path

  platform = reaper.GetOS()
  proj_renderpath = reaper.GetProjectPath(0)
  is_win = string.match(platform, "^Win")
  is_win_absolute_path = string.match(proj_renderpath, "^%u:\\")
  is_nix_absolute_path = string.match(proj_renderpath, "^/")
  
  if (is_win and not is_win_absolute_path) or (not is_win and not is_nix_absolute_path) then
    reaper.ShowMessageBox("Set an absolute path in Project Settings > Media > Path or save your new project and try again.", "Glue-Reversible needs a file render path.", 0)
    return false
  else
    return true
  end
end


function itemsAreSelected(selected_item_count)
  -- gluing single item is enabled. change to "< 2" to disable
  if not selected_item_count or selected_item_count < 1 then 
    return false
  else
    return true
  end
end


-- get open container info from selection
function checkSelectionForContainer(selected_item_count)
  local i, item, this_container_num, new_container_num, container

  for i = 0, selected_item_count-1 do
    item = reaper.GetSelectedMediaItem(0, i)
    new_container_num = getContainerName(item)

    -- if pool ID found on this item
    if new_container_num then
      -- if this search has already found another container
      if this_container_num then
        return false
      else
        container = item
        this_container_num = new_container_num
      end

    -- if we don't have a non-container item yet
    elseif not non_container_item then
      non_container_item = item
    end
  end

  -- make sure we have all 3 needed items
  if not this_container_num or not container or not non_container_item then return end

  return this_container_num, container
end


function getSourceSelections()
  source_item = getOriginalItem()
  source_track = getOriginalTrack(source_item)

  return source_item, source_track
end


function getOriginalItem()
  return reaper.GetSelectedMediaItem(0, 0)
end


function getOriginalTrack(source_item)
  return reaper.GetMediaItemTrack(source_item)
end


function setResetItemSelectionSet(set)
  if set == true then
    -- save selected item selection set to slot 10
    reaper.Main_OnCommand(41238, 0)
  else
    -- reset item selection from selection set slot 10
    reaper.Main_OnCommand(41248, 0)
  end
end


function selectAllItemsInPool(current_pool_id, num_all_items)
  local i, this_item, this_item_pool_id

  if not num_all_items then
    num_all_items = reaper.CountMediaItems(0)
  end

  for i = 0, num_all_items-1 do
    this_item = reaper.GetMediaItem(0, i)
    this_item_pool_id = reaper.GetSetMediaItemInfo_String(this_item, "P_EXT:glue-reversible_pool-id", "", false)

    if this_item_pool_id == current_pool_id then
      reaper.SetMediaItemSelected(this_item, true)
    end
  end
end


function itemsOnMultipleTracksAreSelected(selected_item_count)
  local itemsOnMultipleTracksDetected = detectItemsOnMultipleTracks(selected_item_count)

  if itemsOnMultipleTracksDetected == true then 
      reaper.ShowMessageBox(msg_change_selected_items, "Glue-Reversible and Edit container item only work on items on a single track.", 0)
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


function openContainersAreInvalid(selected_item_count)
  local glued_containers, open_containers = getContainers(selected_item_count)

  if #open_containers > 1 or recursiveContainerIsBeingGlued(glued_containers, open_containers) == true then
    reaper.ShowMessageBox(msg_change_selected_items, "Glue-Reversible can only Reglue or Edit one container at a time.", 0)
    setResetItemSelectionSet()
    return true
  end
end


function getContainers(selected_item_count)
  local glued_containers, open_containers, noncontainers, i, item

  glued_containers = {}
  open_containers = {}
  noncontainers = {}

  for i = 0, selected_item_count-1 do
    item = reaper.GetSelectedMediaItem(0, i)

    if getItemType(item) == "glued" then
      table.insert(glued_containers, item)
    elseif getItemType(item) == "open" then
      table.insert(open_containers, item)
    elseif getItemType(item) == "noncontainer" then
      table.insert(noncontainers, item)
    end
  end

  return glued_containers, open_containers, noncontainers
end


function recursiveContainerIsBeingGlued(glued_containers, open_containers)
  local i, j, this_container_num, this_glued_container_num, glued_container_name_prefix, open_container_name_prefix

  for i = 1, #glued_containers do
    this_container_num = getSetItemName(glued_containers[i])
    glued_container_name_prefix = "^gr:(%d+)"
    this_glued_container_num = string.match(this_container_num, glued_container_name_prefix)

    j = 1
    for j = 1, #open_containers do
      this_container_num = getSetItemName(open_containers[j])
      open_container_name_prefix = "^grc:(%d+)"
      this_open_container_num = string.match(this_container_num, open_container_name_prefix)
      
      if this_glued_container_num == this_open_container_num then
        reaper.ShowMessageBox(msg_change_selected_items, "Glue-Reversible can't glue a pooled, glued container item to an open copy of itself, or you could destroy the universe!", 0)
        setResetItemSelectionSet()
        return true
      end
    end
  end
end


function pureMIDIItemsAreSelected(selected_item_count, source_track)
  local selected_items, item, track_has_virtual_instrument, this_item_is_MIDI, midi_item_is_selected, i, this_item_is_open_container

  selected_items = {}
  track_has_virtual_instrument = reaper.TrackFX_GetInstrument(source_track)
  midi_item_is_selected = false
  this_item_is_open_container = false

  for i = 0, selected_item_count-1 do
    selected_items[i] = reaper.GetSelectedMediaItem(0, i)
    item = selected_items[i]

    this_item_is_MIDI = isMIDIItem(item)    
    if this_item_is_MIDI == true then
      midi_item_is_selected = true
    end

    if getItemType(item) == "open" then
      this_item_is_open_container = true
    end
  end

  if selected_item_count == 1 and this_item_is_open_container == true then
    return false
  end

  if midi_item_is_selected and track_has_virtual_instrument == -1 then
    reaper.ShowMessageBox("Add a virtual instrument to render audio into the glued container or try a different item selection.", "Glue-Reversible can't glue pure MIDI without a virtual instrument.", 0)
    return true
  end
end


function isMIDIItem(item)
  local active_take = reaper.GetActiveTake(item)

  if active_take and reaper.TakeIsMIDI(active_take) then
    return true
  else
    return false
  end
end


function markSelectedItemsToPool(this_container_num, selected_item_count)
  local i, selected_item

  if not selected_item_count then
    selected_item_count = reaper.CountSelectedMediaItems(0)
  end

  for i = 0, selected_item_count-1 do
    selected_item = reaper.GetSelectedMediaItem(0, i)

    if this_container_num == false then
      reaper.GetSetMediaItemInfo_String(selected_item, "P_EXT:glue-reversible_pool-id", "", true)
    else
      reaper.GetSetMediaItemInfo_String(selected_item, "P_EXT:glue-reversible_pool-id", tostring(this_container_num), true)
    end
  end
end


function triggerGlueReversible(this_container_num, source_track, source_item, container, obey_time_selection)
  local glued_item

  if this_container_num then
    glued_item = doReglueReversible(source_track, source_item, this_container_num, container, obey_time_selection)
  else
    glued_item = doGlueReversible(source_track, source_item, obey_time_selection)
  end

  return glued_item
end


function exclusiveSelectItem(item)
  if item then
    deselectAll()
    reaper.SetMediaItemSelected(item, true)
  end
end


function deselectAll()
  local num = reaper.CountSelectedMediaItems(0)
  
  if not num or num < 1 then return end
  
  local i = 0
  while i < num do
    reaper.SetMediaItemSelected( reaper.GetSelectedMediaItem(0, 0), false)
    i = i + 1
  end

  num = reaper.CountSelectedMediaItems(0)
end


function cleanUpAction(undo_block_string)
  refreshUI()
  reaper.Undo_EndBlock(undo_block_string, -1)
end


function refreshUI()
  reaper.PreventUIRefresh(-1)
  reaper.UpdateTimeline()
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(true)
end


function doGlueReversible(source_track, source_item, obey_time_selection, this_container_num, existing_container, ignore_depends)
  local selected_item_count, original_items, is_nested_container, nested_container_label, item, item_states, container, open_container, i, r, container_length, container_position, item_position, new_length, glued_item, item_container_name, key, dependencies_table, dependencies, dependency, dependents, dependent, original_state_key, container_name, first_item_take, first_item_name, item_name_addl_count, glued_item_init_name

  -- make a new this_container_num id from pool ID if this is a new pool and name glue_track accordingly
  if not this_container_num then
    r, last_container_num = reaper.GetProjExtState(0, "GLUE-REVERSIBLE", "last", '')
    if r > 0 and last_container_num then
      last_container_num = tonumber( last_container_num )
      this_container_num = math.floor(last_container_num + 1)
    else
      this_container_num = 1
    end
  end

  -- store this pool ID so next pooled item can increment up
  reaper.SetProjExtState(0, "GLUE-REVERSIBLE", "last", this_container_num)


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

  deselectAll()

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

      item_container_name = getContainerName(item, true)
      if item_container_name then
        -- keep track of this item's pool to set up dependencies later
        dependencies_table[item_container_name] = item_container_name
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
    open_container = reaper.AddMediaItemToTrack(source_track)
    
    -- select open_container too; it will be absorbed in the glue
    reaper.SetMediaItemSelected(open_container, true)
    
    -- resize and reposition new open_container to match existing container
    container_length = reaper.GetMediaItemInfo_Value(container, "D_LENGTH")
    container_position = reaper.GetMediaItemInfo_Value(container, "D_POSITION")
    reaper.SetMediaItemInfo_Value(open_container, "D_LENGTH", container_length)
    reaper.SetMediaItemInfo_Value(open_container, "D_POSITION", container_position)
    
    -- does this container have a reference to an original state of item that was open?
    container_name = getSetItemName(container)
    original_state_key = string.match(container_name, "original_state:%d+:%d+")
    -- get rid of original state key from container, not needed anymore
    getSetItemName(container, "%s+original_state:%d+:%d+", -1)
  
  -- otherwise this is a new glue, create container that will be resized and stored after glue is done
  else
    container = reaper.AddMediaItemToTrack(source_track)
    -- set container's name to point to this pool
    setItemPool(container, this_container_num)
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
    -- glue ignoring time selection
    reaper.Main_OnCommand(40362, 0)
  end
  
  -- store ref to new glued item
  glued_item = reaper.GetSelectedMediaItem(0, 0)

  -- store a reference to this pool in glued item
  if item_name_addl_count and item_name_addl_count > 0 then
    item_name_addl_count = " +"..(selected_item_count-1).. " more"
  else
    item_name_addl_count = ""
  end 
  glued_item_init_name = this_container_num.." [\u{0022}"..first_item_name.."\u{0022}"..item_name_addl_count.."]"
  setItemPool(glued_item, glued_item_init_name, true)

  new_length, item_position = setItemParams(glued_item, container)

  -- add container to stored states
  item_states = item_states..getSetObjectState(container)

  -- insert stored states into ProjExtState
  reaper.SetProjExtState(0, "GLUE-REVERSIBLE", this_container_num, item_states)

  -- update pooled copies, unless being called from updateSources() nested call
  if not ignore_depends then

    r, old_dependencies = reaper.GetProjExtState(0, "GLUE-REVERSIBLE", this_container_num..":dependencies", '')
    if r < 1 then old_dependencies = "" end

    dependencies = ""
    dependent = "|"..this_container_num.."|"

    -- store a reference to this pool for all the nested container items so if any of them get updated, they can check and update this pool
    for item_container_name, r in pairs(dependencies_table) do
      
      -- make a key for nested container items to keep track of which pools are dependent on it
      key = item_container_name..":dependents"
      -- see if nested container item already has a list of dependents
      r, dependents = reaper.GetProjExtState(0, "GLUE-REVERSIBLE", key, '')
      if r == 0 then dependents = "" end
      -- if this pool isn't already in list, add it
      if not string.find(dependents, dependent) then
        dependents = dependents..dependent
        reaper.SetProjExtState(0, "GLUE-REVERSIBLE", key, dependents)
      end

      -- now keep track of these pool dependencies
      dependency = "|"..item_container_name.."|"
      dependencies = dependencies..dependency
      -- remove this dependency from old_dependencies string
      old_dependencies = string.gsub(old_dependencies, dependency, "")
    end

    -- store this pool's dependencies list
    reaper.SetProjExtState(0, "GLUE-REVERSIBLE", this_container_num..":dependencies", dependencies)

    -- have the dependencies changed?
    if string.len(old_dependencies) > 0 then
      -- loop thru all the dependencies no longer needed
      for dependency in string.gmatch(old_dependencies, "%d+") do 
        -- remove this pool from the other pool's dependents list
        key = dependency..":dependents"
        r, dependents = reaper.GetProjExtState(0, "GLUE-REVERSIBLE", key, '')
        if r > 0 and string.find(dependents, dependent) then
          dependents = string.gsub(dependents, dependent, "")
          reaper.SetProjExtState(0, "GLUE-REVERSIBLE", key, dependents)
        end

      end
    end
  end

  reaper.DeleteTrackMediaItem(source_track, container)

  return glued_item, original_state_key, item_position, new_length
end


function setItemParams(glued_item, container)
  local new_length, item_position

  -- make sure container is big enough
  new_length = reaper.GetMediaItemInfo_Value(glued_item, "D_LENGTH")
  reaper.SetMediaItemInfo_Value(container, "D_LENGTH", new_length)

  -- make sure container is aligned with start of items
  item_position = reaper.GetMediaItemInfo_Value(glued_item, "D_POSITION")
  reaper.SetMediaItemInfo_Value(container, "D_POSITION", item_position)

  setItemImage(glued_item)

  return new_length, item_position
end


function setItemImage(item, remove)
  local script_path, img_path 

  script_path = string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$")
  if not remove then
    img_path = script_path.."gr-bg.png"
  else
    img_path = ""
  end

  reaper.BR_SetMediaItemImageResource(item, img_path, 1)
end


function doReglueReversible(source_track, source_item, this_container_num, container, obey_time_selection)
  local glued_item, original_state_key, pos, length, new_src, r, original_state, take
  
  glued_item, original_state_key, pos, length = doGlueReversible(source_track, source_item, obey_time_selection, this_container_num, container)

  -- store updated src
  new_src = getItemWavSrc(glued_item)

  -- if there is a key in container's name, find it in ProjExtState and delete it from item
  if original_state_key then
    r, original_state = reaper.GetProjExtState(0, "GLUE-REVERSIBLE", original_state_key, '')

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
      reaper.SetProjExtState(0, "GLUE-REVERSIBLE", original_state_key, '')
    end
  end

  -- calculate dependents, create an update_table with a nicely ordered sequence and re-insert the items of each pool into temp tracks so they can be updated
  calculateUpdates(this_container_num)
  -- sort dependents update_table by how nested they are
  sortUpdates()
  -- do actual updates now
  updateDependents(glued_item, this_container_num, new_src, length, obey_time_selection)

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


function setItemPool(item, item_name_ending, not_container)
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


-- gets container item name prefix
function getContainerName(item, not_container)

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


function getGluedContainerName(item)
  return getContainerName(item, true)
end


function getItemType(item)
  local name, take_name, is_open_container, is_glued_container

  take = reaper.GetActiveTake(item)
  if take then 
    name = reaper.GetTakeName(take)
  else
    return
  end

  is_open_container = "^grc:(%d+)"
  is_glued_container = "^gr:(%d+)"

  if string.match(name, is_open_container) then
    return "open"
  elseif string.match(name, is_glued_container) then
    return "glued"
  else
    return "noncontainer"
  end
end


function updateSources(glued_item, this_container_num, new_src, length)
  local selected_item_count, this_container_name, i, this_item, old_src, old_srcs

  deselectAll()

  this_container_name = "gr:"..this_container_num

  old_srcs = {}

  -- count all items
  selected_item_count = reaper.CountMediaItems(0)

  -- loop through and update wav srcs
  i = 0
  while i < selected_item_count do
    this_item = reaper.GetMediaItem(0, i)
    old_src = updateSource(glued_item, this_item, this_container_name, this_container_num, new_src, length)

    if old_src then old_srcs[old_src] = true end

    i = i + 1
  end

  -- delete old srcs, dont need em
  for old_src, i in pairs(old_srcs) do
    os.remove(old_src)
    os.remove(old_src..'.reapeaks')
  end

end


function updateSource(glued_item, item, this_container_name, this_container_num, new_src, length)
  local take_name, take, retval, glued_item_guid, glued_item_current_pos, this_item_guid, current_src, this_item_current_pos, glued_item_preglue_pos, pos_delta, new_pos

  -- get take name and see if it matches currently updated pool
  take_name, take = getSetItemName(item)

  retval, glued_item_guid = reaper.GetSetMediaItemInfo_String(glued_item, "GUID", "", false)
  glued_item_current_pos = reaper.GetMediaItemInfo_Value(glued_item, "D_POSITION")

  if take_name and string.find(take_name, this_container_name) then
    current_src = getItemWavSrc(item)

    if current_src ~= new_src then

      retval, this_item_guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
      this_item_current_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      retval, glued_item_preglue_pos = reaper.GetProjExtState(0, "GLUE-REVERSIBLE", this_container_num.."-pos")
      pos_delta = glued_item_current_pos - glued_item_preglue_pos 
      new_pos = this_item_current_pos + pos_delta

      if this_item_guid ~= glued_item_guid then
        reaper.SetMediaItemInfo_Value(item, "D_POSITION", new_pos)
      end

      reaper.BR_SetTakeSourceFromFile2(take, new_src, false, true)
      reaper.SetMediaItemInfo_Value(item, "D_LENGTH", length)
      reaper.ClearPeakCache()

      return current_src
    end
  end
end


-- keys
update_table = {}
-- numeric version
iupdate_table = {}
--

function calculateUpdates(this_container_num, nesting_level)

  if not update_table then update_table = {} end
  if not nesting_level then nesting_level = 1 end

  local r, dependents = reaper.GetProjExtState(0, "GLUE-REVERSIBLE", this_container_num..":dependents", '')

  if r > 0 and string.len(dependents) > 0 then

    local track, dependent_pool, restored_items, item, container, glued_item, new_src, i, v, update_item, current_entry

    for dependent_pool in string.gmatch(dependents, "%d+") do 

      dependent_pool = math.floor(tonumber(dependent_pool))

      -- check if an entry for this pool already exists
      if update_table[dependent_pool] then
        -- keep track of how deeply nested this item is
        update_table[dependent_pool].nesting_level = math.max(nesting_level, update_table[dependent_pool].nesting_level)

      else 
      -- this is the first time this pool has come up. set up for update loop
        current_entry = {}
        current_entry.this_container_num = dependent_pool
        current_entry.nesting_level = nesting_level

        -- make track for this item's updates
        reaper.InsertTrackAtIndex(0, false)
        track = reaper.GetTrack(0, 0)

        -- restore items into newly made empty track
        item, container, restored_items = restoreItems(dependent_pool, track, 0, true, true)

        -- store references to temp track and items
        current_entry.track = track
        current_entry.item = item
        current_entry.container = container
        current_entry.restored_items = restored_items

        -- store this item in update_table
        update_table[dependent_pool] = current_entry

        -- check if this pool also has dependents
        calculateUpdates(dependent_pool, nesting_level + 1)
      end
    end
  end
end


function restoreItems( this_container_num, track, position, dont_restore_take, dont_offset )
  local r, stored_items, splits, restored_items, key, val, restored_item, container, item, return_item, left_most, pos, i

  deselectAll()

  -- get items stored during last glue
  r, stored_items = reaper.GetProjExtState(0, "GLUE-REVERSIBLE", this_container_num, '')

  splits = string.split(stored_items, "|||")

  restored_items = {}

  -- parse stored items data
  for key, val in ipairs(splits) do
    if val then

      -- add item back into track
      restored_item = reaper.AddMediaItemToTrack(track)
      getSetObjectState(restored_item, val)

      -- restored_item is the open container?
      if string.find(val, "grc:") then 
        container = restored_item
      elseif not return_item then
        return_item = restored_item
      end

      -- set to true in calculateUpdates() for some reason
      if not dont_restore_take then restoreOriginalTake(restored_item) end

      markSelectedItemsToPool(false)

      -- set items' bg image
      setItemImage(restored_item)

      -- get position of left-most pooled copy
      if not left_most then
        left_most = reaper.GetMediaItemInfo_Value(restored_item, "D_POSITION")
      else
        left_most = math.min(reaper.GetMediaItemInfo_Value(restored_item, "D_POSITION"), left_most)
      end

      -- populate new array
      restored_items[key] = restored_item
    end
  end

  offset = position - left_most

  -- do position offset if this container is later than earliest positioned pooled copy
  for i, item in ipairs(restored_items) do
    reaper.SetMediaItemSelected(item, true)

    if not dont_offset then
      pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") + offset
      reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos)
    end
  end

  markSelectedItemsToPool(this_container_num)

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


-- do the actual updates of the dependent pools
function updateDependents(glued_item, this_container_num, src, length, obey_time_selection)

  -- update items with just one level of nesting now that they are exposed
  updateSources(glued_item, this_container_num, src, length)

  -- this is pretty weird, declaring local var with same name as argument coming in above?
  local glued_item, i, dependent, new_src

  -- loop thru dependents and update them in order
  for i, dependent in ipairs(iupdate_table) do

    deselectAll()

    reselect(dependent.restored_items)
    
    glued_item = doGlueReversible(dependent.track, dependent.item, obey_time_selection, dependent.this_container_num, dependent.container, true)

    -- update all instances of this pool, including any in other more deeply nested dependent pools which are exposed and waiting to be updated
    new_src = getItemWavSrc(glued_item)
    updateSources(glued_item, dependent.this_container_num, new_src, length)

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


function initEditGluedContainer()
  local selected_item_count, glued_containers, open_containers, noncontainers, this_pool_num

  selected_item_count = initAction("edit")
  if selected_item_count == false then return end

  if itemsOnMultipleTracksAreSelected(selected_item_count) == true then return end

  glued_containers, open_containers, noncontainers = getContainers(selected_item_count)

  if isNotSingleGluedContainer(#glued_containers) == true then return end

  this_pool_num = getGluedContainerName(glued_containers[1])
  if otherPooledInstanceIsOpen(this_pool_num) == true then return end
  
  selectDeselectItems(noncontainers, false)
  doEditGluedContainer()
end


function isNotSingleGluedContainer(glued_container_num)
  local multiitem_result

  if glued_container_num == 0 then
    reaper.ShowMessageBox(msg_change_selected_items, "Glue-Reversible Edit can only Edit previously glued container items." , 0)
    return true
  elseif glued_container_num > 1 then
    multiitem_result = reaper.ShowMessageBox("Would you like to Edit the first (earliest) selected container item only?", "Glue-Reversible Edit can only Edit a single glued container item at a time.", 1)
    if multiitem_result == 2 then
      return true
    end
  else
    return false
  end
end


function otherPooledInstanceIsOpen(this_pool_num)
  local num_all_items, i, this_item, scroll_action_id

  num_all_items = reaper.CountMediaItems(0)

  for i = 0, num_all_items-1 do
    this_item = reaper.GetMediaItem(0, i)

    if getItemType(this_item) == "open" then
      deselectAll()
      reaper.SetMediaItemSelected(this_item, true)
      selectAllItemsInPool(this_pool_num, num_all_items)
      -- scroll to selected item
      scroll_action_id = reaper.NamedCommandLookup("_S&M_SCROLL_ITEM")
      reaper.Main_OnCommand(scroll_action_id, 0)

      reaper.ShowMessageBox("Reglue the open container item from pool "..tostring(this_pool_num).." before trying to edit this glued container item. It will be selected and scrolled to now.", "Glue-Reversible Edit can only edit one glued container item belonging to the same pool at a time.", 0)
      return true
    end
  end
end


function selectDeselectItems(items, toggle)
  local i

  for i = 1, #items do
    reaper.SetMediaItemSelected(items[i], toggle)
  end
end


function doEditGluedContainer()
  local item, this_container_num

  -- only get first selected item. no Edit of multiple items (yet)
  item = reaper.GetSelectedMediaItem(0, 0)

  -- make sure a glued container is selected
  if item then this_container_num = getGluedContainerName(item) end

  if this_container_num and item then
    processEditGluedContainer(item, this_container_num)
    cleanUpAction("Edit-Reversible")
  end
end


function processEditGluedContainer(item, this_container_num)
  local original_item_state, original_item_pos, original_item_track, _, container, original_item_state_key

  original_item_state, original_item_pos, original_item_track = storeOriginalItemState(item)

  deselectAll()

  _, container = restoreItems(this_container_num, original_item_track, original_item_pos)

  -- create a unique key for original state, and store it in container's name, space it out of sight then store it in ProjExtState
  original_item_state_key = "original_state:"..this_container_num..":"..os.time()*7
  getSetItemName(container, "                                                                                                      "..original_item_state_key, 1)
  reaper.SetProjExtState(0, "GLUE-REVERSIBLE", original_item_state_key, original_item_state)

  -- store preglue container position for reglue
  reaper.SetProjExtState(0, "GLUE-REVERSIBLE", this_container_num.."-pos", original_item_pos)

  reaper.DeleteTrackMediaItem(original_item_track, item)
end


function storeOriginalItemState(item)
  local original_item_state, original_item_pos, original_item_track

  original_item_state = getSetObjectState(item)
  original_item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  original_item_track = reaper.GetMediaItemTrack(item)

  return original_item_state, original_item_pos, original_item_track
end


function initSmartAction(obey_time_selection)
  local selected_item_count, this_container_num, glue_reversible_action, glue_abort_dialog

  selected_item_count = doPreGlueChecks()
  if selected_item_count == false then return end

  prepareGlueState("glue")

  -- find open item if present
  this_container_num = checkSelectionForContainer(selected_item_count)

  if openContainersAreInvalid(selected_item_count) == true then return end
  
  selectAllItemsInPool(this_container_num)
  
  -- refresh in case item selection changed
  selected_item_count = getSelectedItemsCount()
  if itemsAreSelected(selected_item_count) == false then return end

  if doGlueUnglueAction(selected_item_count, obey_time_selection) == false then 
    reaper.ShowMessageBox(msg_change_selected_items, "Toggle Glue/Unglue Reversible can't determine which script to run.", 0)
    setResetItemSelectionSet()
    return
  end

  reaper.Undo_EndBlock("Smart Glue/Unglue", -1)
end


function getSmartAction(selected_item_count)
  local glued_containers, open_containers, num_noncontainers, singleGluedContainerIsSelected, noOpenContainersAreSelected, noNoncontainersAreSelected, gluedContainersAreSelected, noGluedContainersAreSelected, singleOpenContainerIsSelected

  glued_containers, open_containers, num_noncontainers = getNumSelectedItemsByType(selected_item_count)
  noGluedContainersAreSelected = #glued_containers == 0
  singleGluedContainerIsSelected = #glued_containers == 1
  gluedContainersAreSelected = #glued_containers > 0
  noOpenContainersAreSelected = #open_containers == 0
  singleOpenContainerIsSelected = #open_containers == 1
  noNoncontainersAreSelected = num_noncontainers == 0
  noncontainersAreSelected = num_noncontainers > 0

  if singleGluedContainerIsSelected and noOpenContainersAreSelected and noNoncontainersAreSelected then
    return "edit"
  elseif singleOpenContainerIsSelected and gluedContainersAreSelected then
    return "glue/abort"
  elseif (noGluedContainersAreSelected and singleOpenContainerIsSelected) or (gluedContainersAreSelected and noOpenContainersAreSelected) or (noncontainersAreSelected and noGluedContainersAreSelected and noOpenContainersAreSelected) then
    return "glue"
  end
end


function getNumSelectedItemsByType(selected_item_count)
  local glued_containers, open_containers, num_noncontainers = 0

  glued_containers, open_containers = getContainers(selected_item_count)
  num_noncontainers = selected_item_count - #glued_containers - #open_containers

  return glued_containers, open_containers, num_noncontainers
end


function doGlueUnglueAction(selected_item_count, obey_time_selection)
  glue_reversible_action = getSmartAction(selected_item_count)

  if glue_reversible_action == "edit" then
    initEditGluedContainer()
  elseif glue_reversible_action == "glue" then
    initGlueReversible(obey_time_selection)
  elseif glue_reversible_action == "glue/abort" then
    glue_abort_dialog = reaper.ShowMessageBox("Are you sure you want to glue them?", "You have selected both an open container and glued container(s).", 1)
    if glue_abort_dialog == 2 then
      setResetItemSelectionSet()
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