-- @description MB Glue-Reversible Utils: Tools for MB Glue-Reversible functionality
-- @author MonkeyBars
-- @version 1.52
-- @changelog Edit doesn't detect container length edits done since last Glue (https://github.com/MonkeyBars3k/ReaScripts/issues/85); Canceling render dialog spits out error (https://github.com/MonkeyBars3k/ReaScripts/issues/96)
-- @provides [nomain] .
--   gr-bg.png
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Code for Glue-Reversible scripts


-- dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")


local msg_change_selected_items = "Change the items selected and try again."


function initGlueReversible(obey_time_selection)
  local selected_item_count, this_container_num, container, source_item, source_track, glued_item

  selected_item_count = initAction("glue")

  if selected_item_count == false then return end

  this_container_num, container = checkSelectionForContainer(selected_item_count)
  source_item, source_track = getSourceSelections()

  if itemsOnMultipleTracksAreSelected(selected_item_count) == true or openContainersAreInvalid(selected_item_count) == true or pureMIDIItemsAreSelected(selected_item_count, source_track) == true then return end

  glued_item = triggerGlueReversible(this_container_num, source_item, source_track, container, obey_time_selection)
  
  exclusiveSelectItem(glued_item)
  cleanUpAction("MB Glue-Reversible")
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
  if requiredLibsAreInstalled() == false then return false end

  return selected_item_count
end


function renderPathIsValid()
  local platform, proj_renderpath, is_win, is_win_absolute_path, is_nix_absolute_path

  platform = reaper.GetOS()
  proj_renderpath = reaper.GetProjectPath(0)
  is_win = string.match(platform, "^Win")
  is_win_absolute_path = string.match(proj_renderpath, "^%u%:\\")
  is_nix_absolute_path = string.match(proj_renderpath, "^/")
  
  if (is_win and not is_win_absolute_path) or (not is_win and not is_nix_absolute_path) then
    reaper.ShowMessageBox("Set an absolute path in Project Settings > Media > Path or save your new project and try again.", "Glue-Reversible needs a file render path.", 0)
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


function requiredLibsAreInstalled()
  local sws_version

  if reaper.CF_GetSWSVersion ~= nil then
    sws_version = reaper.CF_GetSWSVersion()
  end

  if not sws_version then
    reaper.ShowMessageBox("Please install SWS at https://standingwaterstudios.com/ and try again.", "Glue-Reversible requires the SWS plugin extension to work.", 0)
    return false
  end
end


function prepareGlueState(action)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  if action == "glue" then
    setResetItemSelectionSet(true)
  end
end


-- get open container info from selection
function checkSelectionForContainer(selected_item_count)
  local i, item, this_container_num, new_container_num, container

  for i = 0, selected_item_count-1 do
    item = reaper.GetSelectedMediaItem(0, i)
    new_container_num = getContainerName(item)

    -- if pool found on this item
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


function getSourceSelections()
  local source_item, source_track

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


function triggerGlueReversible(this_container_num, source_item, source_track, container, obey_time_selection)
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
  local selected_item_count, original_items, item_states, container, new_length, item_position, glued_item, item_container_name, dependencies_table, original_state_key, first_item_name, glued_item_init_name

  if not this_container_num then
    this_container_num = incrementPoolID()
  end

  selected_item_count, original_items, first_item_name = handleGlueItemSelections()
  item_states, dependencies_table, has_non_container_items, item_container_name = handleItemStates(selected_item_count, original_items, existing_container)

  -- if we're attempting to glue a bunch of containers and nothing else, we're done
  if not has_non_container_items then return end

  container, original_state_key = prepareGlue(existing_container, source_track, this_container_num, original_items, container)
  glued_item, glued_item_init_name = executeGlue(obey_time_selection, original_items, selected_item_count, this_container_num, first_item_name)
  new_length, item_position = setItemParams(glued_item, container, this_container_num)

  updatePoolStates(item_states, container, this_container_num, item_container_name, dependencies_table, ignore_depends)
  getSetGluedContainerData(this_container_num, container)
  reaper.DeleteTrackMediaItem(source_track, container)

  return glued_item, original_state_key, item_position, new_length
