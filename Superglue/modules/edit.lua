-- @noindex

local Edit = {}


local _setup = require("modules.setup")
local _common, _constant, _data, _glue, _state = _setup.load("common, constant, data, glue, state")
local _dev = _setup.load("dev")

function Edit.injectDependencies(modules)
  _common = modules.common
  _constant = modules.constant
  _data = modules.data
  _glue = modules.glue
  _state = modules.state

  _dev = modules.dev
end



function Edit.handleEditOrUnglue(superitem, pool_id, action)

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

  if _constant.support.fixed_lanes then
    -- Get superitem's current Y position
    local superitemY = reaper.GetMediaItemInfo_Value(superitem, "F_FREEMODE_Y")
    _data.storeRetrievePoolData(pool_id, "edit_superitem_y", tostring(superitemY))

    local currentLaneCount = reaper.GetMediaTrackInfo_Value(active_track, "I_NUMFIXEDLANES")
    -- Use rounding instead of flooring for more accurate lane calculation
    local currentLane = math.floor(superitemY * currentLaneCount + 0.5)
    _data.storeRetrievePoolData(pool_id, "edit_superitem_lane", tostring(currentLane))

    if _dev.config.test_logging_enabled then
      _dev.log("EDIT: Stored superitem Y=" .. superitemY .. ", lane=" .. currentLane .. ", laneCount=" .. currentLaneCount)
    end
  end

  _data.storeRetrieveSuperitemParams(pool_id, _constant.actionstep.preedit, superitem)
  _data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.preglue.superitem_state, superitem_state)

  local restored_items = _common.restoreStoredItems(pool_id, active_track, superitem, nil, action, nil)

  local sizing_region_guid = Edit.createSizingRegionFromSuperitem(superitem, pool_id)
  _state.action.edit_or_unglue.restored_items = restored_items

  reaper.DeleteTrackMediaItem(active_track, superitem)
  Edit.updateRestoredItemsData(restored_items, pool_id)
end


function Edit.processUnglue(superitem, pool_id, action)
  local superitem_preedit_params = _data.getSetItemParams(superitem)
  local active_track = reaper.BR_GetMediaTrackByGUID(_constant.api.current_project, superitem_preedit_params.track_guid)

  if _constant.support.fixed_lanes then
    -- Store superitem's current Y position and lane (like in processEdit)
    local superitemY = reaper.GetMediaItemInfo_Value(superitem, "F_FREEMODE_Y")
    _data.storeRetrievePoolData(pool_id, "edit_superitem_y", tostring(superitemY))

    local currentLaneCount = reaper.GetMediaTrackInfo_Value(active_track, "I_NUMFIXEDLANES")
    -- Use rounding instead of flooring for more accurate lane calculation
    local currentLane = math.floor(superitemY * currentLaneCount + 0.5)
    _data.storeRetrievePoolData(pool_id, "edit_superitem_lane", tostring(currentLane))

    if _dev.config.test_logging_enabled then
      _dev.log("UNGLUE: Stored superitem Y=" .. superitemY .. ", lane=" .. currentLane .. ", laneCount=" .. currentLaneCount)
    end

    -- Get the original lane count
    local originalLaneCountStr = _data.storeRetrievePoolData(pool_id, "original_lane_count")
    local originalLaneCount = tonumber(originalLaneCountStr) or currentLaneCount -- Default to current count if not stored

    -- Force track to fixed lanes mode
    reaper.SetMediaTrackInfo_Value(active_track, "I_FOLDERCOMPACT", 2)
    reaper.SetMediaTrackInfo_Value(active_track, "I_NUMFIXEDLANES", originalLaneCount)
    reaper.UpdateArrange()
  end

  local restored_items = _common.restoreStoredItems(pool_id, active_track, superitem, nil, action)
  _state.action.edit_or_unglue.restored_items = restored_items

  reaper.DeleteTrackMediaItem(active_track, superitem)
  return pool_id, restored_items
end


function Edit.validateRestoredItemPositions(superitem, pool_id, action)
  local stored_item_states = _data.getStoredItemStatesTable(pool_id, action)
  local superitem_params = _data.getSetItemParams(superitem)
  local post_glue_params = _data.storeRetrieveSuperitemParams(pool_id, _constant.actionstep.postglue)

  if not post_glue_params then return true end

  local position_delta = superitem_params.position - post_glue_params.position

  for item_guid, stored_item_state in pairs(stored_item_states) do
    if stored_item_state then
      local temp_track = reaper.GetTrack(0, 0)
      local temp_item = reaper.AddMediaItemToTrack(temp_track)
      _data.getSetItemStateChunk(temp_item, stored_item_state)
      local stored_position = reaper.GetMediaItemInfo_Value(temp_item, _constant.api.item.key.position)
      reaper.DeleteTrackMediaItem(temp_track, temp_item)

      local adjusted_position = stored_position + position_delta

      if adjusted_position < 0 then
        reaper.ShowMessageBox("This operation cannot be completed because one or more items would be placed before the start of the project.", "Cannot Edit/Unglue", _constant.api.msg.type.ok)
        return false
      end
    end
  end

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
