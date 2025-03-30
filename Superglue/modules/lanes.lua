-- @noindex

local Lanes = {}


local loadDependencies, _constant, _data, _state

local _dev = require("modules.dev")


loadDependencies = (function()
  _constant = require("modules.constant")
  _data = require("modules.data")
  _state = require("modules.state")
end)()



function Lanes.storeItemLaneDeltas(items, pool_id)

  if not _constant.support.fixed_lanes then return end

  local top_lane, item_lane, delta, max_delta

  top_lane = 0
  max_delta = 0
  top_lane = reaper.GetMediaItemInfo_Value(items[1], _constant.api.item.key.lane_num) or 0

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


function Lanes.addRequiredLanesToTrack(pool_id, track, superitem)
  local contained_items_max_lane_delta, num_current_lanes, superitem_lane_num, num_total_lanes_required, num_new_lanes_required, num_lanes_after_added

  reaper.SetOnlyTrackSelected(track)

  contained_items_max_lane_delta = _data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.contained_items_max_lane_delta)
  contained_items_max_lane_delta = tonumber(contained_items_max_lane_delta)
  num_current_lanes = reaper.GetMediaTrackInfo_Value(track, _constant.api.track.key.num_fixed_lanes)
  superitem_lane_num = reaper.GetMediaItemInfo_Value(superitem, "I_FIXEDLANE")
  num_total_lanes_required = contained_items_max_lane_delta + superitem_lane_num + 1

  if num_total_lanes_required > num_current_lanes then
    num_new_lanes_required = num_total_lanes_required - num_current_lanes

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



return Lanes