end


function incrementPoolID()
  local r, last_container_num, this_container_num
  
  -- make a new pool id from last pool id if this is a new pool and name glue_track accordingly
  r, last_container_num = getSetStateData("last-pool-num")

  if r == true and last_container_num then
    last_container_num = tonumber( last_container_num )
    this_container_num = math.floor(last_container_num + 1)
  else
    this_container_num = 1
  end

  -- store this pool id so next pool can increment up
  getSetStateData("last-pool-num", this_container_num)

  return this_container_num
end



local master_track = reaper.GetMasterTrack(0)
-- save state data in master track tempo envelope because changes get saved in undo points and it can't be deactivated
local master_track_tempo_env = reaper.GetTrackEnvelope(master_track, 0)

function getSetStateData(key, val)
  local get_set, data_param, data_param_prefix, retval, state_data_val

  if val then
    get_set = true
  else
    val = ""
    get_set = false
  end

  data_param = "P_EXT:"
  data_param_script_prefix = "GR_"
  retval, state_data_val = reaper.GetSetEnvelopeInfo_String(master_track_tempo_env, data_param..data_param_script_prefix..key, val, get_set)

  return retval, state_data_val
end


function handleGlueItemSelections()
  local selected_item_count, original_items, first_item_name

  selected_item_count = reaper.CountSelectedMediaItems(0)
  original_items, first_item_name = getOriginalSelectedItems(selected_item_count)

  deselectAll()

  return selected_item_count, original_items, first_item_name
end


function getOriginalSelectedItems(selected_item_count)
  local original_items, i, this_item, this_item_name, this_item_take, first_item_name, this_is_open_container, nested_container_label

  original_items = {}
  
  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(0, i)
    this_item_name, this_item_take = getSetItemName(this_item)
    this_is_open_container = string.match(this_item_name, "^grc:")
    nested_container_label = string.match(this_item_name, "^gr:%d+")

    if not this_is_open_container then
      table.insert(original_items, this_item)

      if not first_item_name then
        if nested_container_label then
          first_item_name = nested_container_label
        else
          first_item_name = this_item_name
        end
      end
    end
  end

  return original_items, first_item_name
end


function handleItemStates(selected_item_count, original_items, existing_container)
  local item_states, dependencies_table, has_non_container_items, i, item, item_container_name

  -- convert to audio takes, store state, and check for dependencies
  item_states = ''
  dependencies_table = {}
  has_non_container_items = false

  for i = 1, getTableSize(original_items) do
    item = original_items[i]

    if item ~= existing_container then
      has_non_container_items = true

      setToAudioTake(item)
      
      item_states = item_states..getSetObjectState(item)
      item_states = item_states.."|||"

      item_container_name = getContainerName(item, true)

      if item_container_name then
        -- store this item's pool to set up dependencies later
        dependencies_table[item_container_name] = item_container_name
      end
    end
  end

  return item_states, dependencies_table, has_non_container_items, item_container_name
end


function prepareGlue(existing_container, source_track, this_container_num, original_items, container)
  local container, original_state_keythis_container_num

  if existing_container then
    container = prepareReglue(existing_container, source_track)
  else
    -- new glue: create container that will be resized and stored after glue is done
    container, original_state_key = reaper.AddMediaItemToTrack(source_track)

    -- set container's name to point to this pool
    setItemPool(container, this_container_num)
  end

  selectDeselectItems(original_items, true)
  reaper.SetMediaItemSelected(container, false)

  return container, original_state_key
end


function prepareReglue(existing_container, source_track)
  local container, open_container, container_length, container_position, container_name, original_state_key

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

  return container, original_state_key
end


function setItemPool(item, item_name_ending, not_container)
  local key, name, take, source

  if not_container then
    key = "gr:"
  else
    key = "grc:"
  end

  name = key..item_name_ending
  take = reaper.GetActiveTake(item)

  if not take then
    take = reaper.AddTakeToMediaItem(item)
  end

  if not not_container then
    source = reaper.PCM_Source_CreateFromType("")
    reaper.SetMediaItemTake_Source(take, source)
  end

  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true)
end


