-- @noindex

local Glue = {}


local loadDependencies, loadCircularDependencies, serpent, _constant, _depool, _init, _lanes, _state, _util, _module_utils, _common, _data

local _dev = require("modules.dev")

loadDependencies = (function()
  serpent = require("lib.serpent")
  _constant = require("modules.constant")
  _depool = require("modules.depool")
  _init = require("modules.init")
  _lanes = require("modules.lanes")
  _state = require("modules.state")
  _util = require("modules.util")

  _module_utils = require("module-utils")
end)()


loadCircularDependencies = (function()
  _common = function() return _module_utils.lazyRequire("common") end
  _data = function() return _module_utils.lazyRequire("data") end
end)()



function Glue.handleGlue(selected_items, pool_id, sizing_region_guid, depool_superitem_params, this_is_ancestor_superitem_update)
  local this_is_depool, first_selected_item, first_selected_item_name, pool_id, sizing_params, this_is_reglue, selected_items_pool_params, items_to_glue

  this_is_depool = depool_superitem_params ~= nil
  first_selected_item = selected_items[1]
  first_selected_item_name = _common().getSetItemName(first_selected_item)

  pool_id, sizing_params, this_is_reglue = Glue.setUpGlue(depool_superitem_params, this_is_ancestor_superitem_update, pool_id, sizing_region_guid, selected_items)

  selected_items_pool_params = Glue.handlePreglueItems(selected_items, pool_id, sizing_params, this_is_reglue, this_is_depool)

  items_to_glue = reaper.CountSelectedMediaItems(0)

  -- why is this here?
  -- for i = 0, items_to_glue-1 do
  --   local item = reaper.GetSelectedMediaItem(0, i)
  -- end

-- if _constant.support.fixed_lanes then
--   _lanes.debugLaneInfo("BEFORE GLUE", selected_items, reaper.GetMediaItemTrack(selected_items[1]), pool_id)
-- end

  local superitem = Glue.glueSelectedItemsIntoSuperitem()

  Glue.handlePostGlue(selected_items, pool_id, first_selected_item_name, superitem, selected_items_pool_params, sizing_params, this_is_reglue, this_is_ancestor_superitem_update)

  return superitem
end


function Glue.setUpGlue(depool_superitem_params, this_is_ancestor_superitem_update, pool_id, sizing_region_guid, selected_items)
  local this_is_new_glue, this_is_depool, this_is_reglue, sizing_params, global_option_toggle_depool_all_siblings_on_reglue

  this_is_new_glue = not pool_id
  this_is_depool = depool_superitem_params
  this_is_reglue = pool_id ~= nil


-- DO DESELECTION *ONLY* ON THIS TRACK IF THIS GLUE IS MULTITRACK?? IF SO, EXPAND _common().selectDeselectItems() TO SUPPORT TRACK ARGUMENT AND CALL THAT INSTEAD
  reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)

  if this_is_new_glue then
    pool_id = Glue.handlePoolId()
    sizing_params = Glue.handleNewGlueSizing(selected_items, this_is_depool, pool_id, depool_superitem_params)

  elseif this_is_reglue then
    sizing_params = Glue.getReglueSizing(pool_id, sizing_region_guid, selected_items, this_is_ancestor_superitem_update)
    -- global_option_toggle_depool_all_siblings_on_reglue = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.depool_all_siblings_on_reglue)

    -- if global_option_toggle_depool_all_siblings_on_reglue == "true" then


-- THIS LINE CAUSES SIBLING DEPOOLED SUPERITEM POSITION TO GO WEIRD – TEST FURTHER -- IS THIS STILL THE CASE??
      _state.restored_items.preglue_restored_item_states = _data().storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.contained_item_states)


    -- end
  end

  return pool_id, sizing_params, this_is_reglue
end


function Glue.handlePoolId()
  local retval, last_pool_id, new_pool_id

  retval, last_pool_id = _data().storeRetrieveProjectData(_constant.data.key.suffix.pool.last_id)
  new_pool_id = Glue.incrementPoolId(last_pool_id)

  _data().storeRetrieveProjectData(_constant.data.key.suffix.pool.last_id, new_pool_id)

  return new_pool_id
end


function Glue.incrementPoolId(last_pool_id)
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


function Glue.handleNewGlueSizing(selected_items, this_is_depool, pool_id, depool_superitem_params)
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
    sizing_params = _common().getBoundsFromItems(selected_items)
  end

  if this_is_depool then
    sizing_params = Glue.setUpGlueWithDePool(pool_id, depool_superitem_params)

  else
    Glue.instantiateDummySizingItem(sizing_params)
  end

  return sizing_params
end


function Glue.setUpGlueWithDePool(pool_id, depool_superitem_params)
  local sizing_params

  _state.restored_items.last_glue_stored_item_states = _data().storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.contained_item_states)
  sizing_params = {
    position = depool_superitem_params.position,
    end_point = depool_superitem_params.end_point
  }
  sizing_params.length = sizing_params.end_point - sizing_params.position

  _data().storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.last_glue.contained_item_states, _state.restored_items.last_glue_stored_item_states)
  Glue.instantiateDummySizingItem(sizing_params)

  return sizing_params
end


function Glue.instantiateDummySizingItem(sizing_params)
  local dummy_sizing_item = reaper.AddMediaItemToTrack(
    _state.action.glue.current_track
  )

  reaper.SetMediaItemPosition(dummy_sizing_item, sizing_params.position, _constant.api.dont_refresh_ui)
  reaper.SetMediaItemLength(dummy_sizing_item, sizing_params.length, _constant.api.dont_refresh_ui)
  reaper.SetMediaItemSelected(dummy_sizing_item, true)

  return dummy_sizing_item
end


function Glue.getReglueSizing(pool_id, sizing_region_guid, selected_items, this_is_ancestor_superitem_update)
  local user_selected_instance_is_being_reglued, sizing_params

  user_selected_instance_is_being_reglued = not this_is_ancestor_superitem_update
  _state.superitem.pool_parent_last_glue_length = _data().storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.parent_length)
  _state.superitem.pool_parent_last_glue_length = tonumber(_state.superitem.pool_parent_last_glue_length)

  if user_selected_instance_is_being_reglued then
    sizing_params = Glue.setUpUserSelectedInstanceReglueSizing(sizing_region_guid, pool_id)

  elseif this_is_ancestor_superitem_update then
    sizing_params = Glue.setUpParentReglueSizing(pool_id, selected_items)
  end

  return sizing_params
end


function Glue.setUpUserSelectedInstanceReglueSizing(sizing_region_guid, pool_id)
  local sizing_params, is_active_superitem_reglue

  sizing_params = _common().getSetSizingRegion(sizing_region_guid)
  is_active_superitem_reglue = sizing_params

  if is_active_superitem_reglue then
    Glue.instantiateDummySizingItem(sizing_params)
    _common().getSetSizingRegion(sizing_region_guid, "delete")
    Glue.handleSizingRegionPoolData(nil, pool_id, "delete")
  end

  return sizing_params
end


function Glue.getParamsFrom_OrDelete_SizingRegion(sizing_region_guid_or_pool_id, params_or_delete, region_idx)
  local get, delete, sizing_region_guid, sizing_region_api__key, this_region_guid, this_region_belongs_to_active_pool, sizing_region_params, retval, is_region

  get = not params_or_delete
  delete = params_or_delete == "delete"
  sizing_region_guid = sizing_region_guid_or_pool_id
  sizing_region_api__key = _constant.api.regionmarker.guid_key_prefix .. region_idx
  _, this_region_guid = reaper.GetSetProjectInfo_String(_constant.api.current_project, sizing_region_api__key, "", false)
  this_region_belongs_to_active_pool = this_region_guid == sizing_region_guid

  if this_region_belongs_to_active_pool then

    if get then
      sizing_region_params = {
        idx = region_idx
      }
      retval, is_region, sizing_region_params.position, sizing_region_params.end_point = reaper.EnumProjectMarkers3(_constant.api.current_project, region_idx)
      sizing_region_params.length = sizing_region_params.end_point - sizing_region_params.position

      return retval, sizing_region_params

    elseif delete then
      reaper.DeleteProjectMarkerByIndex(_constant.api.current_project, region_idx, true)

      retval = 0

      return retval
    end

  else
    retval = nil

    return retval
  end
