-- @description MB_Glue-Reversible Utils: Codebase for MB_Glue-Reversible scripts' functionality
-- @author MonkeyBars
-- @version 1.53
-- @changelog Rename item breaks Glue-Reversible [9] (https://github.com/MonkeyBars3k/ReaScripts/issues/3); Don't store original item state in item name (https://github.com/MonkeyBars3k/ReaScripts/issues/73); Open container item is poor UX (https://github.com/MonkeyBars3k/ReaScripts/issues/75); Update code for item state from faststrings to Reaper state chunks (https://github.com/MonkeyBars3k/ReaScripts/issues/89); Refactor nomenclature (https://github.com/MonkeyBars3k/ReaScripts/issues/115); Replace os.time() for id string with GenGUID() (https://github.com/MonkeyBars3k/ReaScripts/issues/109); Nested pooled containers no longer update (https://github.com/MonkeyBars3k/ReaScripts/issues/114); Change SNM_GetSetObjectState to state chunk functions (https://github.com/MonkeyBars3k/ReaScripts/issues/120); Switch take data number to item data take GUID (https://github.com/MonkeyBars3k/ReaScripts/issues/121); Refactor: Bundle up related variables into tables (https://github.com/MonkeyBars3k/ReaScripts/issues/129); Abstract out (de)serialization (https://github.com/MonkeyBars3k/ReaScripts/issues/132); Remove extra loop in adjustRestoredItems() (https://github.com/MonkeyBars3k/ReaScripts/issues/134); Extrapolate deserialized data handling (https://github.com/MonkeyBars3k/ReaScripts/issues/137)
-- @provides [nomain] .
--   serpent.lua
--   gr-bg.png
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Code for Glue-Reversible scripts


-- dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")
local serpent = require("serpent")


local _script_path, _item_bg_img_path, _peak_data_filename_extension, _scroll_action_id, _glue_undo_block_string, _edit_undo_block_string, _smart_glue_edit_undo_block_string, _sizing_region_label, _sizing_region_color, _api_data_key, _api_project_region_guid_key_prefix, _api_name_key, _api_mute_key, _api_position_key, _api_length_key, _api_src_offset_key, _api_notes_key, _api_takenumber_key, _api_null_takes_val, _global_script_prefix, _glued_container_name_prefix, _sizing_region_guid_key_suffix, _pool_key_prefix, _pool_item_states_key_suffix, _glued_container_pool_id_key_suffix, _restored_item_pool_id_key_suffix, _last_pool_id_key_suffix, _preglue_active_take_guid_key_suffix, _glue_data_key_suffix, _edit_data_key_suffix, _glued_container_params_suffix, _container_post_glue_params_key_suffix, _dependents_data_key_suffix, _item_preglue_state_suffix, _item_offset_to_container_position_key_suffix, _postglue_action_step, _preedit_action_step, _msg_change_selected_items, _data_storage_track, _glued_instance_position_delta_while_open, _keyed_dependents, _numeric_dependents, _position_changed_during_edit, _position_change_response, _earliest_pooled_instance_item_position

_script_path = string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$")
_item_bg_img_path = _script_path .. "gr-bg.png"
_peak_data_filename_extension = ".reapeaks"
_scroll_action_id = reaper.NamedCommandLookup("_S&M_SCROLL_ITEM")
_glue_undo_block_string = "MB_Glue-Reversible"
_edit_undo_block_string = "MB_Glue-Reversible-Edit"
_smart_glue_edit_undo_block_string = "MB_Glue-Reversible-Smart-Glue-Edit"
_sizing_region_label = "GR SIZING: DO NOT DELETE – for Pool #"
_sizing_region_color = reaper.ColorToNative(255, 255, 255)|0x1000000
_api_data_key = "P_EXT:"
_api_project_region_guid_key_prefix = "MARKER_GUID:"
_api_name_key = "P_NAME"
_api_mute_key = "B_MUTE"
_api_position_key = "D_POSITION"
_api_length_key = "D_LENGTH"
_api_src_offset_key = "D_STARTOFFS"
_api_notes_key = "P_NOTES"
_api_takenumber_key = "IP_TAKENUMBER"
_api_null_takes_val = "TAKE NULL"
_global_script_prefix = "GR_"
_glued_container_name_prefix = "gr:"
_sizing_region_guid_key_prefix = "pool-"
_sizing_region_guid_key_suffix = ":sizing-region-guid"
_pool_key_prefix = "pool-"
_pool_item_states_key_suffix = ":contained-item-states"
_glued_container_pool_id_key_suffix = "instance-pool-id"
_restored_item_pool_id_key_suffix = "parent-pool-id"
_last_pool_id_key_suffix = "last-pool-id"
_preglue_active_take_guid_key_suffix = "preglue-active-take-guid"
_glue_data_key_suffix = ":glue"
_edit_data_key_suffix = ":pre-edit"
_glued_container_params_suffix = "_glued-container-params"
_container_post_glue_params_key_suffix = ":post-glue-container-params"
_dependents_data_key_suffix = ":dependents"
_item_preglue_state_suffix = "preglue-state-chunk"
_item_offset_to_container_position_key_suffix = "glued-container-offset"
_postglue_action_step = "postglue"
_preedit_action_step = "preedit"
_msg_change_selected_items = "Change the items selected and try again."
_data_storage_track = reaper.GetMasterTrack(0)
_glued_instance_position_delta_while_open = 0
_keyed_dependents = {}
_numeric_dependents = {}
_position_changed_during_edit = false
_position_change_response = nil
_earliest_pooled_instance_item_position = nil



function initGlue(obey_time_selection)
  local selected_item_count, glue_undo_block_string, restored_items_pool_id, first_selected_item, first_selected_item_track, glued_container

  selected_item_count = initAction("glue")

  if selected_item_count == false then return end

  restored_items_pool_id = getFirstPoolIdFromSelectedItems(selected_item_count)
  first_selected_item = getFirstSelectedItem()
  first_selected_item_track = reaper.GetMediaItemTrack(first_selected_item)

  if itemsOnMultipleTracksAreSelected(selected_item_count) == true or 
    containerSelectionIsInvalid(selected_item_count) == true or 
    pureMIDIItemsAreSelected(selected_item_count, first_selected_item_track) == true then
      return
  end

  glued_container = triggerGlue(restored_items_pool_id, first_selected_item, first_selected_item_track, obey_time_selection)
  
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
    this_item_pool_id = storeRetrieveItemData(this_item, _restored_item_pool_id_key_suffix)
    this_item_has_stored_pool_id = this_item_pool_id and this_item_pool_id ~= ""

    if this_item_has_stored_pool_id then
      return this_item_pool_id
    end
  end

  return false
end


function storeRetrieveItemData(item, key_suffix, val)
  local retrieve, store, data_param_key, retval

  retrieve = not val
  store = val
  data_param_key = _api_data_key .. _global_script_prefix .. key_suffix

  if retrieve then

    retval, val = reaper.GetSetMediaItemInfo_String(item, data_param_key, "", false)

    return val

  elseif store then
    reaper.GetSetMediaItemInfo_String(item, data_param_key, val, true)
  end
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
  local glued_containers, restored_items, last_restored_item_parent_pool_id, i, this_restored_item, this_restored_item_parent_pool_id, multiple_instances_from_same_pool_are_selected, recursive_container_is_being_glued

  glued_containers, restored_items = getSelectedGlueReversibleItems(selected_item_count)
  multiple_instances_from_same_pool_are_selected = false

  for i = 1,#restored_items do
    this_restored_item = restored_items[i]
    this_restored_item_parent_pool_id = storeRetrieveItemData(this_restored_item, _restored_item_pool_id_key_suffix)
    this_is_2nd_or_later_restored_item_with_pool_id = last_restored_item_parent_pool_id and last_restored_item_parent_pool_id ~= ""

    if this_is_2nd_or_later_restored_item_with_pool_id then

      if this_restored_item_parent_pool_id ~= last_restored_item_parent_pool_id then
        multiple_instances_from_same_pool_are_selected = true

        break
      end

    else
      last_restored_item_parent_pool_id = this_restored_item_parent_pool_id
    end
  end
  
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
  
  glued_container_pool_id = storeRetrieveItemData(item, _glued_container_pool_id_key_suffix)
  is_glued_container = glued_container_pool_id and glued_container_pool_id ~= ""
  restored_item_pool_id = storeRetrieveItemData(item, _restored_item_pool_id_key_suffix)
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
    this_glued_container_instance_pool_id = storeRetrieveItemData(this_glued_container, _glued_container_pool_id_key_suffix)

    for j = 1, #restored_items do
      this_restored_item = restored_items[i]
      this_restored_item_parent_pool_id = storeRetrieveItemData(this_restored_item, _glued_container_pool_id_key_suffix)
      
      if this_glued_container_instance_pool_id == this_restored_item_parent_pool_id then
        reaper.ShowMessageBox(_msg_change_selected_items, "Glue-Reversible can't glue a glued container item to an instance from the same pool being Edited – or you could destroy the universe!", 0)
        setResetItemSelectionSet()

        return true
      end
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


function triggerGlue(restored_items_pool_id, first_selected_item, first_selected_item_track, obey_time_selection)
  local glued_container

  if restored_items_pool_id then
    glued_container = handleReglue(first_selected_item_track, first_selected_item, restored_items_pool_id, obey_time_selection)
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


function handleGlue(first_selected_item_track, first_selected_item, pool_id, sizing_region_guid, obey_time_selection, ignore_dependencies)
  local this_is_new_glue, this_is_reglue, selected_item_count, user_selected_items, first_user_selected_item_name, user_selected_item_states, pool_dependencies_table, sizing_region_params, glued_container
  
  this_is_new_glue = not pool_id
  this_is_reglue = pool_id
  selected_item_count = getSelectedItemsCount()
  user_selected_items, first_user_selected_item_name = getUserSelectedItems(selected_item_count)

  deselectAllItems()

  if this_is_new_glue then
    pool_id = handlePoolId()
  elseif this_is_reglue then
    sizing_region_params = setUpReglue(sizing_region_guid, first_selected_item_track)
  end

  setUserSelectedItemsData(user_selected_items, pool_id, sizing_region_params)
  
  user_selected_item_states, pool_dependencies_table = createUserSelectedItemStates(selected_item_count, user_selected_items, pool_id)

  storeGluedItemStates(pool_id, user_selected_item_states)
  selectDeselectItems(user_selected_items, true)

  glued_container = glueSelectedItemsIntoContainer(obey_time_selection)
  glued_container_init_name = handleAddtionalItemCountLabel(user_selected_items, pool_id, first_user_selected_item_name)
  
  handlePostGlueContainer(glued_container, glued_container_init_name, pool_id, this_is_reglue)

  if not ignore_dependencies then
    updatePooledCopies(pool_id, pool_dependencies_table)
  end

  return glued_container, sizing_region_params
end


function handlePoolId()
  local retval, last_pool_id, new_pool_id
  
  retval, last_pool_id = storeRetrieveProjectData(_last_pool_id_key_suffix)
  new_pool_id = incrementPoolId(last_pool_id)

  storeRetrieveProjectData(_last_pool_id_key_suffix, new_pool_id)

  return new_pool_id
end


function incrementPoolId(last_pool_id)
  local this_is_first_glue_in_project, new_pool_id

  this_is_first_glue_in_project = not last_pool_id or last_pool_id == ""

  if this_is_first_glue_in_project then
    new_pool_id = 1

  else
    last_pool_id = tonumber(last_pool_id)
    new_pool_id = math.floor(last_pool_id + 1)
  end

  return new_pool_id
end


function storeRetrieveProjectData(key, val)
  local store, retrieve, store_or_retrieve_state_data, data_param_key, retval, state_data_val

  retrieve = not val
  store = val

  if retrieve then
    val = ""
    store_or_retrieve_state_data = false

  elseif store then
    store_or_retrieve_state_data = true
  end

  data_param_key = _api_data_key .. _global_script_prefix .. key
  retval, state_data_val = reaper.GetSetMediaTrackInfo_String(_data_storage_track, data_param_key, val, store_or_retrieve_state_data)

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
        new_name = current_name .. " " .. new_name

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


function createUserSelectedItemStates(selected_item_count, user_selected_items, pool_id)
  local user_selected_item_count, user_selected_item_states, user_selected_items_separator, pool_dependencies_table, i, this_item, is_last_user_selected_item

  user_selected_item_count = getTableSize(user_selected_items)
  user_selected_item_states = {}
  pool_dependencies_table = {}

  for i = 1, user_selected_item_count do
    this_item = user_selected_items[i]

    convertMidiItemToAudio(this_item)

    this_item_state = getSetItemStateChunk(this_item)

    table.insert(user_selected_item_states, this_item_state)

    if pool_id then
      pool_dependencies_table[pool_id] = pool_id
    end
  end

  return user_selected_item_states, pool_dependencies_table, pool_id
end


function convertMidiItemToAudio(item)
  local item_takes_count, active_take, this_take_is_midi, data_key_label, retval, active_take_guid

  item_takes_count = reaper.GetMediaItemNumTakes(item)

  if item_takes_count > 0 then
    active_take = reaper.GetActiveTake(item)
    this_take_is_midi = active_take and reaper.TakeIsMIDI(active_take)

    if this_take_is_midi then
      reaper.SetMediaItemSelected(item, true)
      renderFxToItem()
      
      active_take = reaper.GetActiveTake(item)
      retval, active_take_guid = reaper.GetSetMediaItemTakeInfo_String(active_take, "GUID", "", false)

      storeRetrieveItemData(item, _preglue_active_take_guid_key_suffix, active_take_guid)
      reaper.SetMediaItemSelected(item, 0)
      cleanNullTakes(item)
    end
  end
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
  local item_state = getSetItemStateChunk(item)

  if string.find(item_state, _api_null_takes_val) or force then
    item_state = string.gsub(state, _api_null_takes_val, "")

    getSetItemStateChunk(item, item_state)
  end
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


function setUserSelectedItemsData(items, pool_id, sizing_region_params)
  local is_new_glue, is_reglue, first_item_position, i, this_item, this_is_1st_item, this_item_position, offset_position, this_item_offset_to_glued_container_position

  is_new_glue = not sizing_region_params
  is_reglue = sizing_region_params

  for i = 1, #items do
    this_item = items[i]
    this_is_1st_item = i == 1
    this_item_position = reaper.GetMediaItemInfo_Value(this_item, _api_position_key)

    storeRetrieveItemData(this_item, _restored_item_pool_id_key_suffix, pool_id)

    if is_new_glue then

      if this_is_1st_item then
        first_item_position = this_item_position
      end

      offset_position = first_item_position

    elseif is_reglue then
      offset_position = sizing_region_params.position
    end
    
    this_item_offset_to_glued_container_position = this_item_position - offset_position

    storeRetrieveItemData(this_item, _item_offset_to_container_position_key_suffix, this_item_offset_to_glued_container_position)
  end
end


function setGluedContainerName(item, item_name_ending)
  local take, item_name_prefix, new_item_name

  take = reaper.GetActiveTake(item)
  new_item_name = _glued_container_name_prefix .. item_name_ending

  reaper.GetSetMediaItemTakeInfo_String(take, _api_name_key, new_item_name, true)
end


function selectDeselectItems(items, select_deselect)
  local i, count

  count = getTableSize(items)

  for i = 1, count do
    reaper.SetMediaItemSelected(items[i], select_deselect)
  end
end


function setUpReglue(sizing_region_guid, active_track)
  local sizing_region_params = getSetSizingRegion(sizing_region_guid)

  reaper.DeleteProjectMarker(0, sizing_region_params.idx, true)

  makeEmptySpacingItem(active_track, sizing_region_params)

  return sizing_region_params
end


function makeEmptySpacingItem(active_track, sizing_region_params)
  local empty_spacing_item = reaper.AddMediaItemToTrack(active_track)

  reaper.SetMediaItemPosition(empty_spacing_item, sizing_region_params.position, false)
  reaper.SetMediaItemLength(empty_spacing_item, sizing_region_params.length, false)
  reaper.SetMediaItemSelected(empty_spacing_item, true)
end


function getSetSizingRegion(sizing_region_guid_or_pool_id, params)
  local get, set, sizing_region_guid, pool_id, sizing_region_guid_key

  get = not params
  set = params

  if get then
    sizing_region_guid = sizing_region_guid_or_pool_id
    params = getSizingRegionParams(sizing_region_guid)

    return params

  elseif set then
    pool_id = sizing_region_guid_or_pool_id
    sizing_region_idx, sizing_region_guid = addSizingRegion(pool_id, params)
    sizing_region_guid_key = _sizing_region_guid_key_prefix .. pool_id .. _sizing_region_guid_key_suffix

    storeRetrieveProjectData(sizing_region_guid_key, sizing_region_guid)

    return sizing_region_guid
  end
end


function getSizingRegionParams(sizing_region_guid)
  local retval, marker_count, region_count, i, this_region_guid, sizing_region_params, is_region

  retval, marker_count, region_count = reaper.CountProjectMarkers(0)

  for i = 0, region_count-1 do
    retval, this_region_guid = reaper.GetSetProjectInfo_String(0, _api_project_region_guid_key_prefix .. i, "", false)
    this_region_belongs_to_active_pool = this_region_guid == sizing_region_guid

    if this_region_belongs_to_active_pool then
      sizing_region_params = {
        ["idx"] = i
      }
      retval, is_region, sizing_region_params.position, sizing_region_params.end_point = reaper.EnumProjectMarkers3(0, sizing_region_params.idx)
      sizing_region_params.length = sizing_region_params.end_point - sizing_region_params.position

      return sizing_region_params
    end
  end
end


function addSizingRegion(pool_id, params)
  local sizing_region_name, sizing_region_idx, retval, sizing_region_guid

  params.end_point = params.position + params.length
  sizing_region_name = _sizing_region_label .. pool_id
  sizing_region_idx = reaper.AddProjectMarker2(0, true, params.position, params.end_point, sizing_region_name, 0, _sizing_region_color)
  retval, sizing_region_guid = reaper.GetSetProjectInfo_String(0, _api_project_region_guid_key_prefix .. sizing_region_idx, "", false)

  return sizing_region_idx, sizing_region_guid
end


function glueSelectedItemsIntoContainer(obey_time_selection)
  local glued_container, this_is_reglue

  glueSelectedItems(obey_time_selection)

  glued_container = getFirstSelectedItem()

  return glued_container
end


function glueSelectedItems(obey_time_selection)
  if obey_time_selection == true then
    reaper.Main_OnCommand(41588, 0)
  else
    reaper.Main_OnCommand(40362, 0)
  end
end


function handleAddtionalItemCountLabel(user_selected_items, pool_id, first_user_selected_item_name)
  local user_selected_item_count, multiple_user_selected_items, other_user_selected_items_count, item_name_addl_count_str, glued_container_init_name, double_quotation_mark

  user_selected_item_count = getTableSize(user_selected_items)
  multiple_user_selected_items = user_selected_item_count > 1
  other_user_selected_items_count = user_selected_item_count - 1
  double_quotation_mark = "\u{0022}"

  if multiple_user_selected_items then
    item_name_addl_count_str = " +" .. other_user_selected_items_count ..  " more"
  else
    item_name_addl_count_str = ""
  end

  glued_container_init_name = pool_id .. " [" .. double_quotation_mark .. first_user_selected_item_name .. double_quotation_mark .. item_name_addl_count_str .. "]"

  return glued_container_init_name
end


function handlePostGlueContainer(glued_container, glued_container_init_name, pool_id, this_is_reglue)
  setGluedContainerName(glued_container, glued_container_init_name, true)

  if this_is_reglue then
    setGluedContainerPositionChangeWhileOpen(glued_container, pool_id)
  end

  addRemoveItemImage(glued_container, true)
  storeRetrieveGluedContainerParams(pool_id, _postglue_action_step, glued_container)
  storeRetrieveItemData(glued_container, _glued_container_pool_id_key_suffix, pool_id)
end


function setGluedContainerPositionChangeWhileOpen(glued_container, pool_id)
  local glued_container_preedit_params, glued_container_postglue_params, position_comparison_values_are_valid

  glued_container_preedit_params = storeRetrieveGluedContainerParams(pool_id, _preedit_action_step)
  glued_container_postglue_params = storeRetrieveGluedContainerParams(pool_id, _postglue_action_step)
  position_comparison_values_are_valid = glued_container_preedit_params.position and glued_container_preedit_params.position ~= "" and glued_container_postglue_params.position and glued_container_postglue_params.position ~= ""

  if position_comparison_values_are_valid then
    glued_container_preedit_params.position = tonumber(glued_container_preedit_params.position)
    glued_container_postglue_params.position = tonumber(glued_container_postglue_params.position)
    _glued_instance_position_delta_while_open = glued_container_preedit_params.position - glued_container_preedit_params.position
    _glued_instance_position_delta_while_open = round(_glued_instance_position_delta_while_open, 13)
  end
end


function addRemoveItemImage(item, add_or_remove)
  local img_path, add, remove

  add = add_or_remove == true
  remove = add_or_remove == false

  if add then
    img_path = _item_bg_img_path
  elseif remove then
    img_path = ""
  end

  reaper.BR_SetMediaItemImageResource(item, img_path, 1)
end


function storeRetrieveGluedContainerParams(pool_id, action_step, glued_container)
  local retrieve, store, connector, glued_container_params_key, retval, glued_container_params

  retrieve = not glued_container
  store = glued_container
  connector = ":"
  glued_container_params_key = _pool_key_prefix .. pool_id .. connector .. action_step .. _glued_container_params_suffix

  if retrieve then
    retval, glued_container_params = storeRetrieveProjectData(glued_container_params_key)
    retval, glued_container_params = serpent.load(glued_container_params)
    glued_container_params.track = reaper.BR_GetMediaTrackByGUID(0, glued_container_params.track_guid)

    return glued_container_params

  elseif store then
    glued_container_params = getItemParams(glued_container)
    glued_container_params = serpent.dump(glued_container_params)

    storeRetrieveProjectData(glued_container_params_key, glued_container_params)
  end
end


function getItemParams(item)
  local track, retval, track_guid, active_take, item_params

  track = reaper.GetMediaItemTrack(item)
  retval, track_guid = reaper.GetSetMediaTrackInfo_String(track, "GUID", "", false)
  active_take = reaper.GetActiveTake(item)
  item_params = {
    ["state"] = getSetItemStateChunk(item),
    ["track_guid"] = track_guid,
    ["position"] = reaper.GetMediaItemInfo_Value(item, _api_position_key),
    ["source_offset"] = reaper.GetMediaItemTakeInfo_Value(active_take, _api_src_offset_key),
    ["length"] = reaper.GetMediaItemInfo_Value(item, _api_length_key)
  }

  return item_params
end


function storeGluedItemStates(pool_id, user_selected_item_states)
  local pool_item_states_key

  pool_item_states_key = _pool_key_prefix .. pool_id .. _pool_item_states_key_suffix
  user_selected_item_states = serpent.dump(user_selected_item_states)
  
  storeRetrieveProjectData(pool_item_states_key, user_selected_item_states)
end


function updatePooledCopies(pool_id, pool_dependencies_table)
  local retval, old_dependencies, dependencies, separator, dependent, ref, dependecies_have_changed, dependency

  retval, old_dependencies = storeRetrieveProjectData(pool_id .. ":dependencies")
  
  if retval == false then
    old_dependencies = ""
  end

  dependencies = ""
  separator = "|"
  dependent = separator .. pool_id .. separator

  -- store a reference to this pool for all the nested pools so if any get updated, they can check and update this pool
  for pool_id, ref in pairs(pool_dependencies_table) do
    dependencies, old_dependencies = storePoolReference(pool_id, dependent, dependencies, old_dependencies)
  end

  -- store this pool's dependencies list
  storeRetrieveProjectData(pool_id .. ":dependencies", dependencies)

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
  key = _pool_key_prefix .. new_pool_id .. _dependents_data_key_suffix
  
  -- see if nested pool already has a list of dependents
  r, dependents = storeRetrieveProjectData(key)
  
  if r == false then
    dependents = "" 
  end

  -- if this pool isn't already in list, add it
  if not string.find(dependents, dependent) then
    dependents = dependents .. dependent
    storeRetrieveProjectData(key, dependents)
  end

  -- now store these pools' dependencies
  dependency = "|" .. new_pool_id .. "|"
  dependencies = dependencies .. dependency

  -- remove this dependency from old_dependencies string
  old_dependencies = string.gsub(old_dependencies, dependency, "")

  return dependencies, old_dependencies
end


function removePoolFromDependents(dependency, dependent)
  local key, retval, dependents

  key = dependency .. _dependents_data_key_suffix
  retval, dependents = storeRetrieveProjectData(key)

  if retval == true and string.find(dependents, dependent) then
    dependents = string.gsub(dependents, dependent, "")

    storeRetrieveProjectData(key, dependents)
  end
end


function handleReglue(first_selected_item_track, first_selected_item, restored_items_pool_id, obey_time_selection)
  local glued_container_last_glue_params, sizing_region_guid_key, glued_container, glued_container_position, glued_container_length, retval, sizing_region_guid, new_src

  -- glued_container_last_glue_params = storeRetrieveGluedContainerParams(restored_items_pool_id, _preedit_action_step)
  sizing_region_guid_key = _sizing_region_guid_key_prefix .. restored_items_pool_id .. _sizing_region_guid_key_suffix
  retval, sizing_region_guid = storeRetrieveProjectData(sizing_region_guid_key)
  glued_container, sizing_region_params = handleGlue(first_selected_item_track, first_selected_item, restored_items_pool_id, sizing_region_guid, obey_time_selection)
  glued_container_params = getItemParams(glued_container)
  new_src = getItemAudioSrcFileName(glued_container)
  glued_container = restoreContainerState(glued_container, restored_items_pool_id, new_src, glued_container_params)
  
  setRegluePositionDeltas(glued_container_params, sizing_region_params)
  calculateDependentUpdates(restored_items_pool_id)
  sortDependentUpdates()
  updateDependents(glued_container, first_selected_item, restored_items_pool_id, new_src, glued_container_length, obey_time_selection)

  return glued_container
end


function restoreContainerState(glued_container, pool_id, new_src, glued_container_params)
  local retval, original_state

  retval, original_state = storeRetrieveProjectData(pool_id .. _item_preglue_state_suffix)

  if retval == true and original_state then
    getSetItemStateChunk(glued_container, original_state)
    updateItemSrc(glued_container, new_src)
    updateItemValues(glued_container, glued_container_params.position, glued_container_params.length)
  end

  return glued_container
end


function updateItemSrc(glued_container, new_src)
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


-- populate _keyed_dependents with a nicely ordered sequence and reinsert the items of each pool into temp tracks so they can be updated
function calculateDependentUpdates(pool_id, nesting_level)
  local retval, dependents, track, dependent_pool, restored_items, item, container, glued_container, new_src, i, v, update_item, current_entry

  dependents_data_key_label = _dependents_data_key_suffix
  retval, dependents = storeRetrieveProjectData(pool_id .. dependents_data_key_label)

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
        current_entry = {
          ["pool_id"] = dependent_pool,
          ["nesting_level"] = nesting_level
        }

        -- make track for this item's updates
        reaper.InsertTrackAtIndex(0, false)
        track = reaper.GetTrack(0, 0)

        deselectAllItems()

        -- restore items into newly made empty track
        restored_items = restorePreviouslyGluedItems(dependent_pool, track, nil, true)

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


function restorePreviouslyGluedItems(pool_id, glued_container_preedit_params, is_dependent_update)
  local pool_item_states_key, retval, stored_items, stored_items_table, restored_items, glued_container_postglue_params, stored_item, stored_item_state, restored_item

  pool_item_states_key = _pool_key_prefix .. pool_id .. _pool_item_states_key_suffix
  retval, stored_items = storeRetrieveProjectData(pool_item_states_key)
  stored_items_table = retrieveItemParams(stored_items)
  restored_items = {}
  glued_container_postglue_params = storeRetrieveGluedContainerParams(pool_id, _postglue_action_step)

  for stored_item, stored_item_state in ipairs(stored_items_table) do
    if stored_item_state then
      restored_item = restoreItem(glued_container_postglue_params.track, stored_item_state, is_dependent_update)
      restored_item = adjustRestoredItem(restored_item, glued_container_preedit_params, glued_container_postglue_params, is_dependent_update)
      restored_items[stored_item] = restored_item
    end
  end

  return restored_items
end


function retrieveItemParams(items)
  local retval, items_table

  retval, items_table = serpent.load(items)
  items_table.track = reaper.BR_GetMediaTrackByGUID(0, items_table.track_guid)

  return items_table
end


function restoreItem(track, state, is_dependent_update)
  local restored_item

  restored_item = reaper.AddMediaItemToTrack(track)

  getSetItemStateChunk(restored_item, state)

  if not is_dependent_update then
    restoreOriginalTake(restored_item)
  end

  addRemoveItemImage(restored_item, true)

  return restored_item
end


function restoreOriginalTake(item)
  local item_takes_count, active_take, preglue_active_take_guid, preglue_active_take, preglue_active_take_num, preglue_active_take

  item_takes_count = reaper.GetMediaItemNumTakes(item)
  
  if item_takes_count > 0 then
    preglue_active_take_guid = storeRetrieveItemData(item, _preglue_active_take_guid_key_suffix)
    preglue_active_take = reaper.SNM_GetMediaItemTakeByGUID(0, preglue_active_take_guid)

    if preglue_active_take then
      preglue_active_take_num = reaper.GetMediaItemTakeInfo_Value(preglue_active_take, _api_takenumber_key)

      if preglue_active_take_num then
        deleteItemAudioSrcFile(item)
        reaper.SetMediaItemSelected(item, true)
        deleteActiveTakeFromItems()

        preglue_active_take_num = tonumber(preglue_active_take_num)
        preglue_active_take = reaper.GetTake(item, preglue_active_take_num)

        if preglue_active_take then
          reaper.SetActiveTake(preglue_active_take)
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
  os.remove(old_src .. _peak_data_filename_extension)
end


function deleteActiveTakeFromItems()
  reaper.Main_OnCommand(40129, 0)
end


function adjustRestoredItem(restored_item, glued_container_preedit_params, glued_container_last_glue_params, is_dependent_update)
  local restored_item_params, is_edit_after_fresh_glue, is_edit_after_reglue, new_restored_item_position, restored_items_current_position_offset_from_first_instance, this_item_length, glued_container_position_delta_since_last_glue, this_restored_item_position_delta_in_container, this_is_edit_after_reglue, this_is_first_edit_of_pool, this_item_prev_delta_in_container, this_item_end_in_container, item_end_is_before_glued_container_position, glued_container_position_is_during_item_space, this_item_end, glued_container_last_glue_end, glued_container_length_cuts_off_item_end, item_position_is_after_glued_container_end

  reaper.SetMediaItemSelected(restored_item, true)

  restored_item_params = getItemParams(restored_item)
  this_item_prev_delta_in_container = storeRetrieveItemData(restored_item, _item_offset_to_container_position_key_suffix)
-- log(tostring(this_item_prev_delta_in_container))
  is_edit_after_fresh_glue = not this_item_prev_delta_in_container or this_item_prev_delta_in_container == ""
  is_edit_after_reglue = this_item_prev_delta_in_container

  if is_edit_after_fresh_glue then
    this_item_prev_delta_in_container = 0
  elseif is_edit_after_reglue then
    this_item_prev_delta_in_container = tonumber(this_item_prev_delta_in_container)
  end

  if not is_dependent_update then
    restored_item_params = offsetPositionFromEarliestPooledInstance(restored_item_params, glued_container_preedit_params)
    restored_item_params = shiftRestoredItemPositionSinceLastGlue(restored_item_params, this_item_prev_delta_in_container, glued_container_last_glue_params)
  end

  -- glued_container_position_delta_since_last_glue = glued_container_preedit_params.offset
  -- this_item_prev_delta_in_container = storeRetrieveItemData(restored_item, _item_offset_to_container_position_key_suffix)
  -- restored_item_params.position_delta_in_container = this_item_prev_delta_in_container --restored_item_params.position - glued_container_preedit_params.position - glued_container_position_delta_since_last_glue

  
  
  -- if this_item_prev_delta_in_container and this_item_prev_delta_in_container ~= "" then
  --   this_item_prev_delta_in_container = tonumber(this_item_prev_delta_in_container)
  -- end

  -- log(tostring(this_item_prev_delta_in_container))
  -- log(tostring(restored_item_params.position))
  -- log(tostring(glued_container_preedit_params.position))
  -- log(tostring(glued_container_preedit_params.offset))

  -- this_item_end_in_container = this_restored_item_position_delta_in_container + this_item_length
  item_end_is_before_glued_container_position = glued_container_preedit_params.source_offset > (this_item_prev_delta_in_container + restored_item_params.length)
  -- glued_container_position_is_during_item_space = glued_container_preedit_params.offset > this_restored_item_position_delta_in_container and glued_container_preedit_params.offset < this_item_end_in_container
  -- this_item_end = glued_container_preedit_params.position + this_restored_item_position_delta_in_container + this_item_length - glued_container_preedit_params.offset
  glued_container_last_glue_params.end_point = glued_container_preedit_params.position + glued_container_preedit_params.length
  -- glued_container_length_cuts_off_item_end = this_item_end > glued_container_last_glue_end
  item_position_is_after_glued_container_end = restored_item_params.position > glued_container_last_glue_params.end_point + glued_container_preedit_params.source_offset

  if item_end_is_before_glued_container_position or item_position_is_after_glued_container_end then
    -- restored_item_params = handleRestoredItemOutsideNewGlue(restored_item_params, glued_container_preedit_params, this_restored_item_position_delta_in_container)
    -- reaper.SetMediaItemInfo_Value(restored_item, _api_mute_key, 1)

  -- elseif glued_container_position_is_during_item_space then
  --   restored_item_params = handleResoredItemDuringNewGlueStart(restored_item_params, glued_container_preedit_params, this_restored_item_position_delta_in_container)
  
  -- elseif glued_container_preedit_params.offset ~= 0 then
  --   restored_item_params = handleRestoredItemInsideContainer(restored_item_params, glued_container_preedit_params)
  -- end

  -- if glued_container_length_cuts_off_item_end then
  --   restored_item_params = handleRestoredItemCutOffByNewGlueEnd(restored_item_params, glued_container_last_glue_params.end_point)
  end

  reaper.SetMediaItemPosition(restored_item, restored_item_params.position, false)
  reaper.SetMediaItemLength(restored_item, restored_item_params.length, false)

  return restored_item
end


function offsetPositionFromEarliestPooledInstance(restored_item_params, glued_container_preedit_params)
  local restored_items_current_position_offset_from_first_instance, new_item_position

  if not _earliest_pooled_instance_item_position then
    _earliest_pooled_instance_item_position = restored_item_params.position
  else
    _earliest_pooled_instance_item_position = math.min(restored_item_params.position, _earliest_pooled_instance_item_position)
  end

  restored_items_current_position_offset_from_first_instance = glued_container_preedit_params.position - _earliest_pooled_instance_item_position
  new_item_position = restored_item_params.position + restored_items_current_position_offset_from_first_instance
  
  return restored_item_params
end


function shiftRestoredItemPositionSinceLastGlue(restored_item_params, this_item_prev_delta_in_container, glued_container_last_glue_params)
  restored_item_params.position = glued_container_last_glue_params.position + this_item_prev_delta_in_container

  return restored_item_params
end


function handleRestoredItemOutsideNewGlue(restored_item_params, glued_container_preedit_params, this_item_position_delta_in_container)
  local new_restored_item_position = glued_container_preedit_params.position - glued_container_preedit_params.source_offset + this_item_position_delta_in_container

  restored_item_params.position = new_restored_item_position

  return restored_item_params
end


function handleResoredItemDuringNewGlueStart(restored_item_params, glued_container_preedit_params, this_item_position_delta_in_container, this_item_length)
  local restored_item_take, new_source_offset, new_length

  restored_item_take = reaper.GetActiveTake(restored_item)
  new_source_offset = glued_container_preedit_params.source_offset - this_item_position_delta_in_container 
  new_length = this_item_length - new_source_offset

  reaper.SetMediaItemInfo_Value(restored_item, _api_position_key, glued_container_preedit_params.position)
  reaper.SetMediaItemTakeInfo_Value(restored_item_take, _api_src_offset_key, new_source_offset)
  reaper.SetMediaItemInfo_Value(restored_item, _api_length_key, new_length)

  return restored_item_params
end


function handleRestoredItemInsideContainer(restored_item_params, this_item_position, glued_container_preedit_params)
  local new_position = this_item_position - glued_container_preedit_params.source_offset

  reaper.SetMediaItemInfo_Value(restored_item, _api_position_key, new_position)

  return restored_item_params
end


function handleRestoredItemCutOffByNewGlueEnd(restored_item_params, this_item_length, glued_container_last_glue_end, this_item_end)
  local new_length = this_item_length + (glued_container_last_glue_end - this_item_end)

  reaper.SetMediaItemInfo_Value(restored_item, _api_length_key, new_length)

  return restored_item_params
end


-- sort dependents _keyed_dependents by how nested they are: convert _keyed_dependents to a numeric array then sort by nesting value
function sortDependentUpdates()
  local i, v

  for i, v in pairs(_keyed_dependents) do
    table.insert(_numeric_dependents, v)
  end
  
  table.sort( _numeric_dependents, function(a, b) return a.nesting_level < b.nesting_level end)
end


function setRegluePositionDeltas(glued_container_params, sizing_region_params)
  -- glued_container_last_glue_source_offset = tonumber(glued_container_last_glue_source_offset)
  glued_container_params.position = tonumber(glued_container_params.position)

  if not _glued_instance_position_delta_while_open then
    _glued_instance_position_delta_while_open = 0
  end
  
  if sizing_region_params.position ~= glued_container_params.position then
    _glued_instance_position_delta_while_open = round(sizing_region_params.position - glued_container_params.position, 13)
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
  this_container_name = _glued_container_name_prefix .. edited_pool_id
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

  glued_container_pool_id = storeRetrieveItemData(this_item, _glued_container_pool_id_key_suffix)
  is_glued_container = glued_container_pool_id and glued_container_pool_id == edited_pool_id

  if is_glued_container then
    return this_item
  end
end


function updatePooledItem(glued_pool_item_count, edited_pool_id, glued_container, this_item, new_src, length, nesting_level)
  local this_item_pool_id, item_is_in_edited_pool, current_position, this_is_reglued_container, multiple_glued_pooled_items, this_item_is_nested, glued_container_position, offset_to_glued_container, user_wants_position_change, new_position, take_name, take, current_src

  this_item_pool_id = storeRetrieveItemData(this_item, _restored_item_pool_id_key_suffix)
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

  dependent_glued_container = handleGlue(dependent.track, first_selected_item, dependent.pool_id, nil, obey_time_selection, true)
  new_src = getItemAudioSrcFileName(dependent_glued_container)

  updatePooledItems(dependent_glued_container, dependent.pool_id, new_src, length, dependent.nesting_level)
  reaper.DeleteTrack(dependent.track)
end


function initEdit()
  local selected_item_count, glued_containers, this_pool_id

  selected_item_count = initAction("edit")

  if selected_item_count == false then return end

  glued_containers = getSelectedGlueReversibleItems(selected_item_count)

  if isNotSingleGluedContainer(#glued_containers) == true then return end

  this_pool_id = storeRetrieveItemData(glued_containers[1], _glued_container_pool_id_key_suffix)

  if otherPooledInstanceIsOpen(this_pool_id) then
    handleOtherOpenPooledInstance(item, this_pool_id)

    return
  end
  
  handleEdit(this_pool_id)
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
    restored_item_pool_id = storeRetrieveItemData(item, _restored_item_pool_id_key_suffix)

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

  reaper.ShowMessageBox("Reglue the other open instance from pool " .. edit_pool_id .. " before trying to edit this glued container item. It will be selected and scrolled to now.", "Only one glued container item per pool can be Edited at a time.", 0)
end


function scrollToSelectedItem()
  reaper.Main_OnCommand(_scroll_action_id, 0)
end


function handleEdit(pool_id)
  local glued_container

  glued_container = getFirstSelectedItem()

  storeRetrieveGluedContainerParams(pool_id, _preedit_action_step, glued_container)
  processEditGluedContainer(glued_container, pool_id)
  cleanUpAction(_edit_undo_block_string)
end


function processEditGluedContainer(glued_container, pool_id)
  local glued_container_preedit_params, restored_items, glued_container_postglue_params

  glued_container_preedit_params = getItemParams(glued_container)

  deselectAllItems()

  restored_items = restorePreviouslyGluedItems(pool_id, glued_container_preedit_params)
  
  createSizingRegionFromContainer(glued_container, pool_id)

  glued_container_postglue_params = storeRetrieveGluedContainerParams(pool_id, _postglue_action_step)

  reaper.DeleteTrackMediaItem(glued_container_postglue_params.track, glued_container)
end


function createSizingRegionFromContainer(glued_container, pool_id)
  local glued_container_params = getItemParams(glued_container)

  getSetSizingRegion(pool_id, glued_container_params)
end


function initSmartAction(obey_time_selection)
  local selected_item_count, pool_id
  
  selected_item_count = doPreGlueChecks()
  
  if selected_item_count == false then return end

  prepareAction("glue")
  
  -- refresh in case item selection changed
  selected_item_count = getSelectedItemsCount()
  
  if itemsAreSelected(selected_item_count) == false then return end

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
    initEdit()

  elseif glue_reversible_action == "glue" then
    initGlue(obey_time_selection)

  elseif glue_reversible_action == "glue/abort" then
    glue_abort_dialog = reaper.ShowMessageBox("Are you sure you want to glue them?", "You have selected both an open container and glued container(s).", 1)

    if glue_abort_dialog == 2 then
      setResetItemSelectionSet()

      return
    
    else
      initGlue(obey_time_selection)
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