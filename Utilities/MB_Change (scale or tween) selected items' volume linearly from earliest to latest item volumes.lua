-- @noindex

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local num_selected_items, first_item, last_item, first_item_vol, last_item_vol, first_item_pos, last_item_pos, slope

num_selected_items = reaper.CountSelectedMediaItems(0)

if num_selected_items < 2 then return end

first_item = reaper.GetSelectedMediaItem(0, 0)
last_item = reaper.GetSelectedMediaItem(0, num_selected_items - 1)
first_item_vol = reaper.GetMediaItemInfo_Value(first_item, "D_VOL")
last_item_vol = reaper.GetMediaItemInfo_Value(last_item, "D_VOL")
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
reaper.Undo_EndBlock("MB_Change selected items' volume linearly from earliest to latest item volumes", -1)