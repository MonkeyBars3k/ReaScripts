-- @noindex

local Lanes = {}


local loadDependencies, loadCircularDependencies, _constant, _data, _dev, _module_utils, _common


loadDependencies = (function()
  _constant = require("modules.constant")
  _data = require("modules.data")
  _dev = require("modules.dev")

  _module_utils = require("module-utils")
end)()


loadCircularDependencies = (function()
  _common = function() return _module_utils.lazyRequire("common") end
end)()



function Lanes.getLaneYPosition(laneNum, item)
  -- Calculate Y position based on track's actual height and lane count
  local track = reaper.GetMediaItemTrack(item)
  local trackHeight = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
  local laneCount = reaper.GetMediaTrackInfo_Value(track, _constant.api.track.key.num_fixed_lanes)
  if laneCount <= 0 then laneCount = 1 end

  local laneHeight = trackHeight / laneCount
  return laneNum * laneHeight
end


function Lanes.storeItemLaneDeltas(items, pool_id)

  if not _constant.support.fixed_lanes then return end

  local top_lane, item_lane, delta, max_delta

  top_lane = 0
  max_delta = 0

  for i = 1, #items do
    item_lane = reaper.GetMediaItemInfo_Value(items[i], _constant.api.item.key.lane_num) or 0

    if item_lane < top_lane then
      top_lane = item_lane
    end
  end

  for i = 1, #items do
    item_lane = reaper.GetMediaItemInfo_Value(items[i], _constant.api.item.key.lane_num) or 0
    delta = item_lane - top_lane
    max_delta = math.max(max_delta, delta)

    _data.storeRetrieveItemData(items[i], _constant.data.key.suffix.item.lane_delta, tostring(delta))
  end

  _data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.contained_items_max_lane_delta, tostring(max_delta))
end


function Lanes.validateAndGetTrack(items)
    if not _constant.support.fixed_lanes then
        _dev.log("Lane support disabled")
        return nil
    end

    if #items == 0 then
        _dev.log("No items to restore")
        return nil
    end

    local track = reaper.GetMediaItemTrack(items[1])

    if not track then
        _dev.log("Could not find track for items")
        return nil
    end

    _dev.log("Track validation successful")
    return track
end


function Lanes.calculateMaxLaneDelta(item)
    local max_lane_delta, delta

    max_lane_delta = 0
    delta = _data.storeRetrieveItemData(item, _constant.data.key.suffix.item.lane_delta)
    delta = tonumber(delta) or 0
    max_lane_delta = math.max(max_lane_delta, delta)

    return max_lane_delta
end


function Lanes.addRequiredLanesToTrack(track, pool_id)
  local contained_items_max_lane_delta, num_current_lanes, num_new_lanes_required, num_lanes_after_added

  reaper.SetOnlyTrackSelected(track)

  contained_items_max_lane_delta = _data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.contained_items_max_lane_delta)
  contained_items_max_lane_delta = tonumber(contained_items_max_lane_delta)
  num_current_lanes = reaper.GetMediaTrackInfo_Value(track, _constant.api.track.key.num_fixed_lanes)

  if contained_items_max_lane_delta > num_current_lanes then
    num_new_lanes_required = contained_items_max_lane_delta - num_current_lanes + 1

    for i = 1, num_new_lanes_required do
      reaper.Main_OnCommand(_constant.cmd.add_lane_to_track, _constant.api.cmd_flag)
    end
  end

  num_lanes_after_added = reaper.GetMediaTrackInfo_Value(track, _constant.api.track.key.num_fixed_lanes)

  return num_lanes_after_added
end

function Lanes.restoreItemLaneDelta(item, superitem, track)

    if not _constant.support.fixed_lanes then return end

    local top_lane = reaper.GetMediaItemInfo_Value(superitem, "I_FIXEDLANE")
    local num_track_lanes = reaper.GetMediaTrackInfo_Value(track, _constant.api.track.key.num_fixed_lanes)
    local lane_delta = _data.storeRetrieveItemData(item, _constant.data.key.suffix.item.lane_delta)
    lane_delta = tonumber(lane_delta) or 0
    local target_lane = top_lane + lane_delta
    local new_y_value = target_lane / num_track_lanes

    reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_Y", new_y_value)
end


