-- @noindex

local Common = {}


local _dev = require("modules.dev")

local loadDependencies, loadCircularDependencies, serpent, _constant, _state, _util, _module_utils, _data, _glue, _init, _lanes


loadDependencies = (function()
  serpent = require("lib.serpent")
  _constant = require("modules.constant")
  _state = require("modules.state")
  _util = require("modules.util")

  _module_utils = require("module-utils")
end)()


loadCircularDependencies = (function()
  _data = function() return _module_utils.lazyRequire("data") end
  _glue = function() return _module_utils.lazyRequire("glue") end
  _init = function() return _module_utils.lazyRequire("init") end
  _lanes = function() return _module_utils.lazyRequire("lanes") end
end)()



function Common.getSuperglueItemTypes(items, requested_types)
  local item_types_data, this_item, superitem_pool_id, restored_item_pool_id, this_requested_item_type

  item_types_data = Common.getItemTypes()

  for i = 1, #items do
    this_item = items[i]
    superitem_pool_id = _data().storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.instance_id)
    restored_item_pool_id = _data().storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)
    item_types_data.superitem.is = superitem_pool_id and superitem_pool_id ~= ""
    item_types_data.restored.is = restored_item_pool_id and restored_item_pool_id ~= ""
    item_types_data.nonsuperitem.is = not item_types_data.superitem.is
    item_types_data.child_instance.is = item_types_data.superitem.is and item_types_data.restored.is
    item_types_data.parent_instance.is = item_types_data.superitem.is and not item_types_data.restored.is
    item_types_data.nonsuperglue.is = not item_types_data.superitem.is and not item_types_data.restored.is

    for j = 1, #requested_types do
      this_requested_item_type = requested_types[j]

      if item_types_data[this_requested_item_type].is then
        table.insert(item_types_data[this_requested_item_type].items, this_item)
      end
    end
  end

  return item_types_data
end


function Common.getItemTypes()
  local item_types, item_types_data, this_item_type

  item_types = {"superitem", "restored", "nonsuperitem", "child_instance", "parent_instance", "nonsuperglue"}
  item_types_data = {}

  for i = 1, #item_types do
    this_item_type = item_types[i]
    item_types_data[this_item_type] = {
      items = {}
    }
  end

  return item_types_data
end


function Common.getSetItemName(item, new_name, add_or_remove)
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

      reaper.GetSetMediaItemTakeInfo_String(take, _constant.api.take.key.name, new_name, _constant.api.set_value)

      return new_name, take

    elseif get then

      return current_name, take
    end
  end
end


