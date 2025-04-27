local Reglue = {}


local _dev = require("modules.dev")

local loadDependencies, loadCircularDependencies, serpent, _common, _constant, _data, _depool, _sizing, _state, _util, _module_utils, _glue


loadDependencies = (function()
  serpent = require("lib.serpent")
  _common = require("modules.common")
  _constant = require("modules.constant")
  _data = require("modules.data")
  _depool = require("modules.depool")
  _sizing = require("modules.sizing")
  _state = require("modules.state")
  _util = require("modules.util")

  _module_utils = require("module-utils")
end)()


loadCircularDependencies = (function()
  _glue = function() return _module_utils.lazyRequire("glue") end
end)()






function Reglue.handleDescendantPoolReferences(pool_id, contained_items_pool_params)
  local this_pool_descendants, this_contained_item_instance_pool_id, this_contained_item_params, this_selected_item_is_superitem, this_child_pool_descendant_pool_ids, this_pool_descendants_string

  this_pool_descendants = {}

  for this_contained_item_instance_pool_id, this_contained_item_params in pairs(contained_items_pool_params) do
    this_selected_item_is_superitem = not string.find(this_contained_item_instance_pool_id, _constant.noninstance_label)

    if this_selected_item_is_superitem then
      this_child_pool_descendant_pool_ids = _data.storeRetrievePoolData(this_contained_item_instance_pool_id, _constant.data.key.suffix.pool.descendant_ids)

      table.insert(this_pool_descendants, this_contained_item_instance_pool_id)

      for j = 1, #this_child_pool_descendant_pool_ids do
        table.insert(this_pool_descendants, this_child_pool_descendant_pool_ids[j])
      end
    end
  end

  this_pool_descendants = _util.deduplicateTable(this_pool_descendants)
  this_pool_descendants_string = serpent.dump(this_pool_descendants)

  _data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.descendant_ids, this_pool_descendants_string)
end


function Reglue.handleParentPoolReferencesInChildPools(active_pool_id, contained_items_pool_params)
  local this_contained_item_instance_pool_id, this_contained_item_params, this_selected_item_is_superitem

  for this_contained_item_instance_pool_id, this_contained_item_params in pairs(contained_items_pool_params) do
    this_selected_item_is_superitem = not string.find(this_contained_item_instance_pool_id, _constant.noninstance_label)

    if this_selected_item_is_superitem then
      Reglue.storeParentPoolReferencesInChildPool(this_contained_item_instance_pool_id, active_pool_id)
    end
  end
end


function Reglue.storeParentPoolReferencesInChildPool(preglue_child_instance_pool_id, active_pool_id)
  local parent_pool_ids_data_key_label, retval, parent_pool_ids_referenced_in_child_pool, this_parent_pool_id, this_parent_pool_id_is_referenced_in_child_pool

  parent_pool_ids_data_key_label = _constant.data.key.prefix.pool .. preglue_child_instance_pool_id .. _constant.data.key.suffix.pool.parent_ids_data
  retval, parent_pool_ids_referenced_in_child_pool = _data.storeRetrieveProjectData(parent_pool_ids_data_key_label)

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

    _data.storeRetrieveProjectData(parent_pool_ids_data_key_label, parent_pool_ids_referenced_in_child_pool)
  end
end


function Reglue.deleteUnselectedContainedItems()
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


function Reglue.handleReglue(selected_items, restored_items_pool_id)
  local sizing_region_guid, superitem, superitem_params, result

  sizing_region_guid = _sizing.checkSizingRegionExists(restored_items_pool_id, selected_items)

  if not sizing_region_guid then return false end

  _data.cleanUnselectedRestoredItemsFromPool(restored_items_pool_id)

  _state.superitem.params.last_glue.edited_pool = _data.storeRetrieveSuperitemParams(restored_items_pool_id, _constant.actionstep.postglue)

  superitem = _glue().handleGlue(selected_items, restored_items_pool_id, sizing_region_guid, nil, nil)
  superitem, superitem_params = Reglue.handleReglueSuperitemParams(superitem, restored_items_pool_id)

  Reglue.setRegluePositionDeltas(superitem_params) -- ARGUMENT NECESSARY HERE??
  Reglue.adjustPostGlueTakeMarkersAndEnvelopes(superitem, nil, nil, true)
  Reglue.reglueAncestors(superitem_params.pool_id, superitem)
  reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)
  result = Reglue.propagateChangesToSuperitems(superitem, sizing_region_guid)

  if result == false then return false end

  reaper.ClearPeakCache()

  return superitem