function Lanes.enableFixedLanesTemporarily(track, minLaneCount)
  if not track then return nil end

  local old_mode = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
  local old_laneCount = reaper.GetMediaTrackInfo_Value(track, _constant.api.track.key.num_fixed_lanes)

  -- Force track into fixed lanes mode
  reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)

  -- Set a reasonable lane count (3-5 is safe)
  local newCount = minLaneCount or 3
  newCount = math.max(3, math.min(newCount, 10)) -- Between 3 and 10
  reaper.SetMediaTrackInfo_Value(track, _constant.api.track.key.num_fixed_lanes, newCount)

  reaper.UpdateArrange()

  return {
    track = track,
    old_mode = old_mode,
    old_laneCount = old_laneCount
  }
end


function Lanes.restoreTrackMode(settings)
  if not settings or not settings.track then return end

  -- Always restore the original mode, regardless of what it was
  reaper.SetMediaTrackInfo_Value(settings.track, "I_FOLDERCOMPACT", settings.old_mode)

  -- Put back the old lane count
  reaper.SetMediaTrackInfo_Value(settings.track, _constant.api.track.key.num_fixed_lanes, settings.old_laneCount)

  -- Put back the old freemode setting
  reaper.SetMediaTrackInfo_Value(settings.track, "B_FREEMODE", settings.old_freeMode)

  reaper.UpdateArrange()
end


function Lanes.applyLanePositionToItem(item, referenceLane)
  if not _constant.support.fixed_lanes then return end

  local laneDeltaStr = _data.storeRetrieveItemData(item, _constant.data.key.suffix.item.lane_offset)
  local laneDelta = tonumber(laneDeltaStr) or 0

  -- Sanity check - don't allow extremely large offsets
  laneDelta = math.min(laneDelta, 20)  -- Cap at 20 lanes difference max
  local targetLane = referenceLane + laneDelta

  -- Get track info
  local track = reaper.GetMediaItemTrack(item)
  local trackHeight = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")

  -- Ensure track is in fixed lane mode
  local trackMode = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
  if trackMode ~= 2 then
    reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)
  end

  -- Ensure a reasonable lane count with a hard maximum
  local currentLaneCount = reaper.GetMediaTrackInfo_Value(track, _constant.api.track.key.num_fixed_lanes)
  local neededLaneCount = math.min(targetLane + 1, 20)  -- +1 because lanes are zero-based, cap at 20

  if currentLaneCount < neededLaneCount then
    reaper.SetMediaTrackInfo_Value(track, _constant.api.track.key.num_fixed_lanes, neededLaneCount)
  end

  -- Calculate Y position with sanity checks
  local laneCount = reaper.GetMediaTrackInfo_Value(track, _constant.api.track.key.num_fixed_lanes)
  local laneHeight = trackHeight / math.max(1, laneCount)

  -- Ensure target lane is within valid range
  targetLane = math.min(targetLane, laneCount - 1)
  targetLane = math.max(targetLane, 0)

  local yPosition = targetLane * laneHeight

  -- Set the item to free positioning mode
  reaper.SetMediaItemInfo_Value(item, "B_FREEMODE", 1)

  -- Set Y position - this is what actually controls the lane
  reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_Y", yPosition)

  -- Force REAPER to update visuals
  reaper.UpdateArrange()
end


function Lanes.fixItemLanePositions(items, track, desiredLane)
  if not _constant.support.fixed_lanes or #items == 0 then return end

  -- Get current lane count
  local currentLaneCount = reaper.GetMediaTrackInfo_Value(track, _constant.api.track.key.num_fixed_lanes)

  -- Default to lane 0 if not specified (lane indexing appears to be 0-based)
  desiredLane = desiredLane or 0
  desiredLane = math.max(0, math.min(desiredLane, currentLaneCount - 1)) -- Keep in safe range

  -- Force track to fixed lanes mode
  reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)

  -- Calculate lane height
  local trackH = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
  local laneHeight = trackH / math.max(1, currentLaneCount)

  -- Position all items in the specified lane
  for _, item in ipairs(items) do
    reaper.SetMediaItemInfo_Value(item, "B_FREEMODE", 1)
    reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_Y", desiredLane * laneHeight)
  end

  reaper.UpdateArrange()
end



return Lanes