function Common.getBoundsFromItems(items)
  local last_item_position, last_item_length, items_params

  last_item_position = reaper.GetMediaItemInfo_Value(items[#items], _constant.api.item.key.position, "", false)
  last_item_length = reaper.GetMediaItemInfo_Value(items[#items], _constant.api.item.key.length, "", false)
  items_params = {
    position = reaper.GetMediaItemInfo_Value(items[1], _constant.api.item.key.position, "", false),
    end_point = last_item_position + last_item_length
  }
  items_params.length = items_params.end_point - items_params.position

  return items_params
end


function Common.getSetSizingRegion(sizing_region_guid_or_pool_id, params_or_delete)
  local get_or_delete, set, region_idx, retval, all_markers_count, all_regions_count, retval, sizing_region_params, sizing_region_guid, all_regions_in_proj_have_been_iterated

  get_or_delete = not params_or_delete or params_or_delete == "delete"
  set = params_or_delete and params_or_delete ~= "delete"
  region_idx = 0
  retval, all_markers_count, all_regions_count = reaper.CountProjectMarkers(_constant.api.current_project)

  repeat

    if get_or_delete then
      retval, sizing_region_params = _glue().getParamsFrom_OrDelete_SizingRegion(sizing_region_guid_or_pool_id, params_or_delete, region_idx)

      if sizing_region_params then

        return sizing_region_params
      end

    elseif set then
      sizing_region_params = params_or_delete
      retval, sizing_region_guid = _glue().addSizingRegion(sizing_region_guid_or_pool_id, sizing_region_params, region_idx)

      if sizing_region_guid then

        return sizing_region_guid
      end
    end

    region_idx = region_idx + 1
    all_regions_in_proj_have_been_iterated = region_idx > all_regions_count

  until retval == 0 or all_regions_in_proj_have_been_iterated
end


function Common.selectDeselectItems(items, select_deselect)
  local this_item

  for i = 1, #items do
    this_item = items[i]

    if this_item then
      reaper.SetMediaItemSelected(this_item, select_deselect)
    end
  end
end


function Common.refreshActiveTakeFlag(item, active_take, pool_id)
  local all_takes, superitem_superglue_active_take_key, this_take, flag_value

  all_takes = reaper.CountTakes(item)
  superitem_superglue_active_take_key = _constant.api.data_key .. _constant.brand.prefix.global .. _constant.data.key.prefix.pool .. pool_id .. _constant.data.key.suffix.superitem.superglue_active_take

  for i = 0, all_takes-1 do
    this_take = reaper.GetTake(item, i)
    flag_value = this_take == active_take and "true" or "false"

    -- if this_take == active_take then
    --   reaper.GetSetMediaItemTakeInfo_String(this_take, superitem_superglue_active_take_key, "true", _constant.api.set_value)

    -- else
    --   reaper.GetSetMediaItemTakeInfo_String(this_take, superitem_superglue_active_take_key, "false", _constant.api.set_value)
    -- end

    reaper.GetSetMediaItemTakeInfo_String(this_take, superitem_superglue_active_take_key, flag_value, _constant.api.set_value)
  end
end


function Common.addRemoveItemImage(item, type_or_remove)
  local item_images_are_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.item_images) == "true"

  if item_images_are_enabled then
    local add = type_or_remove
    local type = type_or_remove
    local remove = type_or_remove == false
    local img_path = ""

    if add then
      if type == "superitem" then
        img_path = _constant.file.path.superitem_bg_img
      elseif type == "restored" then
        img_path = _constant.file.path.restored_item_bg_img
      elseif type == "restored_instance" then
        img_path = _constant.file.path.restored_instance_bg_img
      end
    elseif remove then
      img_path = ""
    end

    -- Use fixed height without lane calculations
    local base_height = _constant.api.item.image_full_height

    reaper.BR_SetMediaItemImageResource(item, img_path, base_height)
  end
end


function Common.getImagePathForType(type_or_remove)
  if type_or_remove == false then return "" end

  local paths = {
    superitem = _constant.file.path.superitem_bg_img,
    restored = _constant.file.path.restored_item_bg_img,
    restored_instance = _constant.file.path.restored_instance_bg_img
  }

  return paths[type_or_remove] or ""
end


function Common.setSuperitemColor()
  local global_option_toggle_new_superglue_random_color = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.new_superglue_random_color)

  if global_option_toggle_new_superglue_random_color == "true" then
    reaper.Main_OnCommand(_constant.cmd.set_item_to_one_random_color, _constant.api.cmd_flag)
  end
end


function Common.handleOfflineTake(item, context)
  local active_take, active_src, active_take_is_online, src_filepath, src_exists, src_filename, src_filepath_in_project_folder, user_response, user_chosen_file

  active_take = reaper.GetActiveTake(item)
  active_src = reaper.GetMediaItemTake_Source(active_take)
  active_take_is_online = reaper.CF_GetMediaSourceOnline(active_src)

  if not active_take_is_online then
    src_filepath = reaper.GetMediaSourceFileName(active_src)
    src_exists = _util.fileExists(src_filepath)

    if not src_exists then
      src_filename = _util.getFileNameFromPath(src_filepath)
      src_filepath_in_project_folder = _constant.file.path.proj_render .. _constant.file.os.separator .. src_filename
      src_exists = _util.fileExists(src_filepath_in_project_folder)

      if src_exists then
        reaper.BR_SetTakeSourceFromFile2(active_take, src_filepath_in_project_folder, true, true)

      else
        user_response = reaper.ShowMessageBox(_constant.brand.name .. " can't find a media source. Choose a new source file for the offline " .. context .. " item. Press OK to continue, or Cancel to leave it offline.", "Offline take selected", _constant.api.msg.type.ok_cancel)

        if user_response == _constant.api.msg.response.ok then
          _, user_chosen_file = reaper.JS_Dialog_BrowseForOpenFiles("Choose a new source file for the offline item.", _constant.file.path.proj_render, src_filename, _constant.file.supported_media_types, false)

          reaper.BR_SetTakeSourceFromFile2(active_take, user_chosen_file, true, true)
        end
      end
    end
  end
end


function Common.dePoolRestoredItem(item)
  local item_instance_pool_id, item_is_instance, item_type

  _data().storeRetrieveItemData(item, _constant.data.key.suffix.pool.parent_id, "")

  item_instance_pool_id = _data().storeRetrieveItemData(item, _constant.data.key.suffix.pool.instance_id)
  item_is_instance = item_instance_pool_id and item_instance_pool_id ~= ""
  item_type = item_is_instance and "superitem" or false

  -- if item_is_instance then
  --   Common.addRemoveItemImage(item, "superitem")

  -- else
  --   Common.addRemoveItemImage(item, false)
  -- end

  Common.addRemoveItemImage(item, item_type)
end


function Common.checkSizingRegionExists(pool_id, selected_items)
  local retval, all_pool_ids_with_active_sizing_regions, sizing_region_guid, region_idx, this_region_guid, sizing_region_user_result

  retval, all_pool_ids_with_active_sizing_regions = _data().storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions)
  retval, all_pool_ids_with_active_sizing_regions = serpent.load(all_pool_ids_with_active_sizing_regions)
  sizing_region_guid = all_pool_ids_with_active_sizing_regions[pool_id]

  if sizing_region_guid and sizing_region_guid ~= "" then
    region_idx = 0

    repeat
      retval, this_region_guid = reaper.GetSetProjectInfo_String(_constant.api.current_project, _constant.api.regionmarker.guid_key_prefix .. region_idx, "", false)

      if retval and this_region_guid == sizing_region_guid then
        return this_region_guid
      end

      region_idx = region_idx + 1
    until retval == false

    sizing_region_user_result = Common.handleNoSizingRegionExists(selected_items, pool_id)

    return sizing_region_user_result
  end

  return nil
end


function Common.handleNoSizingRegionExists(selected_items, pool_id)
  local global_option_time_selection_sets_bounds_enabled, time_selection_start, time_selection_end, no_time_selection_exists, user_response_create_time_selection

  global_option_time_selection_sets_bounds_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.time_selection_sets_bounds_on_glue)
  time_selection_start, time_selection_end = reaper.GetSet_LoopTimeRange(false, false, nil, nil, false)
  no_time_selection_exists = time_selection_end == _constant.position_start_of_project

  if global_option_time_selection_sets_bounds_enabled == "false" then

    return Common.handleNoSizer_TimeSelectionBoundsOptionDisabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)

  elseif global_option_time_selection_sets_bounds_enabled == "true" then

    return Common.handleNoSizer_TimeSelectionBoundsOptionEnabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)
  end