end


function Glue.addSizingRegion(sizing_region_guid_or_pool_id, params_or_delete, region_idx)
  local params, pool_id, sizing_region_name, sizing_region_label_num, retval, is_region, this_region_position, this_region_end_point, this_region_name, this_region_label_num, this_region_is_active

  params = params_or_delete
  params.end_point = params.position + params.length
  pool_id = sizing_region_guid_or_pool_id
  sizing_region_name = _constant.sizingregion.label.prefix .. pool_id .. _constant.sizingregion.label.suffix
  sizing_region_label_num = reaper.AddProjectMarker2(_constant.api.current_project, true, params.position, params.end_point, sizing_region_name, _constant.sizingregion.first_display_num, _constant.sizingregion.color)
  retval, is_region, this_region_position, this_region_end_point, this_region_name, this_region_label_num = reaper.EnumProjectMarkers3(_constant.api.current_project, region_idx)

  if is_region then
    this_region_is_active = this_region_label_num == sizing_region_label_num

    if this_region_is_active then
      local guid_result, new_guid = Glue.handleSizingRegionPoolData(region_idx, pool_id)

      return guid_result, new_guid
    end
  end

  return retval
end


function Glue.handleSizingRegionPoolData(region_idx, pool_id, delete)
  local all_pool_ids_with_active_sizing_regions_retval, all_pool_ids_with_active_sizing_regions, sizing_region_api__key, sizing_region_guid

  all_pool_ids_with_active_sizing_regions_retval, all_pool_ids_with_active_sizing_regions = _data().storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions)

  if delete == "delete" then

    if all_pool_ids_with_active_sizing_regions then
      _, all_pool_ids_with_active_sizing_regions = serpent.load(all_pool_ids_with_active_sizing_regions)
      all_pool_ids_with_active_sizing_regions[pool_id] = nil
      all_pool_ids_with_active_sizing_regions = serpent.dump(all_pool_ids_with_active_sizing_regions)

      _data().storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions, all_pool_ids_with_active_sizing_regions)
    end

  else
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

    _data().storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions, all_pool_ids_with_active_sizing_regions)

    return retval, sizing_region_guid
  end
end


function Glue.setUpParentReglueSizing(pool_id, selected_items)
  local pool_parent_length_key_label, pool_parent_last_glue_position, pool_parent_last_glue_end_point, sizing_params

  pool_parent_last_glue_position = _data().storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.parent_position)
  pool_parent_last_glue_position = tonumber(pool_parent_last_glue_position)
  pool_parent_last_glue_end_point = pool_parent_last_glue_position + _state.superitem.pool_parent_last_glue_length
  sizing_params = {
    position = pool_parent_last_glue_position - _state.restored_items.delta.position_delta_near_project_start,
    length = _state.superitem.pool_parent_last_glue_length - _state.restored_items.delta.position_delta_near_project_start,
    end_point = pool_parent_last_glue_end_point - _state.restored_items.delta.position_delta_near_project_start
  }

-- THIS PROBABLY NEEDS TO BE REENABLED (CASE: RESTORED ITEMS SMALLER THAN SIZING PARAMS ON EITHER/BOTH SIDES) BUT MUST BE SELECTED AT THE RIGHT TIME BEFORE GLUE. CURRENTLY THERE IS NO SELECTION SO IT REMAINS AFTER GLUE
  -- Glue.instantiateDummySizingItem(sizing_params)

  return sizing_params
end


function Glue.handlePreglueItems(selected_items, pool_id, sizing_params, this_is_reglue, this_is_depool)
  local selected_item_states, selected_items_pool_params

  _lanes.storeItemLaneDeltas(selected_items)

  selected_item_states, selected_items_pool_params = _data().prepareAndGetItemStates(selected_items, pool_id)

  _data().storeItemStates(pool_id, selected_item_states)
  _common().selectDeselectItems(selected_items, true)

  return selected_items_pool_params
end


function Glue.setPreglueItemsData(preglue_items, pool_id, sizing_params, this_is_reglue, this_is_depool)
  local this_is_new_glue, global_option_time_selection_sets_bounds_enabled, this_item, this_item_position, first_item_position, first_child_position_delta_to_parent

  this_is_new_glue = not this_is_reglue
  global_option_time_selection_sets_bounds_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.time_selection_sets_bounds_on_glue)

  for i = 1, #preglue_items do
    this_item = preglue_items[i]
    this_item_position = reaper.GetMediaItemInfo_Value(this_item, _constant.api.item.key.position)

    _data().storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id, pool_id)

    if i == 1 or this_item_position < first_item_position then
      first_item_position = this_item_position
    end
  end

  first_child_position_delta_to_parent = (this_is_new_glue and not this_is_depool) and 0 or first_item_position - sizing_params.position

  -- if this_is_new_glue and not this_is_depool then
  --   first_child_position_delta_to_parent = 0

  -- else
  --   first_child_position_delta_to_parent = first_item_position - sizing_params.position
  -- end

  _data().storeRetrievePoolData(pool_id, _constant.data.key.suffix.superitem.first_child_delta_to_superitem_position, first_child_position_delta_to_parent)
end


function Glue.convertMidiItemToAudio(item)
  local item_takes_count, active_take, this_take_is_midi, retval, active_take_guid

  item_takes_count = reaper.GetMediaItemNumTakes(item)

  if item_takes_count > 0 then
    active_take = reaper.GetActiveTake(item)
    this_take_is_midi = active_take and reaper.TakeIsMIDI(active_take)

    if this_take_is_midi then
      active_take = reaper.GetActiveTake(item)
      retval, active_take_guid = reaper.GetSetMediaItemTakeInfo_String(active_take, _constant.api.take.key.guid, "", false)

      _data().storeRetrieveItemData(item, _constant.data.key.suffix.preglue.active_take_guid, active_take_guid)
      reaper.SetMediaItemSelected(item, true)
      reaper.Main_OnCommand(_constant.cmd.apply_track_take_fx_to_items, _constant.api.cmd_flag)
      reaper.SetMediaItemSelected(item, false)
      Glue.cleanNullTakes(item)

    else
      _data().storeRetrieveItemData(item, _constant.data.key.suffix.preglue.active_take_guid, "")
    end
  end
end


function Glue.cleanNullTakes(item, force)
  local item_state = _data().getSetItemStateChunk(item)

  if string.find(item_state, _constant.api.take.null_takes_val) or force then
    item_state = string.gsub(item_state, _constant.api.take.null_takes_val, "")

    _data().getSetItemStateChunk(item, item_state)
  end
end


function Glue.glueSelectedItemsIntoSuperitem()
  local increase_channel_count_from_take_fx, superitem

  increase_channel_count_from_take_fx = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.auto_increase_channel_count)

  if increase_channel_count_from_take_fx == "true" then
    reaper.Main_OnCommand(_constant.cmd.apply_fx_to_items_multichannel, _constant.api.cmd_flag)
    reaper.Main_OnCommand(_constant.cmd.crop_selected_items_to_active_takes, _constant.api.cmd_flag)
  end

  reaper.Main_OnCommand(_constant.cmd.glue_ignoring_time_selection_incl_fades, _constant.api.cmd_flag)

  superitem = _init.getFirstSelectedItem()

  return superitem
