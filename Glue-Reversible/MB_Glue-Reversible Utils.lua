-- @description MB_Glue-Reversible Utils: Codebase for MB_Glue-Reversible scripts' functionality
-- @author MonkeyBars
-- @version 1.53
-- @changelog Refactor nomenclature (https://github.com/MonkeyBars3k/ReaScripts/issues/115); Replace os.time() for id string with GenGUID() (https://github.com/MonkeyBars3k/ReaScripts/issues/109); Nested pooled containers no longer update (https://github.com/MonkeyBars3k/ReaScripts/issues/114)
-- @provides [nomain] .
--   gr-bg.png
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Code for Glue-Reversible scripts


-- dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")


local msg_change_selected_items = "Change the items selected and try again."


function initGlueReversible(obey_time_selection)
  local selected_item_count, pool_id, empty_container, first_selected_item, first_selected_item_track, glued_container

  selected_item_count = initAction("glue")

  if selected_item_count == false then return end

  pool_id, empty_container = getEmptyContainerFromSelection(selected_item_count)
  first_selected_item, first_selected_item_track = getInitialSelections()

  if itemsOnMultipleTracksAreSelected(selected_item_count) == true or emptyContainersAreInvalid(selected_item_count) == true or pureMIDIItemsAreSelected(selected_item_count, first_selected_item_track) == true then return end

  glued_container = triggerGlueReversible(pool_id, first_selected_item, first_selected_item_track, empty_container, obey_time_selection)
  
  exclusiveSelectItem(glued_container)
  cleanUpAction("MB Glue-Reversible")
end


function initAction(action)
  local selected_item_count

  selected_item_count = doPreGlueChecks()

  if selected_item_count == false then return false end

  prepareGlue(action)
  
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
  local platform, proj_renderpath, is_win, is_win_absolute_path, is_win_local_path, is_nix_absolute_path, is_other_local_path

  platform = reaper.GetOS()
  proj_renderpath = reaper.GetProjectPath(0)
  is_win = string.match(platform, "^Win")
  is_win_absolute_path = string.match(proj_renderpath, "^%u%:\\")
  is_win_local_path = is_win and not is_win_absolute_path
  is_nix_absolute_path = string.match(proj_renderpath, "^/")
  is_other_local_path = not is_win and not is_nix_absolute_path
  
  if is_win_local_path or is_other_local_path then
    reaper.ShowMessageBox("Set an absolute path in Project Settings > Media > Path or save your new project and try again.", "Glue-Reversible needs a valid file render path.", 0)
    return false
  else
    return true
  end
end


function itemsAreSelected(selected_item_count)
  local no_items_are_selected = selected_item_count < 1

  if not selected_item_count or no_items_are_selected then 
    return false
  else
    return true
  end
end


function requiredLibsAreInstalled()
  local can_get_sws_version, sws_version

  can_get_sws_version = reaper.CF_GetSWSVersion ~= nil

  if can_get_sws_version then
    sws_version = reaper.CF_GetSWSVersion()
  end

  if not can_get_sws_version or not sws_version then
    reaper.ShowMessageBox("Please install SWS at https://standingwaterstudios.com/ and try again.", "Glue-Reversible requires the SWS plugin extension to work.", 0)
    return false
  end
end


function prepareGlue(action)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  if action == "glue" then
    setResetItemSelectionSet(true)
  end
end


function setResetItemSelectionSet(set_reset)
  -- set
  if set_reset == true then
    -- save selected item selection set to slot 10
    reaper.Main_OnCommand(41238, 0)

  -- reset
  else
    -- reset item selection from selection set slot 10
    reaper.Main_OnCommand(41248, 0)
  end
end


function getEmptyContainerFromSelection(selected_item_count)
  local i, item, pool_id, new_pool_id, empty_container

  for i = 0, selected_item_count-1 do

    item = reaper.GetSelectedMediaItem(0, i)
    new_pool_id = getPoolId(item)

    if new_pool_id then

      if pool_id then
        return false
      else
        empty_container = item
        pool_id = new_pool_id
      end
    end
  end

  if not pool_id or not empty_container then return end

  return pool_id, empty_container
end


function getPoolId(item, is_glued_container)
  local take, key, name

  take = reaper.GetActiveTake(item)

  if is_glued_container then
    key = "gr:(%d+)"
  else
    key = "grc:(%d+)"
  end

  if take then 
    name = reaper.GetTakeName(take)
  else
    return
  end

  return string.match(name, key)
end


function getInitialSelections()
  local first_selected_item, first_selected_item_track

  first_selected_item = getFirstSelectedItem()
  first_selected_item_track = getUserSelectedTrack(first_selected_item)

  return first_selected_item, first_selected_item_track
end


function getFirstSelectedItem()
  return reaper.GetSelectedMediaItem(0, 0)
end


function getUserSelectedTrack(first_selected_item)
  return reaper.GetMediaItemTrack(first_selected_item)
end


function itemsOnMultipleTracksAreSelected(selected_item_count)
  local items_on_multiple_tracks_are_detected = detectItemsOnMultipleTracks(selected_item_count)

  if items_on_multiple_tracks_are_detected == true then 
      reaper.ShowMessageBox(msg_change_selected_items, "Glue-Reversible and Edit container item only work on items on a single track.", 0)
      return true
  end
end


function detectItemsOnMultipleTracks(selected_item_count)
  local i, selected_items, this_item, this_item_track, prev_item_track, items_on_multiple_tracks_are_detected

  selected_items = {}
  items_on_multiple_tracks_are_detected = false

  for i = 0, selected_item_count-1 do
    selected_items[i] = reaper.GetSelectedMediaItem(0, i)
    this_item = selected_items[i]
    this_item_track = reaper.GetMediaItemTrack(this_item)
    items_on_multiple_tracks_are_detected = this_item_track and prev_item_track and this_item_track ~= prev_item_track
  
    if items_on_multiple_tracks_are_detected == true then
      return items_on_multiple_tracks_are_detected
    end
    
    prev_item_track = this_item_track
  end
end


function emptyContainersAreInvalid(selected_item_count)
  local glued_containers, empty_containers, multiple_empty_containers_are_selected, recursive_container_is_being_glued

  glued_containers, empty_containers = getContainers(selected_item_count)
  multiple_empty_containers_are_selected = #empty_containers > 1
  recursive_container_is_being_glued = recursiveContainerIsBeingGlued(glued_containers, empty_containers) == true

  if multiple_empty_containers_are_selected or recursive_container_is_being_glued then
    reaper.ShowMessageBox(msg_change_selected_items, "Glue-Reversible can only Reglue or Edit one container at a time.", 0)
    setResetItemSelectionSet()
    return true
  end
end


function getContainers(selected_item_count)
  local glued_containers, empty_containers, noncontainers, i, this_item

  glued_containers = {}
  empty_containers = {}
  noncontainers = {}

  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(0, i)

    if getItemType(this_item) == "glued" then
      table.insert(glued_containers, this_item)
    elseif getItemType(this_item) == "open" then
      table.insert(empty_containers, this_item)
    elseif getItemType(this_item) == "noncontainer" then
      table.insert(noncontainers, this_item)
    end
  end

  return glued_containers, empty_containers, noncontainers
end


function getItemType(item)
  local name, take_name, is_open_container, is_glued_container

  take = reaper.GetActiveTake(item)
  is_open_container = "^grc:(%d+)"
  is_glued_container = "^gr:(%d+)"

  if take then 
    name = reaper.GetTakeName(take)
  else
    return
  end

  if string.match(name, is_open_container) then
    return "open"
  elseif string.match(name, is_glued_container) then
    return "glued"
  else
    return "noncontainer"
  end
end


function recursiveContainerIsBeingGlued(glued_containers, empty_containers)
  local i, j, pool_id, glued_container_name_prefix, this_glued_pool_id, empty_container_name_prefix, this_open_pool_id

  for i = 1, #glued_containers do
    pool_id = getSetItemName(glued_containers[i])
    glued_container_name_prefix = "^gr:(%d+)"
    this_glued_pool_id = string.match(pool_id, glued_container_name_prefix)

    j = 1
    for j = 1, #empty_containers do
      pool_id = getSetItemName(empty_containers[j])
      empty_container_name_prefix = "^grc:(%d+)"
      this_open_pool_id = string.match(pool_id, empty_container_name_prefix)
      
      if this_glued_pool_id == this_open_pool_id then
        reaper.ShowMessageBox(msg_change_selected_items, "Glue-Reversible can't glue a glued container item to an instance from the same pool being Edited – or you could destroy the universe!", 0)
        setResetItemSelectionSet()
        return true
      end
    end
  end
end


function getSetItemName(item, new_name, add_or_remove)
  local item_has_no_takes, take, current_name

  item_has_no_takes = reaper.GetMediaItemNumTakes(item) < 1

  if item_has_no_takes then return end

  take = reaper.GetActiveTake(item)

  if take then
    current_name = reaper.GetTakeName(take)

    -- set
    if new_name then

      if add_or_remove == "add" then
        new_name = current_name.." "..new_name

      elseif add_or_remove == "remove" then
        new_name = string.gsub(current_name, new_name, "")
      end

      reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)

      return new_name, take

    -- get
    else
      return current_name, take
    end
  end