end


function Common.handleNoSizer_TimeSelectionBoundsOptionDisabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)
  local msg_sizing_region__deleted, msg_title_sizing_region__deleted, user_response_reinstate_sizing_region, sizing_region_guid

  msg_sizing_region__deleted = "The sizing region for this Edited Superitem was removed somehow! "
  msg_title_sizing_region__deleted = "Missing sizing region"

  if no_time_selection_exists then
    reaper.ShowMessageBox(msg_sizing_region__deleted .. _constant.brand.name .. " will now create a new sizing region at the bounds of the restored items.", msg_title_sizing_region__deleted, _constant.api.msg.type.ok)
    Common.createSizingRegionFromRestoredItems(selected_items, pool_id)

    return false

  else
    user_response_reinstate_sizing_region = reaper.ShowMessageBox(msg_sizing_region__deleted .. " Select Yes to reglue to time selection, or No to create a new sizing region at the bounds of the restored items.", msg_title_sizing_region__deleted, _constant.api.msg.type.yes_no)

    if user_response_reinstate_sizing_region == _constant.api.msg.response.yes then
      sizing_region_guid = Common.createSizingRegionFromTimeSelection(pool_id, time_selection_start, time_selection_end)

      return sizing_region_guid

    elseif user_response_reinstate_sizing_region == _constant.api.msg.response.no then
      Common.createSizingRegionFromRestoredItems(selected_items, pool_id)

      return false
    end
  end
