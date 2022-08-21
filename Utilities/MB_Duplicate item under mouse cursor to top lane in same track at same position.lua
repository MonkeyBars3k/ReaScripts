-- @noindex

reaper.Undo_BeginBlock()

local user_selected_items_count, user_selected_items, command_id_select_item_under_mouse_cursor, command_id_deselect_all_items, item_under_cursor, active_track, retval, item_under_cursor_chunk, item_under_cursor_position, newly_created_item

user_selected_items_count = reaper.CountSelectedMediaItems(0)
user_selected_items = {}
command_id_select_item_under_mouse_cursor = 40528
command_id_deselect_all_items = 40289

for i = 0, user_selected_items_count-1 do
  table.insert(user_selected_items, reaper.GetSelectedMediaItem(0, i))
end

reaper.Main_OnCommand(command_id_select_item_under_mouse_cursor, 0)

item_under_cursor = reaper.GetSelectedMediaItem(0, 0)

if item_under_cursor then
  active_track = reaper.GetMediaItem_Track(item_under_cursor)
  retval, item_under_cursor_chunk = reaper.GetItemStateChunk(item_under_cursor, "", false)
  item_under_cursor_position = reaper.GetMediaItemInfo_Value(item_under_cursor, "D_POSITION")
  newly_created_item = reaper.AddMediaItemToTrack(active_track)
  
  reaper.SetItemStateChunk(newly_created_item, item_under_cursor_chunk, false)
  reaper.SetMediaItemInfo_Value(newly_created_item, "F_FREEMODE_Y", 0)
  reaper.SetMediaItemPosition(newly_created_item, item_under_cursor_position, false)
  reaper.Main_OnCommand(command_id_deselect_all_items, 0)

  for i = 1, #user_selected_items do
    reaper.SetMediaItemSelected(user_selected_items[i], true)
  end

  reaper.UpdateArrange()
end

reaper.Undo_EndBlock("MB_Duplicate item under mouse cursor to top lane in same track at same position", -1)