function selectDeselectItems(items, toggle)
  local i, count

  count = getTableSize(items)

  for i = 1, count do
    reaper.SetMediaItemSelected(items[i], toggle)
  end
end


function executeGlue(obey_time_selection, original_items, selected_item_count, this_container_num, first_item_name)
  local glued_item, glued_item_init_name

  glueSelectedItems(obey_time_selection)

  glued_item = reaper.GetSelectedMediaItem(0, 0)
  glued_item_init_name = handleAddtionalItemCountLabel(original_items, selected_item_count, this_container_num, first_item_name)
  
  setItemPool(glued_item, glued_item_init_name, true)

  return glued_item, glued_item_init_name
end


function glueSelectedItems(obey_time_selection)
  if obey_time_selection == true then
    reaper.Main_OnCommand(41588, 0)
  else
    reaper.Main_OnCommand(40362, 0)
  end
end


function handleAddtionalItemCountLabel(original_items, selected_item_count, this_container_num, first_item_name)
  local original_items_num, item_name_addl_count, glued_item_init_name

  original_items_num = getTableSize(original_items)

  if original_items_num > 1 then
    item_name_addl_count = " +"..(original_items_num-1).. " more"
  else
    item_name_addl_count = ""
  end

  glued_item_init_name = this_container_num.." [\u{0022}"..first_item_name.."\u{0022}"..item_name_addl_count.."]"

  return glued_item_init_name
end


function updatePoolStates(item_states, container, this_container_num, item_container_name, dependencies_table, ignore_depends)
  -- add container to stored states
  item_states = item_states..getSetObjectState(container)
  
  -- save stored state
  getSetStateData(this_container_num, item_states)

  if not ignore_depends then
    -- i.e., not called by updatePooledItems()
    updatePooledCopies(this_container_num, item_container_name, dependencies_table)
  end
end


function updatePooledCopies(this_container_num, item_container_name, dependencies_table)
  local r, old_dependencies, dependencies, dependent, dependecies_have_changed, dependency

  r, old_dependencies = getSetStateData(this_container_num..":dependencies")
  
  if r == false then
    old_dependencies = ""
  end

  dependencies = ""
  dependent = "|"..this_container_num.."|"

  -- store a reference to this pool for all the nested pools so if any get updated, they can check and update this pool
  for item_container_name, r in pairs(dependencies_table) do
    dependencies, old_dependencies = storePoolReference(item_container_name, dependent, dependencies, old_dependencies)
  end

  -- store this pool's dependencies list
  getSetStateData(this_container_num..":dependencies", dependencies)

  -- have the dependencies changed? - CHANGE CONDITION TO VAR dependencies_have_changed
  if string.len(old_dependencies) > 0 then
    -- loop thru all the dependencies no longer needed
    for dependency in string.gmatch(old_dependencies, "%d+") do 
      -- remove this pool from the other pools' dependents list
      removePoolFromDependents(dependency, dependent)
    end
  end
end


function storePoolReference(item_container_name, dependent, dependencies, old_dependencies)
  local key, r, dependents, dependency

  -- make a key for nested pool to store which pools are dependent on it
  key = item_container_name..":dependents"
  
  -- see if nested pool already has a list of dependents
  r, dependents = getSetStateData(key)
  
  if r == false then
    dependents = "" 
  end

  -- if this pool isn't already in list, add it
  if not string.find(dependents, dependent) then
    dependents = dependents..dependent
    getSetStateData(key, dependents)
  end

  -- now store of these pools' dependencies
  dependency = "|"..item_container_name.."|"
  dependencies = dependencies..dependency

  -- remove this dependency from old_dependencies string
  old_dependencies = string.gsub(old_dependencies, dependency, "")

  return dependencies, old_dependencies
end


function removePoolFromDependents(dependency, dependent)
  local key, r, dependents

  key = dependency..":dependents"
  r, dependents = getSetStateData(key)

  if r == true and string.find(dependents, dependent) then
    dependents = string.gsub(dependents, dependent, "")
    getSetStateData(key, dependents)
  end
end



local pos_delta