end


function pureMIDIItemsAreSelected(selected_item_count, first_selected_item_track)
  local selected_items, track_has_no_virtual_instrument, midi_item_is_selected, i, this_item, this_item_is_MIDI

  selected_items = {}
  track_has_no_virtual_instrument = reaper.TrackFX_GetInstrument(first_selected_item_track) == -1
  midi_item_is_selected = false

  for i = 0, selected_item_count-1 do
    selected_items[i] = reaper.GetSelectedMediaItem(0, i)
    this_item = selected_items[i]

    this_item_is_MIDI = isMIDIItem(this_item)

    if this_item_is_MIDI == true then
      midi_item_is_selected = true
    end
  end

  if midi_item_is_selected and track_has_no_virtual_instrument then
    reaper.ShowMessageBox("Add a virtual instrument to render audio into the glued container or try a different item selection.", "Glue-Reversible can't glue pure MIDI without a virtual instrument.", 0)
    return true
  end
end


function isMIDIItem(item)
  local active_take, this_take_is_midi

  active_take = reaper.GetActiveTake(item)
  this_take_is_midi = reaper.TakeIsMIDI(active_take)

  if active_take and this_take_is_midi then
    return true
  else
    return false
  end
end


function triggerGlueReversible(pool_id, first_selected_item, first_selected_item_track, empty_container, obey_time_selection)
  local glued_container
  
  if pool_id then
    glued_container = reglueContainer(first_selected_item_track, first_selected_item, pool_id, empty_container, obey_time_selection)
  else
    glued_container = createGluedContainer(first_selected_item_track, first_selected_item, obey_time_selection)
  end

  return glued_container
end


function exclusiveSelectItem(item)
  if item then
    deselectAllItems()
    reaper.SetMediaItemSelected(item, true)
  end
end


function deselectAllItems()
  reaper.Main_OnCommand(40289, 0)
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


function createGluedContainer(first_selected_item_track, first_selected_item, obey_time_selection, pool_id, empty_container, ignore_dependencies)
  local selected_item_count, user_selected_items, first_user_selected_item_name, user_selected_item_states, pool_dependencies_table, has_glued_containers_or_noncontainers, new_pool_id, glue_placeholder_item, glued_item, glued_item_length, glued_item_position

  if not pool_id then
    pool_id = handlePoolId()
  end

  selected_item_count = getSelectedItemsCount()
  user_selected_items, first_user_selected_item_name = getUserSelectedItems(selected_item_count)

  deselectAllItems()
  
  user_selected_item_states, pool_dependencies_table, has_glued_containers_or_noncontainers, new_pool_id = createUserSelectedItemStates(selected_item_count, user_selected_items, empty_container)

  if not has_glued_containers_or_noncontainers then return end

  glue_placeholder_item = createGluePlaceholder(empty_container, first_selected_item_track, pool_id, user_selected_items)
  glued_item = glueSelectedItemsIntoContainer(obey_time_selection, user_selected_items, selected_item_count, pool_id, first_user_selected_item_name)
  glued_item_length, glued_item_position = setGluedContainerParams(glued_item, glue_placeholder_item, pool_id)

  getSetGluedContainerData(pool_id, glued_item)
  updatePoolStates(user_selected_item_states, glue_placeholder_item, pool_id, new_pool_id, pool_dependencies_table, ignore_dependencies)
  deletePlaceholder(first_selected_item_track, glue_placeholder_item)

  return glued_item, glued_item_position, glued_item_length
