-- @noindex

local Reglue = {}


local _dev = require("modules.dev")

local loadDependencies, loadCircularDependencies, _common, _constant, _data, _depool, _init, _sizing, _state, _util, _module_utils, _ancestor, _glue, _sibling


loadDependencies = (function()
  _common = require("modules.common")
  _constant = require("modules.constant")
  _data = require("modules.data")
  _depool = require("modules.depool")
  _init = require("modules.init")
  _sizing = require("modules.sizing")
  _state = require("modules.state")
  _util = require("modules.util")

  _module_utils = require("module-utils")
end)()


loadCircularDependencies = (function()
  _ancestor = function() return _module_utils.lazyRequire("ancestor") end
  _glue = function() return _module_utils.lazyRequire("glue") end
  _sibling = function() return _module_utils.lazyRequire("sibling") end
end)()




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
  local sizing_region_guid = _sizing.checkSizingRegionExists(
        restored_items_pool_id, selected_items)

  if not sizing_region_guid then return false end

  _state.superitem.params.last_glue.edited_pool =
        _data.storeRetrieveSuperitemParams(
            restored_items_pool_id, _constant.actionstep.postglue)

  _state.superitem.params.preedit.edited_pool =
        _data.storeRetrieveSuperitemParams(
            restored_items_pool_id, _constant.actionstep.preedit)

  local sr_params = _sizing.getSizingRegion(sizing_region_guid, 0)

  if not sr_params then
        reaper.ShowMessageBox("Sizing region vanished unexpectedly.",
                              "Reglue aborted", _constant.api.msg.type.ok)
        return false
  end

  _state.superitem.delta.position_during_glue =
        sr_params.position - _state.superitem.params.preedit.edited_pool.position
  _state.superitem.delta.position_during_glue_preview = _state.superitem.delta.position_during_glue
  _state.superitem.delta.position_during_glue =
        _util.round(_state.superitem.delta.position_during_glue,
                    _constant.api.time_value_decimal_resolution)

  local validate_result = _sibling().validateSiblingPositionsBeforeReglue(restored_items_pool_id)

  if not validate_result then
    _init.setResetUsersItemSelection("reset")

    return false
  end

  _data.cleanUnselectedRestoredItemsFromPool(restored_items_pool_id)

  local superitem = _glue().handleGlue(
        selected_items, restored_items_pool_id,
        sizing_region_guid, nil, nil)

  _state.superitem.active_instance = superitem
  _state.superitem.active_pool     = restored_items_pool_id

  if superitem == false then return false end

  superitem = Reglue.handleReglueSuperitemParams(superitem, restored_items_pool_id)

  Reglue.setRegluePositionDeltas()
  Reglue.adjustPostGlueTakeMarkersAndEnvelopes(
        superitem, nil, nil, true)
  _ancestor().reglueAncestors(
        _state.superitem.params.fresh_glue.edited_pool.pool_id,
        superitem)

  if superitem then
    reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)
  end

  local ok = Reglue.propagateChangesToSuperitems(
        superitem, sizing_region_guid)
  if ok == false then return false end

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



  _dev.dbg("DELTA_SET_FLAGS", "offset_changed=%s", tostring(_state.superitem.offset_changed_since_last_glue))



  do
    local pool_id = _state.superitem.params.fresh_glue.edited_pool.pool_id
    local cache   = _state.propagation.sibling_cache[pool_id]
    if cache then
      for guid, snap in pairs(cache) do
        local item = reaper.BR_GetMediaItemByGUID(0, guid)
        local take = reaper.GetActiveTake(item)
        local guid = reaper.BR_GetMediaItemGUID(item)
        local rate = reaper.GetMediaItemTakeInfo_Value(take, _constant.api.take.key.playrate)
        local new_len = _sibling().calcNewLength(item, rate)
        snap.new_len = new_len
        cache[guid] = snap
      end
    end
  end

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
    _state.propagation.user_wants_option.source_position = _common.getUserPropagationChoice("source_position", _constant.data.key.options.switch.maintain_source_position)

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


