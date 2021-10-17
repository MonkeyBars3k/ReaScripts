-- @description Reveal contents of existing container item, retaining group
-- @author MonkeyBars
-- @version 1.07
-- @changelog nomenclature
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB Glue (Reversible) Utils")


function unglueGroup()

  -- only get first selected item. no unglue of multiple items
  item = reaper.GetSelectedMediaItem(0,0)

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