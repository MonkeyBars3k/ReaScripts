-- @noindex

reaper.Undo_BeginBlock()

local selected_items_count, color_set, this_selected_item, this_selected_item_takes_count, this_selected_take, random_color_r, random_color_g, random_color_b

selected_items_count = reaper.CountSelectedMediaItems(0)
color_set = {}

for i = 0, selected_items_count-1 do
  this_selected_item = reaper.GetSelectedMediaItem(0, i)
  this_selected_item_takes_count = reaper.CountTakes(this_selected_item)

  for j = 0, this_selected_item_takes_count-1 do
    this_selected_take = reaper.GetMediaItemTake(this_selected_item, j)

    if not color_set[j] then
      random_color_r = math.random(0,255)
      random_color_g = math.random(0,255)
      random_color_b = math.random(0,255)
      color_set[j] = reaper.ColorToNative(random_color_r, random_color_g, random_color_b)|0x1000000
    end

    reaper.SetMediaItemTakeInfo_Value(this_selected_take, "I_CUSTOMCOLOR", color_set[j])
  end

  reaper.UpdateItemInProject(this_selected_item)
end

reaper.Undo_EndBlock("Set all takes on selected items to same series of random colors, correllated by take number", -1)