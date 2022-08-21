-- @noindex

reaper.Undo_BeginBlock()

local selected_tracks_count, all_tracks_count, child_tracks, parent_tracks, this_selected_track, this_parent_track

selected_tracks_count = reaper.CountSelectedTracks(0)
all_tracks_count = reaper.GetNumTracks()
child_tracks = {}
parent_tracks = {}


for i = 0, selected_tracks_count-1 do
  this_selected_track = reaper.GetSelectedTrack(0, i)
  this_parent_track = reaper.GetParentTrack(this_selected_track)

  if this_parent_track then
    table.insert(child_tracks, this_selected_track)
    table.insert(parent_tracks, this_parent_track)
  end
end

for i = 1, #child_tracks do
  reaper.SetTrackSelected(child_tracks[i], false)
end

for i = 1, #parent_tracks do
  reaper.SetTrackSelected(parent_tracks[i], true)
end

reaper.Undo_EndBlock("MB_Deselect tracks if child track(s) & select their direct parent folder track(s)", -1)