function setItemParams(glued_item, container, this_container_num)
  local new_length, new_item_position, retval, source_item_position

  -- make sure container is big enough
  new_length = reaper.GetMediaItemInfo_Value(glued_item, "D_LENGTH")
  reaper.SetMediaItemInfo_Value(container, "D_LENGTH", new_length)

  -- make sure container is aligned with start of items
  new_item_position = reaper.GetMediaItemInfo_Value(glued_item, "D_POSITION")
  reaper.SetMediaItemInfo_Value(container, "D_POSITION", new_item_position)

  retval, source_item_position = getSetStateData(this_container_num.."-pos")
  source_item_position = tonumber(source_item_position)

  if new_item_position and source_item_position then
    pos_delta = round((new_item_position - source_item_position), 13)
  end

  setItemImage(glued_item)

  return new_length, new_item_position
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


local position_changed

function doReglueReversible(source_track, source_item, this_container_num, container, obey_time_selection)
  local glued_item, original_state_key, pos, length, new_src
  
  glued_item, original_state_key, pos, length = doGlueReversible(source_track, source_item, obey_time_selection, this_container_num, container)

  -- store updated src
  new_src = getItemWavSrc(glued_item)

  if original_state_key then
    glued_item = updateItemInfo(original_state_key, glued_item, new_src, pos, length)
  end

  -- calculate dependents, create an update_table with a nicely ordered sequence and re-insert the items of each pool into temp tracks so they can be updated
  calculateDependentUpdates(this_container_num)

  -- sort dependents update_table by how nested they are
  sortDependentUpdates()

  if pos_delta and pos_delta ~= 0 then
    position_changed = true
  end

  -- do actual updates
  updateDependents(glued_item, source_item, this_container_num, new_src, length, obey_time_selection)

  return glued_item
end


function updateItemInfo(original_state_key, glued_item, new_src, pos, length)
  local r, original_state

  -- if there is a key in container's name, find it in state data and delete it from item
  r, original_state = getSetStateData(original_state_key)

  if r == true and original_state then
    getSetObjectState(glued_item, original_state)
    updateItemData(original_state_key, glued_item, new_src, pos, length)
  end

  return glued_item
end


function getSetObjectState(obj, state, minimal)
  local fastStr, set, new_state

  minimal = minimal or false
  fastStr = reaper.SNM_CreateFastString(state)
  set = false

  if state and string.len(state) > 0 then
    set = true
  end
  
  reaper.SNM_GetSetObjectState(obj, fastStr, set, minimal)
  new_state = reaper.SNM_GetFastString(fastStr)
  reaper.SNM_DeleteFastString(fastStr)
  
  return new_state
end


function updateItemData(original_state_key, glued_item, new_src, pos, length)
  updateItemSrc(glued_item)
  updateItemValues(glued_item, pos, length)
  removeOldItemState(original_state_key)
end


function updateItemSrc(glued_item)
  local take

  -- reapply new src because original state would have old one
  take = reaper.GetActiveTake(glued_item)
  reaper.BR_SetTakeSourceFromFile2(take, new_src, false, true)
end


function updateItemValues(glued_item, pos, length)
  -- set new position & length in case of differences from last glue
  reaper.SetMediaItemInfo_Value(glued_item, "D_POSITION", pos)
  reaper.SetMediaItemInfo_Value(glued_item, "D_LENGTH", length)
end


function removeOldItemState(original_state_key)
  -- remove original state data, not needed anymore
  getSetStateData(original_state_key, "")
end


function getSetItemName(item, name, add_or_remove)
  local take, current_name

  if reaper.GetMediaItemNumTakes(item) < 1 then return end

  take = reaper.GetActiveTake(item)

  if take then
    current_name = reaper.GetTakeName(take)

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
  local source, filename

  take = take or reaper.GetActiveTake(item)
  source = reaper.GetMediaItemTake_Source(take)
  filename = reaper.GetMediaSourceFileName(source, '')

  if string.len(filename) > 0 then
    return filename
  end
end


