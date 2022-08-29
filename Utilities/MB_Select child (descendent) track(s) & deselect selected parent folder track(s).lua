-- @description MB_Utilities: Various utility scripts for Reaper
-- @author MonkeyBars
-- @version 1.1.8
-- @changelog Add pooled midi data type to Open script
-- @provides [main] .
--   [main] MB_Create new autoincremented folder and save project.lua
--   [main] MB_Deselect tracks if child track(s) & select their direct parent folder track(s).lua
--   [main] MB_Duplicate item under mouse cursor to top lane in same track at same position.lua
--   [main] MB_Open item properties or subproject or MIDI Editor and zoom to content.lua
--   [main] MB_Set all takes on selected items to same series of random colors, correllated by take number.lua
--   gnu_license_v3.txt

-- NOTES:
-- "MB_Open MIDI Editor or audio item properties.lua" requires Stephan Roemer's script "Script: sr_Open MIDI editor and zoom to content.lua" available in his ReaPack repo: https://github.com/StephanRoemer/ReaScripts/raw/master/index.xml



reaper.Undo_BeginBlock()

local selected_tracks_count, all_tracks_count, descendent_tracks, this_selected_track, this_track

selected_tracks_count = reaper.CountSelectedTracks(0)
all_tracks_count = reaper.GetNumTracks()
descendent_tracks = {}


function trackIsDescendent(current_track, selected_track)
  local parent_track

  parent_track = reaper.GetParentTrack(current_track)
    
  if parent_track == selected_track then

    return true
  
  elseif parent_track then
    return trackIsDescendent(parent_track, selected_track)

  else

    return false
  end
end


for i = 0, selected_tracks_count-1 do
  this_selected_track = reaper.GetSelectedTrack(0, i)
  
  for j = 0, all_tracks_count-1 do
    this_track = reaper.GetTrack(0, j)

    if trackIsDescendent(this_track, this_selected_track) then
      table.insert(descendent_tracks, this_track)
    end
  end
  
  reaper.SetTrackSelected(this_selected_track, false)
end

for i = 1, #descendent_tracks do
  reaper.SetTrackSelected(descendent_tracks[i], true)
end

reaper.Undo_EndBlock("MB_Select child (descendent) track(s) & deselect selected parent folder track(s)", -1)