end


function Glue.handlePostGlue(selected_items, pool_id, first_selected_item_name, superitem, selected_items_pool_params, sizing_params, this_is_reglue, this_is_ancestor_superitem_update)
  local superitem_init_name

  superitem_init_name = Glue.handleAddtionalItemCountLabel(selected_items, pool_id, first_selected_item_name)

  _state.pool.active_glue_pool_id = pool_id

  Glue.handleSuperitemPostGlue(superitem, superitem_init_name, pool_id, sizing_params, this_is_reglue)
  Glue.handleDescendantPoolReferences(pool_id, selected_items_pool_params)

  if not this_is_ancestor_superitem_update then
    Glue.handleParentPoolReferencesInChildPools(pool_id, selected_items_pool_params)
    Glue.deleteUnselectedContainedItems()
  end

  if not this_is_reglue then
    _common().addRemoveItemImage(superitem, "superitem")
  end
end


function Glue.handleAddtionalItemCountLabel(selected_items, pool_id, first_selected_item_name)
  local selected_item_count, multiple_user_items_are_selected, other_selected_items_count, is_nested_superitem_name, has_nested_item_name, item_name_addl_count_str, superitem_init_name

  selected_item_count = _util.getTableSize(selected_items)
  multiple_user_items_are_selected = selected_item_count > 1
  other_selected_items_count = selected_item_count - 1
  is_nested_superitem_name = string.find(first_selected_item_name, _constant.brand.prefix.superitem_name_default)
  has_nested_item_name = string.find(first_selected_item_name, _constant.regex.nested_item_default_name)

  if multiple_user_items_are_selected then
    item_name_addl_count_str = " +" .. other_selected_items_count ..  " more"

  else
    item_name_addl_count_str = ""
  end

  if is_nested_superitem_name and has_nested_item_name then
    first_selected_item_name = string.match(first_selected_item_name, _constant.brand.prefix.superitem_name_default)
  end

  superitem_init_name = pool_id .. " [" .. _constant.unicode.double_quotation_mark .. first_selected_item_name .. _constant.unicode.double_quotation_mark .. item_name_addl_count_str .. "]"

  return superitem_init_name
end


function Glue.handleSuperitemPostGlue(superitem, superitem_init_name, pool_id, sizing_params, this_is_reglue)
  local this_is_fresh_glue, superitem_active_take, superitem_params

  this_is_fresh_glue = not this_is_reglue
  superitem_active_take = reaper.GetActiveTake(superitem)

  Glue.setSuperitemParams(superitem, superitem_active_take, sizing_params, this_is_reglue)

  superitem_params = _data().getSetItemParams(superitem)

  if this_is_fresh_glue then
    Glue.renameSuperitemSource(superitem, pool_id)
    _common().setSuperitemColor()

  elseif this_is_reglue then
    _common().handleOfflineTake(superitem, "reglued")
  end

  if not _state.superitem.active_instance_length_has_changed then
    _state.superitem.active_instance_length_has_changed = _state.superitem.pool_parent_last_glue_length ~= superitem_params.length
  end

  Glue.setSuperitemName(superitem, superitem_init_name)
  Glue.handleSuperitemPostGlueData(pool_id, superitem, superitem_params, superitem_active_take)
end


function Glue.setSuperitemParams(superitem, superitem_active_take, sizing_params, this_is_reglue)
  local global_option_time_selection_sets_bounds_enabled, user_time_selection_is_active, superitem_new_left_edge, superitem_new_right_edge

  global_option_time_selection_sets_bounds_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.time_selection_sets_bounds_on_glue)
  user_time_selection_is_active = _util.getTableSize(_state.user.time_selection_before_action) > 0

  if this_is_reglue then
    superitem_new_left_edge = sizing_params.position
    superitem_new_right_edge = sizing_params.end_point

  elseif global_option_time_selection_sets_bounds_enabled == "true" and user_time_selection_is_active then
    superitem_new_left_edge = _state.user.time_selection_before_action.position
    superitem_new_right_edge = _state.user.time_selection_before_action.end_point
  end

  if superitem_new_left_edge and superitem_new_right_edge then
    reaper.BR_SetItemEdges(superitem, superitem_new_left_edge, superitem_new_right_edge)
  end
end


function Glue.renameSuperitemSource(superitem, pool_id)
  local superitem_active_take, superitem_active_take_source_filepath, superitem_source_new_filepath, superitem_source_new_filepath_extension, escaped_extension

  superitem_active_take, superitem_active_take_source_filepath, superitem_source_new_filepath = Glue.getSuperitemActiveTakeInfo(superitem, pool_id)

  for i in string.gmatch(superitem_source_new_filepath, _constant.regex.file_extension) do
    superitem_source_new_filepath_extension = "." .. i
  end

  escaped_extension = _util.escapeRegexSpecialCharacters(superitem_source_new_filepath_extension)

  if _util.fileExists(superitem_source_new_filepath) then
    superitem_source_new_filepath = string.gsub(superitem_source_new_filepath, escaped_extension, "-redo" .. superitem_source_new_filepath_extension)

    _util.copyFile(superitem_active_take_source_filepath, superitem_source_new_filepath)
    os.remove(superitem_active_take_source_filepath)

  else
    os.rename(superitem_active_take_source_filepath, superitem_source_new_filepath)
  end

  reaper.BR_SetTakeSourceFromFile2(superitem_active_take, superitem_source_new_filepath, true, true)
  reaper.Main_OnCommand(_constant.cmd.build_missing_peaks, _constant.api.cmd_flag)
end


function Glue.getSuperitemActiveTakeInfo(superitem, pool_id)
  local project_path, superitem_active_take, superitem_active_take_source, superitem_active_take_source_peaks, superitem_active_take_source_filepath, superitem_active_take_source_filename, superitem_source_new_filepath

  project_path = reaper.GetProjectPath()
  superitem_active_take = reaper.GetActiveTake(superitem)
  superitem_active_take_source = reaper.GetMediaItemTake_Source(superitem_active_take)
  superitem_active_take_source_filepath = reaper.GetMediaSourceFileName(superitem_active_take_source)

  for i in string.gmatch(superitem_active_take_source_filepath, _constant.file.path.splitter) do
    superitem_active_take_source_filename = i
  end

  superitem_source_new_filepath = project_path .. _constant.file.os.separator .. _constant.brand.prefix.item_name .. _constant.file.name.custom_separator .. _constant.data.key.prefix.pool .. pool_id .. _constant.file.name.custom_separator .. superitem_active_take_source_filename

  return superitem_active_take, superitem_active_take_source_filepath, superitem_source_new_filepath
end


function Glue.setSuperitemName(item, superitem_name_ending)
  local take, new_superitem_name

  take = reaper.GetActiveTake(item)
  new_superitem_name = _constant.brand.prefix.superitem_name .. superitem_name_ending

  reaper.GetSetMediaItemTakeInfo_String(take, _constant.api.take.key.name, new_superitem_name, _constant.api.set_value)
end


function Glue.handleSuperitemPostGlueData(pool_id, superitem, superitem_params, superitem_active_take)
  _data().storeRetrieveSuperitemParams(pool_id, _constant.actionstep.postglue, superitem)
  _data().storeRetrieveItemData(superitem, _constant.data.key.suffix.pool.instance_id, pool_id)
  _data().storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.parent_position, superitem_params.position)
  _data().storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.parent_length, superitem_params.length)
  _data().storeRetrievePoolData(pool_id, _constant.actionstep.freshly_depooled_superitem_flag, "false")
  _common().refreshActiveTakeFlag(superitem, superitem_active_take, pool_id)