function setToAudioTake(item)
  local num_takes, active_take, active_take_number, take_name

  num_takes = reaper.GetMediaItemNumTakes(item)

  if num_takes > 0 then
    
    active_take = reaper.GetActiveTake(item)

    if active_take and reaper.TakeIsMIDI(active_take) then
      -- store ref to original active take for ungluing
      active_take_number = reaper.GetMediaItemTakeInfo_Value(active_take, "IP_TAKENUMBER")

      -- convert active MIDI item to an audio take
      reaper.SetMediaItemSelected(item, 1)
      reaper.Main_OnCommand(40209, 0)

      reaper.SetActiveTake(reaper.GetTake(item, num_takes))
      active_take = reaper.GetActiveTake(item)
      
      take_name = "glue_reversible_render:"..math.floor(active_take_number)

      reaper.GetSetMediaItemTakeInfo_String(active_take, "P_NAME", take_name, true)
      reaper.SetMediaItemSelected(item, 0)

      cleanNullTakes(item)
    end
  end
end


function restoreOriginalTake(item)
  local num_takes, active_take, take_name, take_number, old_src, original_take

  num_takes = reaper.GetMediaItemNumTakes(item)
  
  if num_takes > 0 then
    
    active_take = reaper.GetActiveTake(item)
    
    if active_take then

      take_name =  reaper.GetTakeName(active_take)
      take_number = string.match(take_name, "glue_reversible_render:(%d+)")
      
      if take_number then
        -- delete rendered midi take wav
        old_src = getItemWavSrc(item)
        
        os.remove(old_src)
        os.remove(old_src..'.reapeaks')

        -- delete this take
        reaper.SetMediaItemSelected(item, true)
        reaper.Main_OnCommand(40129, 0)
        
        -- reselect original active take
        original_take = reaper.GetTake(item, take_number)

        if original_take then
          reaper.SetActiveTake(original_take)
        end

        reaper.SetMediaItemSelected(item, false)

        cleanNullTakes(item)
      end
    end
  end
end


function cleanNullTakes(item, force)
  local state = getSetObjectState(item)

  if string.find(state, "TAKE NULL") or force then
    state = string.gsub(state, "TAKE NULL", "")
    reaper.getSetObjectState(item, state)
  end
end


function launchPropagatePositionDialog()
    return reaper.ShowMessageBox("Do you want to propagate this change by adjusting all the other unnested container items' left edge positions from the same pool in the same way?", "The left edge location of the container item you're regluing has changed!", 4)
end



-- keys
local update_table = {}
-- numeric version
local iupdate_table = {}

function calculateDependentUpdates(this_container_num, nesting_level)
  local track, dependent_pool, restored_items, item, container, glued_item, new_src, i, v, update_item, current_entry

  if not update_table then update_table = {} end
  if not nesting_level then nesting_level = 1 end

  r, dependents = getSetStateData(this_container_num..":dependents")

  if r == true and string.len(dependents) > 0 then
    for dependent_pool in string.gmatch(dependents, "%d+") do 
      dependent_pool = math.floor(tonumber(dependent_pool))

      -- check if an entry for this pool already exists
      if update_table[dependent_pool] then
        -- store how deeply nested this item is
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
        calculateDependentUpdates(dependent_pool, nesting_level + 1)
      end
    end
  end
end


function restoreItems(this_container_num, track, position, dont_restore_take, dont_offset)
  local r, stored_items, splits, restored_items, key, val, restored_item, container, item, return_item, left_most, pos, i

  deselectAll()

  -- get items stored during last glue
  r, stored_items = getSetStateData(this_container_num)
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

      -- "dont_restore_take" is set to true in calculateUpdates()
      if not dont_restore_take then
        restoreOriginalTake(restored_item) 
      end

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
  restored_items = offsetEditedItems(restored_items, offset, dont_offset)

  return return_item, container, restored_items
end


function offsetEditedItems(restored_items, offset, dont_offset)
  local i, item, pos

  for i, item in ipairs(restored_items) do
    reaper.SetMediaItemSelected(item, true)

    if not dont_offset then
      -- do position offset if this container is later than earliest positioned pooled copy
      pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") + offset
      reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos)
    end
  end

  return restored_items
end


-- convert update_table to a numeric array then sort by nesting value
function sortDependentUpdates()
  local i, v

  for i, v in pairs(update_table) do
    table.insert(iupdate_table, v)
  end
  
  table.sort( iupdate_table, function(a, b) return a.nesting_level < b.nesting_level end)