end


function Reglue.handleReglueSuperitemParams(superitem, restored_items_pool_id)
  local superitem_params, global_option_toggle_retain_only_last_glue_source_enabled

  superitem_params = _data.getSetItemParams(superitem)
  superitem_params.updated_src = _common.getSetWipeItemAudioSrc(superitem)
  superitem_params.pool_id = restored_items_pool_id
  superitem = _data.restoreSuperitemState(superitem, superitem_params)
  _state.superitem.params.fresh_glue.edited_pool = superitem_params
  _state.superitem.params.preedit.edited_pool = _data.storeRetrieveSuperitemParams(_state.superitem.params.fresh_glue.edited_pool.pool_id, _constant.actionstep.preedit)
  global_option_toggle_retain_only_last_glue_source_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.retain_only_last_glue_source)

  if global_option_toggle_retain_only_last_glue_source_enabled == "true" then
    _common.getSetWipeItemAudioSrc(superitem, "wipe")
  end

  return superitem, superitem_params
end


function Reglue.setRegluePositionDeltas()
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


function Reglue.adjustPostGlueTakeMarkersAndEnvelopes(instance, adjustment_near_project_start, fresh_glue_source_offset, this_is_edited_superitem)
  local instance_position, instance_active_take, instance_current_src_offset, instance_playrate, envelope_point_position_adjustment_delta, take_marker_position_adjustment_delta

  instance_position, instance_active_take, instance_current_src_offset, instance_playrate, fresh_glue_source_offset = Reglue.getParamsForTakeMarkersAndEnvelopes(instance, instance_active_take, fresh_glue_source_offset)
  envelope_point_position_adjustment_delta, take_marker_position_adjustment_delta = Reglue.getDeltasForTakeMarkersAndEnvelopes(adjustment_near_project_start, instance_position, instance_current_src_offset, instance_playrate, this_is_edited_superitem)

  Reglue.adjustTakeEnvelopes(instance_active_take, envelope_point_position_adjustment_delta)
  Reglue.adjustTakeMarkers(instance_active_take, take_marker_position_adjustment_delta, fresh_glue_source_offset)
  Reglue.handleTakeStretchMarkers(instance_active_take, take_marker_position_adjustment_delta, fresh_glue_source_offset)
end


function Reglue.getParamsForTakeMarkersAndEnvelopes(instance, instance_active_take, fresh_glue_source_offset)
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


function Reglue.getDeltasForTakeMarkersAndEnvelopes(adjustment_near_project_start, instance_position, instance_current_src_offset, instance_playrate, this_is_edited_superitem)
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


function Reglue.adjustTakeEnvelopes(instance_active_take, position_adjustment_delta)
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


function Reglue.adjustTakeMarkers(instance_active_take, position_adjustment_delta, fresh_glue_source_offset)
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


function Reglue.handleTakeStretchMarkers(instance_active_take, position_adjustment_delta, fresh_glue_source_offset)
  local stretch_markers_count, marker_position_adjustment, marker_source_position_adjustment

  stretch_markers_count = reaper.GetTakeNumStretchMarkers(instance_active_take)

  if stretch_markers_count > 0 then
    _state.propagation.user_wants_option.source_position = _common.getUserPropagationChoice("source_position", _constant.data.key.options.defaults.maintain_source_position)

    if _state.propagation.user_wants_option.source_position then
      marker_position_adjustment = position_adjustment_delta
      marker_source_position_adjustment = position_adjustment_delta + fresh_glue_source_offset

    else
      marker_position_adjustment = 0
      marker_source_position_adjustment = 0
    end

    Reglue.adjustTakeStretchMarkers(instance_active_take, stretch_markers_count, marker_position_adjustment, marker_source_position_adjustment)
  end
end


function Reglue.adjustTakeStretchMarkers(instance_active_take, stretch_markers_count, marker_position_adjustment, marker_source_position_adjustment)
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


