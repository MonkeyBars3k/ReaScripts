-- @noindex

local Edit = {}


local loadDependencies, _common, _constant, _data, _state

local _dev = require("modules.dev")

loadDependencies = (function()
  _common = require("modules.common")
  _constant = require("modules.constant")
  _data = require("modules.data")
  _state = require("modules.state")
end)()



function Edit.handleEditOrUnglue(superitem, pool_id, action)
  -- THIS IS FALSEY WHICH IS INCORRECT...?
  if not Edit.validateRestoredItemPositions(superitem, pool_id, action) then

    return false
  end

  if action == "Edit" or action == "Smart Glue/Edit" then
    Edit.processEdit(superitem, pool_id, action)

  elseif action == "Unglue" or action == "Smart Glue/Unglue" then
    Edit.processUnglue(superitem, pool_id, action)
  end
end


function Edit.processEdit(superitem, pool_id, action)
  local superitem_preedit_params = _data.getSetItemParams(superitem)
  local active_track = reaper.BR_GetMediaTrackByGUID(_constant.api.current_project, superitem_preedit_params.track_guid)
  local superitem_state = _data.getSetItemStateChunk(superitem)

  _data.storeRetrieveSuperitemParams(pool_id, _constant.actionstep.preedit, superitem)
  _data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.preglue.superitem_state, superitem_state)

  local restored_items

  -- Reuse validated items if available
  if _state.action.edit_or_unglue.validated_items and #_state.action.edit_or_unglue.validated_items > 0 then
    -- Transfer items from temp track to actual track
    restored_items = {}

    for i = 1, #_state.action.edit_or_unglue.validated_items do
      local item = _state.action.edit_or_unglue.validated_items[i]
      local item_state = _data.getSetItemStateChunk(item)

      local new_item = reaper.AddMediaItemToTrack(active_track)
      _data.getSetItemStateChunk(new_item, item_state)

      table.insert(restored_items, new_item)
    end

    -- Clean up the temp track
    if _state.action.edit_or_unglue.validated_track then
      reaper.DeleteTrack(_state.action.edit_or_unglue.validated_track)
      _state.action.edit_or_unglue.validated_track = nil
    end

  else
    -- Fallback to normal restoration if validation wasn't done
    restored_items = _common.restoreStoredItems(pool_id, active_track, superitem, nil, action, nil)
  end

  local sizing_region_guid = Edit.createSizingRegionFromSuperitem(superitem, pool_id)
  _state.action.edit_or_unglue.restored_items = restored_items

  reaper.DeleteTrackMediaItem(active_track, superitem)
  Edit.updateRestoredItemsData(restored_items, pool_id)

  -- Clear validation state
  _state.action.edit_or_unglue.validated_items = nil
end


function Edit.processUnglue(superitem, pool_id, action)
  local superitem_preedit_params = _data.getSetItemParams(superitem)
  local active_track = reaper.BR_GetMediaTrackByGUID(_constant.api.current_project, superitem_preedit_params.track_guid)
  local restored_items

  -- Reuse validated items if available
  if _state.action.edit_or_unglue.validated_items and #_state.action.edit_or_unglue.validated_items > 0 then
    -- Transfer items from temp track to actual track
    restored_items = {}
    for i = 1, #_state.action.edit_or_unglue.validated_items do
      local item = _state.action.edit_or_unglue.validated_items[i]
      local item_state = _data.getSetItemStateChunk(item)

      local new_item = reaper.AddMediaItemToTrack(active_track)
      _data.getSetItemStateChunk(new_item, item_state)

      table.insert(restored_items, new_item)
    end

    -- Clean up the temp track
    if _state.action.edit_or_unglue.validated_track then
      reaper.DeleteTrack(_state.action.edit_or_unglue.validated_track)
      _state.action.edit_or_unglue.validated_track = nil
    end
  else
    -- Fallback to normal restoration if validation wasn't done
    restored_items = _common.restoreStoredItems(pool_id, active_track, superitem, nil, action)
  end

  _state.action.edit_or_unglue.restored_items = restored_items

  reaper.DeleteTrackMediaItem(active_track, superitem)

  -- Clear validation state
  _state.action.edit_or_unglue.validated_items = nil

  return pool_id, restored_items