end


function updateDependents(glued_item, source_item, edited_pool_id, src, length, obey_time_selection)
  local dependent_glued_item, i, dependent, new_src

  -- update items with just one level of nesting now that they're exposed
  updatePooledItems(glued_item, edited_pool_id, src, length)

  -- loop thru dependents and update them in order
  for i, dependent in ipairs(iupdate_table) do
    deselectAll()
    reselect(dependent.restored_items)

    dependent_glued_item = doGlueReversible(dependent.track, source_item, obey_time_selection, dependent.this_container_num, dependent.container, true)

    -- update all instances of this pool, including any in other more deeply nested dependent pools which are exposed and waiting to be updated
    new_src = getItemWavSrc(dependent_glued_item)

    updatePooledItems(dependent_glued_item, dependent.this_container_num, new_src, length)

    -- delete glue track
    reaper.DeleteTrack(dependent.track)
  end

  reaper.ClearPeakCache()
end


function updatePooledItems(glued_item, edited_pool_id, new_src, length)
  local num_all_items, this_container_name, old_srcs, i, this_item

  deselectAll()

  num_all_items = reaper.CountMediaItems(0)
  this_container_name = "gr:"..edited_pool_id
  old_srcs = {}

  for i = 0, num_all_items-1 do
    this_item = reaper.GetMediaItem(0, i)
    updatePooledItem(glued_item, this_item, this_container_name, edited_pool_id, new_src, length)
  end
end



local other_pooled_items_are_present, position_change_response

function updatePooledItem(glued_item, this_item, this_container_name, edited_pool_id, new_src, length)
  local take_name, take, this_item_is_glued, this_item_pool_id, item_is_in_edited_pool, this_is_glued_item, glued_containers, open_containers, current_src, current_pos

  take_name, take = getSetItemName(this_item)
  this_item_is_glued = take_name and string.find(take_name, this_container_name)
  this_item_pool_id = getItemPoolId(this_item)
  item_is_in_edited_pool = this_item_pool_id == edited_pool_id
  this_is_glued_item = glued_item == this_item

  if this_item_is_glued then
    if item_is_in_edited_pool then

      if not position_change_response and position_changed == true and other_pooled_items_are_present == true then
        position_change_response = launchPropagatePositionDialog()
      end

      -- 6 == "YES"
      if item_is_in_edited_pool and position_change_response == 6 then
        current_pos = reaper.GetMediaItemInfo_Value(this_item, "D_POSITION")

        reaper.SetMediaItemInfo_Value(this_item, "D_POSITION", current_pos+pos_delta)
      end

      reaper.SetMediaItemInfo_Value(this_item, "D_LENGTH", length)

      other_pooled_items_are_present = true
    end

    current_src = getItemWavSrc(this_item)

    if current_src ~= new_src then
      reaper.BR_SetTakeSourceFromFile2(take, new_src, false, true)
    end
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

  this_pool_num = getItemPoolId(glued_containers[1])

  if getOtherPooledInstanceStatus(this_pool_num) == "open" then
    handleOtherOpenPooledInstance(item, edit_pool_num)

    return
  end
  
  selectDeselectItems(noncontainers, false)
  doEditGluedContainer()
end


function isNotSingleGluedContainer(glued_container_num)
  local multiitem_result

  if glued_container_num == 0 then
    reaper.ShowMessageBox(msg_change_selected_items, "Glue-Reversible Edit can only Edit previously glued container items." , 0)
    return true
  elseif glued_container_num > 1 then
    multiitem_result = reaper.ShowMessageBox("Would you like to Edit the first (earliest) selected container item only?", "Glue-Reversible Edit can only open one glued container item per action call.", 1)
    if multiitem_result == 2 then
      return true
    end
  else
    return false
  end
end


function getItemPoolId(item)
  return getContainerName(item, true)
end