end


function Glue.handleDescendantPoolReferences(pool_id, contained_items_pool_params)
  local this_pool_descendants, this_contained_item_instance_pool_id, this_contained_item_params, this_selected_item_is_superitem, this_child_pool_descendant_pool_ids, this_pool_descendants_string

  this_pool_descendants = {}

  for this_contained_item_instance_pool_id, this_contained_item_params in pairs(contained_items_pool_params) do
    this_selected_item_is_superitem = not string.find(this_contained_item_instance_pool_id, _constant.noninstance_label)

    if this_selected_item_is_superitem then
      this_child_pool_descendant_pool_ids = _data().storeRetrievePoolData(this_contained_item_instance_pool_id, _constant.data.key.suffix.pool.descendant_ids)

      table.insert(this_pool_descendants, this_contained_item_instance_pool_id)

      for j = 1, #this_child_pool_descendant_pool_ids do
        table.insert(this_pool_descendants, this_child_pool_descendant_pool_ids[j])
      end
    end
  end

  this_pool_descendants = _util.deduplicateTable(this_pool_descendants)
  this_pool_descendants_string = serpent.dump(this_pool_descendants)

  _data().storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.descendant_ids, this_pool_descendants_string)
end


function Glue.handleParentPoolReferencesInChildPools(active_pool_id, contained_items_pool_params)
  local this_contained_item_instance_pool_id, this_contained_item_params, this_selected_item_is_superitem

  for this_contained_item_instance_pool_id, this_contained_item_params in pairs(contained_items_pool_params) do
    this_selected_item_is_superitem = not string.find(this_contained_item_instance_pool_id, _constant.noninstance_label)

    if this_selected_item_is_superitem then
      Glue.storeParentPoolReferencesInChildPool(this_contained_item_instance_pool_id, active_pool_id)
    end
  end
end


function Glue.storeParentPoolReferencesInChildPool(preglue_child_instance_pool_id, active_pool_id)
  local parent_pool_ids_data_key_label, retval, parent_pool_ids_referenced_in_child_pool, this_parent_pool_id, this_parent_pool_id_is_referenced_in_child_pool

  parent_pool_ids_data_key_label = _constant.data.key.prefix.pool .. preglue_child_instance_pool_id .. _constant.data.key.suffix.pool.parent_ids_data
  retval, parent_pool_ids_referenced_in_child_pool = _data().storeRetrieveProjectData(parent_pool_ids_data_key_label)

  if retval == false then
    parent_pool_ids_referenced_in_child_pool = {}

  else
    retval, parent_pool_ids_referenced_in_child_pool = serpent.load(parent_pool_ids_referenced_in_child_pool)
  end

  for i = 1, #parent_pool_ids_referenced_in_child_pool do
    this_parent_pool_id = parent_pool_ids_referenced_in_child_pool[i]

    if this_parent_pool_id == active_pool_id then
      this_parent_pool_id_is_referenced_in_child_pool = true
    end
  end

  if not this_parent_pool_id_is_referenced_in_child_pool then
    active_pool_id = tostring(active_pool_id)

    table.insert(parent_pool_ids_referenced_in_child_pool, active_pool_id)

    parent_pool_ids_referenced_in_child_pool = serpent.dump(parent_pool_ids_referenced_in_child_pool)

    _data().storeRetrieveProjectData(parent_pool_ids_data_key_label, parent_pool_ids_referenced_in_child_pool)
  end
end


function Glue.deleteUnselectedContainedItems()
  local this_contained_item_outside, this_contained_item_track

  if _state.restored_items.unselected_contained_items then

    for i = 1, #_state.restored_items.unselected_contained_items do
      this_contained_item_outside = _state.restored_items.unselected_contained_items[i]
      this_contained_item_track = reaper.GetMediaItem_Track(this_contained_item_outside)

      reaper.DeleteTrackMediaItem(this_contained_item_track, this_contained_item_outside)
    end
  end

  _state.restored_items.unselected_contained_items = nil
end


function Glue.handleReglue(selected_items, restored_items_pool_id)
  local sizing_region_guid, superitem, superitem_params

  sizing_region_guid = _common().checkSizingRegionExists(restored_items_pool_id, selected_items)

  if not sizing_region_guid then return false end

  _data().cleanUnselectedRestoredItemsFromPool(restored_items_pool_id)

  _state.superitem.params.last_glue.edited_pool = _data().storeRetrieveSuperitemParams(restored_items_pool_id, _constant.actionstep.postglue)
  superitem = Glue.handleGlue(selected_items, restored_items_pool_id, sizing_region_guid, nil, nil)
  superitem, superitem_params = Glue.handleReglueSuperitemParams(superitem, restored_items_pool_id)

  Glue.setRegluePositionDeltas(superitem_params) -- ARGUMENT NECESSARY HERE??
  Glue.adjustPostGlueTakeMarkersAndEnvelopes(superitem, nil, nil, true)
  Glue.reglueAncestors(superitem_params.pool_id, superitem)
  reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)
  Glue.propagateChangesToSuperitems(superitem, sizing_region_guid)
  reaper.ClearPeakCache()

  return superitem
end


function Glue.handleReglueSuperitemParams(superitem, restored_items_pool_id)
  local superitem_params, global_option_toggle_retain_only_last_glue_source_enabled

  superitem_params = _data().getSetItemParams(superitem)
  superitem_params.updated_src = _common().getSetWipeItemAudioSrc(superitem)
  superitem_params.pool_id = restored_items_pool_id
  superitem = _data().restoreSuperitemState(superitem, superitem_params)
  _state.superitem.params.fresh_glue.edited_pool = superitem_params
  _state.superitem.params.preedit.edited_pool = _data().storeRetrieveSuperitemParams(_state.superitem.params.fresh_glue.edited_pool.pool_id, _constant.actionstep.preedit)
  global_option_toggle_retain_only_last_glue_source_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.retain_only_last_glue_source)

  if global_option_toggle_retain_only_last_glue_source_enabled == "true" then
    _common().getSetWipeItemAudioSrc(superitem, "wipe")
  end

  return superitem, superitem_params
end


function Glue.setRegluePositionDeltas()
  _state.superitem.params.fresh_glue.edited_pool, _state.superitem.params.preedit.edited_pool, _state.superitem.params.last_glue.edited_pool = _util.numberizeAndRoundElements(
    {_state.superitem.params.fresh_glue.edited_pool, _state.superitem.params.preedit.edited_pool, _state.superitem.params.last_glue.edited_pool},
    {"position", "source_offset"}
  )
  _state.superitem.delta.position_during_glue = _state.superitem.params.fresh_glue.edited_pool.position - _state.superitem.params.preedit.edited_pool.position
  _state.superitem.delta.position_during_glue = _util.round(_state.superitem.delta.position_during_glue, _constant.api.time_value_decimal_resolution)
  _state.superitem.reglue_position_change_affect_on_length = _state.superitem.params.fresh_glue.edited_pool.length - _state.superitem.params.preedit.edited_pool.length
  _state.superitem.delta.offset_since_last_glue = _state.superitem.params.fresh_glue.edited_pool.source_offset - _state.superitem.params.last_glue.edited_pool.source_offset
  _state.superitem.delta.offset_since_last_glue = _util.round(_state.superitem.delta.offset_since_last_glue, _constant.api.time_value_decimal_resolution)

  if _state.superitem.delta.position_during_glue ~= 0 then
    _state.superitem.position_changed_since_last_glue = true
  end

  if _state.superitem.delta.offset_since_last_glue ~= 0 then
    _state.superitem.offset_changed_since_last_glue = true
  end
