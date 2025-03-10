-- @noindex

local Lanes = {}


local _setup = require("modules.setup")
local _common, _constant, _data = _setup.load("common, constant, data")
local _dev = _setup.load("dev")

function Lanes.injectDependencies(modules)
  _common = modules.common
  _constant = modules.constant
  _data = modules.data

  _dev = modules.dev
end


function Lanes.getLaneYPosition(laneNum, item)
  -- Calculate Y position based on track's actual height and lane count
  local track = reaper.GetMediaItemTrack(item)
  local trackHeight = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
  local laneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
  if laneCount <= 0 then laneCount = 1 end

  local laneHeight = trackHeight / laneCount
  return laneNum * laneHeight
end


function Lanes.storeItemLaneOffsets(items, pool_id)
  if not _constant.support.fixed_lanes or #items == 0 then return end

  -- Get the track
  local track = reaper.GetMediaItemTrack(items[1])

  -- Save current track settings
  local originalMode = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
  local originalLaneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")

  -- Make sure track is in fixed lanes mode for accurate lane detection
  if originalMode ~= 2 then
    reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)
    reaper.UpdateArrange()
  end

  -- Find the topmost lane item (lowest lane number)
  local topLane = 255
  local topLaneItem = nil

  for _, item in ipairs(items) do
    local itemLane = reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE")
    if itemLane < topLane and itemLane < 100 then -- Avoid invalid values
      topLane = itemLane
      topLaneItem = item
    end
  end

  -- Default to lane 0 if we couldn't find a valid lane
  if topLane == 255 then
    topLane = 0
    topLaneItem = items[1] -- Just use the first item if no valid lane found
  end

  -- Store the top lane number
  _data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.top_lane, tostring(topLane))

  -- Get and store the exact Y position of the top lane item
  local itemY = reaper.GetMediaItemInfo_Value(topLaneItem, "F_FREEMODE_Y")
  _data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.top_lane_y_pos, tostring(itemY))

  -- Also store the original lane count
  _data.storeRetrievePoolData(pool_id, "original_lane_count", tostring(originalLaneCount))

  -- Store lane offsets relative to top lane
  for _, item in ipairs(items) do
    local itemLane = reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE")
    local offset = 0

    -- Only calculate offset if lane is valid
    if itemLane < 100 then
      offset = itemLane - topLane
    end

    -- Store the offset
    _data.storeRetrieveItemData(item, _constant.data.key.suffix.item.lane_offset, tostring(offset))
  end

  -- Restore original track mode if needed
  if originalMode ~= 2 then
    reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", originalMode)
    reaper.UpdateArrange()
  end
end


function Lanes.restoreItemLaneOffsets(items, revertTrackAfter, pool_id)
  if not _constant.support.fixed_lanes or #items == 0 then return end

  local track = reaper.GetMediaItemTrack(items[1])
  if not track then return end

  -- Get the superitem's Y position at edit time
  local editYStr = _data.storeRetrievePoolData(pool_id, "edit_superitem_y")
  if not editYStr or editYStr == "" then
    _dev.log("ERROR: No edit_superitem_y found for pool " .. pool_id)
    return
  end

  local editY = tonumber(editYStr)
  local editLaneStr = _data.storeRetrievePoolData(pool_id, "edit_superitem_lane")
  local editLane = tonumber(editLaneStr) or 0

  -- Get the current track settings
  local currentLaneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")

  if _dev.config.test_logging_enabled then
    _dev.log("RESTORE: Using editY=" .. editY .. ", editLane=" .. editLane .. ", currentLaneCount=" .. currentLaneCount)
  end

  -- Find maximum lane offset to calculate required lanes
  local maxLaneOffset = 0
  for _, item in ipairs(items) do
    local offsetStr = _data.storeRetrieveItemData(item, _constant.data.key.suffix.item.lane_offset)
    local offset = tonumber(offsetStr) or 0
    maxLaneOffset = math.max(maxLaneOffset, offset)

    if _dev.config.test_logging_enabled then
      _dev.log("Item offset: " .. offset .. ", max so far: " .. maxLaneOffset)
    end
  end

  -- Calculate required lanes and ensure we have enough
  -- Add +1 to account for 0-based indexing in lanes (need lanes 0-10 for 11 total lanes)
  local requiredLaneCount = editLane + maxLaneOffset + 1

  if _dev.config.test_logging_enabled then
    _dev.log("Required lane count: " .. requiredLaneCount)
  end

  -- Ensure track is in fixed lanes mode
  reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)

  -- Increase lane count if needed - IMPORTANT: We need to add 1 for the right number of lanes
  if requiredLaneCount > currentLaneCount then
    local newLaneCount = requiredLaneCount
    if _dev.config.test_logging_enabled then
      _dev.log("Increasing lane count from " .. currentLaneCount .. " to " .. newLaneCount)
    end
    reaper.SetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES", newLaneCount)
    reaper.UpdateArrange()

    -- Update variable after potentially changing it
    currentLaneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
  end

  -- Position each item according to its offset
  for _, item in ipairs(items) do
    local offsetStr = _data.storeRetrieveItemData(item, _constant.data.key.suffix.item.lane_offset)
    local offset = tonumber(offsetStr) or 0

    -- Calculate target lane and Y position
    local targetLane = editLane + offset

    -- Make sure we use the actual current lane count for Y calculation
    local currentLaneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
    local targetY = targetLane / currentLaneCount

    if _dev.config.test_logging_enabled then
      _dev.log("Setting item with offset " .. offset .. " to lane " .. targetLane .. " (Y=" .. targetY .. ")")
    end

    -- Set item positioning
    reaper.SetMediaItemInfo_Value(item, "B_FREEMODE", 1)
    reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_Y", targetY)
  end

  reaper.UpdateArrange()

  if _dev.config.test_logging_enabled then
    _dev.log("Lane restoration complete")
  end