-- not actually using "glued" at this time but leaving in case necessary later
function getOtherPooledInstanceStatus(edit_pool_num, testing_item)
  local num_all_items, i, item, item_pool_num, scroll_action_id

  num_all_items = reaper.CountMediaItems(0)

  for i = 0, num_all_items-1 do
    item = reaper.GetMediaItem(0, i)
    item_pool_num = getContainerName(item)

    if item_pool_num == edit_pool_num and getItemType(item) == "open" then
      return "open"
    elseif item_pool_num == edit_pool_num and testing_item ~= item and getItemType(item) == "glued" then
      return "glued"
    else
      return false
    end
  end
end


function handleOtherOpenPooledInstance(item, edit_pool_num)
  deselectAll()
  reaper.SetMediaItemSelected(item, true)
  scrollToSelectedItem()
  reaper.ShowMessageBox("Reglue the other open container item from pool "..tostring(edit_pool_num).." before trying to edit this glued container item. It will be selected and scrolled to now.", "Only one glued container item per pool can be Edited at a time.", 0)
end


function scrollToSelectedItem()
  scroll_action_id = reaper.NamedCommandLookup("_S&M_SCROLL_ITEM")

  reaper.Main_OnCommand(scroll_action_id, 0)
end


function doEditGluedContainer()
  local item, pool_id, glued_container, item_is_glued_container

  -- only get first selected item. no Edit of multiple items (yet)
  item = reaper.GetSelectedMediaItem(0, 0)

  -- make sure a glued container is selected
  if item then
    pool_id = getItemPoolId(item) 
  end

  item_is_glued_container = pool_id and item
  glued_container = item

  if item_is_glued_container then
    getSetGluedContainerData(pool_id)
    processEditGluedContainer(glued_container, pool_id)
    cleanUpAction("MB Edit Glue-Reversible")
  end
end


function getSetGluedContainerData(pool_id, glued_container)
  local get_set, pool_key_prefix, source_offset_prefix, source_offset_key, length_prefix, length_key, retval, glued_container_source_offset, glued_container_length, glued_container_take

  get_set = glued_container
  pool_key_prefix = "pool-"
  source_offset_prefix = "D_STARTOFFS-"
  source_offset_key = pool_key_prefix..source_offset_prefix
  length_prefix = "D_LENGTH-"
  length_key = pool_key_prefix..length_prefix

  -- get
  if not get_set then
    retval, glued_container_source_offset = getSetStateData(source_offset_key)
    retval, glued_container_length = getSetStateData(length_key)

  -- set
  else
    glued_container_take = reaper.GetActiveTake(glued_container)
    glued_container_source_offset = reaper.GetMediaItemTakeInfo_Value(glued_container_take, "D_STARTOFFS")
    glued_container_length = reaper.GetMediaItemInfo_Value(glued_container, "D_LENGTH")

    getSetStateData(source_offset_key, glued_container_source_offset)
    getSetStateData(length_key, glued_container_length)
  end
end


function processEditGluedContainer(item, this_container_num)
  local original_item_state, original_item_pos, original_item_track, _, container, original_item_state_key

  original_item_state, original_item_pos, original_item_track = getOriginalItemState(item)

  deselectAll()

  _, container = restoreItems(this_container_num, original_item_track, original_item_pos)

  -- create a unique key for original state, and store it in container's name, space it out of sight then store it
  original_item_state_key = "original_state:"..this_container_num..":"..os.time()*7
  
  getSetItemName(container, "                                                                                                      "..original_item_state_key, 1)
  getSetStateData(original_item_state_key, original_item_state)

  -- store preglue container position for reglue
  getSetStateData(this_container_num.."-pos", original_item_pos)

  reaper.DeleteTrackMediaItem(original_item_track, item)
end


function getOriginalItemState(item)
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
  
  -- refresh in case item selection changed
  selected_item_count = getSelectedItemsCount()
  if itemsAreSelected(selected_item_count) == false then return end

  -- find open item if present
  this_container_num = checkSelectionForContainer(selected_item_count)

  if openContainersAreInvalid(selected_item_count) == true then return end

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



--- UTILITY FUNCTIONS ---

function getTableSize(t)
    local count = 0
    for _, __ in pairs(t) do
        count = count + 1
    end
    return count
end


function round(num, precision)
   return math.floor(num*(10^precision)+0.5) / 10^precision
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