end


function Glue.adjustPostGlueTakeMarkersAndEnvelopes(instance, adjustment_near_project_start, fresh_glue_source_offset, this_is_edited_superitem)
  local instance_position, instance_active_take, instance_current_src_offset, instance_playrate, envelope_point_position_adjustment_delta, take_marker_position_adjustment_delta

  instance_position, instance_active_take, instance_current_src_offset, instance_playrate, fresh_glue_source_offset = Glue.getParamsForTakeMarkersAndEnvelopes(instance, instance_active_take, fresh_glue_source_offset)
  envelope_point_position_adjustment_delta, take_marker_position_adjustment_delta = Glue.getDeltasForTakeMarkersAndEnvelopes(adjustment_near_project_start, instance_position, instance_current_src_offset, instance_playrate, this_is_edited_superitem)

  Glue.adjustTakeEnvelopes(instance_active_take, envelope_point_position_adjustment_delta)
  Glue.adjustTakeMarkers(instance_active_take, take_marker_position_adjustment_delta, fresh_glue_source_offset)
  Glue.handleTakeStretchMarkers(instance_active_take, take_marker_position_adjustment_delta, fresh_glue_source_offset)
end


function Glue.getParamsForTakeMarkersAndEnvelopes(instance, instance_active_take, fresh_glue_source_offset)
  local instance_position, instance_active_take, instance_current_src_offset, instance_playrate

  instance_position = reaper.GetMediaItemInfo_Value(instance, _constant.api.item.key.position)
  instance_active_take = reaper.GetActiveTake(instance)
  instance_current_src_offset = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _constant.api.take.key.src_offset)
  instance_playrate = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _constant.api.take.key.playrate)

  if not fresh_glue_source_offset then
    fresh_glue_source_offset = 0
  end

  return instance_position, instance_active_take, instance_current_src_offset, instance_playrate, fresh_glue_source_offset
end


function Glue.getDeltasForTakeMarkersAndEnvelopes(adjustment_near_project_start, instance_position, instance_current_src_offset, instance_playrate, this_is_edited_superitem)
  local envelope_point_position_adjustment_delta, take_marker_position_adjustment_delta

  if this_is_edited_superitem or _state.propagation.user_wants_option.position then
    envelope_point_position_adjustment_delta = -_state.superitem.delta.offset_since_last_glue
    take_marker_position_adjustment_delta = -_state.superitem.delta.offset_since_last_glue

  else
    envelope_point_position_adjustment_delta = 0
    take_marker_position_adjustment_delta = 0
  end

  if adjustment_near_project_start then

    if instance_position == 0 then
      envelope_point_position_adjustment_delta = 0
      take_marker_position_adjustment_delta = adjustment_near_project_start - instance_current_src_offset

    else
      envelope_point_position_adjustment_delta = instance_position * instance_playrate
      take_marker_position_adjustment_delta = adjustment_near_project_start - instance_current_src_offset + (instance_position * instance_playrate)
    end
  end

  return envelope_point_position_adjustment_delta, take_marker_position_adjustment_delta
end


function Glue.adjustTakeEnvelopes(instance_active_take, position_adjustment_delta)
  local take_envelopes_count, this_take_envelope, envelope_points_count, j, retval, this_envelope_point_position, adjusted_envelope_point_position

  take_envelopes_count = reaper.CountTakeEnvelopes(instance_active_take)

  if take_envelopes_count > 0 then

    for i = 0, take_envelopes_count-1 do
      this_take_envelope = reaper.GetTakeEnvelope(instance_active_take, i)
      envelope_points_count = reaper.CountEnvelopePoints(this_take_envelope)

      for j = 0, envelope_points_count-1 do
        retval, this_envelope_point_position = reaper.GetEnvelopePoint(this_take_envelope, j)
        adjusted_envelope_point_position = this_envelope_point_position + position_adjustment_delta

        reaper.SetEnvelopePoint(this_take_envelope, j, adjusted_envelope_point_position, nil, nil, nil, nil, true)
      end
    end
  end
end


function Glue.adjustTakeMarkers(instance_active_take, position_adjustment_delta, fresh_glue_source_offset)
  local take_markers_count, all_take_markers, this_marker_position, this_marker_name, retval, adjusted_marker_position

  take_markers_count = reaper.GetNumTakeMarkers(instance_active_take)

  if take_markers_count > 0 then
    all_take_markers = {}

    for i = 0, take_markers_count-1 do
      this_marker_position, this_marker_name = reaper.GetTakeMarker(instance_active_take, i)

      table.insert(all_take_markers, {
        position = this_marker_position,
        name = this_marker_name
      })
    end

    repeat
      retval = reaper.DeleteTakeMarker(instance_active_take, 0)

    until retval == false

    for i = 1, #all_take_markers do
      adjusted_marker_position = all_take_markers[i].position + position_adjustment_delta + fresh_glue_source_offset

      reaper.SetTakeMarker(instance_active_take, _constant.api.take.new_take_marker_idx, all_take_markers[i].name, adjusted_marker_position)
    end
  end
end


function Glue.handleTakeStretchMarkers(instance_active_take, position_adjustment_delta, fresh_glue_source_offset)
  local stretch_markers_count, marker_position_adjustment, marker_source_position_adjustment

  stretch_markers_count = reaper.GetTakeNumStretchMarkers(instance_active_take)

  if stretch_markers_count > 0 then
    _state.propagation.user_wants_option.source_position = _common().getUserPropagationChoice("source_position", _constant.data.key.options.defaults.maintain_source_position)

    if _state.propagation.user_wants_option.source_position then
      marker_position_adjustment = position_adjustment_delta
      marker_source_position_adjustment = position_adjustment_delta + fresh_glue_source_offset

    else
      marker_position_adjustment = 0
      marker_source_position_adjustment = 0
    end

    Glue.adjustTakeStretchMarkers(instance_active_take, stretch_markers_count, marker_position_adjustment, marker_source_position_adjustment)
  end
end


function Glue.adjustTakeStretchMarkers(instance_active_take, stretch_markers_count, marker_position_adjustment, marker_source_position_adjustment)
  local all_stretch_markers, this_marker_position, this_marker_source_position, adjusted_marker_position, adjusted_marker_source_position

  all_stretch_markers = {}

  for i = 0, stretch_markers_count-1 do
    _, this_marker_position, this_marker_source_position = reaper.GetTakeStretchMarker(instance_active_take, i)

    table.insert(all_stretch_markers, {
      position = this_marker_position,
      source_position = this_marker_source_position
    })
  end

  reaper.DeleteTakeStretchMarkers(instance_active_take, 0, stretch_markers_count)

  for i = 1, #all_stretch_markers do
    adjusted_marker_position = all_stretch_markers[i].position + marker_position_adjustment
    adjusted_marker_source_position = all_stretch_markers[i].source_position + marker_source_position_adjustment

    reaper.SetTakeStretchMarker(instance_active_take, _constant.api.take.new_take_marker_idx, adjusted_marker_position, adjusted_marker_source_position)
  end
end


