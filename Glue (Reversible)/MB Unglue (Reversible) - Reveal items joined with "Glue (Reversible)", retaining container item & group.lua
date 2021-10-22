-- @description MB Unglue (Reversible): Reveal constituent items of previously Glue (Reversible) container item, retaining group
-- @author MonkeyBars
-- @version 1.23
-- @changelog Tighten error messages
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB Glue (Reversible) Utils")


function unglueGroup()
  local num_items, selected_items, num_containers_selected, noncontainers, i, glued_container, item_track, prev_item_track, item, multiitem_result, noncontainer_idx

  num_items = reaper.CountSelectedMediaItems(0)

 
  selected_items = {}
  num_containers_selected = 0
  noncontainers = {}
  msg_change_selected_items = "Change the items selected and try again."
  i = 0
  while i < num_items do
    selected_items[i] = reaper.GetSelectedMediaItem(0, i)
    glued_container = checkItemForGlueGroup(selected_items[i])
    
     -- check whether items glued/unglued
    if glued_container then
      num_containers_selected = num_containers_selected + 1
    else
      table.insert(noncontainers, i)
    end

    -- check for multitrack
    item_track = reaper.GetMediaItemTrack(selected_items[i])
    -- this item's track differs from the last?
    if item_track and prev_item_track and item_track ~= prev_item_track then
      -- display "OK" message and quit
      reaper.ShowMessageBox(msg_change_selected_items, "Unglue (Reversible) can only unglue items on a single track.", 0)
      return false
    end
    prev_item_track = item_track

    i = i + 1
  end

  -- Throw error if zero or multiple container items selected
  if num_containers_selected == 0 then
    reaper.ShowMessageBox(msg_change_selected_items, "Unglue (Reversible) can only unglue previously glued container items." , 0)
    return
  elseif num_containers_selected > 1 then
    multiitem_result = reaper.ShowMessageBox("Would you like to Unglue the first (earliest) selected container item only?", "Unglue (Reversible) can only unglue a single glued container item at a time.", 1)
    if multiitem_result == 2 then
      return
    end
  end

  -- deselect noncontainers
  i = 0
  while i < #noncontainers do
    -- LUA starts iteration at 1.
    noncontainer_idx = noncontainers[i+1]
    reaper.SetMediaItemSelected(selected_items[noncontainer_idx], false)
    i = i + 1
  end
  if #noncontainers > 0 then
    reaper.UpdateArrange()
  end


  -- only get first selected item. no unglue of multiple items (yet)
  item = reaper.GetSelectedMediaItem(0, 0)

  -- make sure we selected something that is a glued group instance
  if item then glue_group = checkItemForGlueGroup(item) end

  if glue_group and item then

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    -- store state of glued item
    original_state = getSetObjectState(item)
    original_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    original_track = reaper.GetMediaItemTrack(item)

    -- deselect all
    deselect()

    -- restore stored items
    _, container = restoreItems(glue_group, original_track, original_pos)

    -- create a unique key for original state, and store it in container's name, space it out of sight then store it in ProjExtState
    original_state_key = "original_state:"..glue_group..":"..os.time()*7
    getSetItemName(container, "                                                                                                      "..original_state_key, 1)
    reaper.SetProjExtState(0, "GLUE_GROUPS", original_state_key, original_state)

    --remove item from track
    reaper.DeleteTrackMediaItem(original_track, item)

    -- clean up
    reaper.PreventUIRefresh(-1)
    reaper.UpdateTimeline()
    reaper.UpdateArrange()
    reaper.TrackList_AdjustWindows(true)
    reaper.Undo_EndBlock("Unglue (Reversible)", -1)

  end
end


unglueGroup()