end


function Common.handleNoSizer_TimeSelectionBoundsOptionEnabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)
  local user_response_create_time_selection, sizing_region_guid

  if no_time_selection_exists then
    user_response_create_time_selection = reaper.ShowMessageBox("There's no time selection to set Superitem bounds to. Select Yes to set time selection to the bounds of the restored items, or No to abort Reglue.", "No time selection", _constant.api.msg.type.yes_no)

    if user_response_create_time_selection == _constant.api.msg.response.yes then
      Common.createTimeSelectionFromRestoredItems(selected_items)
      Common.createSizingRegionFromRestoredItems(selected_items, pool_id)

      return false

    else

      return false
    end

  else
    sizing_region_guid = Common.createSizingRegionFromTimeSelection(pool_id, time_selection_start, time_selection_end)

    return sizing_region_guid
  end
end


function Common.createSizingRegionFromRestoredItems(selected_items, pool_id)
  local sizing_region_params = Common.getBoundsFromItems(selected_items)

  Common.getSetSizingRegion(pool_id, sizing_region_params)
end


function Common.createTimeSelectionFromRestoredItems(selected_items)
  local sizing_region_params = Common.getBoundsFromItems(selected_items)

  reaper.GetSet_LoopTimeRange(true, false, sizing_region_params.position, sizing_region_params.end_point, false)
end


function Common.createSizingRegionFromTimeSelection(pool_id, time_selection_start, time_selection_end)
  local sizing_region_params, sizing_region_guid

  sizing_region_params = {
    position = time_selection_start,
    end_point = time_selection_end
  }
  sizing_region_params.length = time_selection_end - time_selection_start
  sizing_region_guid = Common.getSetSizingRegion(pool_id, sizing_region_params)

  return sizing_region_guid
end


function Common.getSetWipeItemAudioSrc(item, src_or_wipe)
  local get, set, wipe, take, source, filename, filename_is_valid, src

  get = not src_or_wipe
  set = src_or_wipe and src_or_wipe ~= "wipe"
  wipe = src_or_wipe == "wipe"

  if get then
    take = reaper.GetActiveTake(item)
    source = reaper.GetMediaItemTake_Source(take)
    filename = reaper.GetMediaSourceFileName(source)
    filename_is_valid = string.len(filename) > 0

    if filename_is_valid then
      return filename
    end

  elseif set then
    src = src_or_wipe
    take = reaper.GetActiveTake(item)

    reaper.BR_SetTakeSourceFromFile2(take, src, false, true)

  elseif wipe then
    src = Common.getSetWipeItemAudioSrc(item)

    os.remove(src)
    os.remove(src .. _constant.file.name.peak_data_extension)
  end
end