end


function Lanes.enableFixedLanesTemporarily(track, minLaneCount)
  if not track then return nil end

  local old_mode = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
  local old_laneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")

  -- Force track into fixed lanes mode
  reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)

  -- Set a reasonable lane count (3-5 is safe)
  local newCount = minLaneCount or 3
  newCount = math.max(3, math.min(newCount, 10)) -- Between 3 and 10
  reaper.SetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES", newCount)

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
  reaper.SetMediaTrackInfo_Value(settings.track, "I_NUMFIXEDLANES", settings.old_laneCount)

  -- Put back the old freemode setting
  reaper.SetMediaTrackInfo_Value(settings.track, "B_FREEMODE", settings.old_freeMode)

  reaper.UpdateArrange()
end


function Lanes.applyLanePositionToItem(item, referenceLane)
  if not _constant.support.fixed_lanes then return end

  local laneOffsetStr = _data.storeRetrieveItemData(item, _constant.data.key.suffix.item.lane_offset)
  local laneOffset = tonumber(laneOffsetStr) or 0

  -- Sanity check - don't allow extremely large offsets
  laneOffset = math.min(laneOffset, 20)  -- Cap at 20 lanes difference max
  local targetLane = referenceLane + laneOffset

  -- Get track info
  local track = reaper.GetMediaItemTrack(item)
  local trackHeight = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")

  -- Ensure track is in fixed lane mode
  local trackMode = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
  if trackMode ~= 2 then
    reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)
  end

  -- Ensure a reasonable lane count with a hard maximum
  local currentLaneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
  local neededLaneCount = math.min(targetLane + 1, 20)  -- +1 because lanes are zero-based, cap at 20

  if currentLaneCount < neededLaneCount then
    reaper.SetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES", neededLaneCount)
  end

  -- Calculate Y position with sanity checks
  local laneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
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
  local currentLaneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")

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


function Lanes.debugLaneInfo(label, items, track, pool_id)
  _dev.log("==== LANE DEBUG: " .. label .. " ====")

  -- Track info
  local trackMode = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
  local laneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
  local trackHeight = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
  local trackFreeMode = reaper.GetMediaTrackInfo_Value(track, "B_FREEMODE")

  _dev.log(string.format("TRACK - Mode: %d, Lanes: %d, Height: %d, FreeMode: %d",
    trackMode, laneCount, trackHeight, trackFreeMode))

  -- Pool info
  local topLaneStr = _data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.top_lane)
  _dev.log("Pool #" .. pool_id .. " top lane: " .. (topLaneStr or "nil"))

  -- Items info
  if items then
    for i, item in ipairs(items) do
      if reaper.ValidatePtr(item, "MediaItem*") then
        local name = _common.getSetItemName(item) or "unnamed"
        local fixedLane = reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE")
        local freeY = reaper.GetMediaItemInfo_Value(item, "F_FREEMODE_Y")
        local freeMode = reaper.GetMediaItemInfo_Value(item, "B_FREEMODE")
        local offsetStr = _data.storeRetrieveItemData(item, _constant.data.key.suffix.item.lane_offset)

        _dev.log(string.format(
          "Item %d: %s - Lane: %d, FreeY: %.2f, FreeMode: %d, Offset: %s",
          i, name, fixedLane, freeY, freeMode, offsetStr or "nil"
        ))
      end
    end
  end

  _dev.log("==============================")
end



return Lanes
