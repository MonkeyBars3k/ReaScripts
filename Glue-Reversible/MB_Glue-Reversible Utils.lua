-- @description MB_Glue-Reversible Utils: Codebase for MB_Glue-Reversible scripts' functionality
-- @author MonkeyBars
-- @version 1.53
-- @changelog Refactor nomenclature (https://github.com/MonkeyBars3k/ReaScripts/issues/115); Replace os.time() for id string with GenGUID() (https://github.com/MonkeyBars3k/ReaScripts/issues/109); Nested pooled containers no longer update (https://github.com/MonkeyBars3k/ReaScripts/issues/114)
-- @provides [nomain] .
--   gr-bg.png
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Code for Glue-Reversible scripts


-- dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")


local _global_script_prefix, _glued_container_name_prefix, _glue_undo_block_string, _edit_undo_block_string, _smart_glue_edit_undo_block_string, _sizing_region_label, _item_info_instance_pool_id_label, _item_info_parent_pool_id_label, _peak_data_filename_extension, _sizing_region_key_guid, _pool_data_key_prefix, _pool_data_key_suffix, _glued_container_pool_id_suffix, _restored_item_pool_id_suffix, _last_pool_id_suffix, _active_take_num_suffix, _glue_data_key_suffix, _edit_data_key_suffix, _position_data_key_suffix, _dependents_data_key_suffix, _item_preglue_state_suffix, _api_data_key, _api_project_region_guid_key, _api_name_key, _api_mute_key, _api_position_key, _api_length_key, _api_src_offset_key, _api_notes_key, _api_null_takes_val, _msg_change_selected_items, _data_storage_track, _master_track_tempo_env, _glued_instance_position_delta_while_open, _keyed_dependents, _numeric_dependents, _position_changed_during_edit, _position_change_response

_global_script_prefix = "GR_"
_glued_container_name_prefix = "gr:"
_glue_undo_block_string = "MB_Glue-Reversible"
_edit_undo_block_string = "MB_Edit-Glue-Reversible"
_smart_glue_edit_undo_block_string = "MB_Glue-Reversible-Smart-Glue-Edit"
_sizing_region_label = "Pool "
_item_info_instance_pool_id_label = _glue_undo_block_string..": Glued instance from pool #"
_item_info_parent_pool_id_label = _glue_undo_block_string..": Member of instance from pool #"
_peak_data_filename_extension = ".reapeaks"
_sizing_region_key_guid = "sizing-region-guid"
_pool_data_key_prefix = "pool-"
_pool_data_key_suffix = "-item-states"
_glued_container_pool_id_suffix = "instance-pool-id"
_restored_item_pool_id_suffix = "parent-pool-id"
_last_pool_id_suffix = "last-pool-id"
_active_take_num_suffix = "glue-reversible-render"
_glue_data_key_suffix = ":glue"
_edit_data_key_suffix = ":edit"
_position_data_key_suffix = ":pos"
_dependents_data_key_suffix = ":dependents"
_item_preglue_state_suffix = "preglue_state_chunk"
_api_data_key = "P_EXT:"
_api_project_region_guid_key = "MARKER_GUID:"
_api_name_key = "P_NAME"
_api_mute_key = "B_MUTE"
_api_position_key = "D_POSITION"
_api_length_key = "D_LENGTH"
_api_src_offset_key = "D_STARTOFFS"
_api_notes_key = "P_NOTES"
_api_null_takes_val = "TAKE NULL"
_msg_change_selected_items = "Change the items selected and try again."
_data_storage_track = reaper.GetMasterTrack(0)
  -- save state data in master track tempo envelope because changes get saved in undo points and it can't be deactivated (i.e., data removed)
_master_track_tempo_env = reaper.GetTrackEnvelopeByName(_data_storage_track, "Tempo map")
_glued_instance_position_delta_while_open = 0
_keyed_dependents = {}
_numeric_dependents = {}
_position_changed_during_edit = false
_position_change_response = nil



function initGlueReversible(obey_time_selection)
  local selected_item_count, glue_undo_block_string, pool_id, first_selected_item, first_selected_item_track, glued_container

  selected_item_count = initAction("glue")

  if selected_item_count == false then return end

  pool_id = getFirstPoolIdFromSelectedItems(selected_item_count)
  first_selected_item = getFirstSelectedItem()
  first_selected_item_track = reaper.GetMediaItemTrack(first_selected_item)

  if itemsOnMultipleTracksAreSelected(selected_item_count) == true or 
    containerSelectionIsInvalid(selected_item_count) == true or 
    pureMIDIItemsAreSelected(selected_item_count, first_selected_item_track) == true then
      return
  end

  glued_container = triggerGlueReversible(pool_id, first_selected_item, first_selected_item_track, obey_time_selection)
  
  exclusiveSelectItem(glued_container)
  cleanUpAction(_glue_undo_block_string)
end


function initAction(action)
  local selected_item_count

  selected_item_count = doPreGlueChecks()

  if selected_item_count == false then return false end

  prepareAction(action)
  
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
  local platform, proj_renderpath, win_platform_regex, is_win, win_absolute_path_regex, is_win_absolute_path, is_win_local_path, nix_absolute_path_regex, is_nix_absolute_path, is_other_local_path

  platform = reaper.GetOS()
  proj_renderpath = reaper.GetProjectPath(0)
  win_platform_regex = "^Win"
  is_win = string.match(platform, win_platform_regex)
  win_absolute_path_regex = "^%u%:\\"
  is_win_absolute_path = string.match(proj_renderpath, win_absolute_path_regex)
  is_win_local_path = is_win and not is_win_absolute_path
  nix_absolute_path_regex = "^/"
  is_nix_absolute_path = string.match(proj_renderpath, nix_absolute_path_regex)
  is_other_local_path = not is_win and not is_nix_absolute_path
  
  if is_win_local_path or is_other_local_path then
    reaper.ShowMessageBox("Set an absolute path in Project Settings > Media > Path or save your new project and try again.", "Glue-Reversible needs a valid file render path.", 0)
    
    return false

  else
    return true
  end
end


function getSelectedItemsCount()
  return reaper.CountSelectedMediaItems(0)
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


function prepareAction(action)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  if action == "glue" then
    setResetItemSelectionSet(true)
  end
end


function setResetItemSelectionSet(set_reset)
  local set, reset

  set = set_reset == true
  reset = not set_reset or set_reset == false

  if set then
    -- save selected item selection set to slot 10
    reaper.Main_OnCommand(41238, 0)

  elseif reset then
    -- reset item selection from selection set slot 10
    reaper.Main_OnCommand(41248, 0)
  end
end


function getFirstPoolIdFromSelectedItems(selected_item_count)
  local i, this_item, this_item_pool_id, this_item_has_stored_pool_id

  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(0, i)
    this_item_pool_id = getSetItemData(this_item, _restored_item_pool_id_suffix)
    this_item_has_stored_pool_id = this_item_pool_id and this_item_pool_id ~= ""
    
    if this_item_has_stored_pool_id then
      return this_item_pool_id
    end
  end

  return false
end


function getFirstSelectedItem()
  return reaper.GetSelectedMediaItem(0, 0)
end


function itemsOnMultipleTracksAreSelected(selected_item_count)
  local items_on_multiple_tracks_are_selected = detectSelectedItemsOnMultipleTracks(selected_item_count)

  if items_on_multiple_tracks_are_selected == true then 
      reaper.ShowMessageBox(_msg_change_selected_items, "Glue-Reversible and Edit container item only work on items on a single track.", 0)
      return true
  end
end


function detectSelectedItemsOnMultipleTracks(selected_item_count)
  local item_is_on_different_track_than_previous, i, this_item, this_item_track, prev_item_track

  item_is_on_different_track_than_previous = false

  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(0, i)
    this_item_track = reaper.GetMediaItemTrack(this_item)
    item_is_on_different_track_than_previous = this_item_track and prev_item_track and this_item_track ~= prev_item_track
  
    if item_is_on_different_track_than_previous == true then
      return item_is_on_different_track_than_previous
    end
    
    prev_item_track = this_item_track
  end
end


function containerSelectionIsInvalid(selected_item_count)
  local glued_containers, restored_items, multiple_instances_from_same_pool_are_selected, recursive_container_is_being_glued

  glued_containers, restored_items = getSelectedGlueReversibleItems(selected_item_count)
  multiple_instances_from_same_pool_are_selected = #restored_items > 1
  recursive_container_is_being_glued = recursiveContainerIsBeingGlued(glued_containers, restored_items) == true

  if multiple_instances_from_same_pool_are_selected or recursive_container_is_being_glued then
    reaper.ShowMessageBox(_msg_change_selected_items, "Glue-Reversible can only Reglue or Edit one container at a time.", 0)
    setResetItemSelectionSet()

    return true
  end
end


function getSelectedGlueReversibleItems(selected_item_count)
  local glued_containers, restored_items, i, this_item

  glued_containers = {}
  restored_items = {}

  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(0, i)

    if getItemType(this_item) == "glued" then
      table.insert(glued_containers, this_item)
    elseif getItemType(this_item) == "restored" then
      table.insert(restored_items, this_item)
    end
  end

  return glued_containers, restored_items
end


function getItemType(item)
  local glued_container_pool_id, is_glued_container, restored_item_pool_id, is_restored_item
  
  glued_container_pool_id = getSetItemData(item, _glued_container_pool_id_suffix)
  is_glued_container = glued_container_pool_id and glued_container_pool_id ~= ""
  restored_item_pool_id = getSetItemData(item, _restored_item_pool_id_suffix)
  is_restored_item = restored_item_pool_id and restored_item_pool_id ~= ""

  if is_glued_container then
    return "glued"
  elseif is_restored_item then
    return "restored"
  else
    return "noncontained"
  end
end


function recursiveContainerIsBeingGlued(glued_containers, restored_items)
  local i, this_glued_container, this_glued_container_instance_pool_id, j, this_restored_item, this_restored_item_parent_pool_id

  for i = 1, #glued_containers do
    this_glued_container = glued_containers[i]
    this_glued_container_instance_pool_id = getSetItemData(this_item, _glued_container_pool_id_suffix)

    for j = 1, #restored_items do
      this_restored_item = restored_items[i]
      this_restored_item_parent_pool_id = getSetItemData(this_restored_item, _glued_container_pool_id_suffix)
      
      if this_glued_container_instance_pool_id == this_restored_item_parent_pool_id then
        reaper.ShowMessageBox(_msg_change_selected_items, "Glue-Reversible can't glue a glued container item to an instance from the same pool being Edited – or you could destroy the universe!", 0)
        setResetItemSelectionSet()

        return true
      end
    end
  end
end


function getSetItemName(item, new_name, add_or_remove)
  local set, get, add, remove, item_has_no_takes, take, current_name

  set = new_name
  get = not new_name
  add = add_or_remove == true
  remove = add_or_remove == false

  item_has_no_takes = reaper.GetMediaItemNumTakes(item) < 1

  if item_has_no_takes then return end

  take = reaper.GetActiveTake(item)

  if take then
    current_name = reaper.GetTakeName(take)

    if set then

      if add then
        new_name = current_name.." "..new_name

      elseif remove then
        new_name = string.gsub(current_name, new_name, "")
      end

      reaper.GetSetMediaItemTakeInfo_String(take, _api_name_key, new_name, true)

      return new_name, take

    elseif get then
      return current_name, take
    end
  end
end


function pureMIDIItemsAreSelected(selected_item_count, first_selected_item_track)
  local track_has_no_virtual_instrument, i, this_item, midi_item_is_selected

  track_has_no_virtual_instrument = reaper.TrackFX_GetInstrument(first_selected_item_track) == -1

  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(0, i)
    midi_item_is_selected = midiItemIsSelected(this_item)

    if midi_item_is_selected then
      break
    end
  end

  if midi_item_is_selected and track_has_no_virtual_instrument then
    reaper.ShowMessageBox("Add a virtual instrument to render audio into the glued container or try a different item selection.", "Glue-Reversible can't glue pure MIDI without a virtual instrument.", 0)
    return true
  end
end


function midiItemIsSelected(item)
  local active_take, active_take_is_midi

  active_take = reaper.GetActiveTake(item)
  active_take_is_midi = reaper.TakeIsMIDI(active_take)

  if active_take and active_take_is_midi then
    return true
  else
    return false
  end
end


function triggerGlueReversible(pool_id, first_selected_item, first_selected_item_track, obey_time_selection)
  local glued_container

  if pool_id then
    glued_container = handleReglue(first_selected_item_track, first_selected_item, pool_id, obey_time_selection)
  else
    glued_container = handleGlue(first_selected_item_track, first_selected_item, nil, obey_time_selection)
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


function handleGlue(first_selected_item_track, first_selected_item, active_pool_id, obey_time_selection, ignore_dependencies)
  local this_is_new_glue, this_is_reglue, selected_item_count, user_selected_items, first_user_selected_item_name, user_selected_item_states, pool_dependencies_table, new_pool_id, glued_container, glued_container_length, glued_container_positions
  
  this_is_new_glue = not active_pool_id
  this_is_reglue = active_pool_id
  selected_item_count = getSelectedItemsCount()
  user_selected_items, first_user_selected_item_name = getUserSelectedItems(selected_item_count)

  deselectAllItems()

  if this_is_new_glue then
    active_pool_id = handlePoolId()
  elseif this_is_reglue then
    sizing_region_idx, sizing_region_position, sizing_region_length = getSetSizingRegion(active_pool_id)
  end

  setUserSelectedItemsData(user_selected_items, active_pool_id)
  
  user_selected_item_states, pool_dependencies_table, new_pool_id = createUserSelectedItemStates(selected_item_count, user_selected_items)
  
  selectDeselectItems(user_selected_items, true)
  
  glued_container = glueSelectedItemsIntoContainer(obey_time_selection, user_selected_items, selected_item_count, active_pool_id, first_user_selected_item_name)
  glued_container_length, glued_container_position = setGluedContainerParams(glued_container, active_pool_id)
  glue_data_key_label = pool_id.._glue_data_key_suffix

  getSetGluedContainerParams(glue_data_key_label, glued_container)
  setGluedContainerData(active_pool_id, glued_container)
  updatePoolStates(user_selected_item_states, active_pool_id, new_pool_id, pool_dependencies_table, ignore_dependencies)

  return glued_container, glued_container_position, glued_container_length
end


function handlePoolId()
  local retval, last_pool_id, active_pool_id
  
  retval, last_pool_id = getSetProjectData(_last_pool_id_suffix)
  active_pool_id = incrementPoolId(last_pool_id)

  getSetProjectData(_last_pool_id_suffix, active_pool_id)

  return active_pool_id
end


function incrementPoolId(last_pool_id)
  local this_is_first_glue_in_project, active_pool_id

  this_is_first_glue_in_project = not last_pool_id or last_pool_id == ""

  if this_is_first_glue_in_project then
    active_pool_id = 1

  else
    last_pool_id = tonumber(last_pool_id)
    active_pool_id = math.floor(last_pool_id + 1)
  end

  return active_pool_id
end


function getSetProjectData(key, val)
  local set, get, get_or_set_state_data, data_param_key, retval, state_data_val

  set = val
  get = not val

  if set then
    get_or_set_state_data = true

  elseif get then
    val = ""
    get_or_set_state_data = false
  end

  data_param_key = _api_data_key.._global_script_prefix..key
  retval, state_data_val = reaper.GetSetMediaTrackInfo_String(_data_storage_track, data_param_key, val, get_or_set_state_data)

  return retval, state_data_val
end


function getUserSelectedItems(selected_item_count)
  local user_selected_items, i, this_item, first_user_selected_item_name

  user_selected_items = {}
  
  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(0, i)

    table.insert(user_selected_items, this_item)

    if not first_user_selected_item_name then
      first_user_selected_item_name = getSetItemName(this_item)
    end
  end

  return user_selected_items, first_user_selected_item_name
end


function createUserSelectedItemStates(selected_item_count, user_selected_items)
  local user_selected_item_count, user_selected_item_states, user_selected_items_separator, pool_dependencies_table, i, this_item, is_last_user_selected_item, new_pool_id

  user_selected_item_count = getTableSize(user_selected_items)
  user_selected_item_states = ""
  pool_dependencies_table = {}
  user_selected_items_separator = "|||"

  for i = 1, user_selected_item_count do
    this_item = user_selected_items[i]
    is_last_user_selected_item = i == user_selected_item_count

    convertMidiItemToAudio(this_item)
    
    if is_last_user_selected_item then
      user_selected_item_states = user_selected_item_states..getSetItemStateChunk(this_item)
    else
      user_selected_item_states = user_selected_item_states..getSetItemStateChunk(this_item)..user_selected_items_separator
    end
    
    pool_id = getSetItemData(this_item, _restored_item_pool_id_suffix)

    if pool_id then
      pool_dependencies_table[pool_id] = new_pool_id
    end
  end

  return user_selected_item_states, pool_dependencies_table, new_pool_id
end


function convertMidiItemToAudio(item)
  local item_takes_count, active_take, this_take_is_midi, active_take_num, data_key_label, take_num_data_val

  item_takes_count = reaper.GetMediaItemNumTakes(item)

  if item_takes_count > 0 then
    active_take = reaper.GetActiveTake(item)
    this_take_is_midi = active_take and reaper.TakeIsMIDI(active_take)

    if this_take_is_midi then
      active_take_num = getTakeNum(active_take)

      reaper.SetMediaItemSelected(item, 1)
      renderFxToItem()
      
      active_take = setLastTakeActive(item, item_takes_count)
      -- take_num_data_val = math.floor(active_take_num)

      getSetTakeData(active_take, _active_take_num_suffix, active_take_num)
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


function getSetTakeData(take, data_key_label, data_val)
  local get, set, data_param_key, retval
    
  get = not data_val
  set = data_val
  data_param_key = _api_data_key.._global_script_prefix..data_key_label

  if get then
    retval, data_val = reaper.GetMediaItemTakeInfo_Value(take, data_param_key)

    return data_val

  elseif set then
    reaper.SetMediaItemTakeInfo_Value(take, data_param_key, data_val, true)
  end
end


function cleanNullTakes(item, force)
  local item_state = getSetItemStateChunk(item)

  if string.find(item_state, _api_null_takes_val) or force then
    item_state = string.gsub(state, _api_null_takes_val, "")

    getSetItemStateChunk(item, item_state)
  end
end


function setUserSelectedItemsData(items, pool_id)
  local i, this_item
  
  for i = 1, #items do
    this_item = items[i]

    getSetItemData(this_item, _restored_item_pool_id_suffix, pool_id)

local retval, state = reaper.GetItemStateChunk(this_item, "")
log(state)
  end
end


function setGluedContainerName(item, item_name_ending)
  local take, item_name_prefix, new_item_name

  take = reaper.GetActiveTake(item)
  new_item_name = _glued_container_name_prefix..item_name_ending

  reaper.GetSetMediaItemTakeInfo_String(take, _api_name_key, new_item_name, true)
end


function selectDeselectItems(items, select_deselect)
  local i, count

  count = getTableSize(items)

  for i = 1, count do
    reaper.SetMediaItemSelected(items[i], select_deselect)
  end
end


function prepareSizingRegion(items, pool_id)
  local i, this_item, first_item, last_item, first_item_position, last_item_position, last_item_length, all_items_length, sizing_region_guid

  first_item = items[1]
  last_item = items[#items]
  first_item_position = reaper.GetMediaItemInfo_Value(first_item, _api_position_key)
  last_item_position = reaper.GetMediaItemInfo_Value(last_item, _api_position_key)
  last_item_length = reaper.GetMediaItemInfo_Value(last_item, _api_length_key)
  first_item_position, all_items_length = getSelectedItemsParams(first_item_position, last_item_position, last_item_length)
  sizing_region_idx, sizing_region_guid = getSetSizingRegion(pool_id, first_item_position, all_items_length)

  return sizing_region_guid
end


function getSelectedItemsParams(first_item_position, last_item_position, last_item_length)
  local all_items_end, all_items_length

  first_item_position = tonumber(first_item_position)
  last_item_position = tonumber(last_item_position)
  last_item_length = tonumber(last_item_length)
  all_items_end = last_item_position + last_item_length
  all_items_length = all_items_end - first_item_position

  return first_item_position, all_items_length
end


function getSetSizingRegion(sizing_region_guid_or_pool_id, sizing_region_position, sizing_region_length)
  local get, set, sizing_region_guid, sizing_region_idx, pool_id

  get = not sizing_region_position or not sizing_region_length
  set = sizing_region_position and sizing_region_length

  if get then
    sizing_region_guid = sizing_region_guid_or_pool_id
    sizing_region_guid, sizing_region_position, sizing_region_length = getSizingRegionParams(sizing_region_guid_or_pool_id)

    return sizing_region_position, sizing_region_length

  elseif set then
    pool_id = sizing_region_guid_or_pool_id
    sizing_region_idx = createSizingRegion(sizing_region_guid_or_pool_id, sizing_region_position, sizing_region_length)

    getSetProjectData(_sizing_region_key_guid, sizing_region_guid)

    return sizing_region_guid
  end
end


function getSizingRegionParams(sizing_region_guid)
  local retval, marker_count, region_count, i, this_region_guid, sizing_region_idx, is_region, sizing_region_position, sizing_region_end, sizing_region_length

  retval, marker_count, region_count = reaper.CountProjectMarkers(0)

  if not sizing_region_guid then
    sizing_region_guid = getSetProjectData(_sizing_region_key_guid)
  end

  for i = 1, region_count do
    retval, this_region_guid = reaper.GetSetProjectInfo_String(0, _api_project_region_guid_key..i, "", false)

    if this_region_guid == sizing_region_guid then
      sizing_region_idx = i

      break
    end
  end
  
  retval, is_region, sizing_region_position, sizing_region_end = reaper.EnumProjectMarkers3(0, sizing_region_idx)
  sizing_region_position = tonumber(sizing_region_position)
  sizing_region_end = tonumber(sizing_region_end)
  sizing_region_length = sizing_region_end - sizing_region_position

  return sizing_region_guid, sizing_region_position, sizing_region_length, sizing_region_idx
end


function createSizingRegion(pool_id, sizing_region_position, sizing_region_length)
  local sizing_region_end, sizing_region_name, sizing_region_color, sizing_region_idx

  sizing_region_end = sizing_region_position + sizing_region_length
  sizing_region_name = _global_script_prefix.._sizing_region_label..pool_id
  sizing_region_color = reaper.ColorToNative(255, 255, 255)|0x1000000
  sizing_region_idx = reaper.AddProjectMarker2(0, true, sizing_region_position, sizing_region_end, sizing_region_name, 0, sizing_region_color)

  return sizing_region_idx
end


function glueSelectedItemsIntoContainer(obey_time_selection, user_selected_items, selected_item_count, pool_id, first_user_selected_item_name)
  local glued_container, glued_container_init_name

  glueSelectedItems(obey_time_selection)

  glued_container = getFirstSelectedItem()
  glued_container_init_name = handleAddtionalItemCountLabel(user_selected_items, selected_item_count, pool_id, first_user_selected_item_name)
  
  setGluedContainerName(glued_container, glued_container_init_name, true)

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
  local user_selected_item_count, multiple_user_selected_items, other_user_selected_items_count, item_name_addl_count_str, glued_container_init_name, double_quotation_mark

  user_selected_item_count = getTableSize(user_selected_items)
  multiple_user_selected_items = user_selected_item_count > 1
  other_user_selected_items_count = user_selected_item_count - 1
  double_quotation_mark = "\u{0022}"

  if multiple_user_selected_items then
    item_name_addl_count_str = " +"..other_user_selected_items_count.. " more"
  else
    item_name_addl_count_str = ""
  end

  glued_container_init_name = pool_id.." ["..double_quotation_mark..first_user_selected_item_name..double_quotation_mark..item_name_addl_count_str.."]"

  return glued_container_init_name
end


function setGluedContainerParams(glued_container, pool_id)
  local new_glued_container_length, new_glued_container_position, position_key_prefix, position_key_suffix, position_key, retval, first_selected_item_position, position_comparison_values_are_valid

  new_glued_container_length = reaper.GetMediaItemInfo_Value(glued_container, _api_length_key)
  new_glued_container_position = reaper.GetMediaItemInfo_Value(glued_container, _api_position_key)
  position_key = _pool_data_key_prefix..pool_id.._position_data_key_suffix
  retval, first_selected_item_position = getSetProjectData(position_key)
  position_comparison_values_are_valid = new_glued_container_position and new_glued_container_position ~= "" and first_selected_item_position and first_selected_item_position ~= ""

  if position_comparison_values_are_valid then
    new_glued_container_position = tonumber(new_glued_container_position)
    first_selected_item_position = tonumber(first_selected_item_position)
    _glued_instance_position_delta_while_open = round((new_glued_container_position - first_selected_item_position), 13)
  end

  addRemoveItemImage(glued_container, true)

  return new_glued_container_length, new_glued_container_position
end


function addRemoveItemImage(item, add_or_remove)
  local script_path, img_path, add, remove

  add = add_or_remove == true
  remove = add_or_remove == false
  script_path = string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$")

  if add then
    img_path = script_path.."gr-bg.png"
  elseif remove then
    img_path = ""
  end

  reaper.BR_SetMediaItemImageResource(item, img_path, 1)
end


function updatePoolStates(user_selected_item_states, active_pool_id, new_pool_id, pool_dependencies_table, ignore_dependencies)
  local pool_item_states_key = _global_script_prefix.._pool_data_key_prefix..active_pool_id.._pool_data_key_suffix
  
  getSetProjectData(pool_item_states_key, user_selected_item_states)

  if not ignore_dependencies then
    updatePooledCopies(active_pool_id, new_pool_id, pool_dependencies_table)
  end
end


function updatePooledCopies(active_pool_id, new_pool_id, pool_dependencies_table)
  local retval, old_dependencies, dependencies, separator, dependent, ref, dependecies_have_changed, dependency

  retval, old_dependencies = getSetProjectData(active_pool_id..":dependencies")
  
  if retval == false then
    old_dependencies = ""
  end

  dependencies = ""
  separator = "|"
  dependent = separator..active_pool_id..separator

  -- store a reference to this pool for all the nested pools so if any get updated, they can check and update this pool
  for new_pool_id, ref in pairs(pool_dependencies_table) do
    dependencies, old_dependencies = storePoolReference(new_pool_id, dependent, dependencies, old_dependencies)
  end

  -- store this pool's dependencies list
  getSetProjectData(active_pool_id..":dependencies", dependencies)

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
  key = new_pool_id.._dependents_data_key_suffix
  
  -- see if nested pool already has a list of dependents
  r, dependents = getSetProjectData(key)
  
  if r == false then
    dependents = "" 
  end

  -- if this pool isn't already in list, add it
  if not string.find(dependents, dependent) then
    dependents = dependents..dependent
    getSetProjectData(key, dependents)
  end

  -- now store of these pools' dependencies
  dependency = "|"..new_pool_id.."|"
  dependencies = dependencies..dependency

  -- remove this dependency from old_dependencies string
  old_dependencies = string.gsub(old_dependencies, dependency, "")

  return dependencies, old_dependencies
end


function removePoolFromDependents(dependency, dependent)
  local key, retval, dependents

  key = dependency.._dependents_data_key_suffix
  retval, dependents = getSetProjectData(key)

  if retval == true and string.find(dependents, dependent) then
    dependents = string.gsub(dependents, dependent, "")

    getSetProjectData(key, dependents)
  end
end


function handleReglue(first_selected_item_track, first_selected_item, pool_id, obey_time_selection)
  local glue_data_key_label, glued_container_source_offset, glued_container, glued_container_position, original_item_length, sizing_region_guid, sizing_region_position, sizing_region_length, sizing_region_idx, new_src
  
  glue_data_key_label = pool_id.._glue_data_key_suffix
  glued_container_source_offset = getSetGluedContainerParams(glue_data_key_label)
  glued_container, glued_container_position, original_item_length, sizing_region_guid = handleGlue(first_selected_item_track, first_selected_item, obey_time_selection, pool_id)
  sizing_region_guid, sizing_region_position, sizing_region_length, sizing_region_idx = getSizingRegionParams(sizing_region_guid)
  new_src = getItemAudioSrcFileName(glued_container)
  glued_container = reglueContainer(glued_container, pool_id, new_src, glued_container_position, sizing_region_length)
  
  reaper.DeleteProjectMarker(0, sizing_region_idx, true)
  calculateDependentUpdates(pool_id)
  sortDependentUpdates()
  setRegluePositionDeltas(glued_container_source_offset, glued_container_position, sizing_region_position, sizing_region_length)
  updateDependents(glued_container, first_selected_item, pool_id, new_src, sizing_region_length, obey_time_selection)

  return glued_container
end


function getSetGluedContainerParams(pool_label, glued_container)
  local get, set, source_offset_key, length_key, position_key, retval, glued_container_source_offset, glued_container_length, glued_container_position, glued_container_take

  get = not glued_container
  set = glued_container
  source_offset_key = _pool_data_key_prefix..pool_label.._api_src_offset_key.._glue_data_key_suffix
  length_key = _pool_data_key_prefix..pool_label.._api_length_key.._glue_data_key_suffix
  position_key = _pool_data_key_prefix..pool_label.._api_position_key.._glue_data_key_suffix

  if get then
    retval, glued_container_source_offset = getSetProjectData(source_offset_key)
    retval, glued_container_length = getSetProjectData(length_key)
    retval, glued_container_position = getSetProjectData(position_key)

    return glued_container_source_offset, glued_container_length, glued_container_position

  elseif set then
    glued_container_take = reaper.GetActiveTake(glued_container)
    glued_container_source_offset = reaper.GetMediaItemTakeInfo_Value(glued_container_take, _api_src_offset_key)
    glued_container_length = reaper.GetMediaItemInfo_Value(glued_container, _api_length_key)
    glued_container_position = reaper.GetMediaItemInfo_Value(glued_container, _api_position_key)

    getSetProjectData(source_offset_key, glued_container_source_offset)
    getSetProjectData(length_key, glued_container_length)
    getSetProjectData(position_key, glued_container_position)
  end
end


function setGluedContainerData(active_pool_id, glued_container)
  getSetItemData(glued_container, _glued_container_pool_id_suffix, active_pool_id)
end


function reglueContainer(glued_container, pool_id, new_src, glued_container_position, length)
  local retval, original_state

  retval, original_state = getSetProjectData(pool_id.._item_preglue_state_suffix)

  if retval == true and original_state then
    getSetItemStateChunk(glued_container, original_state)
    updateItemSrc(glued_container)
    updateItemValues(glued_container, glued_container_position, length)
  end

  return glued_container
end


function getSetItemStateChunk(item, state)
  local get, set, retval

  get = not state
  set = state

  if get then
    retval, state = reaper.GetItemStateChunk(item, "", true)

    return state

  elseif set then
    reaper.SetItemStateChunk(item, state, true)
  end
end


function updateItemSrc(glued_container)
  local take

  take = reaper.GetActiveTake(glued_container)

  reaper.BR_SetTakeSourceFromFile2(take, new_src, false, true)
end


function updateItemValues(glued_container, position, length)
  reaper.SetMediaItemInfo_Value(glued_container, _api_position_key, position)
  reaper.SetMediaItemInfo_Value(glued_container, _api_length_key, length)
end


function getItemAudioSrcFileName(item, take)
  local source, filename, filename_is_valid

  take = take or reaper.GetActiveTake(item)
  source = reaper.GetMediaItemTake_Source(take)
  filename = reaper.GetMediaSourceFileName(source)
  filename_is_valid = string.len(filename) > 0

  if filename_is_valid then
    return filename
  end
end


function restoreOriginalTake(item)
  local item_takes_count, active_take, take_num, original_take

  item_takes_count = reaper.GetMediaItemNumTakes(item)
  
  if item_takes_count > 0 then
    active_take = reaper.GetActiveTake(item)
    
    if active_take then
      take_num = getSetTakeData(active_take, _active_take_num_suffix)
      
      if take_num then
        deleteItemAudioSrcFile(item)
        reaper.SetMediaItemSelected(item, true)
        deleteActiveTakeFromItems()
        
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


function deleteItemAudioSrcFile(item)
  local old_src = getItemAudioSrcFileName(item)

  os.remove(old_src)
  os.remove(old_src.._peak_data_filename_extension)
end


function deleteActiveTakeFromItems()
  reaper.Main_OnCommand(40129, 0)
end


-- populate _keyed_dependents with a nicely ordered sequence and reinsert the items of each pool into temp tracks so they can be updated
function calculateDependentUpdates(pool_id, nesting_level)
  local retval, dependents, track, dependent_pool, restored_items, item, container, glued_container, new_src, i, v, update_item, current_entry

  dependents_data_key_label = _dependents_data_key_suffix
  retval, dependents = getSetProjectData(pool_id..dependents_data_key_label)

  if not _keyed_dependents then
    _keyed_dependents = {}
  end
  
  if not nesting_level then
    nesting_level = 1
  end

  if retval == true and string.len(dependents) > 0 then
    for dependent_pool in string.gmatch(dependents, "%d+") do 
      dependent_pool = math.floor(tonumber(dependent_pool))

      -- check if an entry for this pool already exists
      if _keyed_dependents[dependent_pool] then
        -- store how deeply nested this item is
        _keyed_dependents[dependent_pool].nesting_level = math.max(nesting_level, _keyed_dependents[dependent_pool].nesting_level)

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
        restored_items = restorePreviouslyGluedItems(dependent_pool, track, 0, 0, 0, true, true)

        -- store references to temp track and items
        current_entry.track = track
        current_entry.item = item
        current_entry.container = container
        current_entry.restored_items = restored_items

        -- store this item in _keyed_dependents
        _keyed_dependents[dependent_pool] = current_entry

        -- check if this pool also has dependents
        calculateDependentUpdates(dependent_pool, nesting_level + 1)
      end
    end
  end
end


function restorePreviouslyGluedItems(pool_id, track, prev_stored_item_position, prev_stored_item_offset, prev_stored_item_length, dont_restore_take, dont_offset)
  local pool_item_states_key, retval, stored_items, separator, stored_item_splits, restored_items, key, val, this_restored_item, earliest_pooled_instance_item_position, current_position_offset_from_first_instance

  pool_item_states_key = _global_script_prefix.._pool_data_key_prefix..pool_id.._pool_data_key_suffix
  retval, stored_items = getSetProjectData(pool_item_states_key)

  separator = "|||"
  stored_item_splits = string.split(stored_items, separator)
  restored_items = {}

  for key, val in ipairs(stored_item_splits) do
    if val then
      this_restored_item = reaper.AddMediaItemToTrack(track)

      getSetItemStateChunk(this_restored_item, val)
local retval, state = reaper.GetItemStateChunk(this_restored_item, "")
log(state)
      if not dont_restore_take then
        restoreOriginalTake(this_restored_item)
      end

      this_restored_item_position = reaper.GetMediaItemInfo_Value(this_restored_item, _api_position_key)

      addRemoveItemImage(this_restored_item, true)

      if not earliest_pooled_instance_item_position then
        earliest_pooled_instance_item_position = this_restored_item_position
      else
        earliest_pooled_instance_item_position = math.min(this_restored_item_position, earliest_pooled_instance_item_position)
      end

      restored_items[key] = this_restored_item
    end
  end

  prev_stored_item_position = tonumber(prev_stored_item_position)
  earliest_pooled_instance_item_position = tonumber(earliest_pooled_instance_item_position)
  current_position_offset_from_first_instance = prev_stored_item_position - earliest_pooled_instance_item_position
  restored_items = adjustRestoredItems(restored_items, prev_stored_item_position, current_position_offset_from_first_instance, prev_stored_item_offset, prev_stored_item_length, dont_offset)

  return restored_items
end


function adjustRestoredItems(restored_items, prev_stored_item_position, current_position_offset_from_first_instance, prev_stored_item_offset, prev_stored_item_length, dont_offset)
  local i, this_item

  for i, this_item in ipairs(restored_items) do
    if not dont_offset then
      offsetRestoredItemFromEarliestPooledInstance(this_item, current_position_offset_from_first_instance)
    end

    reaper.SetMediaItemSelected(this_item, true)
    adjustRestoredItem(this_item, prev_stored_item_position, prev_stored_item_offset, prev_stored_item_length)
  end

  return restored_items
end


function offsetRestoredItemFromEarliestPooledInstance(item, current_position_offset_from_first_instance)
  local old_position, new_position

  old_position = reaper.GetMediaItemInfo_Value(item, _api_position_key)
  old_position = tonumber(old_position)
  new_position = old_position + current_position_offset_from_first_instance
  
  reaper.SetMediaItemInfo_Value(item, _api_position_key, new_position)
end


function adjustRestoredItem(this_item, original_item_position, original_item_offset, original_item_length)
  local this_item_position, this_item_position_delta_in_container, this_item_length, this_item_end_in_container, item_end_is_before_glued_container_position, glued_container_position_is_during_item_space, this_item_end, original_item_end, glued_container_length_cuts_off_item_end, item_position_is_after_glued_container_end

  this_item_position = reaper.GetMediaItemInfo_Value(this_item, _api_position_key)
  this_item_position_delta_in_container = this_item_position - original_item_position
  this_item_length = reaper.GetMediaItemInfo_Value(this_item, _api_length_key)
  this_item_end_in_container = this_item_position_delta_in_container + this_item_length
  item_end_is_before_glued_container_position = original_item_offset > this_item_position_delta_in_container + this_item_length
  glued_container_position_is_during_item_space = original_item_offset > this_item_position_delta_in_container and original_item_offset < this_item_end_in_container
  this_item_end = original_item_position + this_item_position_delta_in_container + this_item_length - original_item_offset
  original_item_end = original_item_position + original_item_length
  glued_container_length_cuts_off_item_end = this_item_end > original_item_end
  item_position_is_after_glued_container_end = this_item_position > original_item_end + original_item_offset

  if item_end_is_before_glued_container_position or item_position_is_after_glued_container_end then
    handleRestoredItemOutsideNewGlue(this_item, original_item_position, original_item_offset, this_item_position_delta_in_container)

  elseif glued_container_position_is_during_item_space then
    handleResoredItemDuringNewGlueStart(this_item, original_item_position, original_item_offset, this_item_position_delta_in_container, this_item_length)
  
  elseif original_item_offset ~= 0 then
    handleOtherRestoredItem(this_item, this_item_position, original_item_offset)
  end

  if glued_container_length_cuts_off_item_end then
    handleRestoredItemCutOffByNewGlueEnd(this_item, this_item_length, original_item_end, this_item_end)
  end
end


function handleRestoredItemOutsideNewGlue(this_item, original_item_position, original_item_offset, this_item_position_delta_in_container)
  local new_position = original_item_position - original_item_offset + this_item_position_delta_in_container

  reaper.SetMediaItemInfo_Value(this_item, _api_position_key, new_position)
  reaper.SetMediaItemInfo_Value(this_item, _api_mute_key, 1)
end


function handleResoredItemDuringNewGlueStart(this_item, original_item_position, original_item_offset, this_item_position_delta_in_container, this_item_length)
  local this_item_take, new_position, new_source_offset, new_length

    this_item_take = reaper.GetActiveTake(this_item)
    new_position = original_item_position
    new_source_offset = original_item_offset - this_item_position_delta_in_container 
    new_length = this_item_length - new_source_offset

    reaper.SetMediaItemInfo_Value(this_item, _api_position_key, new_position)
    reaper.SetMediaItemTakeInfo_Value(this_item_take, _api_src_offset_key, new_source_offset)
    reaper.SetMediaItemInfo_Value(this_item, _api_length_key, new_length)
end


function handleOtherRestoredItem(this_item,this_item_position, original_item_offset)
  local new_position = this_item_position - original_item_offset

  reaper.SetMediaItemInfo_Value(this_item, _api_position_key, new_position)
end


function handleRestoredItemCutOffByNewGlueEnd(this_item, this_item_length, original_item_end, this_item_end)
  local new_length = this_item_length + (original_item_end - this_item_end)

  reaper.SetMediaItemInfo_Value(this_item, _api_length_key, new_length)
end


-- sort dependents _keyed_dependents by how nested they are: convert _keyed_dependents to a numeric array then sort by nesting value
function sortDependentUpdates()
  local i, v

  for i, v in pairs(_keyed_dependents) do
    table.insert(_numeric_dependents, v)
  end
  
  table.sort( _numeric_dependents, function(a, b) return a.nesting_level < b.nesting_level end)
end


function setRegluePositionDeltas(glued_container_source_offset, glued_container_position, sizing_region_position, length)
  glued_container_source_offset = tonumber(glued_container_source_offset)
  glued_container_position = tonumber(glued_container_position)

  if not _glued_instance_position_delta_while_open then
    _glued_instance_position_delta_while_open = 0
  end

  if sizing_region_position ~= glued_container_position then
    _glued_instance_position_delta_while_open = round(sizing_region_position - glued_container_position, 13)
  end
  
  if _glued_instance_position_delta_while_open ~= 0 then
    _position_changed_during_edit = true
  end
end


function updateDependents(glued_container, first_selected_item, edited_pool_id, src, length, obey_time_selection)
  local i, dependent

  -- items unnested & nested only 1 level deep
  updatePooledItems(glued_container, edited_pool_id, src, length)

  for i, dependent in ipairs(_numeric_dependents) do
    handlePooledItemsNested2PlusLevels(dependent, first_selected_item, obey_time_selection, length)
  end

  reaper.ClearPeakCache()
end


function updatePooledItems(glued_container, edited_pool_id, new_src, length, nesting_level)
  local all_items_count, this_container_name, items_in_glued_pool, i, this_item, glued_container_name_prefix, items_in_glued_pool_count

  deselectAllItems()

  all_items_count = reaper.CountMediaItems(0)
  this_container_name = _glued_container_name_prefix..edited_pool_id
  items_in_glued_pool = {}

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(0, i)
    glued_pool_item = getPooledItem(this_item, edited_pool_id)

    if glued_pool_item then
      table.insert(items_in_glued_pool, glued_pool_item)
    end
  end

  items_in_glued_pool_count = #items_in_glued_pool

  for i = 1, items_in_glued_pool_count do
    this_item = items_in_glued_pool[i]

    updatePooledItem(items_in_glued_pool_count, edited_pool_id, glued_container, this_item, new_src, length, nesting_level)
  end
end


function getPooledItem(this_item, edited_pool_id)
  local glued_container_pool_id, is_glued_container

  glued_container_pool_id = getSetItemData(this_item, _glued_container_pool_id_suffix)
  is_glued_container = glued_container_pool_id and glued_container_pool_id == edited_pool_id

  if is_glued_container then
    return this_item
  end
end


function updatePooledItem(glued_pool_item_count, edited_pool_id, glued_container, this_item, new_src, length, nesting_level)
  local this_item_pool_id, item_is_in_edited_pool, current_position, this_is_reglued_container, multiple_glued_pooled_items, this_item_is_nested, glued_container_position, offset_to_glued_container, user_wants_position_change, new_position, take_name, take, current_src

  this_item_pool_id = getSetItemData(this_item, _restored_item_pool_id_suffix)
  item_is_in_edited_pool = this_item_pool_id == edited_pool_id
  current_position = reaper.GetMediaItemInfo_Value(this_item, _api_position_key)
  this_is_reglued_container = glued_container == this_item
  multiple_glued_pooled_items = glued_pool_item_count > 1

  if nesting_level then
    this_item_is_nested = nesting_level > 0

    if this_item_is_nested then
      glued_container_position = reaper.GetMediaItemInfo_Value(glued_container, _api_position_key)
      offset_to_glued_container = current_position - glued_container_position
      current_position = current_position + offset_to_glued_container
    end
  end

  if item_is_in_edited_pool then

    if multiple_glued_pooled_items then
      
      if not _position_change_response and _position_changed_during_edit == true then
        _position_change_response = launchPropagatePositionDialog()
      end

      user_wants_position_change = _position_change_response == 6

      if user_wants_position_change then
        new_position = current_position - _glued_instance_position_delta_while_open

        reaper.SetMediaItemInfo_Value(this_item, _api_position_key, new_position)
      end
    end

    reaper.SetMediaItemInfo_Value(this_item, _api_length_key, length)
  end

  current_src = getItemAudioSrcFileName(this_item)

  if current_src ~= new_src then
    take_name, take = getSetItemName(this_item)

    reaper.BR_SetTakeSourceFromFile2(take, new_src, false, true)
  end
end


function launchPropagatePositionDialog()
  return reaper.ShowMessageBox("Do you want to propagate this change by adjusting all the other unnested container items' left edge positions from the same pool in the same way?", "The left edge location of the container item you're regluing has changed!", 4)
end


function handlePooledItemsNested2PlusLevels(dependent, first_selected_item, obey_time_selection, length)
  local dependent_glued_container, new_src

  deselectAllItems()
  selectDeselectItems(dependent.restored_items, true)

  dependent_glued_container = handleGlue(dependent.track, first_selected_item, obey_time_selection, dependent.pool_id, true)
  new_src = getItemAudioSrcFileName(dependent_glued_container)

  updatePooledItems(dependent_glued_container, dependent.pool_id, new_src, length, dependent.nesting_level)
  reaper.DeleteTrack(dependent.track)
end


function initEditGluedContainer()
  local selected_item_count, glued_containers, this_pool_id

  selected_item_count = initAction("edit")

  if selected_item_count == false then return end

  glued_containers = getSelectedGlueReversibleItems(selected_item_count)

  if isNotSingleGluedContainer(#glued_containers) == true then return end

  this_pool_id = getSetItemData(glued_containers[1], _glued_container_pool_id_suffix)

  if otherPooledInstanceIsOpen(this_pool_id) then
    handleOtherOpenPooledInstance(item, this_pool_id)

    return
  end
  
  handleEdit()
end


function isNotSingleGluedContainer(glued_containers_count)
  local multiitem_result, user_wants_to_edit_1st_container

  if glued_containers_count == 0 then
    reaper.ShowMessageBox(_msg_change_selected_items, "Glue-Reversible Edit can only Edit previously glued container items." , 0)

    return true
  
  elseif glued_containers_count > 1 then
    multiitem_result = reaper.ShowMessageBox("Would you like to Edit the first selected container item (on the top track) only?", "Glue-Reversible Edit can only open one glued container item per action call.", 1)
    user_wants_to_edit_1st_container = multiitem_result == 2

    if user_wants_to_edit_1st_container then
      return true
    end
  
  else
    return false
  end
end


function otherPooledInstanceIsOpen(edit_pool_id)
  local all_items_count, i, this_item, restored_item_pool_id

  all_items_count = reaper.CountMediaItems(0)

  for i = 0, all_items_count-1 do
    item = reaper.GetMediaItem(0, i)
    restored_item_pool_id = getSetItemData(item, _restored_item_pool_id_suffix)
    if restored_item_pool_id == edit_pool_id then
      return true
    end
  end
end


function handleOtherOpenPooledInstance(item, edit_pool_id)
  deselectAllItems()
  reaper.SetMediaItemSelected(item, true)
  scrollToSelectedItem()

  edit_pool_id = tostring(edit_pool_id)

  reaper.ShowMessageBox("Reglue the other open instance from pool "..edit_pool_id.." before trying to edit this glued container item. It will be selected and scrolled to now.", "Only one glued container item per pool can be Edited at a time.", 0)
end


function scrollToSelectedItem()
  scroll_action_id = reaper.NamedCommandLookup("_S&M_SCROLL_ITEM")

  reaper.Main_OnCommand(scroll_action_id, 0)
end


function handleEdit()
  local glued_container, pool_id, edit_data_key_label

  glued_container = getFirstSelectedItem()
  pool_id = getSetItemData(glued_container, _glued_container_pool_id_suffix)
  edit_data_key_label = pool_id.._edit_data_key_suffix

  getSetGluedContainerParams(edit_data_key_label, glued_container)
  processEditGluedContainer(glued_container, pool_id)
  cleanUpAction(_edit_undo_block_string)
end


function processEditGluedContainer(glued_container, pool_id)
  local preglue_item_state, preglue_item_position, preglue_item_offset, preglue_item_length, preglue_item_track, restored_items

  preglue_item_state, preglue_item_position, preglue_item_offset, preglue_item_length, preglue_item_track = getPreGlueItemState(glued_container)

  deselectAllItems()

  restored_items = restorePreviouslyGluedItems(pool_id, preglue_item_track, preglue_item_position, preglue_item_offset, preglue_item_length)
  
  prepareSizingRegion(restored_items, pool_id)
  getSetProjectData(pool_id.._item_preglue_state_suffix, preglue_item_state)
  getSetProjectData(pool_id.._position_data_key_suffix, preglue_item_position)

  reaper.DeleteTrackMediaItem(preglue_item_track, glued_container)
end


function getPreGlueItemState(item)
  local preglue_item_state, preglue_item_position, preglue_item_take, preglue_item_offset, preglue_item_length, preglue_item_track

  preglue_item_state = getSetItemStateChunk(item)
  preglue_item_position = reaper.GetMediaItemInfo_Value(item, _api_position_key)
  preglue_item_take = reaper.GetActiveTake(item)
  preglue_item_offset = reaper.GetMediaItemTakeInfo_Value(preglue_item_take, _api_src_offset_key)
  preglue_item_length = reaper.GetMediaItemInfo_Value(item, _api_length_key)
  preglue_item_track = reaper.GetMediaItemTrack(item)

  return preglue_item_state, preglue_item_position, preglue_item_offset, preglue_item_length, preglue_item_track
end


function getSetItemData(item, key_suffix, val)
  local get, set, data_param_key, retval

  get = not val
  set = val
  data_param_key = _api_data_key.._global_script_prefix..key_suffix

  if get then
    retval, val = reaper.GetSetMediaItemInfo_String(item, data_param_key, "", false)

    return val

  elseif set then
    reaper.GetSetMediaItemInfo_String(item, data_param_key, val, true)
  end
end


function initSmartAction(obey_time_selection)
  local selected_item_count, pool_id
  
  selected_item_count = doPreGlueChecks()
  
  if selected_item_count == false then return end

  prepareAction("glue")
  
  -- refresh in case item selection changed
  selected_item_count = getSelectedItemsCount()
  
  if itemsAreSelected(selected_item_count) == false then return end

  -- find open item if present
  pool_id = getFirstPoolIdFromSelectedItems(selected_item_count)

  if containerSelectionIsInvalid(selected_item_count) == true then return end

  if triggerAction(selected_item_count, obey_time_selection) == false then 
    reaper.ShowMessageBox(_msg_change_selected_items, "Glue-Reversible Smart Glue/Edit can't determine which script to run.", 0)
    setResetItemSelectionSet()

    return
  end

  reaper.Undo_EndBlock(_smart_glue_edit_undo_block_string, -1)
end


function getSmartAction(selected_item_count)
  local glued_containers, restored_items, glued_containers_count, no_glued_containers_are_selected, single_glued_container_is_selected, glued_containers_are_selected, restored_item_count, no_open_instances_are_selected, single_open_instance_is_selected, no_restored_items_are_selected, restored_items_are_selected

  glued_containers, restored_items = getSelectedGlueReversibleItems(selected_item_count)
  glued_containers_count = #glued_containers
  no_glued_containers_are_selected = glued_containers_count == 0
  single_glued_container_is_selected = glued_containers_count == 1
  glued_containers_are_selected = glued_containers_count > 0
  restored_item_count = #restored_items
  no_open_instances_are_selected = restored_item_count == 0
  single_open_instance_is_selected =restored_item_count == 1
  no_restored_items_are_selected = restored_item_count == 0
  restored_items_are_selected = restored_item_count > 0

  if single_glued_container_is_selected and no_open_instances_are_selected and no_restored_items_are_selected then
    return "edit"
  
  elseif single_open_instance_is_selected and glued_containers_are_selected then
    return "glue/abort"
  
  elseif (no_glued_containers_are_selected and single_open_instance_is_selected) or (glued_containers_are_selected and no_open_instances_are_selected) or (restored_items_are_selected and noglued_containers_are_selected and no_open_instances_are_selected) then
    return "glue"
  end
end


function triggerAction(selected_item_count, obey_time_selection)
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