-- @noindex

local Glue = {}


local loadDependencies, loadCircularDependencies, serpent, _constant, _init, _lanes, _sizing, _state, _util, _module_utils, _ancestor, _common, _data, _reglue

local _dev = require("modules.dev")

loadDependencies = (function()
  serpent = require("lib.serpent")
  _constant = require("modules.constant")
  _init = require("modules.init")
  _lanes = require("modules.lanes")
  _sizing = require("modules.sizing")
  _state = require("modules.state")
  _util = require("modules.util")

  _module_utils = require("module-utils")
end)()


loadCircularDependencies = (function()
  _ancestor = function() return _module_utils.lazyRequire("ancestor") end
  _common = function() return _module_utils.lazyRequire("common") end
  _data = function() return _module_utils.lazyRequire("data") end
  _reglue = function() return _module_utils.lazyRequire("reglue") end
end)()



function Glue.handleGlue(selected_items, pool_id, sizing_region_guid, depool_superitem_params, this_is_ancestor_superitem_update)
  local this_is_depool, first_selected_item, first_selected_item_name, sizing_params, this_is_reglue, selected_items_pool_params, items_to_glue

  this_is_depool = depool_superitem_params ~= nil
  first_selected_item = selected_items[1]
  first_selected_item_name = _common().getSetItemName(first_selected_item)
  pool_id, sizing_params, this_is_reglue = Glue.setUpGlue(depool_superitem_params, this_is_ancestor_superitem_update, pool_id, sizing_region_guid, selected_items)
  selected_items_pool_params = Glue.handlePreglueItems(selected_items, pool_id, sizing_params, this_is_reglue, this_is_depool)

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
    sizing_params = _sizing.handleNewGlueSizing(selected_items, this_is_depool, pool_id, depool_superitem_params)

  elseif this_is_reglue then
    sizing_params = _sizing.getReglueSizing(pool_id, sizing_region_guid, selected_items, this_is_ancestor_superitem_update)

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


function Glue.setUpGlueWithDePool(pool_id, depool_superitem_params)
  local sizing_params

  _state.restored_items.last_glue_stored_item_states = _data().storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.contained_item_states)
  sizing_params = {
    position = depool_superitem_params.position,
    end_point = depool_superitem_params.end_point
  }
  sizing_params.length = sizing_params.end_point - sizing_params.position

  _data().storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.last_glue.contained_item_states, _state.restored_items.last_glue_stored_item_states)
  _sizing.instantiateDummySizingItem(sizing_params)

  return sizing_params
end


function Glue.handlePreglueItems(selected_items, pool_id, sizing_params, this_is_reglue, this_is_depool)
  local selected_item_states, selected_items_pool_params

  _lanes.storeItemLaneDeltas(selected_items, pool_id)

  selected_item_states, selected_items_pool_params = _data().prepareAndGetItemStates(selected_items, pool_id)

  _data().storeItemStates(pool_id, selected_item_states)

  _common().selectDeselectItems(selected_items, true, function(item)
    local guid = reaper.BR_GetMediaItemGUID(item)
    return not _state.propagation.sibling_cache[pool_id] or not _state.propagation.sibling_cache[pool_id][guid]
  end)

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



  for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    local it = reaper.GetSelectedMediaItem(0, i)
  end



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
  _ancestor().handleDescendantPoolReferences(pool_id, selected_items_pool_params)

  if not this_is_ancestor_superitem_update then
    _ancestor().handleParentPoolReferencesInChildPools(pool_id, selected_items_pool_params)
    _reglue().deleteUnselectedContainedItems()
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



return Glue
