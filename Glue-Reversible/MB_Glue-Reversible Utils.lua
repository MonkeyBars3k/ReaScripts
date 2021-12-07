-- @description MB_Glue-Reversible Utils: Codebase for MB_Glue-Reversible scripts' functionality
-- @author MonkeyBars
-- @version 1.53
-- @changelog Refactor nomenclature (https://github.com/MonkeyBars3k/ReaScripts/issues/115); Replace os.time() for id string with GenGUID() (https://github.com/MonkeyBars3k/ReaScripts/issues/109); Nested pooled containers no longer update (https://github.com/MonkeyBars3k/ReaScripts/issues/114)
-- @provides [nomain] .
--   gr-bg.png
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Code for Glue-Reversible scripts


-- dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")


local msg_change_selected_items, glued_container_pool_id_key, restored_item_pool_id_key, item_preglue_state_key, api_name_key, api_position_key, api_length_key, api_src_offset_key, keyed_dependents, numeric_dependents, position_change_response, position_changed

msg_change_selected_items = "Change the items selected and try again."
pool_data_key_prefix = "pool-"
glued_container_pool_id_key = "instance-pool-id"
restored_item_pool_id_key = "parent-pool-id"
glue_data_key_suffix = ":glue"
edit_data_key_suffix = ":edit"
position_data_key_suffix = ":pos"
dependents_data_key_suffix = ":dependents"
item_preglue_state_key = "preglue_state_chunk"
api_data_key = "P_EXT:"
global_script_prefix = "GR_"
api_name_key = "P_NAME"
api_position_key = "D_POSITION"
api_length_key = "D_LENGTH"
api_src_offset_key = "D_STARTOFFS"
last_pool_id_key = "last-pool-id"
keyed_dependents = {}
numeric_dependents = {}



function initGlueReversible(obey_time_selection)
  local selected_item_count, pool_id, first_selected_item, first_selected_item_track, glued_container

  selected_item_count = initAction("glue")

  if selected_item_count == false then return end

  pool_id = getFirstPoolIdFromSelectedItems(selected_item_count)
  first_selected_item, first_selected_item_track = getInitialSelections()

  if itemsOnMultipleTracksAreSelected(selected_item_count) == true or containerSelectionIsInvalid(selected_item_count) == true or pureMIDIItemsAreSelected(selected_item_count, first_selected_item_track) == true then return end

  glued_container = triggerGlueReversible(pool_id, first_selected_item, first_selected_item_track, obey_time_selection)
  
  exclusiveSelectItem(glued_container)
  cleanUpAction("MB_Glue-Reversible")
end


function initAction(action)
  local selected_item_count

  selected_item_count = doPreGlueChecks()

  if selected_item_count == false then return false end

  prepareAction(action)
  
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


function prepareAction(action)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  if action == "glue" then
    setResetItemSelectionSet(true)
  end
end


function setResetItemSelectionSet(set_reset)
  local set, reset

  set =set_reset == true
  reset = not set_reset or set_reset == false

  if set then
    -- save selected item selection set to slot 10
    reaper.Main_OnCommand(41238, 0)

  elseif reset then
    -- reset item selection from selection set slot 10
    reaper.Main_OnCommand(41248, 0)
  end
end


-- function getEmptyContainerFromSelection(selected_item_count)
--   local i, this_item, this_item_pool_id, empty_container_pool_id, empty_container, non_empty_container_item

--   for i = 0, selected_item_count-1 do
--     this_item = reaper.GetSelectedMediaItem(0, i)
--     this_item_pool_id = getPoolId(this_item)

--     if this_item_pool_id then
--       if empty_container_pool_id then
--         return false
--       else
--         empty_container = this_item
--         empty_container_pool_id = this_item_pool_id

--         return empty_container, empty_container_pool_id
--       end

--     elseif non_empty_container_item then
--       non_empty_container_item = this_item
--     end
-- LEGACY VERSION
    -- if this_item_type == "empty" then
    --   empty_container = this_item
    --   empty_container_pool_id = this_item_pool_id

    --   return empty_container, empty_container_pool_id
    -- end
-- /LEGACY VERSION
  -- end

-- LEGACY VERSION
  --   this_item_pool_id = getPoolId(this_item)

  --   if this_item_pool_id then

  --     if empty_container_pool_id then
  --       return false
  --     else
  --       empty_container = this_item
  --       empty_container_pool_id = this_item_pool_id
  --     end

  --   elseif not non_empty_container_item then
  --     non_empty_container_item = item
  --   end
  -- end
-- /LEGACY VERSION

--   required_item_missing = not empty_container_pool_id or not empty_container or not non_empty_container_item

--   if required_item_missing then return end

--   return empty_container_pool_id 
-- end


function getFirstPoolIdFromSelectedItems(selected_item_count)
  local i, this_item

  for i = 0, selected_item_count-1 do
    this_item = selected_item_count[i]
    this_item_pool = getSetItemState(this_item, restored_item_pool_id_key)

    if this_item_pool ~= "" then
      return this_item_pool
    end
  end

  return false
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
  local selected_items_on_multiple_tracks_are_detected = detectSelectedItemsOnMultipleTracks(selected_item_count)

  if selected_items_on_multiple_tracks_are_detected == true then 
      reaper.ShowMessageBox(msg_change_selected_items, "Glue-Reversible and Edit container item only work on items on a single track.", 0)
      return true
  end
end


function detectSelectedItemsOnMultipleTracks(selected_item_count)
  local i, selected_items, this_item, this_item_track, prev_item_track, selected_items_on_multiple_tracks_are_detected

  selected_items = {}
  selected_items_on_multiple_tracks_are_detected = false

  for i = 0, selected_item_count-1 do
    selected_items[i] = reaper.GetSelectedMediaItem(0, i)
    this_item = selected_items[i]
    this_item_track = reaper.GetMediaItemTrack(this_item)
    selected_items_on_multiple_tracks_are_detected = this_item_track and prev_item_track and this_item_track ~= prev_item_track
  
    if selected_items_on_multiple_tracks_are_detected == true then
      return selected_items_on_multiple_tracks_are_detected
    end
    
    prev_item_track = this_item_track
  end
end


function containerSelectionIsInvalid(selected_item_count)
  local glued_containers, restored_items, multiple_instances_from_same_pool_are_selected, recursive_container_is_being_glued

  glued_containers, restored_items = getContainers(selected_item_count)
  multiple_instances_from_same_pool_are_selected = #restored_items > 1
  recursive_container_is_being_glued = recursiveContainerIsBeingGlued(glued_containers, restored_items) == true

  if multiple_instances_from_same_pool_are_selected or recursive_container_is_being_glued then
    reaper.ShowMessageBox(msg_change_selected_items, "Glue-Reversible can only Reglue or Edit one container at a time.", 0)
    setResetItemSelectionSet()
    return true
  end
end


function getContainers(selected_item_count)
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
  local glued_container_pool_id_key, glued_container_pool_id, is_glued_container, restored_item_pool_id_key, restored_item_pool_id, is_restored_item

  
  glued_container_pool_id = getSetItemData(item, glued_container_pool_id_key)
  is_glued_container = glued_container_pool_id and glued_container_pool_id ~= ""
  restored_item_pool_id = getSetItemData(item, restored_item_pool_id_key)
  is_restored_item = restored_item_pool_id and restored_item_pool_id = ""

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
    this_glued_container_instance_pool_id = getSetItemState(this_item, glued_container_pool_id_key)

    for j = 1, #restored_items do
      this_restored_item = restored_items[i]
      this_restored_item_parent_pool_id = getSetItemState(this_restored_item, glued_container_pool_id_key)
      
      if this_glued_container_instance_pool_id == this_restored_item_parent_pool_id then
        reaper.ShowMessageBox(msg_change_selected_items, "Glue-Reversible can't glue a glued container item to an instance from the same pool being Edited – or you could destroy the universe!", 0)
        setResetItemSelectionSet()

        return true
      end
    end
  end
end


function getSetItemName(item, new_name, add_or_remove)
  local set, get, item_has_no_takes, take, current_name

  set = new_name
  get = not new_name

  item_has_no_takes = reaper.GetMediaItemNumTakes(item) < 1

  if item_has_no_takes then return end

  take = reaper.GetActiveTake(item)

  if take then
    current_name = reaper.GetTakeName(take)

    if set then

      if add_or_remove == "add" then
        new_name = current_name.." "..new_name

      elseif add_or_remove == "remove" then
        new_name = string.gsub(current_name, new_name, "")
      end

      reaper.GetSetMediaItemTakeInfo_String(take, api_name_key, new_name, true)

      return new_name, take

    elseif get then
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


function triggerGlueReversible(pool_id, first_selected_item, first_selected_item_track, obey_time_selection)
  local glued_container
  
  if pool_id then
    glued_container = reglueContainer(first_selected_item_track, first_selected_item, pool_id, obey_time_selection)
  else
    glued_container = createGluedContainer(first_selected_item_track, first_selected_item, nil, obey_time_selection)
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


function createGluedContainer(first_selected_item_track, first_selected_item, obey_time_selection, active_pool_id, ignore_dependencies)
  local this_is_reglue, selected_item_count, user_selected_items, first_user_selected_item_name, user_selected_item_states, pool_dependencies_table, active_pool_id, glue_placeholder_item, sizing_region_idx, glued_item, glued_item_length, glued_item_position

  this_is_reglue = false
  selected_item_count = getSelectedItemsCount()
  user_selected_items, first_user_selected_item_name = getUserSelectedItems(selected_item_count)

  deselectAllItems()
  
  user_selected_item_states, pool_dependencies_table, new_pool_id = createUserSelectedItemStates(selected_item_count, user_selected_items)

  if not active_pool_id then
    active_pool_id = handlePoolId()
    this_is_reglue = true
  end

  glue_placeholder_item, sizing_region_idx = createGluePlaceholder(first_selected_item_track, active_pool_id, user_selected_item, this_is_reglue)
  glued_item = glueSelectedItemsIntoContainer(obey_time_selection, user_selected_items, selected_item_count, active_pool_id, first_user_selected_item_name)
  glued_item_length, glued_item_position = setGluedContainerParams(glued_item, glue_placeholder_item, active_pool_id)

  getSetGluedContainerData(active_pool_id..glue_data_key_suffix, glued_item)
  updatePoolStates(user_selected_item_states, glue_placeholder_item, active_pool_id, new_pool_id, pool_dependencies_table, ignore_dependencies)
  deletePlaceholder(first_selected_item_track, glue_placeholder_item)

  return glued_item, glued_item_position, glued_item_length, sizing_region_idx
end


function handlePoolId()
  local retval, last_pool_id, active_pool_id
  
  retval, last_pool_id = getSetStateData(last_pool_id_key)
  active_pool_id = incrementPoolId(last_pool_id)

  getSetStateData(last_pool_id_key, active_pool_id)

  return active_pool_id
end


function incrementPoolId(last_pool_id)
  local active_pool_id

  if last_pool_id and last_pool_id ~= "" then
    last_pool_id = tonumber(last_pool_id)
    active_pool_id = math.floor(last_pool_id + 1)
  else
    active_pool_id = 1
  end

  return active_pool_id
end


-- outside function since getSetStateData() gets called a lot
local master_track = reaper.GetMasterTrack(0)
-- save state data in master track tempo envelope because changes get saved in undo points and it can't be deactivated (i.e., data removed)
local master_track_tempo_env = reaper.GetTrackEnvelope(master_track, 0)

function getSetStateData(key, val)
  local set, get, get_or_set, data_param_key, retval, state_data_val

  set = val
  get = not val

  if set then
    get_or_set = true
  elseif get then
    val = ""
    get_or_set = false
  end

  data_param_key = api_data_key..global_script_prefix..key
  retval, state_data_val = reaper.GetSetEnvelopeInfo_String(master_track_tempo_env, data_param_key, val, get_or_set)

  return retval, state_data_val
end


function getSelectedItemsCount()
  return reaper.CountSelectedMediaItems(0)
end


function getUserSelectedItems(selected_item_count)
  local user_selected_items, i, this_item, first_user_selected_item_name

  user_selected_items = {}
  
  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(0, i)
    table.insert(user_selected_items, this_item)

    if not first_user_selected_item_name then
      first_user_selected_item_name = reaper.getSetItemName(this_item)
    end
  end

  return user_selected_items, first_user_selected_item_name
end


function createUserSelectedItemStates(selected_item_count, user_selected_items)
  local user_selected_item_count, user_selected_item_states, pool_dependencies_table, i, this_item, new_pool_id

  user_selected_item_count = getTableSize(user_selected_items)
  user_selected_item_states = ""
  pool_dependencies_table = {}

  for i = 1, user_selected_item_count do
    this_item = user_selected_items[i]

    convertMidiItemToAudio(this_item)
    
    user_selected_item_states = user_selected_item_states..getSetItemState(this_item).."|||"
    new_pool_id = getSetItemState(this_item, restored_item_pool_id_key)

    if new_pool_id then
      pool_dependencies_table[new_pool_id] = new_pool_id
    end
  end

  return user_selected_item_states, pool_dependencies_table, new_pool_id
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
      data_param_label = "glue_reversible_render"
      data_val = math.floor(active_take_num)

      getSetTakeData(active_take, data_param_label, data_val)
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
  local get, set, data_param_key
    
  get = not data_val
  set = data_val
  data_param_key = api_data_key..global_script_prefix..data_param_label

  if get then
    retval, data_val = reaper.GetMediaItemTakeInfo_Value(take, data_param_key)

    return data_val

  elseif set then
    reaper.SetMediaItemTakeInfo_Value(take, data_param_key, data_val, true)
  end
end


function cleanNullTakes(item, force)
  local item_state = getSetItemState(item)

  if string.find(item_state, "TAKE NULL") or force then
    item_state = string.gsub(state, "TAKE NULL", "")

    reaper.getSetItemState(item, item_state)
  end
end


function createGluePlaceholder(first_selected_item_track, pool_id, user_selected_items, this_is_reglue)
  local this_is_glue, glue_placeholder_item, sizing_region_idx

  this_is_glue = not this_is_reglue

  if this_is_reglue then
    glue_placeholder_item, sizing_region_idx = prepareRegluePlaceholder(first_selected_item_track, user_selected_items, pool_id)

  elseif this_is_glue then
    glue_placeholder_item = reaper.AddMediaItemToTrack(first_selected_item_track)

    setTakeSource(glue_placeholder_item)
    setContainerItemName(glue_placeholder_item, pool_id)
  end

  selectDeselectItems(user_selected_items, true)
  reaper.SetMediaItemSelected(glue_placeholder_item, false)

  return glue_placeholder_item, sizing_region_idx
end


function setContainerItemName(item, item_name_ending)
  local take, item_name_prefix, new_item_name

  take = reaper.GetActiveTake(item)
  item_name_prefix = "gr:"
  new_item_name = item_name_prefix..item_name_ending

  reaper.GetSetMediaItemTakeInfo_String(take, api_name_key, new_item_name, true)
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


function prepareRegluePlaceholder(first_selected_item_track, user_selected_items, pool_id)
  local i, this_item, retval, user_selected_first_item_start, user_selected_last_item_start, user_selected_last_item_length, user_selected_items_end, sizing_region_idx, temp_marker_item, user_selected_items_length

  for i = 0, #user_selected_items-1 do
    this_item = user_selected_items[i]
    this_is_first_item = i == 0
    this_is_last_item = i == #user_selected_items-1

    if this_is_first_item then
      retval, user_selected_first_item_start = reaper.GetMediaItemInfo_Value(this_item, api_position_key)
    end

    if this_is_last_item then
      retval, user_selected_last_item_start = reaper.GetMediaItemInfo_Value(this_item, api_position_key)
      retval, user_selected_last_item_length = reaper.GetMediaItemInfo_Value(this_item, api_length_key)
    end
  end

  user_selected_first_item_start = tonumber(user_selected_first_item_start)
  user_selected_last_item_start = tonumber(user_selected_last_item_start)
  user_selected_last_item_length = tonumber(user_selected_last_item_length)
  user_selected_items_end = user_selected_last_item_start + user_selected_last_item_length
  user_selected_items_length = user_selected_items_end - user_selected_first_item_start
  sizing_region_idx = getSetSizingRegion(pool_id, user_selected_first_item_start, user_selected_items_length)
  temp_marker_item = reaper.AddMediaItemToTrack(first_selected_item_track)
  
  reaper.SetMediaItemSelected(temp_marker_item, true)
  reaper.SetMediaItemInfo_Value(temp_marker_item, api_position_key, user_selected_first_item_start)
  reaper.SetMediaItemInfo_Value(temp_marker_item, api_length_key, user_selected_items_length)
  resetPreglueItemState(reglue_placeholder_item)

  return reglue_placeholder_item, sizing_region_idx
end


function getSetSizingRegion(region_idx_or_pool_id, position, length)
  local get, set, retval, is_region, sizing_region_end, sizing_region_name, sizing_region_color, sizing_region_idx

  get = not position or not length
  set = position and length

  if get then
    retval, is_region, position, sizing_region_end = reaper.EnumProjectMarkers3(0, region_idx_or_pool_id)
    position = tonumber(position)
    sizing_region_end = tonumber(sizing_region_end)
    length = sizing_region_end - position

    return position, length

  elseif set then
    sizing_region_end = position + length
    sizing_region_name = global_script_prefix.."Sizing-Guide: Pool ID "..region_idx_or_pool_id
    sizing_region_color = reaper.ColorToNative(255, 255, 255)
    sizing_region_idx = reaper.AddProjectMarker2(0, true, position, sizing_region_end, sizing_region_name, 0, sizing_region_color)

    return sizing_region_idx
  end
end


function resetPreglueItemState(reglue_placeholder_item)
  getSetItemData(reglue_placeholder_item, item_preglue_state_key, "")
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



local glued_instance_position_delta_while_open

function setGluedContainerParams(glued_container, glue_placeholder_item, pool_id)
  local new_glued_container_length, new_glued_container_position, position_key_prefix, position_key_suffix, position_key, retval, first_selected_item_position

  new_glued_container_length = reaper.GetMediaItemInfo_Value(glued_container, api_length_key)
  new_glued_container_position = reaper.GetMediaItemInfo_Value(glued_container, api_position_key)
  position_key = pool_data_key_prefix..pool_id..position_data_key_suffix
  retval, first_selected_item_position = getSetStateData(position_key)

  if new_glued_container_position and first_selected_item_position then
    new_glued_container_position = tonumber(new_glued_container_position)
    first_selected_item_position = tonumber(first_selected_item_position)
    glued_instance_position_delta_while_open = round((new_glued_container_position - first_selected_item_position), 13)
  else
    glued_instance_position_delta_while_open = 0
  end

  reaper.SetMediaItemInfo_Value(glue_placeholder_item, api_length_key, new_glued_container_length)
  reaper.SetMediaItemInfo_Value(glue_placeholder_item, api_position_key, new_glued_container_position)
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


function updatePoolStates(user_selected_item_states, glue_placeholder_item, active_pool_id, new_pool_id, pool_dependencies_table, ignore_dependencies)
  user_selected_item_states = user_selected_item_states..getSetItemState(glue_placeholder_item)
  
  getSetStateData(active_pool_id, user_selected_item_states)

  if not ignore_dependencies then
    updatePooledCopies(active_pool_id, new_pool_id, pool_dependencies_table)
  end
end


function updatePooledCopies(active_pool_id, new_pool_id, pool_dependencies_table)
  local retval, old_dependencies, dependencies, dependent, ref, dependecies_have_changed, dependency

  retval, old_dependencies = getSetStateData(active_pool_id..":dependencies")
  
  if retval == false then
    old_dependencies = ""
  end

  dependencies = ""
  dependent = "|"..active_pool_id.."|"

  -- store a reference to this pool for all the nested pools so if any get updated, they can check and update this pool
  for new_pool_id, ref in pairs(pool_dependencies_table) do
    dependencies, old_dependencies = storePoolReference(new_pool_id, dependent, dependencies, old_dependencies)
  end

  -- store this pool's dependencies list
  getSetStateData(active_pool_id..":dependencies", dependencies)

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
  key = new_pool_id..dependents_data_key_suffix
  
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
  local key, retval, dependents

  key = dependency..dependents_data_key_suffix
  retval, dependents = getSetStateData(key)

  if retval == true and string.find(dependents, dependent) then
    dependents = string.gsub(dependents, dependent, "")

    getSetStateData(key, dependents)
  end
end


function deletePlaceholder(first_selected_item_track, glue_placeholder_item)
  reaper.DeleteTrackMediaItem(first_selected_item_track, glue_placeholder_item)
end


function reglueContainer(first_selected_item_track, first_selected_item, pool_id, obey_time_selection)
  local glued_container_source_offset, open_instance_source_offset, open_instance_length, open_instance_position, sizing_region_position, sizing_region_length, glued_container, glued_item_position, original_item_length, sizing_region_idx, new_src

  glued_container_source_offset = getSetGluedContainerData(pool_id..glue_data_key_suffix)
  open_instance_source_offset, open_instance_length, open_instance_position = getSetGluedContainerData(pool_id..edit_data_key_suffix)
  glued_container, glued_item_position, original_item_length, sizing_region_idx = createGluedContainer(first_selected_item_track, first_selected_item, obey_time_selection, pool_id)
  sizing_region_position = getSetSizingRegion(sizing_region_idx)
  new_src = getItemAudioSrcFileName(glued_container)
  glued_container = updateItemInfo(glued_container, new_src, glued_item_position, length)

  calculateDependentUpdates(pool_id)
  sortDependentUpdates()
  setRegluePositionDeltas(glued_container_source_offset, glued_item_position, sizing_region_position, length)
  updateDependents(glued_container, first_selected_item, pool_id, new_src, length, obey_time_selection)

  return glued_container
end


function updateItemInfo(glued_container, new_src, glued_item_position, length)
  local retval, original_state

  retval, original_state = getSetStateData(item_preglue_state_key)

  if retval == true and original_state then
    getSetItemState(glued_container, original_state)
    updateItemSrc(glued_container)
    updateItemValues(glued_container, glued_item_position, length)
    removeOldItemState()
  end

  return glued_container
end


function getSetItemState(item, state)
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
  reaper.SetMediaItemInfo_Value(glued_container, api_position_key, position)
  reaper.SetMediaItemInfo_Value(glued_container, api_length_key, length)
end


function removeOldItemState()
  getSetStateData(item_preglue_state_key, "")
end


function getItemAudioSrcFileName(item, take)
  local source, filename

  take = take or reaper.GetActiveTake(item)
  source = reaper.GetMediaItemTake_Source(take)
  filename = reaper.GetMediaSourceFileName(source, '')

  if string.len(filename) > 0 then
    return filename
  end
end


function restoreOriginalTake(item)
  local item_takes_count, active_take, take_num, original_take

  item_takes_count = reaper.GetMediaItemNumTakes(item)
  
  if item_takes_count > 0 then
    active_take = reaper.GetActiveTake(item)
    
    if active_take then
      data_param_label = "glue_reversible_render"
      take_num = getSetTakeData(active_take, data_param_label)
      
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
  local old_src, peak_data_filename_extension

  old_src = getItemAudioSrcFileName(item)
  peak_data_filename_extension = ".reapeaks"
  
  os.remove(old_src)
  os.remove(old_src..peak_data_filename_extension)
end


function deleteActiveTakeFromItems()
  reaper.Main_OnCommand(40129, 0)
end


-- create an keyed_dependents with a nicely ordered sequence and re-insert the items of each pool into temp tracks so they can be updated
function calculateDependentUpdates(pool_id, nesting_level)
  local retval, dependents, track, dependent_pool, restored_items, item, container, glued_container, new_src, i, v, update_item, current_entry

  dependents_data_key_label = dependents_data_key_suffix
  retval, dependents = getSetStateData(pool_id..dependents_data_key_label)

  if not keyed_dependents then
    keyed_dependents = {}
  end
  
  if not nesting_level then
    nesting_level = 1
  end

  if retval == true and string.len(dependents) > 0 then
    for dependent_pool in string.gmatch(dependents, "%d+") do 
      dependent_pool = math.floor(tonumber(dependent_pool))

      -- check if an entry for this pool already exists
      if keyed_dependents[dependent_pool] then
        -- store how deeply nested this item is
        keyed_dependents[dependent_pool].nesting_level = math.max(nesting_level, keyed_dependents[dependent_pool].nesting_level)

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
        restored_items = restoreItems(dependent_pool, track, 0, 0, 0, 0, true, true)

        -- store references to temp track and items
        current_entry.track = track
        current_entry.item = item
        current_entry.container = container
        current_entry.restored_items = restored_items

        -- store this item in keyed_dependents
        keyed_dependents[dependent_pool] = current_entry

        -- check if this pool also has dependents
        calculateDependentUpdates(dependent_pool, nesting_level + 1)
      end
    end
  end
end


function restoreItems(pool_id, track, original_item_position, original_item_offset, original_item_length, dont_restore_take, dont_offset)
  local retval, stored_items, separator, stored_item_splits, restored_items, key, val, this_restored_item, earliest_pooled_instance_position, position_offset_from_first_instance

  -- get items stored during last glue
  retval, stored_items = getSetStateData(pool_id)
  separator = "|||"
  stored_item_splits = string.split(stored_items, separator)
  restored_items = {}

  for key, val in ipairs(stored_item_splits) do
    if val then
      this_restored_item = reaper.AddMediaItemToTrack(track)

      getSetItemState(this_restored_item, val)

      if not dont_restore_take then
        restoreOriginalTake(this_restored_item) 
      end

      addRemoveItemImage(this_restored_item, true)

      if not earliest_pooled_instance then
        earliest_pooled_instance_position = reaper.GetMediaItemInfo_Value(this_restored_item, api_position_key)
      else
        earliest_pooled_instance_position = math.min(reaper.GetMediaItemInfo_Value(this_restored_item, api_position_key), earliest_pooled_instance_position)
      end

      restored_items[key] = this_restored_item
    end
  end

  position_offset_from_first_instance = original_item_position - earliest_pooled_instance_position
  restored_items = adjustRestoredItems(pool_id, restored_items, original_item_position, position_offset_from_first_instance, original_item_offset, original_item_length, dont_offset)

  return restored_items
end


function adjustRestoredItems(pool_id, restored_items, original_item_position, position_offset_from_first_instance, original_item_offset, original_item_length, dont_offset)
  local i, this_item

  for i, this_item in ipairs(restored_items) do

    if not dont_offset then
      offsetRestoredItemFromEarliestPooledInstance(this_item, position_offset_from_first_instance)
    end

    reaper.SetMediaItemSelected(this_item, true)
    adjustRestoredItem(this_item, original_item_position, original_item_offset, original_item_length)
  end

  return restored_items
end


function offsetRestoredItemFromEarliestPooledInstance(item, position_offset_from_first_instance)
  local old_position, new_position

  old_position = reaper.GetMediaItemInfo_Value(item, api_position_key)
  new_position = old_position + position_offset_from_first_instance
  
  reaper.SetMediaItemInfo_Value(item, api_position_key, new_position)
end


function adjustRestoredItem(this_item, original_item_position, original_item_offset, original_item_length)
  local this_item_position, this_item_position_delta_in_container, this_item_length, this_item_end_in_container, item_end_is_before_glued_container_position, glued_container_position_is_during_item_space, this_item_end, original_item_end, glued_container_length_cuts_off_item_end, item_position_is_after_glued_container_end

  this_item_position = reaper.GetMediaItemInfo_Value(this_item, api_position_key)
  this_item_position_delta_in_container = this_item_position - original_item_position
  this_item_length = reaper.GetMediaItemInfo_Value(this_item, api_length_key)
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

  reaper.SetMediaItemInfo_Value(this_item, api_position_key, new_position)
  reaper.SetMediaItemInfo_Value(this_item, "B_MUTE", 1)
end


function handleResoredItemDuringNewGlueStart(this_item, original_item_position, original_item_offset, this_item_position_delta_in_container, this_item_length)
  local this_item_take, new_position, new_source_offset, new_length

    this_item_take = reaper.GetActiveTake(this_item)
    new_position = original_item_position
    new_source_offset = original_item_offset - this_item_position_delta_in_container 
    new_length = this_item_length - new_source_offset

    reaper.SetMediaItemInfo_Value(this_item, api_position_key, new_position)
    reaper.SetMediaItemTakeInfo_Value(this_item_take, api_src_offset_key, new_source_offset)
    reaper.SetMediaItemInfo_Value(this_item, api_length_key, new_length)
end


function handleOtherRestoredItem(this_item,this_item_position, original_item_offset)
  local new_position = this_item_position - original_item_offset

  reaper.SetMediaItemInfo_Value(this_item, api_position_key, new_position)
end


function handleRestoredItemCutOffByNewGlueEnd(this_item, this_item_length, original_item_end, this_item_end)
  local new_length = this_item_length + (original_item_end - this_item_end)

  reaper.SetMediaItemInfo_Value(this_item, api_length_key, new_length)
end


-- sort dependents keyed_dependents by how nested they are: convert keyed_dependents to a numeric array then sort by nesting value
function sortDependentUpdates()
  local i, v

  for i, v in pairs(keyed_dependents) do
    table.insert(numeric_dependents, v)
  end
  
  table.sort( numeric_dependents, function(a, b) return a.nesting_level < b.nesting_level end)
end


function setRegluePositionDeltas(glued_container_source_offset, glued_item_position, sizing_region_position, length)
  glued_container_source_offset = tonumber(glued_container_source_offset)
  glued_item_position = tonumber(glued_item_position)

  if not glued_instance_position_delta_while_open then
    glued_instance_position_delta_while_open = 0
  end

  if sizing_region_position ~= glued_item_position then
    glued_instance_position_delta_while_open = round(sizing_region_position - glued_item_position, 13)
  end
  
  if glued_instance_position_delta_while_open ~= 0 then
    position_changed = true
  end
end


function updateDependents(glued_container, first_selected_item, edited_pool_id, src, length, obey_time_selection)
  local dependent_glued_container, i, dependent, new_src

  -- items unnested & nested only 1 level deep
  updatePooledItems(glued_container, edited_pool_id, src, length)

  for i, dependent in ipairs(numeric_dependents) do
    handlePooledItemsNested2PlusLevels(dependent, first_selected_item, obey_time_selection, length)
  end

  reaper.ClearPeakCache()
end


function updatePooledItems(glued_container, edited_pool_id, new_src, length, nesting_level)
  local all_items_count, glued_container_name_prefix, this_container_name, items_in_glued_pool, i, this_item

  deselectAllItems()

  all_items_count = reaper.CountMediaItems(0)
  glued_container_name_prefix = "gr:"
  this_container_name = glued_container_name_prefix..edited_pool_id
  items_in_glued_pool = {}

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(0, i)
    glued_pool_item = getPooledItem(this_item)

    if glued_pool_item then
      table.insert(items_in_glued_pool, glued_pool_item)
    end
  end

  for i = 1, #items_in_glued_pool do
    this_item = items_in_glued_pool[i]

    updatePooledItem(#items_in_glued_pool, edited_pool_id, glued_container, this_item, new_src, length, nesting_level)
  end
end


function getPooledItem(this_item)
  local glued_container_data, is_glued_container

  glued_container_data = getSetItemData(this_item, glued_container_pool_id_key)
  is_glued_container = glued_container_data and glued_container_data ~= ""

  if is_glued_container then
    return this_item
  end
end


function updatePooledItem(glued_pool_item_count, edited_pool_id, glued_container, this_item, new_src, length, nesting_level)
  local this_item_pool_id, item_is_in_edited_pool, take_name, take, this_is_reglued_container, multiple_glued_pooled_items, this_item_is_nested, current_position, glued_container_position, offset_to_glued_container, new_position, current_src

  this_item_pool_id = getSetItemData(this_item, restored_item_pool_id_key)
  item_is_in_edited_pool = this_item_pool_id == edited_pool_id
  current_position = reaper.GetMediaItemInfo_Value(this_item, api_position_key)
  this_is_reglued_container = glued_container == this_item
  multiple_glued_pooled_items = glued_pool_item_count > 1

  if nesting_level then
    this_item_is_nested = nesting_level > 0

    if this_item_is_nested then
      glued_container_position = reaper.GetMediaItemInfo_Value(glued_container, api_position_key)
      offset_to_glued_container = current_position - glued_container_position
      current_position = current_position + offset_to_glued_container
    end
  end

  if item_is_in_edited_pool then

    if multiple_glued_pooled_items then
      
      if not position_change_response and position_changed == true then
        position_change_response = launchPropagatePositionDialog()
      end

      user_wants_position_change = position_change_response == 6

      if user_wants_position_change then
        new_position = current_position - glued_instance_position_delta_while_open

        reaper.SetMediaItemInfo_Value(this_item, api_position_key, new_position)
      end
    end

    reaper.SetMediaItemInfo_Value(this_item, api_length_key, length)
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
  reselect(dependent.restored_items)

  dependent_glued_container = createGluedContainer(dependent.track, first_selected_item, obey_time_selection, dependent.pool_id, true)
  new_src = getItemAudioSrcFileName(dependent_glued_container)

  updatePooledItems(dependent_glued_container, dependent.pool_id, new_src, length, dependent.nesting_level)
  reaper.DeleteTrack(dependent.track)
end


function reselect( items )
  local i, item

  for i,item in pairs(items) do
    reaper.SetMediaItemSelected(item, true)
  end
end


function initEditGluedContainer()
  local selected_item_count, glued_containers, this_pool_id

  selected_item_count = initAction("edit")

  if selected_item_count == false then return end

  glued_containers = getContainers(selected_item_count)

  if isNotSingleGluedContainer(#glued_containers) == true then return end

  this_pool_id = getSetItemState(glued_containers[1], restored_item_pool_id_key)

  if otherPooledInstanceIsOpen(this_pool_id) then
    handleOtherOpenPooledInstance(item, edit_pool_id)

    return
  end
  
  selectDeselectItems(noncontainers, false)
  doEditGluedContainer()
end


function isNotSingleGluedContainer(num_glued_containers)
  local multiitem_result

  if num_glued_containers == 0 then
    reaper.ShowMessageBox(msg_change_selected_items, "Glue-Reversible Edit can only Edit previously glued container items." , 0)

    return true
  
  elseif num_glued_containers > 1 then
    multiitem_result = reaper.ShowMessageBox("Would you like to Edit the first selected container item (on the top track) only?", "Glue-Reversible Edit can only open one glued container item per action call.", 1)

    if multiitem_result == 2 then
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
    restored_item_pool_id = getSetItemState(item, restored_item_pool_id_key)

    if restored_item_pool_id == edit_pool_id then
      return true
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

  item = getFirstSelectedItem()

  if item then
    pool_id =getSetItemData(item, glued_container_pool_id_key)
  end

  item_is_glued_container = pool_id and item
  glued_container = item

  if item_is_glued_container then
    getSetGluedContainerData(pool_id..edit_data_key_suffix, glued_container)
    processEditGluedContainer(glued_container, pool_id)
    cleanUpAction("MB_Edit-Glue-Reversible")
  end
end


function getSetGluedContainerData(pool_label, glued_container)
  local get, set, pool_data_key_prefix, source_offset_key, length_key, position_key, retval, glued_container_source_offset, glued_container_length, glued_container_position, glued_container_take

  get = not glued_container
  set = glued_container
  source_offset_key = pool_data_key_prefix..pool_label..api_src_offset_key
  length_key = pool_data_key_prefix..pool_label..api_length_key
  position_key = pool_data_key_prefix..pool_label..api_position_key

  if get then
    retval, glued_container_source_offset = getSetStateData(source_offset_key)
    retval, glued_container_length = getSetStateData(length_key)
    retval, glued_container_position = getSetStateData(position_key)

    return glued_container_source_offset, glued_container_length, glued_container_position

  elseif set then
    glued_container_take = reaper.GetActiveTake(glued_container)
    glued_container_source_offset = reaper.GetMediaItemTakeInfo_Value(glued_container_take, api_src_offset_key)
    glued_container_length = reaper.GetMediaItemInfo_Value(glued_container, api_length_key)
    glued_container_position = reaper.GetMediaItemInfo_Value(glued_container, api_position_key)

    getSetStateData(source_offset_key, glued_container_source_offset)
    getSetStateData(length_key, glued_container_length)
    getSetStateData(position_key, glued_container_position)
  end
end


function processEditGluedContainer(item, pool_id)
  local glued_container_source_offset, glued_container_length, preglue_item_state, preglue_item_position, preglue_item_track, preglue_item_source_offset, preglue_item_length

  preglue_item_state, preglue_item_position, preglue_item_offset, preglue_item_length, preglue_item_track = getPreGlueItemState(item)

  deselectAllItems()
  restoreItems(pool_id, preglue_item_track, preglue_item_position, preglue_item_offset, preglue_item_length)
  getSetItemData(item, item_preglue_state_key, preglue_item_state)
  getSetStateData(pool_id..position_data_key_suffix, preglue_item_position)

  reaper.DeleteTrackMediaItem(preglue_item_track, item)
end


function getPreGlueItemState(item)
  local preglue_item_state, preglue_item_position, preglue_item_take, preglue_item_offset, preglue_item_length, preglue_item_track

  preglue_item_state = getSetItemState(item)
  preglue_item_position = reaper.GetMediaItemInfo_Value(item, api_position_key)
  preglue_item_take = reaper.GetActiveTake(item)
  preglue_item_offset = reaper.GetMediaItemTakeInfo_Value(preglue_item_take, api_src_offset_key)
  preglue_item_length = reaper.GetMediaItemInfo_Value(item, api_length_key)
  preglue_item_track = reaper.GetMediaItemTrack(item)

  return preglue_item_state, preglue_item_position, preglue_item_offset, preglue_item_length, preglue_item_track
end


function getSetItemData(item, key, val)
  local get, set, data_param_key, retval

  get = not val
  set = val
  data_param_key = api_data_key..global_script_prefix..key

  if get then
    retval, val = reaper.GetSetMediaItemInfo_String(item, data_param_key, "", false)

    return val

  elseif set then
    reaper.GetSetMediaItemInfo_String(item, data_param_key, val, true)
  end
end


function initSmartAction(obey_time_selection)
  local selected_item_count, pool_id, glue_reversible_action, glue_abort_dialog

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
    reaper.ShowMessageBox(msg_change_selected_items, "Glue-Reversible Smart Glue/Edit can't determine which script to run.", 0)
    setResetItemSelectionSet()

    return
  end

  reaper.Undo_EndBlock("MB_Glue-Reversible-Smart-Glue-Edit", -1)
end


function getSmartAction(selected_item_count)
  local glued_containers, restored_items, no_glued_containers_are_selected, single_glued_container_is_selected, glued_containers_are_selected, restored_item_count, no_open_instances_are_selected, single_open_instance_is_selected, no_restored_items_are_selected, restored_items_are_selected

  glued_containers, restored_items = getContainers(selected_item_count)
  no_glued_containers_are_selected = #glued_containers == 0
  single_glued_container_is_selected = #glued_containers == 1
  glued_containers_are_selected = #glued_containers > 0
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