function Glue.reglueAncestors(pool_id, superitem, descendant_nesting_depth_of_active_parent)
  local parent_pool_ids_data_key_label, retval, parent_pool_ids, parent_pool_ids_data_found_for_active_pool, this_parent_pool_id, parent_pool_is_present_in_overglue_pools

  parent_pool_ids_data_key_label = _constant.data.key.prefix.pool .. pool_id .. _constant.data.key.suffix.pool.parent_ids_data
  retval, parent_pool_ids = _data().storeRetrieveProjectData(parent_pool_ids_data_key_label)
  parent_pool_ids_data_found_for_active_pool = retval == true

  if not descendant_nesting_depth_of_active_parent then
    descendant_nesting_depth_of_active_parent = 1
  end

  if parent_pool_ids_data_found_for_active_pool then
    retval, parent_pool_ids = serpent.load(parent_pool_ids)

    if #parent_pool_ids > 0 then
      _state.user.time_selection_before_action.position, _state.user.time_selection_before_action.end_point = reaper.GetSet_LoopTimeRange(false, false, nil, nil, false)

      for i = 1, #parent_pool_ids do
        this_parent_pool_id = parent_pool_ids[i]
        parent_pool_is_present_in_overglue_pools = _util.isPresentInArray(this_parent_pool_id, _state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor)

        if not parent_pool_is_present_in_overglue_pools then

          if _state.superitem.params.ancestor_pools[this_parent_pool_id] then
            Glue.assignParentNestingDepth(this_parent_pool_id, descendant_nesting_depth_of_active_parent)

          else
            Glue.traverseAncestorsUsingTempTracks(this_parent_pool_id, superitem, descendant_nesting_depth_of_active_parent)
          end
        end
      end

      reaper.GetSet_LoopTimeRange(true, false, _state.user.time_selection_before_action.position, _state.user.time_selection_before_action.end_point, false)
    end
  end
end


function Glue.assignParentNestingDepth(this_parent_pool_id, descendant_nesting_depth_of_active_parent)
  _state.superitem.params.ancestor_pools[this_parent_pool_id].children_nesting_depth = math.max(descendant_nesting_depth_of_active_parent, _state.superitem.params.ancestor_pools[this_parent_pool_id].children_nesting_depth)
end


function Glue.traverseAncestorsUsingTempTracks(this_parent_pool_id, superitem, descendant_nesting_depth_of_active_parent)
  local this_parent_is_ancestor_in_project, this_parent_instance_params, this_parent_instance_is_item_in_project

  this_parent_instance_params = Glue.getFirstPoolInstanceParams(this_parent_pool_id)
  this_parent_instance_is_item_in_project = this_parent_instance_params

  if not this_parent_instance_is_item_in_project then
    this_parent_is_ancestor_in_project = Glue.checkParentPoolIsAncestorInProject(this_parent_pool_id)

    if this_parent_is_ancestor_in_project then
      this_parent_instance_params = {}
    end
  end

  if this_parent_instance_is_item_in_project or this_parent_is_ancestor_in_project then
    Glue.setUpAncestorReglues(this_parent_instance_params, this_parent_pool_id, descendant_nesting_depth_of_active_parent, superitem)
  end
end


function Glue.getFirstPoolInstanceParams(pool_id)
  local all_items_count, this_item, this_item_instance_pool_id, parent_instance_params

  all_items_count = reaper.CountMediaItems(_constant.api.current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_constant.api.current_project, i)
    this_item_instance_pool_id = _data().storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.instance_id)
    this_item_instance_pool_id = tonumber(this_item_instance_pool_id)

    if this_item_instance_pool_id == pool_id then
      parent_instance_params = _data().getSetItemParams(this_item)

      return parent_instance_params
    end
  end

  return false
end


function Glue.checkParentPoolIsAncestorInProject(this_parent_pool_id)
  local all_pool_ids_in_project, this_pool, this_pool_descendant_pool_ids, this_pool_descendant_pool_id

  all_pool_ids_in_project = Glue.getAllPoolIdsInProject()

  for i = 1, #all_pool_ids_in_project do
    this_pool = all_pool_ids_in_project[i]

    if this_pool == this_parent_pool_id then

      return true
    end

    this_pool_descendant_pool_ids = _data().storeRetrievePoolData(this_pool, _constant.data.key.suffix.pool.descendant_ids)
    _, this_pool_descendant_pool_ids = serpent.load(this_pool_descendant_pool_ids)

    if this_pool_descendant_pool_ids then

      for j = 1, #this_pool_descendant_pool_ids do
        this_pool_descendant_pool_id = tonumber(this_pool_descendant_pool_ids[j])

        if this_pool_descendant_pool_id == this_parent_pool_id then

          return true
        end
      end
    end
  end

  Glue.deletePoolDescendantsData(this_parent_pool_id)

  return false
end


function Glue.getAllPoolIdsInProject()
  local all_items_count, all_pool_ids_in_project, this_item, this_item_instance_pool_id

  all_items_count = reaper.CountMediaItems(_constant.api.current_project)
  all_pool_ids_in_project = {}

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_constant.api.current_project, i)
    this_item_instance_pool_id = _data().storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.instance_id)

    if this_item_instance_pool_id and this_item_instance_pool_id ~= "" then
      table.insert(all_pool_ids_in_project, this_item_instance_pool_id)
    end
  end

  return _util.deduplicateTable(all_pool_ids_in_project)
end


function Glue.deletePoolDescendantsData(pool_id)
  _data().storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.descendant_ids, "")
end


function Glue.setUpAncestorReglues(parent_instance_params, parent_pool_id, descendant_nesting_depth_of_active_parent, superitem)
  local parent_edit_temp_track__name, parent_edit_temp_track, restored_items, next_nesting_depth

  parent_instance_params.pool_id = parent_pool_id
  parent_instance_params.children_nesting_depth = descendant_nesting_depth_of_active_parent
  parent_edit_temp_track__name = "Pool #" .. parent_pool_id .. " temp edit"

  reaper.InsertTrackAtIndex(_constant.api.track.very_1st_track_of_project, _constant.api.track.no_defaults)

  parent_edit_temp_track = reaper.GetTrack(_constant.api.current_project, 0)

  reaper.GetSetMediaTrackInfo_String(parent_edit_temp_track, _constant.api.track.key.name, parent_edit_temp_track__name, _constant.api.set_value)
  reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)

  restored_items = _common().restoreStoredItems(parent_pool_id, parent_edit_temp_track, superitem, true, nil)
  parent_instance_params.track = parent_edit_temp_track
  parent_instance_params.restored_items = restored_items
  _state.superitem.params.ancestor_pools[parent_pool_id] = parent_instance_params
  next_nesting_depth = descendant_nesting_depth_of_active_parent + 1

  Glue.reglueAncestors(parent_pool_id, superitem, next_nesting_depth)
end


function Glue.propagateChangesToSuperitems(active_superitem, sizing_region_guid)
  local this_is_ancestor_superitem_update, ancestor_pools_near_project_start, ancestor_pools_params_sorted_by_ascending_nesting_depth, this_ancestor_pool_id, ancestor_pool_is_present_in_overglue_pools

  this_is_ancestor_superitem_update = false
  ancestor_pools_near_project_start = Glue.handleSuperitemsChangedByReglue(active_superitem, this_is_ancestor_superitem_update)
  ancestor_pools_params_sorted_by_ascending_nesting_depth = Glue.sortAncestorUpdatesByNestingDepth()

  for i = 1, #ancestor_pools_params_sorted_by_ascending_nesting_depth do
    _state.superitem.params.fresh_glue.current_pool = ancestor_pools_params_sorted_by_ascending_nesting_depth[i]
    this_ancestor_pool_id = tostring(_state.superitem.params.fresh_glue.current_pool.pool_id)
    _state.restored_items.delta.position_delta_near_project_start = ancestor_pools_near_project_start[this_ancestor_pool_id]
    _state.superitem.params.preedit.current_pool = _data().storeRetrieveSuperitemParams(this_ancestor_pool_id, _constant.actionstep.preedit)
    ancestor_pool_is_present_in_overglue_pools = _util.isPresentInArray(this_ancestor_pool_id, _state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor)

    if _state.restored_items.delta.position_delta_near_project_start then
      Glue.adjustParentPoolChildrenNearProjectStart(this_ancestor_pool_id, _state.superitem.params.fresh_glue.edited_pool.pool_id)

    else
      _state.restored_items.delta.position_delta_near_project_start = 0
    end

    if not ancestor_pool_is_present_in_overglue_pools then
      Glue.reglueAncestor(sizing_region_guid)
    end
  end