function Common.restoreStoredItems(pool_id, active_track, superitem, this_is_ancestor_superitem_update, action, superitemLane)
  local stored_item_states_table, restored_items, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled

  if _constant.support.fixed_lanes then
    _lanes().debugLaneInfo("RESTORE START", nil, active_track, pool_id)

    -- Make sure track is in fixed lanes mode for consistent lane calculations
    local currentMode = reaper.GetMediaTrackInfo_Value(active_track, "I_FOLDERCOMPACT")
    if currentMode ~= 2 then
      reaper.SetMediaTrackInfo_Value(active_track, "I_FOLDERCOMPACT", 2)
      reaper.UpdateArrange()
    end
  end

  stored_item_states_table = _data().getStoredItemStatesTable(pool_id, action)
  restored_items = {}

  _data().defineStoredItemsParams(pool_id)

  -- Create all items first without lane positioning
  for item_guid, stored_item_state in pairs(stored_item_states_table) do
    if stored_item_state then
      _state.superitem.params.preunglue.unglued_pool = _data().getSetItemParams(superitem)
      local restored_item = Common.handleRestoredItem(superitem, active_track, stored_item_state, {}, this_is_ancestor_superitem_update, action)
      table.insert(restored_items, restored_item)
    end
  end

  -- CRITICAL: Apply lane positioning only AFTER all items are created and ONLY ONCE
  if _constant.support.fixed_lanes and #restored_items > 0 then
    if _dev.config.test_logging_enabled then
      _dev.log("Calling restoreItemLaneOffsets for " .. #restored_items .. " items")
    end

    _lanes().restoreItemLaneOffsets(restored_items, false, pool_id)
    _lanes().debugLaneInfo("AFTER RESTORE", restored_items, active_track, pool_id)
  end

  return restored_items, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled
end


function Common.handleRestoredItem(superitem, active_track, stored_item_state, restored_instances_near_project_start, this_is_ancestor_superitem_update, action)
  local restored_item, restored_instance_pool_id, restored_item_negative_position_delta, this_is_first_edit_after_auto_depool, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled

  restored_item = Common.restoreItem(active_track, stored_item_state, this_is_ancestor_superitem_update)
  restored_instance_pool_id = _data().storeRetrieveItemData(restored_item, _constant.data.key.suffix.pool.instance_id)

  Common.handleOfflineTake(restored_item, "restored")
  reaper.SetMediaItemSelected(restored_item, true)
  Common.handleRestoredItemImage(restored_item, restored_instance_pool_id, action)

  if not this_is_ancestor_superitem_update then
    restored_item, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled = Common.adjustRestoredItem(superitem, restored_item, action)
  end

  if action == "Unglue" or action == "DePool" then
    _data().storeRetrieveItemData(restored_item, _constant.data.key.suffix.pool.parent_id, "")
  end

  return restored_item, restored_instances_near_project_start, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled
end


function Common.handleRestoredItemImage(restored_item, restored_instance_pool_id, action)
  local this_restored_item_is_instance, image_type

  this_restored_item_is_instance = restored_instance_pool_id and restored_instance_pool_id ~= ""

  if action == "Unglue" then
    image_type = this_restored_item_is_instance and "superitem" or false

    -- if this_restored_item_is_instance then
    --   Common.addRemoveItemImage(restored_item, "superitem")

    -- else
    --   Common.addRemoveItemImage(restored_item, false)
    -- end

  else
    image_type = this_restored_item_is_instance and "restored_instance" or "restored"

  --   if this_restored_item_is_instance then
  --     Common.addRemoveItemImage(restored_item, "restored_instance")

  --   else
  --     Common.addRemoveItemImage(restored_item, "restored")
  --   end
  end

  Common.addRemoveItemImage(restored_item, image_type)
end


function Common.restoreItem(track, state, this_is_ancestor_superitem_update)
  local restored_item = reaper.AddMediaItemToTrack(track)

  if state then
    _data().getSetItemStateChunk(restored_item, state)
  end

  if not this_is_ancestor_superitem_update then
    Common.restoreOriginalMidiTake(restored_item)
  end

  return restored_item
end


function Common.restoreOriginalMidiTake(item)
  local item_takes_count, preglue_active_midi_take_guid, preglue_active_midi_take, rendered_audio_take, rendered_audio_take_num, global_option_toggle_retain_only_last_glue_source_enabled

  item_takes_count = reaper.GetMediaItemNumTakes(item)

  if item_takes_count > 0 then
    preglue_active_midi_take_guid = _data().storeRetrieveItemData(item, _constant.data.key.suffix.preglue.active_take_guid)
    preglue_active_midi_take = reaper.SNM_GetMediaItemTakeByGUID(_constant.api.current_project, preglue_active_midi_take_guid)

    if preglue_active_midi_take then
      rendered_audio_take = reaper.GetActiveTake(item)
      rendered_audio_take_num = reaper.GetMediaItemTakeInfo_Value(rendered_audio_take, "IP_TAKENUMBER")
      global_option_toggle_retain_only_last_glue_source_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.retain_only_last_glue_source)

      if global_option_toggle_retain_only_last_glue_source_enabled == "true" then
        Common.getSetWipeItemAudioSrc(item, "wipe")
      end

      reaper.NF_DeleteTakeFromItem(item, rendered_audio_take_num)
      reaper.SetActiveTake(preglue_active_midi_take)
      _glue().cleanNullTakes(item)
    end
  end