end


function handlePoolId()
  local retval, last_pool_id, new_pool_id
  
  retval, last_pool_id = getSetStateData("last-pool-id")
  new_pool_id = incrementPoolId(last_pool_id)

  getSetStateData("last-pool-id", new_pool_id)

  return new_pool_id
end


function incrementPoolId(last_pool_id)
  local new_pool_id

  if last_pool_id and last_pool_id ~= "" then
    last_pool_id = tonumber(last_pool_id)
    new_pool_id = math.floor(last_pool_id + 1)
  else
    new_pool_id = 1
  end

  return new_pool_id
end


-- outside function since getSetStateData() gets called a lot
local master_track = reaper.GetMasterTrack(0)
-- save state data in master track tempo envelope because changes get saved in undo points and it can't be deactivated (i.e., data removed)
local master_track_tempo_env = reaper.GetTrackEnvelope(master_track, 0)

function getSetStateData(key, val)
  local get_set, data_param, data_param_script_prefix, data_param_key, retval, state_data_val

  -- set
  if val then
    get_set = true

  -- get
  else
    val = ""
    get_set = false
  end

  data_param = "P_EXT:"
  data_param_script_prefix = "GR_"
  data_param_key = data_param..data_param_script_prefix..key
  retval, state_data_val = reaper.GetSetEnvelopeInfo_String(master_track_tempo_env, data_param_key, val, get_set)

  return retval, state_data_val
end


function getSelectedItemsCount()
  return reaper.CountSelectedMediaItems(0)
end


function getUserSelectedItems(selected_item_count)
  local user_selected_items, i, this_item, this_item_name, this_item_take, first_user_selected_item_name, this_is_empty_container, nested_container_label

  user_selected_items = {}
  
  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(0, i)
    this_item_name, this_item_take = getSetItemName(this_item)
    this_is_empty_container = string.match(this_item_name, "^grc:")
    nested_container_label = string.match(this_item_name, "^gr:%d+")

    if not this_is_empty_container then
      table.insert(user_selected_items, this_item)

      if not first_user_selected_item_name then
        if nested_container_label then
          first_user_selected_item_name = nested_container_label
        else
          first_user_selected_item_name = this_item_name
        end
      end
    end
  end

  return user_selected_items, first_user_selected_item_name
end


function createUserSelectedItemStates(selected_item_count, user_selected_items, empty_container)
  local user_selected_item_count, user_selected_item_states, pool_dependencies_table, has_glued_containers_or_noncontainers, i, this_item, this_item_is_not_empty_container, new_pool_id

  user_selected_item_count = getTableSize(user_selected_items)
  user_selected_item_states = ""
  pool_dependencies_table = {}
  has_glued_containers_or_noncontainers = false

  for i = 1, user_selected_item_count do
    this_item = user_selected_items[i]
    this_item_is_not_empty_container = this_item ~= empty_container

    if this_item_is_not_empty_container then
      convertMidiItemToAudio(this_item)
      
      user_selected_item_states = user_selected_item_states..getSetObjectState(this_item).."|||"
      has_glued_containers_or_noncontainers = true
      new_pool_id = getPoolId(this_item, true)

      if new_pool_id then
        pool_dependencies_table[new_pool_id] = new_pool_id
      end
    end
  end

  return user_selected_item_states, pool_dependencies_table, has_glued_containers_or_noncontainers, new_pool_id
end


function convertMidiItemToAudio(item)
  local item_takes_count, active_take, this_take_is_midi, active_take_num, new_take_name

  item_takes_count = reaper.GetMediaItemNumTakes(item)

  if item_takes_count > 0 then
    
    active_take = reaper.GetActiveTake(item)
    this_take_is_midi = active_take and reaper.TakeIsMIDI(active_take)

    if this_take_is_midi then
      active_take_num = getTakeNum(active_take)

      reaper.SetMediaItemSelected(item, 1)
      renderFxToItem()

      active_take = setLastTakeActive(item, item_takes_count)
      new_take_name = "glue_reversible_render:"..math.floor(active_take_num)

      reaper.GetSetMediaItemTakeInfo_String(active_take, "P_NAME", new_take_name, true)
      reaper.SetMediaItemSelected(item, 0)
      cleanNullTakes(item)
    end
  end
end


function getTakeNum(take)
  return reaper.GetMediaItemTakeInfo_Value(take, "IP_TAKENUMBER")
end


function renderFxToItem()
  reaper.Main_OnCommand(40209, 0)
end


function setLastTakeActive(item, item_takes_count)
  local last_take = reaper.GetTake(item, item_takes_count)

  reaper.SetActiveTake(last_take)

  return last_take
end


function cleanNullTakes(item, force)
  local item_state = getSetObjectState(item)

  if string.find(item_state, "TAKE NULL") or force then
    item_state = string.gsub(state, "TAKE NULL", "")

    reaper.getSetObjectState(item, item_state)
  end
end


function createGluePlaceholder(empty_container, first_selected_item_track, pool_id, user_selected_items)
  local glue_placeholder_item

  -- reglue
  if empty_container then
    glue_placeholder_item = prepareRegluePlaceholder(empty_container, first_selected_item_track)

  -- new glue
  else
    glue_placeholder_item = reaper.AddMediaItemToTrack(first_selected_item_track)

    setContainerItemName(glue_placeholder_item, pool_id)
    setTakeSource(glue_placeholder_item)
  end

  selectDeselectItems(user_selected_items, true)
  reaper.SetMediaItemSelected(glue_placeholder_item, false)

  return glue_placeholder_item