function Reglue.propagateChangesToSuperitems(active_superitem, sizing_region_guid)
  local this_is_ancestor_superitem_update, result, ancestor_pools_near_project_start, ancestor_pools_params_sorted_by_ascending_nesting_depth, this_ancestor_pool_id, ancestor_pool_is_present_in_overglue_pools

  this_is_ancestor_superitem_update = false
  result = Reglue.handleSuperitemsChangedByReglue(active_superitem, this_is_ancestor_superitem_update)

  if result == false then return false end

  ancestor_pools_near_project_start = result

  ancestor_pools_params_sorted_by_ascending_nesting_depth = _ancestor().sortAncestorUpdatesByNestingDepth()

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
      _ancestor().reglueAncestor(sizing_region_guid)
    end
  end
end


function Reglue.handleSuperitemsChangedByReglue(active_superitem, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  local all_items_count, result, ancestor_pools_near_project_start, this_item, this_active_pool_instance, global_option_toggle_depool_all_siblings_on_reglue

  all_items_count = reaper.CountMediaItems(_constant.api.current_project)
  ancestor_pools_near_project_start = {}

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_constant.api.current_project, i)

    if not reaper.ValidatePtr(this_item, "MediaItem*") or
      reaper.BR_GetMediaItemGUID(this_item) == reaper.BR_GetMediaItemGUID(_state.superitem.active_instance)
    then goto continue end

    this_active_pool_instance = Reglue.getSuperitemChangedByReglue(this_item, active_superitem, this_is_ancestor_superitem_update)

    -- ■ cached sibling adjustment (if dry-run already built it)
    do
      local pool_id = _data.storeRetrieveItemData(this_item,
              _constant.data.key.suffix.pool.instance_id)
      local cache   = _state.propagation.sibling_cache[pool_id]
      if cache then
        local guid = reaper.BR_GetMediaItemGUID(this_item)
        local adj = cache and cache[guid]
        if adj then
          reaper.SetMediaItemPosition(this_item, adj.new_pos, _constant.api.dont_refresh_ui)
          reaper.SetMediaItemLength  (this_item, adj.new_len, _constant.api.dont_refresh_ui)

          if adj.new_src then
            reaper.SetMediaItemTakeInfo_Value(
              reaper.GetActiveTake(this_item),
              _constant.api.take.key.src_offset,
              adj.new_src)
          end

          return ancestor_pools_near_project_start  -- skip redundant processing
        end
      end
    end

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

    ::continue::
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


function Reglue.adjustSuperitemChangedByReglue(instance, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update, sibling_negative_position_validation)

  do
    local pool_id = _data.storeRetrieveItemData(instance, _constant.data.key.suffix.pool.instance_id)
    local g       = reaper.BR_GetMediaItemGUID(instance)
    local snap    = _state.propagation.sibling_cache[pool_id] and _state.propagation.sibling_cache[pool_id][g]

    if snap and not sibling_negative_position_validation then
      reaper.SetMediaItemPosition(instance, snap.new_pos, _constant.api.dont_refresh_ui)
      reaper.SetMediaItemLength  (instance, snap.new_len, _constant.api.dont_refresh_ui)

      if snap.new_src then
        local tk = reaper.GetActiveTake(instance)



        _dev.dbg("CACHE_APPLY_SRC", "GUID=%s  setting src_offset=%s", g, tostring(snap.new_src))




        reaper.SetMediaItemTakeInfo_Value(tk, _constant.api.take.key.src_offset, snap.new_src)
      end





      if not snap then
        _dev.dbg("CACHE_MISS_SRC", "GUID=%s  no cached source offset applied", g)
      end




      return
    end
  end

  local this_is_sibling_instance_update = not this_is_ancestor_superitem_update
  local instance_active_take = reaper.GetActiveTake(instance)
  local instance_current_src_offset = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _constant.api.take.key.src_offset)
  local instance_playrate = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _constant.api.take.key.playrate)

  _sibling().loadSuperitemPropagationOptionChoices()

  if this_is_sibling_instance_update then
    local instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start =
    Reglue.calculateAdjustedPosition(instance, instance_current_src_offset, instance_playrate)

    if sibling_negative_position_validation and instance_would_get_adjusted_before_project_start then
      return "sibling_would_go_negative"
    end

    if not sibling_negative_position_validation then
      if _state.propagation.user_wants_option.position then
        local take_markers_source_offset = _state.superitem.params.fresh_glue.edited_pool.source_offset - _state.superitem.params.preedit.edited_pool.source_offset
        Reglue.adjustPostGlueTakeMarkersAndEnvelopes(instance, nil, take_markers_source_offset)
        reaper.SetMediaItemPosition(instance, instance_adjusted_position, _constant.api.dont_refresh_ui)

        if _state.propagation.user_wants_option.source_position == nil then
          _state.propagation.user_wants_option.source_position = _common.getUserPropagationChoice(
            "source_position",
            _constant.data.key.options.switch.maintain_source_position
          )
        end

        if _state.propagation.user_wants_option.source_position then
          reaper.SetMediaItemTakeInfo_Value(instance_active_take, _constant.api.take.key.src_offset, instance_current_src_offset)
        end

      else
        Reglue.adjustPostGlueTakeMarkersAndEnvelopes(instance)
      end
    end
  end

  if sibling_negative_position_validation then
    return instance_would_get_adjusted_before_project_start
    and "sibling_would_go_negative" or nil,
    {
      guid     = reaper.BR_GetMediaItemGUID(instance),
      new_pos  = instance_adjusted_position,
      -- new_len added later in caller
    }

  else
    if (this_is_sibling_instance_update or this_is_direct_parent_instance_update) and
      _state.propagation.user_wants_option.source_position then
      Reglue.adjustSuperitemSourceOffset(
        instance,
        instance_active_take,
        instance_current_src_offset,
        this_is_direct_parent_instance_update,
        this_is_sibling_instance_update
      )
    end
  end
