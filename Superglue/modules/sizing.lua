-- @noindex

local Sizing = {}


local _dev = require("modules.dev")

local loadDependencies, loadCircularDependencies, serpent, _constant, _data, _state, _module_utils, _glue


loadDependencies = (function()
  serpent = require("lib.serpent")
  _constant = require("modules.constant")
  _data = require("modules.data")
  _state = require("modules.state")

  _module_utils = require("module-utils")
end)()


loadCircularDependencies = (function()
  _glue = function() return _module_utils.lazyRequire("glue") end
end)()



function Sizing.prepSizingRegionParams(region_idx, sizing_region_guid)
  local guid_key = _constant.api.regionmarker.guid_key_prefix .. region_idx
  local _, this_guid = reaper.GetSetProjectInfo_String(_constant.api.current_project, guid_key, "", false)

  return this_guid == sizing_region_guid
end


function Sizing.getSizingRegion(sizing_region_guid, region_idx)
  local _, _, all_regions_count = reaper.CountProjectMarkers(_constant.api.current_project)

  repeat

    if Sizing.prepSizingRegionParams(region_idx, sizing_region_guid) then
      local params = { idx = region_idx }
      _, _, params.position, params.end_point = reaper.EnumProjectMarkers3(_constant.api.current_project, region_idx)
      params.length = params.end_point - params.position

      return params
    end

    region_idx = region_idx + 1

  until region_idx >= all_regions_count

  return nil
end


function Sizing.deleteSizingRegion(sizing_region_guid, region_idx)
  local _, _, all_regions_count = reaper.CountProjectMarkers(_constant.api.current_project)

  repeat

    if Sizing.prepSizingRegionParams(region_idx, sizing_region_guid) then
      reaper.DeleteProjectMarkerByIndex(_constant.api.current_project, region_idx, true)

      return true
    end

    region_idx = region_idx + 1

  until region_idx >= all_regions_count

  return false
end


function Sizing.setSizingRegion(pool_id, sizing_region_params, region_idx)
  local retval, new_guid = Sizing.addSizingRegion(pool_id, sizing_region_params, region_idx)

  if new_guid then

    return retval, new_guid

  else

    return nil
  end
end


function Sizing.getSetDeleteSizingRegion(sizing_region_guid_or_pool_id, params_or_delete)
  local region_idx = 0

  if params_or_delete == "delete" then

    return Sizing.deleteSizingRegion(sizing_region_guid_or_pool_id, region_idx)

  elseif not params_or_delete then

    return Sizing.getSizingRegion(sizing_region_guid_or_pool_id, region_idx)

  else

    return Sizing.setSizingRegion(sizing_region_guid_or_pool_id, params_or_delete, region_idx)
  end
end


function Sizing.addSizingRegion(pool_id, params, region_idx)
  local sizing_region_name, sizing_region_label_num, all_regions_count, is_region, this_region_label_num, this_region_is_active

  params.end_point = params.position + params.length
  sizing_region_name = _constant.sizingregion.label.prefix .. pool_id .. _constant.sizingregion.label.suffix
  sizing_region_label_num = reaper.AddProjectMarker2(_constant.api.current_project, _constant.api.regionmarker.is_region, params.position, params.end_point, sizing_region_name, _constant.sizingregion.first_display_num, _constant.sizingregion.color)
  _, _, all_regions_count = reaper.CountProjectMarkers(_constant.api.current_project)

  repeat

    _, is_region, _, _, _, this_region_label_num = reaper.EnumProjectMarkers3(_constant.api.current_project, region_idx)

    if is_region then
      this_region_is_active = this_region_label_num == sizing_region_label_num

      if this_region_is_active then
        local retval, new_guid = Sizing.handleSizingRegionPoolData(region_idx, pool_id)

        return retval, new_guid
      end
    end

    region_idx = region_idx + 1

  until region_idx >= all_regions_count

  return nil
end


