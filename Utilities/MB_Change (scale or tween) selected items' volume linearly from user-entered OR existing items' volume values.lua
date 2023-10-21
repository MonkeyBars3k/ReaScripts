-- @noindex

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local num_selected_items, retval, input_str, target_volume, start_volume, first_item, last_item, first_item_vol, last_item_vol, first_item_pos, last_item_pos, slope

num_selected_items = reaper.CountSelectedMediaItems(0)

if num_selected_items < 2 then return end

retval, input_str = reaper.GetUserInputs("Set Volumes", 2, "Start Volume for First Item (dB):\r(optional, otherwise will use existing values),Target Volume for Last Item (dB):", ",")

if not retval then return end

start_volume, target_volume = input_str:match("([^,]+),([^,]+)")
first_item = reaper.GetSelectedMediaItem(0, 0)
first_item_vol = reaper.GetMediaItemInfo_Value(first_item, "D_VOL")

if start_volume ~= "" then
  start_volume = tonumber(start_volume)

  if start_volume then
    first_item_vol = 10 ^ (start_volume / 20)
  end
end

last_item = reaper.GetSelectedMediaItem(0, num_selected_items - 1)
last_item_vol = reaper.GetMediaItemInfo_Value(last_item, "D_VOL")

if target_volume ~= "" then
  target_volume = tonumber(target_volume)

  if target_volume then
    last_item_vol = 10 ^ (target_volume / 20)
  end
end

first_item_pos = reaper.GetMediaItemInfo_Value(first_item, "D_POSITION")
last_item_pos = reaper.GetMediaItemInfo_Value(last_item, "D_POSITION")
slope = (last_item_vol - first_item_vol) / (last_item_pos - first_item_pos)

for i = 0, num_selected_items - 1 do
  local item, item_pos, new_vol
  
  item = reaper.GetSelectedMediaItem(0, i)
  item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  new_vol = first_item_vol + slope * (item_pos - first_item_pos)

  reaper.SetMediaItemInfo_Value(item, "D_VOL", new_vol)
end

reaper.UpdateTimeline()
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("MB_Change selected items' volume linearly from user-entered OR existing items' volume values", -1)