end


function setContainerItemName(item, item_name_ending, is_glued_item)
  local item_name_prefix, new_item_name, take

  if is_glued_item then
    item_name_prefix = "gr:"
  else
    item_name_prefix = "grc:"
  end

  new_item_name = item_name_prefix..item_name_ending
  take = reaper.GetActiveTake(item)

  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_item_name, true)
end


function setTakeSource(item)
  local take, take_source

  take = reaper.GetActiveTake(item)
  take_source = reaper.PCM_Source_CreateFromType("")

  if not take then
    take = reaper.AddTakeToMediaItem(item)
  end

  reaper.SetMediaItemTake_Source(take, take_source)
end


function selectDeselectItems(items, select_deselect)
  local i, count

  count = getTableSize(items)

  for i = 1, count do
    reaper.SetMediaItemSelected(items[i], select_deselect)
  end
end


function prepareRegluePlaceholder(empty_container, first_selected_item_track)
  local reglue_placeholder_item, temp_marker_item, reglue_placeholder_item_length, reglue_placeholder_item_position, reglue_placeholder_item_name

  reglue_placeholder_item = empty_container
  temp_marker_item = reaper.AddMediaItemToTrack(first_selected_item_track)
  
  reaper.SetMediaItemSelected(temp_marker_item, true)
  
  reglue_placeholder_item_length = reaper.GetMediaItemInfo_Value(reglue_placeholder_item, "D_LENGTH")
  reglue_placeholder_item_position = reaper.GetMediaItemInfo_Value(reglue_placeholder_item, "D_POSITION")

  reaper.SetMediaItemInfo_Value(temp_marker_item, "D_LENGTH", reglue_placeholder_item_length)
  reaper.SetMediaItemInfo_Value(temp_marker_item, "D_POSITION", reglue_placeholder_item_position)
  
  reglue_placeholder_item_name = getSetItemName(reglue_placeholder_item)

  getSetItemName(reglue_placeholder_item, "%s+original_state:%d+:%d+", "remove")

  return reglue_placeholder_item
end


function glueSelectedItemsIntoContainer(obey_time_selection, user_selected_items, selected_item_count, pool_id, first_user_selected_item_name)
  local glued_container, glued_container_init_name

  glueSelectedItems(obey_time_selection)

  glued_container = reaper.GetSelectedMediaItem(0, 0)
  glued_container_init_name = handleAddtionalItemCountLabel(user_selected_items, selected_item_count, pool_id, first_user_selected_item_name)
  
  setContainerItemName(glued_container, glued_container_init_name, true)

  return glued_container
end


function glueSelectedItems(obey_time_selection)
  if obey_time_selection == true then
    reaper.Main_OnCommand(41588, 0)
  else
    reaper.Main_OnCommand(40362, 0)
  end
end


function handleAddtionalItemCountLabel(user_selected_items, selected_item_count, pool_id, first_user_selected_item_name)
  local user_selected_item_count, multiple_user_selected_items, item_name_addl_count_str, glued_container_init_name, double_quotation_mark

  user_selected_item_count = getTableSize(user_selected_items)
  multiple_user_selected_items = user_selected_item_count > 1
  double_quotation_mark = "\u{0022}"

  if multiple_user_selected_items then
    item_name_addl_count_str = " +"..(user_selected_item_count-1).. " more"
  else
    item_name_addl_count_str = ""
  end

  glued_container_init_name = pool_id.." ["..double_quotation_mark..first_user_selected_item_name..double_quotation_mark..item_name_addl_count_str.."]"

  return glued_container_init_name
end



local glued_instance_pos_delta_during_edit

function setGluedContainerParams(glued_container, container, pool_id)
  local new_glued_container_length, new_glued_container_position, retval, user_selected_item_position

  -- make sure container is big enough
  new_glued_container_length = reaper.GetMediaItemInfo_Value(glued_container, "D_LENGTH")
  reaper.SetMediaItemInfo_Value(container, "D_LENGTH", new_glued_container_length)

  -- make sure container is aligned with start of items
  new_glued_container_position = reaper.GetMediaItemInfo_Value(glued_container, "D_POSITION")
  reaper.SetMediaItemInfo_Value(container, "D_POSITION", new_glued_container_position)

  retval, user_selected_item_position = getSetStateData(pool_id.."-pos")
  user_selected_item_position = tonumber(user_selected_item_position)

  if new_glued_container_position and user_selected_item_position then
    glued_instance_pos_delta_during_edit = round((new_glued_container_position - user_selected_item_position), 13)
  else
    glued_instance_pos_delta_during_edit = 0
  end

  setItemImage(glued_container)

  return new_glued_container_length, new_glued_container_position
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


function updatePoolStates(user_selected_item_states, container, pool_id, new_pool_id, pool_dependencies_table, ignore_dependencies)
  -- add container to stored states
  user_selected_item_states = user_selected_item_states..getSetObjectState(container)
  
  -- save stored state
  getSetStateData(pool_id, user_selected_item_states)

  if not ignore_dependencies then
    -- i.e., not called by updatePooledItems()
    updatePooledCopies(pool_id, new_pool_id, pool_dependencies_table)
  end
end


function updatePooledCopies(pool_id, new_pool_id, pool_dependencies_table)
  local r, old_dependencies, dependencies, dependent, dependecies_have_changed, dependency

  r, old_dependencies = getSetStateData(pool_id..":dependencies")
  
  if r == false then
    old_dependencies = ""
  end

  dependencies = ""
  dependent = "|"..pool_id.."|"

  -- store a reference to this pool for all the nested pools so if any get updated, they can check and update this pool
  for new_pool_id, r in pairs(pool_dependencies_table) do
    dependencies, old_dependencies = storePoolReference(new_pool_id, dependent, dependencies, old_dependencies)
  end

  -- store this pool's dependencies list
  getSetStateData(pool_id..":dependencies", dependencies)

  -- have the dependencies changed? - CHANGE CONDITION TO VAR dependencies_have_changed
  if string.len(old_dependencies) > 0 then
    -- loop thru all the dependencies no longer needed
    for dependency in string.gmatch(old_dependencies, "%d+") do 
      -- remove this pool from the other pools' dependents list
      removePoolFromDependents(dependency, dependent)
    end
  end