function Sizing.handleSizingRegionPoolData(region_idx, pool_id, delete)
  local all_pool_ids_with_active_sizing_regions_retval, all_pool_ids_with_active_sizing_regions, sizing_region_api__key, sizing_region_guid

  all_pool_ids_with_active_sizing_regions_retval, all_pool_ids_with_active_sizing_regions = _data.storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions)

  if delete == "delete" then
    Sizing.deleteSizingRegionPoolData(all_pool_ids_with_active_sizing_regions, pool_id)

  else

    return Sizing.storeSizingRegionPoolData(all_pool_ids_with_active_sizing_regions_retval, all_pool_ids_with_active_sizing_regions, pool_id, region_idx)
  end
end


function Sizing.deleteSizingRegionPoolData(all_pool_ids_with_active_sizing_regions, pool_id)

  if not all_pool_ids_with_active_sizing_regions then return end

  _, all_pool_ids_with_active_sizing_regions = serpent.load(all_pool_ids_with_active_sizing_regions)
  all_pool_ids_with_active_sizing_regions[pool_id] = nil
  all_pool_ids_with_active_sizing_regions = serpent.dump(all_pool_ids_with_active_sizing_regions)

  _data.storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions, all_pool_ids_with_active_sizing_regions)
end


function Sizing.storeSizingRegionPoolData(all_pool_ids_with_active_sizing_regions_retval, all_pool_ids_with_active_sizing_regions, pool_id, region_idx)
  sizing_region_api__key = _constant.api.regionmarker.guid_key_prefix .. region_idx
  _, sizing_region_guid = reaper.GetSetProjectInfo_String(_constant.api.current_project, sizing_region_api__key, "", false)

  if all_pool_ids_with_active_sizing_regions_retval then
    _, all_pool_ids_with_active_sizing_regions = serpent.load(all_pool_ids_with_active_sizing_regions)
    all_pool_ids_with_active_sizing_regions[pool_id] = sizing_region_guid

  else
    all_pool_ids_with_active_sizing_regions = {
      [pool_id] = sizing_region_guid
    }
  end

  all_pool_ids_with_active_sizing_regions = serpent.dump(all_pool_ids_with_active_sizing_regions)

  _data.storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions, all_pool_ids_with_active_sizing_regions)

  return true, sizing_region_guid
end


function Sizing.checkSizingRegionExists(pool_id, selected_items)
  local retval, all_pool_ids_with_active_sizing_regions, sizing_region_guid, region_idx, this_region_guid, sizing_region_user_result

  retval, all_pool_ids_with_active_sizing_regions = _data.storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions)
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

    sizing_region_user_result = Sizing.handleNoSizingRegionExists(selected_items, pool_id)

    return sizing_region_user_result
  end

  return nil
end


function Sizing.handleNoSizingRegionExists(selected_items, pool_id)
  local global_option_time_selection_sets_bounds_enabled, time_selection_start, time_selection_end, no_time_selection_exists, user_response_create_time_selection

  global_option_time_selection_sets_bounds_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.time_selection_sets_bounds_on_glue)
  time_selection_start, time_selection_end = reaper.GetSet_LoopTimeRange(false, false, nil, nil, false)
  no_time_selection_exists = time_selection_end == _constant.position_start_of_project

  if global_option_time_selection_sets_bounds_enabled == "false" then

    return Sizing.handleNoSizer_TimeSelectionBoundsOptionDisabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)

  elseif global_option_time_selection_sets_bounds_enabled == "true" then

    return Sizing.handleNoSizer_TimeSelectionBoundsOptionEnabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)
  end
end