function Reglue.reglueAncestors(pool_id, superitem, descendant_nesting_depth_of_active_parent)
  local parent_pool_ids_data_key_label, retval, parent_pool_ids, parent_pool_ids_data_found_for_active_pool, this_parent_pool_id, parent_pool_is_present_in_overglue_pools

  parent_pool_ids_data_key_label = _constant.data.key.prefix.pool .. pool_id .. _constant.data.key.suffix.pool.parent_ids_data
  retval, parent_pool_ids = _data.storeRetrieveProjectData(parent_pool_ids_data_key_label)
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
            Reglue.assignParentNestingDepth(this_parent_pool_id, descendant_nesting_depth_of_active_parent)

          else
            Reglue.traverseAncestorsUsingTempTracks(this_parent_pool_id, superitem, descendant_nesting_depth_of_active_parent)
          end
        end
      end

      reaper.GetSet_LoopTimeRange(true, false, _state.user.time_selection_before_action.position, _state.user.time_selection_before_action.end_point, false)
    end
  end
end


function Reglue.assignParentNestingDepth(this_parent_pool_id, descendant_nesting_depth_of_active_parent)
  _state.superitem.params.ancestor_pools[this_parent_pool_id].children_nesting_depth = math.max(descendant_nesting_depth_of_active_parent, _state.superitem.params.ancestor_pools[this_parent_pool_id].children_nesting_depth)
end


function Reglue.traverseAncestorsUsingTempTracks(this_parent_pool_id, superitem, descendant_nesting_depth_of_active_parent)
  local this_parent_is_ancestor_in_project, this_parent_instance_params, this_parent_instance_is_item_in_project

  this_parent_instance_params = Reglue.getFirstPoolInstanceParams(this_parent_pool_id)
  this_parent_instance_is_item_in_project = this_parent_instance_params

  if not this_parent_instance_is_item_in_project then
    this_parent_is_ancestor_in_project = Reglue.checkParentPoolIsAncestorInProject(this_parent_pool_id)

    if this_parent_is_ancestor_in_project then
      this_parent_instance_params = {}
    end
  end

  if this_parent_instance_is_item_in_project or this_parent_is_ancestor_in_project then
    Reglue.setUpAncestorReglues(this_parent_instance_params, this_parent_pool_id, descendant_nesting_depth_of_active_parent, superitem)
  end
end


function Reglue.getFirstPoolInstanceParams(pool_id)
  local all_items_count, this_item, this_item_instance_pool_id, parent_instance_params

  all_items_count = reaper.CountMediaItems(_constant.api.current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_constant.api.current_project, i)
    this_item_instance_pool_id = _data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.instance_id)
    this_item_instance_pool_id = tonumber(this_item_instance_pool_id)

    if this_item_instance_pool_id == pool_id then
      parent_instance_params = _data.getSetItemParams(this_item)

      return parent_instance_params
    end
  end

  return false
end


function Reglue.checkParentPoolIsAncestorInProject(this_parent_pool_id)
  local all_pool_ids_in_project, this_pool, this_pool_descendant_pool_ids, this_pool_descendant_pool_id

  all_pool_ids_in_project = Reglue.getAllPoolIdsInProject()

  for i = 1, #all_pool_ids_in_project do
    this_pool = all_pool_ids_in_project[i]

    if this_pool == this_parent_pool_id then

      return true
    end

    this_pool_descendant_pool_ids = _data.storeRetrievePoolData(this_pool, _constant.data.key.suffix.pool.descendant_ids)
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

  Reglue.deletePoolDescendantsData(this_parent_pool_id)

  return false
end


function Reglue.getAllPoolIdsInProject()
  local all_items_count, all_pool_ids_in_project, this_item, this_item_instance_pool_id

  all_items_count = reaper.CountMediaItems(_constant.api.current_project)
  all_pool_ids_in_project = {}

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_constant.api.current_project, i)
    this_item_instance_pool_id = _data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.instance_id)

    if this_item_instance_pool_id and this_item_instance_pool_id ~= "" then
      table.insert(all_pool_ids_in_project, this_item_instance_pool_id)
    end
  end

  return _util.deduplicateTable(all_pool_ids_in_project)
end


function Reglue.deletePoolDescendantsData(pool_id)
  _data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.descendant_ids, "")
end


