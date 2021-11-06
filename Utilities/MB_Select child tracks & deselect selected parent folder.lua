-- @description Select child tracks & deselect selected parent folder
-- @author MonkeyBars
-- @version 1.0
-- @changelog Initial commit
-- @provides .

local i, this_selected_track, j, this_track, this_parent_track

for i = 0, reaper.CountSelectedTracks(0)-1 do
  this_selected_track = reaper.GetSelectedTrack(0, i)
  
  for j = 0, reaper.GetNumTracks()-1 do
    this_track = reaper.GetTrack(0, j)
    this_parent_track = reaper.GetParentTrack(this_track)
    
    if this_parent_track == this_selected_track then
      reaper.SetTrackSelected(this_track, true)
    end
  end
  
  reaper.SetTrackSelected(this_selected_track, false)
end