end


function Common.adjustRestoredItem(superitem, restored_item, action)
  local restored_item_params, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled, adjusted_restored_item_position_is_before_project_start, restored_item_negative_position

  restored_item_params = _data().getSetItemParams(restored_item)
  restored_item_params.position, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled = Common.getRestoredItemPositionDeltaSinceLastGlue(superitem, restored_item, restored_item_params, action)
  adjusted_restored_item_position_is_before_project_start = restored_item_params.position < 0

  reaper.SetMediaItemPosition(restored_item, restored_item_params.position, _constant.api.dont_refresh_ui)

  return restored_item, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled
end


function Common.getRestoredItemPositionDeltaSinceLastGlue(superitem, restored_item, restored_item_params, action)
  local looped_source_sets_sizing_region__enabled, this_item_position_delta_to_last_glue_superitem_instance, superitem_loop_is_enabled, superitem_active_take, superitem_source, superitem_source_length, superitem_loop_starts_in_later_half, restored_item_altered_position

  looped_source_sets_sizing_region__enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.loop_source_sets_sizing_region_bounds_on_reglue)
  superitem_loop_is_enabled = reaper.GetMediaItemInfo_Value(superitem, _constant.api.item.key.loop_src) == _constant.api.timeline.loop_enabled
  superitem_active_take = reaper.GetActiveTake(superitem)
  superitem_source = reaper.GetMediaItemTake_Source(superitem_active_take)
  superitem_source_length = reaper.GetMediaSourceLength(superitem_source)

  if action == "Edit" or action == "Unglue" or action == "Smart Glue/Edit" or action == "Smart Glue/Unglue" then
    superitem_loop_starts_in_later_half = _state.superitem.params.preunglue.unglued_pool.source_offset > (superitem_source_length / 2)
    this_item_position_delta_to_last_glue_superitem_instance = _state.superitem.params.preunglue.unglued_pool.position - _state.superitem.params.post_glue.edited_pool.position - _state.superitem.params.preunglue.unglued_pool.source_offset

    if _state.superitem.this_previously_depooled_superitem_has_not_been_edited ~= "true" then
      this_item_position_delta_to_last_glue_superitem_instance = this_item_position_delta_to_last_glue_superitem_instance + _state.superitem.params.post_glue.edited_pool.source_offset
    end

    if looped_source_sets_sizing_region__enabled == "true" and superitem_loop_is_enabled and superitem_loop_starts_in_later_half then
      this_item_position_delta_to_last_glue_superitem_instance = this_item_position_delta_to_last_glue_superitem_instance + superitem_source_length
    end

  elseif action == "DePool" then
    this_item_position_delta_to_last_glue_superitem_instance = _state.superitem.params.preunglue.unglued_pool.position - _state.superitem.params.post_glue.edited_pool.position + _state.superitem.params.post_glue.edited_pool.source_offset
  end

  restored_item_altered_position = restored_item_params.position + this_item_position_delta_to_last_glue_superitem_instance

  return restored_item_altered_position, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled
