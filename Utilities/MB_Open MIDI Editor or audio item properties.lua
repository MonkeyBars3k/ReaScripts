-- @noindex

local selected_items_count, open_midi_editor_and_zoom_to_content, show_item_properties, this_selected_item, this_selected_item_active_take, this_selected_item_source, this_selected_item_source_type, at_least_1_midi_item_is_selected

reaper.Undo_BeginBlock()

selected_items_count = reaper.CountSelectedMediaItems(0)
open_midi_editor_and_zoom_to_content = reaper.NamedCommandLookup("_RS84074b5fb92a906b135f993286a2bfb5f7bc86bd")
show_item_properties = 40009

for i = 0, selected_items_count-1 do
  this_selected_item = reaper.GetSelectedMediaItem(0, i)
  this_selected_item_active_take = reaper.GetActiveTake(this_selected_item)

  if this_selected_item_active_take then
    this_selected_item_source = reaper.GetMediaItemTake_Source(this_selected_item_active_take)
    this_selected_item_source_type = reaper.GetMediaSourceType(this_selected_item_source)
  end

  if this_selected_item_source_type == "MIDI" then
    at_least_1_midi_item_is_selected = true
  end
end

if at_least_1_midi_item_is_selected then
  reaper.Main_OnCommand(open_midi_editor_and_zoom_to_content, 0)

else
  reaper.Main_OnCommand(show_item_properties, 0)
end

reaper.Undo_EndBlock("MB_Open MIDI Editor or audio item properties", -1)