end


function storePoolReference(new_pool_id, dependent, dependencies, old_dependencies)
  local key, r, dependents, dependency

  -- make a key for nested pool to store which pools are dependent on it
  key = new_pool_id..":dependents"
  
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
  dependency = "|"..new_pool_id.."|"
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


function deletePlaceholder(first_selected_item_track, glue_placeholder_item)
  reaper.DeleteTrackMediaItem(first_selected_item_track, glue_placeholder_item)
end


function reglueContainer(first_selected_item_track, first_selected_item, pool_id, container, obey_time_selection)
  local glued_container_source_offset, open_container_source_offset, open_container_length, open_container_pos, original_item_state, original_item_pos, glued_container, pos, length, new_src

  glued_container_source_offset = getSetGluedContainerData(pool_id)
  open_container_source_offset, open_container_length, open_container_pos = getSetGluedContainerData("open-"..pool_id)
  original_item_state, original_item_pos = getOriginalItemState(container)
  glued_container, pos, length = createGluedContainer(first_selected_item_track, first_selected_item, obey_time_selection, pool_id, container)

  -- store updated src
  new_src = getItemWavSrc(glued_container)

  -- this never got called
  -- if original_state_key then
  --   glued_container = updateItemInfo(original_state_key, glued_container, new_src, pos, length)
  -- end

  calculateDependentUpdates(pool_id)
  sortDependentUpdates()
  setPositionDeltas(glued_container_source_offset, open_container_pos, original_item_pos, open_container_source_offset)
  updateDependents(glued_container, first_selected_item, pool_id, new_src, length, obey_time_selection)

  return glued_container
end


-- this never got called
-- function updateItemInfo(original_state_key, glued_container, new_src, pos, length)
--   local r, original_state

--   -- if there is a key in container's name, find it in state data and delete it from item
--   r, original_state = getSetStateData(original_state_key)

--   if r == true and original_state then
--     getSetObjectState(glued_container, original_state)
--     updateItemData(original_state_key, glued_container, new_src, pos, length)
--   end

--   return glued_container
-- end


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


function updateItemData(original_state_key, glued_container, new_src, pos, length)
  updateItemSrc(glued_container)
  updateItemValues(glued_container, pos, length)
  removeOldItemState(original_state_key)
end


function updateItemSrc(glued_container)
  local take

  -- reapply new src because original state would have old one
  take = reaper.GetActiveTake(glued_container)
  reaper.BR_SetTakeSourceFromFile2(take, new_src, false, true)
end


function updateItemValues(glued_container, pos, length)
  -- set new position & length in case of differences from last glue
  reaper.SetMediaItemInfo_Value(glued_container, "D_POSITION", pos)
  reaper.SetMediaItemInfo_Value(glued_container, "D_LENGTH", length)
end


function removeOldItemState(original_state_key)
  -- remove original state data, not needed anymore
  getSetStateData(original_state_key, "")
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


function restoreOriginalTake(item)
  local item_takes_count, active_take, take_name, take_num, old_src, original_take

  item_takes_count = reaper.GetMediaItemNumTakes(item)
  
  if item_takes_count > 0 then
    
    active_take = reaper.GetActiveTake(item)
    
    if active_take then

      take_name = reaper.GetTakeName(active_take)
      take_num = string.match(take_name, "glue_reversible_render:(%d+)")
      
      if take_num then
        -- delete rendered midi take wav
        old_src = getItemWavSrc(item)
        
        os.remove(old_src)
        os.remove(old_src..'.reapeaks')

        -- delete this take
        reaper.SetMediaItemSelected(item, true)
        reaper.Main_OnCommand(40129, 0)
        
        -- reselect original active take
        original_take = reaper.GetTake(item, take_num)

        if original_take then
          reaper.SetActiveTake(original_take)
        end

        reaper.SetMediaItemSelected(item, false)

        cleanNullTakes(item)
      end
    end
  end
end



-- keys
local update_table = {}
-- numeric version
local iupdate_table = {}

-- create an update_table with a nicely ordered sequence and re-insert the items of each pool into temp tracks so they can be updated
function calculateDependentUpdates(pool_id, nesting_level)
  local track, dependent_pool, restored_items, item, container, glued_container, new_src, i, v, update_item, current_entry

  if not update_table then update_table = {} end
  if not nesting_level then nesting_level = 1 end

  r, dependents = getSetStateData(pool_id..":dependents")

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
        current_entry.pool_id = dependent_pool
        current_entry.nesting_level = nesting_level

        -- make track for this item's updates
        reaper.InsertTrackAtIndex(0, false)
        track = reaper.GetTrack(0, 0)

        deselectAllItems()

        -- restore items into newly made empty track
        item, container, restored_items = restoreItems(dependent_pool, track, 0, 0, 0, 0, true, true)

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


function restoreItems(pool_id, track, original_item_pos, original_item_offset, original_item_length, dont_restore_take, dont_offset)
  local r, stored_items, splits, restored_items, key, val, restored_item, container, item, return_item, left_most, pos_offset_from_first_instance

  -- get items stored during last glue
  r, stored_items = getSetStateData(pool_id)
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

      -- NB: "dont_restore_take" is set to true in calculateUpdates()
      if not dont_restore_take then
        restoreOriginalTake(restored_item) 
      end

      setItemImage(restored_item)

      -- get position of left-most pooled instance
      if not left_most then
        left_most = reaper.GetMediaItemInfo_Value(restored_item, "D_POSITION")
      else
        left_most = math.min(reaper.GetMediaItemInfo_Value(restored_item, "D_POSITION"), left_most)
      end

      -- populate new array
      restored_items[key] = restored_item
    end
  end

  pos_offset_from_first_instance = original_item_pos - left_most
  restored_items = adjustRestoredItems(pool_id, restored_items, original_item_pos, pos_offset_from_first_instance, original_item_offset, original_item_length, dont_offset)

  return return_item, container, restored_items
end