end


function Glue.handleSuperitemsChangedByReglue(active_superitem, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  local all_items_count, ancestor_pools_near_project_start, this_item, this_active_pool_instance, global_option_toggle_depool_all_siblings_on_reglue

  all_items_count = reaper.CountMediaItems(_constant.api.current_project)
  ancestor_pools_near_project_start = {}

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_constant.api.current_project, i)
    this_active_pool_instance = Glue.getSuperitemChangedByReglue(this_item, active_superitem, this_is_ancestor_superitem_update)

    if this_active_pool_instance then
      global_option_toggle_depool_all_siblings_on_reglue = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.depool_all_siblings_on_reglue)

      if global_option_toggle_depool_all_siblings_on_reglue == "true" and not this_is_ancestor_superitem_update then
        global_option_toggle_depool_all_siblings_on_reglue = _depool.handleDePoolSibling(this_active_pool_instance)

      elseif global_option_toggle_depool_all_siblings_on_reglue == "false" then
        ancestor_pools_near_project_start = Glue.updateSuperitemChangedByReglue(this_active_pool_instance, this_item, ancestor_pools_near_project_start, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
      end
    end
  end

  return ancestor_pools_near_project_start
end


function Glue.getSuperitemChangedByReglue(item, active_superitem, this_is_ancestor_superitem_update)
  local item_instance_pool_id, item_is_instance, fresh_glue_params, item_is_active_pool_instance, instance_current_src, this_instance_needs_update

  item_instance_pool_id = _data().storeRetrieveItemData(item, _constant.data.key.suffix.pool.instance_id)
  item_is_instance = item_instance_pool_id and item_instance_pool_id ~= ""
  fresh_glue_params = this_is_ancestor_superitem_update and _state.superitem.params.fresh_glue.current_pool or _state.superitem.params.fresh_glue.edited_pool

  -- if this_is_ancestor_superitem_update then
  --   fresh_glue_params = _state.superitem.params.fresh_glue.current_pool

  -- else
  --   fresh_glue_params = _state.superitem.params.fresh_glue.edited_pool
  -- end

  if item_is_instance then

    if not fresh_glue_params.instance_pool_id or fresh_glue_params.instance_pool_id == "" then
      fresh_glue_params.instance_pool_id = fresh_glue_params.pool_id
      fresh_glue_params.instance_pool_id = tostring(fresh_glue_params.instance_pool_id)
    end

    item_is_active_pool_instance = item_instance_pool_id == fresh_glue_params.instance_pool_id

    if item_is_active_pool_instance then
      instance_current_src = _common().getSetWipeItemAudioSrc(item)
      this_instance_needs_update = instance_current_src ~= fresh_glue_params.updated_src and item ~= active_superitem

      if this_instance_needs_update then

        return item
      end
    end
  end
end


function Glue.updateSuperitemChangedByReglue(active_pool_instance, item, ancestor_pools_near_project_start, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  local siblings_are_being_updated, current_pool_updated_src, attempted_negative_instance_position, instance_parent_pool_id, parent_active_take, parent_playrate, parent_current_src_offset, parent_adjusted_src_offset

  siblings_are_being_updated = not this_is_ancestor_superitem_update

  if this_is_ancestor_superitem_update then
    current_pool_updated_src = _state.superitem.params.fresh_glue.current_pool.updated_src

  elseif siblings_are_being_updated then
    current_pool_updated_src = _state.superitem.params.fresh_glue.edited_pool.updated_src
  end

  _common().getSetWipeItemAudioSrc(active_pool_instance, current_pool_updated_src)

  attempted_negative_instance_position = Glue.adjustSuperitemChangedByReglue(active_pool_instance, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)

  if attempted_negative_instance_position ~= 0 then
    instance_parent_pool_id = _data().storeRetrieveItemData(item, _constant.data.key.suffix.pool.parent_id)
    ancestor_pools_near_project_start[instance_parent_pool_id] = attempted_negative_instance_position
  end

  return ancestor_pools_near_project_start
end


function Glue.adjustSuperitemChangedByReglue(instance, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  local this_is_sibling_instance_update, this_instance_parent_pool_id, this_instance_is_child, instance_active_take, instance_current_src_offset, instance_playrate, instance_would_get_adjusted_before_project_start

  this_is_sibling_instance_update = not this_is_ancestor_superitem_update
  this_instance_parent_pool_id = _data().storeRetrieveItemData(instance, _constant.data.key.suffix.pool.parent_id)
  this_instance_is_child = this_instance_parent_pool_id and this_instance_parent_pool_id ~= ""
  instance_active_take = reaper.GetActiveTake(instance)
  instance_current_src_offset = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _constant.api.take.key.src_offset, "", false)
  instance_playrate = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _constant.api.take.key.playrate)

  Glue.getSuperitemPropagationOptionChoices()

  if this_is_sibling_instance_update then
    instance_would_get_adjusted_before_project_start = Glue.adjustSuperitemPosition(instance, instance_active_take, instance_current_src_offset, instance_playrate)
    Glue.adjustSuperitemLength(instance, instance_playrate, this_instance_is_child)

    -- Propagate lane position to siblings
    if _constant.support.fixed_lanes and _state.propagation.user_wants_option.lane then
      -- local editedSuperitem = reaper.BR_GetMediaItemByGUID(_constant.api.current_project, _state.superitem.params.fresh_glue.edited_pool.item_guid)
      -- if editedSuperitem then
      --   local editedSuperitemLane = reaper.GetMediaItemInfo_Value(editedSuperitem, "I_FIXEDLANE")
      --   local instanceLane = reaper.GetMediaItemInfo_Value(instance, "I_FIXEDLANE")
      --   local laneDelta = instanceLane - editedSuperitemLane

      --   -- Get the edited superitem's new lane
      --   local freshEditedSuperitemLane = reaper.GetMediaItemInfo_Value(_state.superitem.params.fresh_glue.edited_pool.superitem, "I_FIXEDLANE")
      --   local targetLane = freshEditedSuperitemLane + laneDelta

      --   -- Apply lane position - THIS SHOULD BE ABSTRACTED IN THE LANES MODULE
      --   local laneY = _lanes.getLaneYPosition(targetLane)
      --   reaper.SetMediaItemInfo_Value(instance, "F_FREEMODE_Y", laneY)
      -- end
    end
  end

  if (this_is_sibling_instance_update or this_is_direct_parent_instance_update) and
    _state.propagation.user_wants_option.source_position and
    not instance_would_get_adjusted_before_project_start then

    Glue.adjustSuperitemSourceOffset(instance, instance_active_take, instance_current_src_offset, this_is_direct_parent_instance_update, this_is_sibling_instance_update)
  end
end


function Glue.getSuperitemPropagationOptionChoices()
  _state.propagation.user_wants_option.playrate_toggle = _common().getUserPropagationChoice("playrate_toggle", _constant.data.key.options.defaults.playrate_affects_propagation)

  if _state.superitem.position_changed_since_last_glue then
    _state.propagation.user_wants_option.position = _common().getUserPropagationChoice("position", _constant.data.key.options.defaults.propagate_position)

    -- Lane propagation follows position propagation behavior
    if _constant.support.fixed_lanes then
      _state.propagation.user_wants_option.lane = _state.propagation.user_wants_option.position
    end
  end

  if _state.superitem.offset_changed_since_last_glue then
    _state.propagation.user_wants_option.source_position = _common().getUserPropagationChoice("source_position", _constant.data.key.options.defaults.maintain_source_position)
  end
end


function Glue.adjustSuperitemPosition(instance, instance_active_take, instance_current_src_offset, instance_playrate)
  local instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start, take_markers_source_offset

  instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start = Glue.getPositionPropagationParams(instance, instance_current_src_offset, instance_playrate)

if _state.propagation.user_wants_option.position then
    take_markers_source_offset = _state.superitem.params.fresh_glue.edited_pool.source_offset - _state.superitem.params.preedit.edited_pool.source_offset

    Glue.adjustPostGlueTakeMarkersAndEnvelopes(instance, nil, take_markers_source_offset)
    reaper.SetMediaItemPosition(instance, instance_adjusted_position, _constant.api.dont_refresh_ui)

    if _state.propagation.user_wants_option.source_position == nil then
      _state.propagation.user_wants_option.source_position = _common().getUserPropagationChoice("source_position", _constant.data.key.options.defaults.maintain_source_position)
    end

    if _state.propagation.user_wants_option.source_position then
      reaper.SetMediaItemTakeInfo_Value(instance_active_take, _constant.api.take.key.src_offset, instance_current_src_offset)
    end

  else
    Glue.adjustPostGlueTakeMarkersAndEnvelopes(instance)
  end

  return instance_would_get_adjusted_before_project_start
end


function Glue.getPositionPropagationParams(instance, instance_current_src_offset, instance_playrate)
  local instance_current_position, instance_position_adjustment_delta, instance_adjusted_position, instance_would_get_adjusted_before_project_start

  instance_current_position = reaper.GetMediaItemInfo_Value(instance, _constant.api.item.key.position)
  instance_position_adjustment_delta = _state.superitem.delta.position_during_glue

  if _state.propagation.user_wants_option.playrate_toggle then
    instance_position_adjustment_delta = instance_position_adjustment_delta / instance_playrate
  end

  instance_adjusted_position = instance_current_position + instance_position_adjustment_delta
  instance_would_get_adjusted_before_project_start = instance_adjusted_position < _constant.position_start_of_project

  return instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start
end


function Glue.adjustSuperitemSourceOffset(instance, instance_active_take, instance_current_src_offset, this_is_direct_parent_instance_update, this_is_sibling_instance_update)
  local instance_adjusted_src_offset, ancestor_position, ancestor_pool_id, active_child_position_delta_to_parent

  if this_is_direct_parent_instance_update then

    if _state.propagation.user_wants_option.position then

      if instance_current_src_offset >= 0 then
        instance_adjusted_src_offset = _state.superitem.params.fresh_glue.current_pool.source_offset

      else
        instance_adjusted_src_offset = instance_current_src_offset - _state.superitem.delta.offset_since_last_glue
      end

    else
      instance_adjusted_src_offset = instance_current_src_offset
    end

  elseif this_is_sibling_instance_update then
    instance_adjusted_src_offset = _state.superitem.params.fresh_glue.edited_pool.source_offset
  end

  reaper.SetMediaItemTakeInfo_Value(instance_active_take, _constant.api.take.key.src_offset, instance_adjusted_src_offset)

  -- UNUSED??
  _state.superitem.delta.source_position_adjustment = _state.superitem.params.fresh_glue.edited_pool.source_offset - _state.superitem.params.preedit.edited_pool.source_offset
end


function Glue.adjustSuperitemLength(instance, instance_playrate, this_instance_is_child)
  local instance_current_length, instance_length_adjustment_delta, user_wants_relative_length_propagation, instance_adjusted_length

  instance_current_length = reaper.GetMediaItemInfo_Value(instance, _constant.api.item.key.length)
  _state.propagation.user_wants_option.length = _common().getUserPropagationChoice("length", _constant.data.key.options.defaults.propagate_length)

  if _state.propagation.user_wants_option.length then
    _state.propagation.user_wants_option.playrate_toggle = _common().getUserPropagationChoice("playrate_toggle", _constant.data.key.options.defaults.playrate_affects_propagation)
    _state.propagation.user_wants_option.absolute_length_propagation = _common().getUserPropagationChoice("absolute_length_propagation", _constant.data.key.options.defaults.length_propagation_type)
    user_wants_relative_length_propagation = not _state.propagation.user_wants_option.absolute_length_propagation

    if _state.propagation.user_wants_option.absolute_length_propagation then
      instance_adjusted_length = _state.superitem.params.fresh_glue.edited_pool.length

      if _state.propagation.user_wants_option.playrate_toggle then
        instance_adjusted_length = _state.superitem.params.fresh_glue.edited_pool.length / instance_playrate
      end

    elseif user_wants_relative_length_propagation then
      instance_adjusted_length = instance_current_length + _state.superitem.reglue_position_change_affect_on_length

      if _state.propagation.user_wants_option.playrate_toggle then
        instance_adjusted_length = instance_current_length + (_state.superitem.reglue_position_change_affect_on_length / instance_playrate)
      end
    end

    reaper.SetMediaItemLength(instance, instance_adjusted_length, _constant.api.dont_refresh_ui)
  end
end


function Glue.sortAncestorUpdatesByNestingDepth()
  local ancestor_pools_params_sorted_by_ascending_nesting_depth

  ancestor_pools_params_sorted_by_ascending_nesting_depth = {}

  for pool_id, this_parent_instance_params in pairs(_state.superitem.params.ancestor_pools) do
    table.insert(ancestor_pools_params_sorted_by_ascending_nesting_depth, this_parent_instance_params)
  end

  table.sort(ancestor_pools_params_sorted_by_ascending_nesting_depth, function(a, b)

    return a.children_nesting_depth < b.children_nesting_depth end
  )

  return ancestor_pools_params_sorted_by_ascending_nesting_depth
end


function Glue.reglueAncestor(sizing_region_guid)
  local this_is_ancestor_superitem_update, selected_items, this_is_direct_parent_instance_update, ancestor_instance, ancestor_active_track

  reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)
  _depool.refreshCurrentPoolStoredItemsPostDePool()
  _common().selectDeselectItems(_state.superitem.params.fresh_glue.current_pool.restored_items, true)

  this_is_ancestor_superitem_update = true
  selected_items = _init.getSelectedItems(#_state.superitem.params.fresh_glue.current_pool.restored_items)
  this_is_direct_parent_instance_update = Glue.isThisDirectParentInstanceUpdate(selected_items)
  ancestor_instance = Glue.handleGlue(selected_items, _state.superitem.params.fresh_glue.current_pool.pool_id, sizing_region_guid, nil, this_is_ancestor_superitem_update)
  ancestor_active_track = _state.superitem.params.fresh_glue.current_pool.track
  _state.superitem.params.fresh_glue.current_pool = _data().getSetItemParams(ancestor_instance)
  _state.superitem.params.fresh_glue.current_pool.updated_src = _common().getSetWipeItemAudioSrc(ancestor_instance)

  reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)
  Glue.handleSuperitemsChangedByReglue(ancestor_instance, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  reaper.DeleteTrack(ancestor_active_track)
end


function Glue.isThisDirectParentInstanceUpdate(selected_items)
  local this_selected_item, this_selected_item_params, this_selected_instance_pool_id, this_is_direct_parent_instance_update

  for i = 1, #selected_items do
    this_selected_item = selected_items[i]
    this_selected_item_params = _data().getSetItemParams(this_selected_item)
    this_selected_instance_pool_id = this_selected_item_params.instance_pool_id

    if this_selected_instance_pool_id == _state.superitem.params.fresh_glue.edited_pool.pool_id then
      this_is_direct_parent_instance_update = true

      break
    end
  end

  return this_is_direct_parent_instance_update
end



return Glue
