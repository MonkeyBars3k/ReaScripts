-- @description MB_Utilities: Various utility scripts for Reaper
-- @author MonkeyBars
-- @version 1.1.5
-- @changelog Change new script name; add subproject
-- @provides [main] .
--   [main] MB_Create new autoincremented folder and save project.lua
--   [main] MB_Deselect child tracks & select their parent folder.lua
--   [main] MB_Open item properties or subproject or MIDI Editor and zoom to content.lua
--   gnu_license_v3.txt

-- NOTES:
-- "MB_Open MIDI Editor or audio item properties.lua" requires Stephan Roemer's script "Script: sr_Open MIDI editor and zoom to content.lua" available in his ReaPack repo: https://github.com/StephanRoemer/ReaScripts/raw/master/index.xml


-- to do:
-- add checks for more track nesting
-- check for no tracks selected

local i, this_selected_track, j, this_track, this_parent_track

reaper.Undo_BeginBlock()

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

reaper.Undo_EndBlock("MB_Select child tracks & deselect selected parent folder", -1)