function adjustRestoredItems(pool_id, restored_items, original_item_pos, pos_offset_from_first_instance, original_item_offset, original_item_length, dont_offset)
  local i, this_item, is_empty_container

  for i, this_item in ipairs(restored_items) do

    if not dont_offset then
      offsetRestoredItemFromEarliestPooledInstance(this_item, pos_offset_from_first_instance)
    end

    is_empty_container = i == #restored_items

    reaper.SetMediaItemSelected(this_item, true)

    if is_empty_container then
      adjustEmptyContainer(original_item_pos, original_item_length, this_item)
    else
      adjustRestoredRegularItem(this_item, original_item_pos, original_item_offset, original_item_length)
    end
  end

  return restored_items
end


function offsetRestoredItemFromEarliestPooledInstance(item, pos_offset_from_first_instance)
  local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") + pos_offset_from_first_instance
  
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos)
end


function adjustEmptyContainer(original_item_pos, original_item_length, this_item)
  local new_pos, new_length

  new_pos = original_item_pos
  new_length = original_item_length

  reaper.SetMediaItemInfo_Value(this_item, "D_POSITION", new_pos)
  reaper.SetMediaItemInfo_Value(this_item, "D_LENGTH", new_length)
end


function adjustRestoredRegularItem(this_item, original_item_pos, original_item_offset, original_item_length)
  local this_item_pos, this_item_pos_delta_in_container, this_item_length, this_item_end_in_container, item_end_is_before_glued_container_pos, glued_container_pos_is_during_item_space, this_item_end, original_item_end, glued_container_length_cuts_off_item_end, item_pos_is_after_glued_container_end

  this_item_pos = reaper.GetMediaItemInfo_Value(this_item, "D_POSITION")
  this_item_pos_delta_in_container = this_item_pos - original_item_pos
  this_item_length = reaper.GetMediaItemInfo_Value(this_item, "D_LENGTH")
  this_item_end_in_container = this_item_pos_delta_in_container + this_item_length
  item_end_is_before_glued_container_pos = original_item_offset > this_item_pos_delta_in_container + this_item_length
  glued_container_pos_is_during_item_space = original_item_offset > this_item_pos_delta_in_container and original_item_offset < this_item_end_in_container
  this_item_end = original_item_pos + this_item_pos_delta_in_container + this_item_length - original_item_offset
  original_item_end = original_item_pos + original_item_length
  glued_container_length_cuts_off_item_end = this_item_end > original_item_end
  item_pos_is_after_glued_container_end = this_item_pos > original_item_end + original_item_offset

  if item_end_is_before_glued_container_pos or item_pos_is_after_glued_container_end then
    handleRestoredItemOutsideNewGlue(this_item, original_item_pos, original_item_offset, this_item_pos_delta_in_container)
  elseif glued_container_pos_is_during_item_space then
    handleResoredItemDuringNewGlueStart(this_item, original_item_pos, original_item_offset, this_item_pos_delta_in_container, this_item_length)
  elseif original_item_offset ~= 0 then
    handleOtherRestoredItem(this_item, this_item_pos, original_item_offset)
  end

  if glued_container_length_cuts_off_item_end then
    handleRestoredItemCutOffByNewGlueEnd(this_item, this_item_length, original_item_end, this_item_end)
  end
end


function handleRestoredItemOutsideNewGlue(this_item, original_item_pos, original_item_offset, this_item_pos_delta_in_container)
  local new_pos = original_item_pos - original_item_offset + this_item_pos_delta_in_container

  reaper.SetMediaItemInfo_Value(this_item, "D_POSITION", new_pos)
  reaper.SetMediaItemInfo_Value(this_item, "B_MUTE", 1)
end


function handleResoredItemDuringNewGlueStart(this_item, original_item_pos, original_item_offset, this_item_pos_delta_in_container, this_item_length)
  local this_item_take, new_pos, new_source_offset, new_length

    this_item_take = reaper.GetActiveTake(this_item)
    new_pos = original_item_pos
    new_source_offset = original_item_offset - this_item_pos_delta_in_container 
    new_length = this_item_length - new_source_offset

    reaper.SetMediaItemInfo_Value(this_item, "D_POSITION", new_pos)
    reaper.SetMediaItemTakeInfo_Value(this_item_take, "D_STARTOFFS", new_source_offset)
    reaper.SetMediaItemInfo_Value(this_item, "D_LENGTH", new_length)
end


function handleOtherRestoredItem(this_item,this_item_pos, original_item_offset)
  local new_pos = this_item_pos - original_item_offset

  reaper.SetMediaItemInfo_Value(this_item, "D_POSITION", new_pos)
end


function handleRestoredItemCutOffByNewGlueEnd(this_item, this_item_length, original_item_end, this_item_end)
  local new_length = this_item_length + (original_item_end - this_item_end)

  reaper.SetMediaItemInfo_Value(this_item, "D_LENGTH", new_length)
end


-- sort dependents update_table by how nested they are: convert update_table to a numeric array then sort by nesting value
function sortDependentUpdates()
  local i, v

  for i, v in pairs(update_table) do
    table.insert(iupdate_table, v)
  end
  
  table.sort( iupdate_table, function(a, b) return a.nesting_level < b.nesting_level end)
end



local position_changed

function setPositionDeltas(glued_container_source_offset, open_container_pos, original_item_pos, open_container_source_offset)
  glued_container_source_offset = tonumber(glued_container_source_offset)
  open_container_pos = tonumber(open_container_pos)
  original_item_pos = tonumber(original_item_pos)

  if not glued_instance_pos_delta_during_edit then
    glued_instance_pos_delta_during_edit = 0
  end

  if open_container_pos ~= original_item_pos then
    glued_instance_pos_delta_during_edit = round(open_container_pos - original_item_pos, 13)
  end
  
  if glued_instance_pos_delta_during_edit ~= 0 then
    position_changed = true
  end
end


