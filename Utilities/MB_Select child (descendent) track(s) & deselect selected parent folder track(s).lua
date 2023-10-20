-- @description MB_Utilities: Various utility scripts for Reaper
-- @author MonkeyBars
-- @version 1.5.1
-- @changelog Add field for earliest item in changing items' volume linearly; Add script for changing item's volume linearly with no inputs
-- @provides [main] .
--   [main] MB_Change selected items' volume linearly from earliest item volume to entered target volume.lua
--   [main] MB_Change selected items' volume linearly from earliest to latest item volumes.lua
--   [main] MB_Create new autoincremented folder and save project.lua
--   [main] MB_Create new pair of grouped tracks with MIDI & stereo audio routing to & from selected (virtual instrument) tracks.lua
--   [main] MB_Deselect tracks if child track(s) & select their direct parent folder track(s).lua
--   [main] MB_Duplicate item under mouse cursor to top lane in same track at same position.lua
--   [main] MB_Edit project marker with highest index at position.lua
--   [main] MB_Open item properties or subproject or MIDI Editor and zoom to content.lua
--   [main] MB_Set all takes on selected items to same series of random colors, correllated by take number.lua
--   [main] DP_Set track playback offset - MB_multitrack.lua
--   [nomain] mb-dev-functions.lua
--   gnu_license_v3.txt

-- NOTES:
-- "MB_Open MIDI Editor or audio item properties.lua" requires Stephan Roemer's script "sr_Open MIDI editor and zoom to content.lua" available in his ReaPack repo: https://github.com/StephanRoemer/ReaScripts/raw/master/index.xml



reaper.Undo_BeginBlock()

local _api_current_project, _user_selected_tracks_count, _all_tracks_count, _user_selected_tracks, _descendent_tracks, this_selected_track, this_track

_api_current_project = 0
_user_selected_tracks_count = reaper.CountSelectedTracks(_api_current_project)
_all_tracks_count = reaper.GetNumTracks()
_user_selected_tracks = {}
_descendent_tracks = {}


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


for i = 0, _user_selected_tracks_count-1 do
  this_selected_track = reaper.GetSelectedTrack(_api_current_project, i)
  
  for j = 0, _all_tracks_count-1 do
    this_track = reaper.GetTrack(_api_current_project, j)

    if trackIsDescendent(this_track, this_selected_track) then
      table.insert(_descendent_tracks, this_track)
    end
  end

  table.insert(_user_selected_tracks, this_selected_track)
end

for i = 1, #_user_selected_tracks do
  reaper.SetTrackSelected(_user_selected_tracks[i], false)
end

for i = 1, #_descendent_tracks do
  reaper.SetTrackSelected(_descendent_tracks[i], true)
end

reaper.Undo_EndBlock("MB_Select child (descendent) track(s) & deselect selected parent folder track(s)", -1)