function Sizing.handleNoSizer_TimeSelectionBoundsOptionDisabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)
  local msg_sizing_region__deleted, msg_title_sizing_region__deleted, user_response_reinstate_sizing_region, sizing_region_guid

  msg_sizing_region__deleted = "The sizing region for this Edited Superitem was removed somehow! "
  msg_title_sizing_region__deleted = "Missing sizing region"

  if no_time_selection_exists then
    reaper.ShowMessageBox(msg_sizing_region__deleted .. _constant.brand.name .. " will now create a new sizing region at the bounds of the restored items.", msg_title_sizing_region__deleted, _constant.api.msg.type.ok)
    Sizing.createSizingRegionFromRestoredItems(selected_items, pool_id)

    return false

  else
    user_response_reinstate_sizing_region = reaper.ShowMessageBox(msg_sizing_region__deleted .. " Select Yes to reglue to time selection, or No to create a new sizing region at the bounds of the restored items.", msg_title_sizing_region__deleted, _constant.api.msg.type.yes_no)

    if user_response_reinstate_sizing_region == _constant.api.msg.response.yes then
      sizing_region_guid = Sizing.createSizingRegionFromTimeSelection(pool_id, time_selection_start, time_selection_end)

      return sizing_region_guid

    elseif user_response_reinstate_sizing_region == _constant.api.msg.response.no then
      Sizing.createSizingRegionFromRestoredItems(selected_items, pool_id)

      return false
    end
  end
end


function Sizing.handleNoSizer_TimeSelectionBoundsOptionEnabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)
  local user_response_create_time_selection, sizing_region_guid

  if no_time_selection_exists then
    user_response_create_time_selection = reaper.ShowMessageBox("There's no time selection to set Superitem bounds to. Select Yes to set time selection to the bounds of the restored items, or No to abort Re_glue().", "No time selection", _constant.api.msg.type.yes_no)

    if user_response_create_time_selection == _constant.api.msg.response.yes then
      Sizing.createTimeSelectionFromRestoredItems(selected_items)
      Sizing.createSizingRegionFromRestoredItems(selected_items, pool_id)

      return false

    else

      return false
    end

  else
    sizing_region_guid = Sizing.createSizingRegionFromTimeSelection(pool_id, time_selection_start, time_selection_end)

    return sizing_region_guid
  end
end


function Sizing.createSizingRegionFromRestoredItems(selected_items, pool_id)
  local sizing_region_params = Sizing.getBoundsFromItems(selected_items)

  Sizing.getSetDeleteSizingRegion(pool_id, sizing_region_params)
end


function Sizing.createTimeSelectionFromRestoredItems(selected_items)
  local sizing_region_params = Sizing.getBoundsFromItems(selected_items)

  reaper.GetSet_LoopTimeRange(true, false, sizing_region_params.position, sizing_region_params.end_point, false)
end


function Sizing.createSizingRegionFromTimeSelection(pool_id, time_selection_start, time_selection_end)
  local sizing_region_params, sizing_region_guid

  sizing_region_params = {
    position = time_selection_start,
    end_point = time_selection_end
  }
  sizing_region_params.length = time_selection_end - time_selection_start
  sizing_region_guid = Sizing.getSetDeleteSizingRegion(pool_id, sizing_region_params)

  return sizing_region_guid
end


function Sizing.getBoundsFromItems(items)
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


function Sizing.instantiateDummySizingItem(sizing_params)
  local dummy_sizing_item = reaper.AddMediaItemToTrack(
    _state.action.glue.current_track
  )

  reaper.SetMediaItemPosition(dummy_sizing_item, sizing_params.position, _constant.api.dont_refresh_ui)
  reaper.SetMediaItemLength(dummy_sizing_item, sizing_params.length, _constant.api.dont_refresh_ui)
  reaper.SetMediaItemSelected(dummy_sizing_item, true)

  return dummy_sizing_item
end


function Sizing.getReglueSizing(pool_id, sizing_region_guid, selected_items, this_is_ancestor_superitem_update)
  local user_selected_instance_is_being_reglued, sizing_params

  user_selected_instance_is_being_reglued = not this_is_ancestor_superitem_update
  _state.superitem.pool_parent_last_glue_length = _data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.parent_length)
  _state.superitem.pool_parent_last_glue_length = tonumber(_state.superitem.pool_parent_last_glue_length)

  if user_selected_instance_is_being_reglued then
    sizing_params = Sizing.setUpUserSelectedInstanceReglueSizing(sizing_region_guid, pool_id)

  elseif this_is_ancestor_superitem_update then
    sizing_params = Sizing.setUpParentReglueSizing(pool_id, selected_items)
  end

  return sizing_params
