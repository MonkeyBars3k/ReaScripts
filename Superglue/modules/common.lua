-- @noindex

local Common = {}


local _dev = require("modules.dev")

local loadDependencies, loadCircularDependencies, _constant, _state, _util, _module_utils, _data, _glue, _init, _lanes


loadDependencies = (function()
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


function Common.restoreStoredItems(pool_id, active_track, superitem, this_is_ancestor_superitem_update, action)
  local stored_item_states_table, restored_items, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled

  stored_item_states_table = _data().getStoredItemStatesTable(pool_id, action)
  restored_items = {}

  _data().defineStoredItemsParams(pool_id)

  for _, stored_item_state in pairs(stored_item_states_table) do

    if stored_item_state then
      _state.superitem.params.preunglue.unglued_pool = _data().getSetItemParams(superitem)
      local restored_item = Common.handleRestoredItem(superitem, active_track, stored_item_state, {}, this_is_ancestor_superitem_update, action)

      table.insert(restored_items, restored_item)
    end
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
    restored_item, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled = Common.adjustRestoredItem(superitem, restored_item, active_track, action)
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


function Common.adjustRestoredItem(superitem, restored_item, active_track, action)
  local restored_item_params, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled

  restored_item_params = _data().getSetItemParams(restored_item)
  restored_item_params.position, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled = Common.getRestoredItemPositionDeltaSinceLastGlue(superitem, restored_item, restored_item_params, action)

  reaper.SetMediaItemPosition(restored_item, restored_item_params.position, _constant.api.dont_refresh_ui)
  _lanes().restoreItemLaneDelta(restored_item, superitem, active_track)

  return restored_item, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled
end


function Common.getRestoredItemPositionDeltaSinceLastGlue(superitem, restored_item, restored_item_params, action)
  local looped_source_sets_sizing_region__enabled, this_item_position_delta_to_last_glue_superitem_instance, superitem_loop_is_enabled, superitem_active_take, superitem_source, superitem_source_length, superitem_loop_starts_in_later_half, restored_item_altered_position

  -- Log state values that affect calculation
  -- _dev.log("RESTORE: item_params.position = " .. restored_item_params.position)
  -- _dev.log("RESTORE: preunglue.position = " .. _state.superitem.params.preunglue.unglued_pool.position)
  -- _dev.log("RESTORE: post_glue.position = " .. _state.superitem.params.post_glue.edited_pool.position)
  -- _dev.log("RESTORE: preunglue.source_offset = " .. _state.superitem.params.preunglue.unglued_pool.source_offset)

  -- if _state.superitem.params.post_glue.edited_pool.source_offset then
  --   _dev.log("RESTORE: post_glue.source_offset = " .. _state.superitem.params.post_glue.edited_pool.source_offset)
  -- end

  looped_source_sets_sizing_region__enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.loop_source_sets_sizing_region_bounds_on_reglue)
  superitem_loop_is_enabled = reaper.GetMediaItemInfo_Value(superitem, _constant.api.item.key.loop_src) == _constant.api.timeline.loop_enabled
  superitem_active_take = reaper.GetActiveTake(superitem)
  superitem_source = reaper.GetMediaItemTake_Source(superitem_active_take)
  superitem_source_length = reaper.GetMediaSourceLength(superitem_source)

  if action == "Edit" or action == "Unglue" or string.find(action, "Smart") or string.find(action, "DePool") then
    superitem_loop_starts_in_later_half = _state.superitem.params.preunglue.unglued_pool.source_offset > (superitem_source_length / 2)
    this_item_position_delta_to_last_glue_superitem_instance = _state.superitem.params.preunglue.unglued_pool.position - _state.superitem.params.post_glue.edited_pool.position - _state.superitem.params.preunglue.unglued_pool.source_offset

    if _state.superitem.this_previously_depooled_superitem_has_not_been_edited ~= "true" then
      this_item_position_delta_to_last_glue_superitem_instance = this_item_position_delta_to_last_glue_superitem_instance + _state.superitem.params.post_glue.edited_pool.source_offset
    end

    if looped_source_sets_sizing_region__enabled == "true" and superitem_loop_is_enabled and superitem_loop_starts_in_later_half then
      this_item_position_delta_to_last_glue_superitem_instance = this_item_position_delta_to_last_glue_superitem_instance + superitem_source_length
    end

  elseif string.find(action, "DePool") then
    this_item_position_delta_to_last_glue_superitem_instance = _state.superitem.params.preunglue.unglued_pool.position - _state.superitem.params.post_glue.edited_pool.position + _state.superitem.params.post_glue.edited_pool.source_offset
  end

  restored_item_altered_position = restored_item_params.position + this_item_position_delta_to_last_glue_superitem_instance

  -- _dev.log("RESTORE: actual position_delta = " .. this_item_position_delta_to_last_glue_superitem_instance)
  -- _dev.log("RESTORE: final position = " .. restored_item_altered_position)

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


-- function Common.exclusiveSelectItem(item)

--   if item then
--     reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)
--     reaper.SetMediaItemSelected(item, true)

--   else

--     return false
--   end
-- end



return Common