end


function Edit.validateRestoredItemPositions(superitem, pool_id, action)
  local superitem_params = _data.getSetItemParams(superitem)
  local post_glue_params = _data.storeRetrieveSuperitemParams(pool_id, _constant.actionstep.postglue)

  if not post_glue_params then return true end

  -- Clear any previous stored items from validation
  _state.action.edit_or_unglue.validated_items = {}
  _state.action.edit_or_unglue.validated_track = nil

  -- Setup state needed for restoration process
  _state.superitem.params.preunglue = _state.superitem.params.preunglue or {}
  _state.superitem.params.preunglue.unglued_pool = superitem_params
  _state.superitem.params.post_glue = _state.superitem.params.post_glue or {}
  _state.superitem.params.post_glue.edited_pool = post_glue_params

  -- Create a hidden temporary track for validation
  local temp_track_idx = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(temp_track_idx, false)
  local temp_track = reaper.GetTrack(0, temp_track_idx)
  reaper.SetMediaTrackInfo_Value(temp_track, "B_SHOWINTCP", 0)
  reaper.SetMediaTrackInfo_Value(temp_track, "B_SHOWINMIXER", 0)

  -- Store the temp track in state
  _state.action.edit_or_unglue.validated_track = temp_track

  -- Use Common.restoreStoredItems to restore the items and check for negative positions
  local restored_items, _, _ = _common.restoreStoredItems(pool_id, temp_track, superitem, nil, action, "validate")

  -- Check for negative positions
  local anyNegativePositions = false
  for i = 1, #restored_items do
    local position = reaper.GetMediaItemInfo_Value(restored_items[i], "D_POSITION")

    if position < 0 then
      anyNegativePositions = true
      break
    end
  end

  if anyNegativePositions then
    -- Clean up temporary items and track if validation fails
    for i = 1, #restored_items do
      reaper.DeleteTrackMediaItem(temp_track, restored_items[i])
    end
    reaper.DeleteTrack(temp_track)

    reaper.ShowMessageBox(
      "This operation cannot be completed because one or more items would be placed before the start of the project.",
      "Cannot Edit/Unglue",
      _constant.api.msg.type.ok
    )
    return false
  end

  -- Store the valid restored items in state for reuse
  _state.action.edit_or_unglue.validated_items = restored_items
  return true
end


function Edit.createSizingRegionFromSuperitem(superitem, pool_id, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled)
  local superitem_params, sizing_region_guid

  superitem_params = _data.getSetItemParams(superitem)

  if looped_source_sets_sizing_region__enabled == "true" and superitem_loop_is_enabled then
    superitem_params.length, superitem_params.end_point = Edit.getSuperitemLoopLength(superitem, superitem_params)
  end

  sizing_region_guid = _common.getSetSizingRegion(pool_id, superitem_params)

  return sizing_region_guid
end


function Edit.getSuperitemLoopLength(superitem, superitem_params)
  local superitem_active_take, superitem_active_take_source, superitem_length, superitem_end_point

  superitem_active_take = reaper.GetActiveTake(superitem)
  superitem_active_take_source = reaper.GetMediaItemTake_Source(superitem_active_take)
  superitem_length = reaper.GetMediaSourceLength(superitem_active_take_source)
  superitem_end_point = superitem_length - superitem_params.position

  return superitem_length, superitem_end_point
end


function Edit.updateRestoredItemsData(restored_items, pool_id)
  local this_restored_item

  for i = 1, #restored_items do
    this_restored_item = restored_items[i]

    _data.storeRetrieveItemData(this_restored_item, _constant.data.key.suffix.pool.parent_id, pool_id)
  end
end



return Edit