function Reglue.setUpAncestorReglues(parent_instance_params, parent_pool_id, descendant_nesting_depth_of_active_parent, superitem)
  local parent_edit_temp_track__name, parent_edit_temp_track, restored_items, next_nesting_depth

  parent_instance_params.pool_id = parent_pool_id
  parent_instance_params.children_nesting_depth = descendant_nesting_depth_of_active_parent
  parent_edit_temp_track__name = "Pool #" .. parent_pool_id .. " temp edit"

  reaper.InsertTrackAtIndex(_constant.api.track.very_1st_track_of_project, _constant.api.track.no_defaults)

  parent_edit_temp_track = reaper.GetTrack(_constant.api.current_project, 0)

  reaper.GetSetMediaTrackInfo_String(parent_edit_temp_track, _constant.api.track.key.name, parent_edit_temp_track__name, _constant.api.set_value)
  reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)

  restored_items = _common.restoreStoredItems(parent_pool_id, parent_edit_temp_track, superitem, true, nil)
  parent_instance_params.track = parent_edit_temp_track
  parent_instance_params.restored_items = restored_items
  _state.superitem.params.ancestor_pools[parent_pool_id] = parent_instance_params
  next_nesting_depth = descendant_nesting_depth_of_active_parent + 1

  Reglue.reglueAncestors(parent_pool_id, superitem, next_nesting_depth)
end


function Reglue.propagateChangesToSuperitems(active_superitem, sizing_region_guid)
  local this_is_ancestor_superitem_update, result, ancestor_pools_near_project_start, ancestor_pools_params_sorted_by_ascending_nesting_depth, this_ancestor_pool_id, ancestor_pool_is_present_in_overglue_pools

  this_is_ancestor_superitem_update = false
  result = Reglue.handleSuperitemsChangedByReglue(active_superitem, this_is_ancestor_superitem_update)

  if result == false then return false end

  ancestor_pools_near_project_start = result

  ancestor_pools_params_sorted_by_ascending_nesting_depth = Reglue.sortAncestorUpdatesByNestingDepth()

  for i = 1, #ancestor_pools_params_sorted_by_ascending_nesting_depth do
    _state.superitem.params.fresh_glue.current_pool = ancestor_pools_params_sorted_by_ascending_nesting_depth[i]
    this_ancestor_pool_id = tostring(_state.superitem.params.fresh_glue.current_pool.pool_id)
    -- _state.restored_items.delta.position_delta_near_project_start = ancestor_pools_near_project_start[this_ancestor_pool_id]
    _state.superitem.params.preedit.current_pool = _data.storeRetrieveSuperitemParams(this_ancestor_pool_id, _constant.actionstep.preedit)
    ancestor_pool_is_present_in_overglue_pools = _util.isPresentInArray(this_ancestor_pool_id, _state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor)

    -- if _state.restored_items.delta.position_delta_near_project_start then
    --   Reglue.adjustParentPoolChildrenNearProjectStart(this_ancestor_pool_id, _state.superitem.params.fresh_glue.edited_pool.pool_id)

    -- else
      -- _state.restored_items.delta.position_delta_near_project_start = 0
    -- end

    if not ancestor_pool_is_present_in_overglue_pools then
      Reglue.reglueAncestor(sizing_region_guid)
    end
  end
end


function Reglue.handleSuperitemsChangedByReglue(active_superitem, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  local all_items_count, result, ancestor_pools_near_project_start, this_item, this_active_pool_instance, global_option_toggle_depool_all_siblings_on_reglue

  all_items_count = reaper.CountMediaItems(_constant.api.current_project)
  ancestor_pools_near_project_start = {}

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_constant.api.current_project, i)
    this_active_pool_instance = Reglue.getSuperitemChangedByReglue(this_item, active_superitem, this_is_ancestor_superitem_update)

    if this_active_pool_instance then
      global_option_toggle_depool_all_siblings_on_reglue = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.depool_all_siblings_on_reglue)

      if global_option_toggle_depool_all_siblings_on_reglue == "true" and not this_is_ancestor_superitem_update then
        global_option_toggle_depool_all_siblings_on_reglue = _depool.handleDePoolSibling(this_active_pool_instance)

      elseif global_option_toggle_depool_all_siblings_on_reglue == "false" then
        result = Reglue.updateSuperitemChangedByReglue(this_active_pool_instance, this_item, ancestor_pools_near_project_start, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)

        if result == false then return false end

        ancestor_pools_near_project_start = result
      end
    end
  end

  return ancestor_pools_near_project_start
end