end


function Common.getUserPropagationChoice(propagation_option, ext_state_key)
  local option_value, user_choice

  option_value = reaper.GetExtState(_constant.data.key.options.global_section, ext_state_key)

  if not _state.propagation.user_responses[propagation_option] and option_value == "ask" then
    _state.propagation.user_responses[propagation_option] = Common.launchPropagateDialog(propagation_option)
  end

  user_choice = option_value == "always" or _state.propagation.user_responses[propagation_option] == _constant.api.msg.response.yes

  return user_choice
end


function Common.launchPropagateDialog(param)
  local propagate_dialog_params, global_option_propagate_default, msg_title, msg_content

  propagate_dialog_params = Common.getPropagateDialogValues()
  global_option_propagate_default = reaper.GetExtState(_constant.data.key.options.global_section, propagate_dialog_params[param].global_option_param_key)
  msg_title = _constant.brand.name .. ": " .. propagate_dialog_params[param].message_title_string .. " changed"
  msg_content = "The " .. propagate_dialog_params[param].message_title_string .. " of the Superitem you're regluing has changed! Do you want to adjust pool sibling Superitems' " .. propagate_dialog_params[param].message_content_string

  if global_option_propagate_default == "ask" then

    return reaper.ShowMessageBox(msg_content, msg_title, _constant.api.msg.type.yes_no)

  elseif global_option_propagate_default == "always" then

    return _constant.api.msg.response.yes

  elseif global_option_propagate_default == "no" then

    return _constant.api.msg.response.no
  end
end


function Common.getPropagateDialogValues()
  local propagate_dialog_data, propagate_dialog_params

  propagate_dialog_data = {
    {"source_position", _constant.data.key.options.defaults.maintain_source_position, "audio source timeline locations so they remain in the same place?", "source position"},
    {"length", _constant.data.key.options.defaults.propagate_length, "lengths to match?", "length"},
    {"position", _constant.data.key.options.defaults.propagate_position, "left edge to adjust as well?", "left edge position"},
    {"absolute_length_propagation", _constant.data.key.options.defaults.length_propagation_type, "length to match the Edited Superitem? (No = alter sibling length relatively by the length change amount)", "length"},
    {"playrate_toggle", _constant.data.key.options.defaults.playrate_affects_propagation, "position and/or length in proportion to their playrates?", "length and/or position"}
  }
  propagate_dialog_params = {}

  for i = 1, #propagate_dialog_data do
    propagate_dialog_params[propagate_dialog_data[i][1]] = {
      global_option_param_key = propagate_dialog_data[i][2],
      message_content_string = propagate_dialog_data[i][3],
      message_title_string = propagate_dialog_data[i][4]
    }
  end

  return propagate_dialog_params
end


function Common.setAllSuperitemsColor(action)
  local current_window, retval, color, pool_ids, all_items_count, this_item, this_item_instance_pool_id

  current_window = reaper.GetMainHwnd()
  retval, color = reaper.GR_SelectColor(current_window)
  pool_ids = {}

  if retval ~= 0 then
    _init().prepareAction("color")

    all_items_count = reaper.CountMediaItems(_constant.api.current_project)

    for i = 0, all_items_count-1 do
      this_item = reaper.GetMediaItem(_constant.api.current_project, i)
      this_item_instance_pool_id = _data().storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.instance_id)

      if this_item_instance_pool_id and this_item_instance_pool_id ~= "" then
        reaper.SetMediaItemInfo_Value(this_item, _constant.api.item.key.color, color|0x1000000)
        table.insert(pool_ids, this_item_instance_pool_id)
      end
    end

    _init().cleanUpAction(action, pool_ids)
  end
end



return Common