end


function Sizing.setUpUserSelectedInstanceReglueSizing(sizing_region_guid, pool_id)
  local sizing_params, is_active_superitem_reglue

  sizing_params = Sizing.getSetDeleteSizingRegion(sizing_region_guid)
  is_active_superitem_reglue = sizing_params

  if is_active_superitem_reglue then
    Sizing.instantiateDummySizingItem(sizing_params)
    Sizing.getSetDeleteSizingRegion(sizing_region_guid, "delete")
    Sizing.handleSizingRegionPoolData(nil, pool_id, "delete")
  end

  return sizing_params
end


function Sizing.setUpParentReglueSizing(pool_id, selected_items)
  local pool_parent_length_key_label, pool_parent_last_glue_position, pool_parent_last_glue_end_point, sizing_params

  pool_parent_last_glue_position = _data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.parent_position)
  pool_parent_last_glue_position = tonumber(pool_parent_last_glue_position)
  pool_parent_last_glue_end_point = pool_parent_last_glue_position + _state.superitem.pool_parent_last_glue_length
  sizing_params = {
    position = pool_parent_last_glue_position - _state.restored_items.delta.position_delta_near_project_start,
    length = _state.superitem.pool_parent_last_glue_length - _state.restored_items.delta.position_delta_near_project_start,
    end_point = pool_parent_last_glue_end_point - _state.restored_items.delta.position_delta_near_project_start
  }

-- THIS PROBABLY NEEDS TO BE REENABLED (CASE: RESTORED ITEMS SMALLER THAN SIZING PARAMS ON EITHER/BOTH SIDES) BUT MUST BE SELECTED AT THE RIGHT TIME BEFORE _glue(). CURRENTLY THERE IS NO SELECTION SO IT REMAINS AFTER GLUE
  -- Sizing.instantiateDummySizingItem(sizing_params)

  return sizing_params
end


function Sizing.createSizingRegionFromSuperitem(superitem, pool_id, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled)
  local superitem_params, sizing_region_guid

  superitem_params = _data.getSetItemParams(superitem)

  if looped_source_sets_sizing_region__enabled == "true" and superitem_loop_is_enabled then
    superitem_params.length, superitem_params.end_point = Sizing.getSuperitemLoopLength(superitem, superitem_params)
  end

  sizing_region_guid = Sizing.getSetDeleteSizingRegion(pool_id, superitem_params)

  return sizing_region_guid
end


function Sizing.getSuperitemLoopLength(superitem, superitem_params)
  local superitem_active_take, superitem_active_take_source, superitem_length, superitem_end_point

  superitem_active_take = reaper.GetActiveTake(superitem)
  superitem_active_take_source = reaper.GetMediaItemTake_Source(superitem_active_take)
  superitem_length = reaper.GetMediaSourceLength(superitem_active_take_source)
  superitem_end_point = superitem_length - superitem_params.position

  return superitem_length, superitem_end_point
end


function Sizing.handleNewGlueSizing(selected_items, this_is_depool, pool_id, depool_superitem_params)
  local global_option_time_selection_sets_bounds_enabled, sizing_params

  global_option_time_selection_sets_bounds_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.time_selection_sets_bounds_on_glue)

  if global_option_time_selection_sets_bounds_enabled == "true" then
    _state.user.time_selection_before_action.position, _state.user.time_selection_before_action.end_point = reaper.GetSet_LoopTimeRange(false, false, nil, nil, false)
    sizing_params = {
      position = _state.user.time_selection_before_action.position,
      length = _state.user.time_selection_before_action.end_point - _state.user.time_selection_before_action.position,
      end_point = _state.user.time_selection_before_action.end_point
    }

  elseif global_option_time_selection_sets_bounds_enabled == "false" then
    sizing_params = Sizing.getBoundsFromItems(selected_items)
  end

  if this_is_depool then
    sizing_params = _glue().setUpGlueWithDePool(pool_id, depool_superitem_params)

  else
    _sizing.instantiateDummySizingItem(sizing_params)
  end

  return sizing_params
end



return Sizing