function Reglue.getSuperitemChangedByReglue(item, active_superitem, this_is_ancestor_superitem_update)
  local item_instance_pool_id, item_is_instance, fresh_glue_params, item_is_active_pool_instance, instance_current_src, this_instance_needs_update

  item_instance_pool_id = _data.storeRetrieveItemData(item, _constant.data.key.suffix.pool.instance_id)
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
      instance_current_src = _common.getSetWipeItemAudioSrc(item)
      this_instance_needs_update = instance_current_src ~= fresh_glue_params.updated_src and item ~= active_superitem

      if this_instance_needs_update then

        return item
      end
    end
  end
end


function Reglue.updateSuperitemChangedByReglue(active_pool_instance, item, ancestor_pools_near_project_start, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  local siblings_are_being_updated, current_pool_updated_src, attempted_negative_instance_position, instance_parent_pool_id, parent_active_take, parent_playrate, parent_current_src_offset, parent_adjusted_src_offset

  siblings_are_being_updated = not this_is_ancestor_superitem_update

  if this_is_ancestor_superitem_update then
    current_pool_updated_src = _state.superitem.params.fresh_glue.current_pool.updated_src

  elseif siblings_are_being_updated then
    current_pool_updated_src = _state.superitem.params.fresh_glue.edited_pool.updated_src
  end

  _common.getSetWipeItemAudioSrc(active_pool_instance, current_pool_updated_src)

  attempted_negative_instance_position = Reglue.adjustSuperitemChangedByReglue(active_pool_instance, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)

  if attempted_negative_instance_position == false then

      return false

  elseif attempted_negative_instance_position ~= 0 then
    instance_parent_pool_id = _data.storeRetrieveItemData(item, _constant.data.key.suffix.pool.parent_id)
    ancestor_pools_near_project_start[instance_parent_pool_id] = attempted_negative_instance_position
  end

  return ancestor_pools_near_project_start
end


function Reglue.adjustSuperitemChangedByReglue(instance, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  local this_is_sibling_instance_update, this_instance_parent_pool_id, this_instance_is_child, instance_active_take, instance_current_src_offset, instance_playrate, instance_would_get_adjusted_before_project_start

  this_is_sibling_instance_update = not this_is_ancestor_superitem_update
  this_instance_parent_pool_id = _data.storeRetrieveItemData(instance, _constant.data.key.suffix.pool.parent_id)
  this_instance_is_child = this_instance_parent_pool_id and this_instance_parent_pool_id ~= ""
  instance_active_take = reaper.GetActiveTake(instance)
  instance_current_src_offset = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _constant.api.take.key.src_offset, "", false)
  instance_playrate = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _constant.api.take.key.playrate)

  Reglue.getSuperitemPropagationOptionChoices()

  if this_is_sibling_instance_update then
    instance_would_get_adjusted_before_project_start = Reglue.adjustSuperitemPosition(instance, instance_active_take, instance_current_src_offset, instance_playrate)

    if instance_would_get_adjusted_before_project_start then
      local msg = string.format(
        "%s can't propagate the left-edge position change to a sibling instance (Pool #%s) because it would be moved before project start.\n\nFix the Superitem's position and try again.",
        _constant.brand.name,
        tostring(this_instance_parent_pool_id)
      )

      reaper.ShowMessageBox(msg, "Invalid Sibling Propagation", _constant.api.msg.type.ok)

      return false
    end

    Reglue.adjustSuperitemLength(instance, instance_playrate, this_instance_is_child)

    -- Propagate lane position to siblings -- WHY??
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

    Reglue.adjustSuperitemSourceOffset(instance, instance_active_take, instance_current_src_offset, this_is_direct_parent_instance_update, this_is_sibling_instance_update)
  end
end


function Reglue.getSuperitemPropagationOptionChoices()
  _state.propagation.user_wants_option.playrate_toggle = _common.getUserPropagationChoice("playrate_toggle", _constant.data.key.options.defaults.playrate_affects_propagation)

  if _state.superitem.position_changed_since_last_glue then
    _state.propagation.user_wants_option.position = _common.getUserPropagationChoice("position", _constant.data.key.options.defaults.propagate_position_change)

    -- Lane propagation follows position propagation behavior
    if _constant.support.fixed_lanes then
      _state.propagation.user_wants_option.lane = _state.propagation.user_wants_option.position
    end
  end

  if _state.superitem.offset_changed_since_last_glue then
    _state.propagation.user_wants_option.source_position = _common.getUserPropagationChoice("source_position", _constant.data.key.options.defaults.maintain_source_position)
  end
end