function updateDependents(glued_container, first_selected_item, edited_pool_id, src, length, obey_time_selection)
  local dependent_glued_container, i, dependent, new_src

  -- update items with just one level of nesting now that they're exposed
  updatePooledItems(glued_container, edited_pool_id, src, length)

  -- loop thru dependents and update them in order
  for i, dependent in ipairs(iupdate_table) do
    deselectAllItems()
    reselect(dependent.restored_items)

    dependent_glued_container = createGluedContainer(dependent.track, first_selected_item, obey_time_selection, dependent.pool_id, dependent.container, true)
    new_src = getItemWavSrc(dependent_glued_container)

    -- update all instances of this pool, including any in other more deeply nested dependent pools which are exposed and waiting to be updated
    updatePooledItems(dependent_glued_container, dependent.pool_id, new_src, length, dependent.nesting_level)

    -- delete glue track
    reaper.DeleteTrack(dependent.track)
  end

  reaper.ClearPeakCache()
end


function updatePooledItems(glued_container, edited_pool_id, new_src, length, nesting_level)
  local all_items_count, this_container_name, items_in_glued_pool, i, this_item, j

  deselectAllItems()

  all_items_count = reaper.CountMediaItems(0)
  this_container_name = "gr:"..edited_pool_id
  items_in_glued_pool = {}
  j = 1

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(0, i)
    items_in_glued_pool[j] = getPooledItem(this_item, this_container_name, edited_pool_id)

    if items_in_glued_pool[j] then
      j = j + 1
    end
  end

  for i = 1, #items_in_glued_pool do
    this_item = items_in_glued_pool[i]

    updatePooledItem(#items_in_glued_pool, edited_pool_id, glued_container, this_item, new_src, length, nesting_level)
  end
end


function getPooledItem(this_item, this_container_name)
  local take_name, take, this_item_is_glued

  take_name, take = getSetItemName(this_item)
  this_item_is_glued = take_name and string.find(take_name, this_container_name)

  if this_item_is_glued then
    return this_item
  end
end



local position_change_response

function updatePooledItem(glued_pool_item_count, edited_pool_id, glued_container, this_item, new_src, length, nesting_level)
  local this_item_pool_id, item_is_in_edited_pool, take_name, take, this_is_reglued_container, this_item_is_nested, current_pos, glued_container_pos, offset_to_glued_container, new_pos, current_src

  this_item_pool_id = getItemPoolId(this_item)
  item_is_in_edited_pool = this_item_pool_id == edited_pool_id
  current_pos = reaper.GetMediaItemInfo_Value(this_item, "D_POSITION")
  this_is_reglued_container = glued_container == this_item

  if nesting_level then
    this_item_is_nested = nesting_level > 0

    if this_item_is_nested then
      glued_container_pos = reaper.GetMediaItemInfo_Value(glued_container, "D_POSITION")
      offset_to_glued_container = current_pos - glued_container_pos
      current_pos = current_pos + offset_to_glued_container
    end
  end

  if item_is_in_edited_pool then

    if glued_pool_item_count > 1 then
      
      if not position_change_response and position_changed == true then
        position_change_response = launchPropagatePositionDialog()
      end

      -- 6 == "YES"
      if position_change_response == 6 then
        new_pos = current_pos - glued_instance_pos_delta_during_edit

        reaper.SetMediaItemInfo_Value(this_item, "D_POSITION", new_pos)
      end
    end

    reaper.SetMediaItemInfo_Value(this_item, "D_LENGTH", length)
  end

  current_src = getItemWavSrc(this_item)

  if current_src ~= new_src then
    take_name, take = getSetItemName(this_item)

    reaper.BR_SetTakeSourceFromFile2(take, new_src, false, true)
  end
end


function launchPropagatePositionDialog()
    return reaper.ShowMessageBox("Do you want to propagate this change by adjusting all the other unnested container items' left edge positions from the same pool in the same way?", "The left edge location of the container item you're regluing has changed!", 4)
end


function reselect( items )
  local i, item

  for i,item in pairs(items) do
    reaper.SetMediaItemSelected(item, true)
  end
end


function initEditGluedContainer()
  local selected_item_count, glued_containers, empty_containers, noncontainers, this_pool_id

  selected_item_count = initAction("edit")

  if selected_item_count == false then return end

  glued_containers, empty_containers, noncontainers = getContainers(selected_item_count)

  if isNotSingleGluedContainer(#glued_containers) == true then return end

  this_pool_id = getItemPoolId(glued_containers[1])

  if getOtherPooledInstanceStatus(this_pool_id) == "open" then
    handleOtherOpenPooledInstance(item, edit_pool_id)

    return
  end
  
  selectDeselectItems(noncontainers, false)
  doEditGluedContainer()
end


function isNotSingleGluedContainer(glued_pool_id)
  local multiitem_result

  if glued_pool_id == 0 then
    reaper.ShowMessageBox(msg_change_selected_items, "Glue-Reversible Edit can only Edit previously glued container items." , 0)

    return true
  
  elseif glued_pool_id > 1 then
    multiitem_result = reaper.ShowMessageBox("Would you like to Edit the first selected container item (on the top track) only?", "Glue-Reversible Edit can only open one glued container item per action call.", 1)

    if multiitem_result == 2 then
      return true
    end
  
  else
    return false
  end
end


function getItemPoolId(item)
  return getPoolId(item, true)
end


-- not actually using "glued" at this time but leaving in case necessary later
function getOtherPooledInstanceStatus(edit_pool_id, testing_item)
  local all_items_count, i, item, item_pool_id, scroll_action_id

  all_items_count = reaper.CountMediaItems(0)

  for i = 0, all_items_count-1 do
    item = reaper.GetMediaItem(0, i)
    item_pool_id = getPoolId(item)

    if item_pool_id == edit_pool_id and getItemType(item) == "open" then
      return "open"
    elseif item_pool_id == edit_pool_id and testing_item ~= item and getItemType(item) == "glued" then
      return "glued"
    else
      return false
    end
  end
end


function handleOtherOpenPooledInstance(item, edit_pool_id)
  deselectAllItems()
  reaper.SetMediaItemSelected(item, true)
  scrollToSelectedItem()
  reaper.ShowMessageBox("Reglue the other open container item from pool "..tostring(edit_pool_id).." before trying to edit this glued container item. It will be selected and scrolled to now.", "Only one glued container item per pool can be Edited at a time.", 0)
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
    getSetGluedContainerData("open-"..pool_id, glued_container)
    processEditGluedContainer(glued_container, pool_id)
    cleanUpAction("MB Edit Glue-Reversible")
  end
end


function getSetGluedContainerData(pool_id, glued_container)
  local get_set, pool_key_prefix, source_offset_prefix, source_offset_key, length_prefix, length_key, pos_prefix, pos_key, retval, glued_container_source_offset, glued_container_length, glued_container_pos, glued_container_take

  get_set = glued_container
  pool_key_prefix = "pool-"
  source_offset_prefix = "_D_STARTOFFS"
  source_offset_key = pool_key_prefix..pool_id..source_offset_prefix
  length_prefix = "_D_LENGTH"
  length_key = pool_key_prefix..pool_id..length_prefix
  pos_prefix = "_D_POSITION"
  pos_key = pool_key_prefix..pool_id..pos_prefix

  -- get
  if not get_set then
    retval, glued_container_source_offset = getSetStateData(source_offset_key)
    retval, glued_container_length = getSetStateData(length_key)
    retval, glued_container_pos = getSetStateData(pos_key)

    return glued_container_source_offset, glued_container_length, glued_container_pos

  -- set
  else
    glued_container_take = reaper.GetActiveTake(glued_container)
    glued_container_source_offset = reaper.GetMediaItemTakeInfo_Value(glued_container_take, "D_STARTOFFS")
    glued_container_length = reaper.GetMediaItemInfo_Value(glued_container, "D_LENGTH")
    glued_container_pos = reaper.GetMediaItemInfo_Value(glued_container, "D_POSITION")

    getSetStateData(source_offset_key, glued_container_source_offset)
    getSetStateData(length_key, glued_container_length)
    getSetStateData(pos_key, glued_container_pos)
  end
end


function processEditGluedContainer(item, pool_id)
  local glued_container_source_offset, glued_container_length, original_item_state, original_item_pos, original_item_track, original_item_source_offset, original_item_length, _, container, original_item_state_key_guid, original_item_state_key

  original_item_state, original_item_pos, original_item_offset, original_item_length, original_item_track = getOriginalItemState(item)

  deselectAllItems()
  
  _, container, restored_items = restoreItems(pool_id, original_item_track, original_item_pos, original_item_offset, original_item_length)

  -- create a unique key for original state, and store it in container's name, space it out of sight then store it
  original_item_state_key_guid = reaper.genGuid()
  original_item_state_key = "original_state:"..pool_id..":"..original_item_state_key_guid
  
  getSetItemName(container, "                                                                                                      "..original_item_state_key, "add")
  getSetStateData(original_item_state_key, original_item_state)

  -- store preglue container position for reglue
  getSetStateData(pool_id.."-pos", original_item_pos)

  reaper.DeleteTrackMediaItem(original_item_track, item)
end


function getOriginalItemState(item)
  local original_item_state, original_item_pos, original_item_take, original_item_offset, original_item_length, original_item_track

  original_item_state = getSetObjectState(item)
  original_item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  original_item_take = reaper.GetActiveTake(item)
  original_item_offset = reaper.GetMediaItemTakeInfo_Value(original_item_take, "D_STARTOFFS")
  original_item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  original_item_track = reaper.GetMediaItemTrack(item)

  return original_item_state, original_item_pos, original_item_offset, original_item_length, original_item_track
end


function initSmartAction(obey_time_selection)
  local selected_item_count, pool_id, glue_reversible_action, glue_abort_dialog

  selected_item_count = doPreGlueChecks()
  if selected_item_count == false then return end

  prepareGlue("glue")
  
  -- refresh in case item selection changed
  selected_item_count = getSelectedItemsCount()
  if itemsAreSelected(selected_item_count) == false then return end

  -- find open item if present
  pool_id = getEmptyContainerFromSelection(selected_item_count)

  if emptyContainersAreInvalid(selected_item_count) == true then return end

  if doGlueOrEdit(selected_item_count, obey_time_selection) == false then 
    reaper.ShowMessageBox(msg_change_selected_items, "Toggle Glue/Unglue Reversible can't determine which script to run.", 0)
    setResetItemSelectionSet()

    return
  end

  reaper.Undo_EndBlock("Smart Glue/Unglue", -1)
end


function getSmartAction(selected_item_count)
  local glued_containers, empty_containers, noncontainer_count, singleGluedContainerIsSelected, noOpenContainersAreSelected, noNoncontainersAreSelected, gluedContainersAreSelected, noGluedContainersAreSelected, singleOpenContainerIsSelected

  glued_containers, empty_containers, noncontainer_count = getNumSelectedItemsByType(selected_item_count)
  noGluedContainersAreSelected = #glued_containers == 0
  singleGluedContainerIsSelected = #glued_containers == 1
  gluedContainersAreSelected = #glued_containers > 0
  noOpenContainersAreSelected = #empty_containers == 0
  singleOpenContainerIsSelected = #empty_containers == 1
  noNoncontainersAreSelected = noncontainer_count == 0
  noncontainersAreSelected = noncontainer_count > 0

  if singleGluedContainerIsSelected and noOpenContainersAreSelected and noNoncontainersAreSelected then
    return "edit"
  elseif singleOpenContainerIsSelected and gluedContainersAreSelected then
    return "glue/abort"
  elseif (noGluedContainersAreSelected and singleOpenContainerIsSelected) or (gluedContainersAreSelected and noOpenContainersAreSelected) or (noncontainersAreSelected and noGluedContainersAreSelected and noOpenContainersAreSelected) then
    return "glue"
  end
end


function getNumSelectedItemsByType(selected_item_count)
  local glued_containers, empty_containers, noncontainer_count = 0

  glued_containers, empty_containers = getContainers(selected_item_count)
  noncontainer_count = selected_item_count - #glued_containers - #empty_containers

  return glued_containers, empty_containers, noncontainer_count
end


function doGlueOrEdit(selected_item_count, obey_time_selection)
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