end


function Reglue.calculateAdjustedPosition(instance, instance_current_src_offset, instance_playrate)
  local instance_current_position = reaper.GetMediaItemInfo_Value(instance, _constant.api.item.key.position)
  local instance_position_adjustment_delta = _state.superitem.delta.position_during_glue

  if _state.propagation.user_wants_option.playrate_toggle then
    instance_position_adjustment_delta = instance_position_adjustment_delta / instance_playrate
  end

  local instance_adjusted_position = instance_current_position + instance_position_adjustment_delta
  local instance_would_get_adjusted_before_project_start = instance_adjusted_position < _constant.position_start_of_project

  return instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start
end


function Reglue.adjustSuperitemPosition(instance, instance_active_take, instance_current_src_offset, instance_playrate, sibling_negative_position_validation)
  local instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start, take_markers_source_offset

  instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start = _sibling().getPositionPropagationParams(instance, instance_current_src_offset, instance_playrate)

if _state.propagation.user_wants_option.position then
    take_markers_source_offset = _state.superitem.params.fresh_glue.edited_pool.source_offset - _state.superitem.params.preedit.edited_pool.source_offset

    Reglue.adjustPostGlueTakeMarkersAndEnvelopes(instance, nil, take_markers_source_offset)

    if not sibling_negative_position_validation then
      reaper.SetMediaItemPosition(instance, instance_adjusted_position, _constant.api.dont_refresh_ui)
    end

    if _state.propagation.user_wants_option.source_position == nil then
      _state.propagation.user_wants_option.source_position = _common.getUserPropagationChoice("source_position", _constant.data.key.options.switch.maintain_source_position)
    end

    if _state.propagation.user_wants_option.source_position then
      reaper.SetMediaItemTakeInfo_Value(instance_active_take, _constant.api.take.key.src_offset, instance_current_src_offset)
    end

  else
    Reglue.adjustPostGlueTakeMarkersAndEnvelopes(instance)
  end

  return instance_would_get_adjusted_before_project_start
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
  _state.propagation.user_wants_option.length = _common.getUserPropagationChoice("length", _constant.data.key.options.switch.propagate_length)

  if _state.propagation.user_wants_option.length then
    _state.propagation.user_wants_option.playrate_toggle = _common.getUserPropagationChoice("playrate_toggle", _constant.data.key.options.switch.playrate_affects_propagation)
    _state.propagation.user_wants_option.absolute_length_propagation = _common.getUserPropagationChoice("absolute_length_propagation", _constant.data.key.options.switch.length_propagation_type)
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


return Reglue