function Reglue.adjustSuperitemPosition(instance, instance_active_take, instance_current_src_offset, instance_playrate)
  local instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start, take_markers_source_offset

  instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start = Reglue.getPositionPropagationParams(instance, instance_current_src_offset, instance_playrate)

if _state.propagation.user_wants_option.position then
    take_markers_source_offset = _state.superitem.params.fresh_glue.edited_pool.source_offset - _state.superitem.params.preedit.edited_pool.source_offset

    Reglue.adjustPostGlueTakeMarkersAndEnvelopes(instance, nil, take_markers_source_offset)
    reaper.SetMediaItemPosition(instance, instance_adjusted_position, _constant.api.dont_refresh_ui)

    if _state.propagation.user_wants_option.source_position == nil then
      _state.propagation.user_wants_option.source_position = _common.getUserPropagationChoice("source_position", _constant.data.key.options.defaults.maintain_source_position)
    end

    if _state.propagation.user_wants_option.source_position then
      reaper.SetMediaItemTakeInfo_Value(instance_active_take, _constant.api.take.key.src_offset, instance_current_src_offset)
    end

  else
    Reglue.adjustPostGlueTakeMarkersAndEnvelopes(instance)
  end

  return instance_would_get_adjusted_before_project_start
end


function Reglue.getPositionPropagationParams(instance, instance_current_src_offset, instance_playrate)
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


function Reglue.adjustSuperitemSourceOffset(instance, instance_active_take, instance_current_src_offset, this_is_direct_parent_instance_update, this_is_sibling_instance_update)
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


function Reglue.adjustSuperitemLength(instance, instance_playrate, this_instance_is_child)
  local instance_current_length, instance_length_adjustment_delta, user_wants_relative_length_propagation, instance_adjusted_length

  instance_current_length = reaper.GetMediaItemInfo_Value(instance, _constant.api.item.key.length)
  _state.propagation.user_wants_option.length = _common.getUserPropagationChoice("length", _constant.data.key.options.defaults.propagate_length_change)

  if _state.propagation.user_wants_option.length then
    _state.propagation.user_wants_option.playrate_toggle = _common.getUserPropagationChoice("playrate_toggle", _constant.data.key.options.defaults.playrate_affects_propagation)
    _state.propagation.user_wants_option.absolute_length_propagation = _common.getUserPropagationChoice("absolute_length_propagation", _constant.data.key.options.defaults.length_propagation_type)
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


function Reglue.sortAncestorUpdatesByNestingDepth()
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


function Reglue.reglueAncestor(sizing_region_guid)
  local this_is_ancestor_superitem_update, selected_items, this_is_direct_parent_instance_update, ancestor_instance, ancestor_active_track

  reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)
  _depool.refreshCurrentPoolStoredItemsPostDePool()
  _common.selectDeselectItems(_state.superitem.params.fresh_glue.current_pool.restored_items, true)

  this_is_ancestor_superitem_update = true
  selected_items = _common.getSelectedItems(#_state.superitem.params.fresh_glue.current_pool.restored_items)
  this_is_direct_parent_instance_update = Reglue.isThisDirectParentInstanceUpdate(selected_items)
  ancestor_instance = _glue().handleGlue(selected_items, _state.superitem.params.fresh_glue.current_pool.pool_id, sizing_region_guid, nil, this_is_ancestor_superitem_update)
  ancestor_active_track = _state.superitem.params.fresh_glue.current_pool.track
  _state.superitem.params.fresh_glue.current_pool = _data.getSetItemParams(ancestor_instance)
  _state.superitem.params.fresh_glue.current_pool.updated_src = _common.getSetWipeItemAudioSrc(ancestor_instance)

  reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)
  Reglue.handleSuperitemsChangedByReglue(ancestor_instance, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  reaper.DeleteTrack(ancestor_active_track)
end


function Reglue.isThisDirectParentInstanceUpdate(selected_items)
  local this_selected_item, this_selected_item_params, this_selected_instance_pool_id, this_is_direct_parent_instance_update

  for i = 1, #selected_items do
    this_selected_item = selected_items[i]
    this_selected_item_params = _data.getSetItemParams(this_selected_item)
    this_selected_instance_pool_id = this_selected_item_params.instance_pool_id

    if this_selected_instance_pool_id == _state.superitem.params.fresh_glue.edited_pool.pool_id then
      this_is_direct_parent_instance_update = true

      break
    end
  end

  return this_is_direct_parent_instance_update
end


return Reglue
