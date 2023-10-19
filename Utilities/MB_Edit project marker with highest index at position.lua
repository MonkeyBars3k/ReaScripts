-- @noindex

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local _highest_marker_number, _marker_idx_to_edit, _first_marker_idx, _first_marker_name, _first_marker_color, _cursor_pos, _num_markers, _num_regions, _command_id__edit_marker_near_cursor

_highest_marker_number = -1
_marker_idx_to_edit = -1
_first_marker_idx = -1
_first_marker_name = ""
_first_marker_color = 0
_cursor_pos = reaper.GetCursorPosition()
_num_markers, _num_regions = reaper.CountProjectMarkers(0)
_command_id__edit_marker_near_cursor = 40614

for i = 0, _num_markers + _num_regions - 1 do
  local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers(i)
  
  if not isrgn and math.abs(pos - _cursor_pos) < 1e-5 then

    if _first_marker_idx == -1 then
      _first_marker_idx, _first_marker_name, _first_marker_color = i, name, color
    end
    
    if markrgnindexnumber > _highest_marker_number then
      _highest_marker_number, _marker_idx_to_edit = markrgnindexnumber, i
    end
  end
end

if _marker_idx_to_edit ~= -1 and _first_marker_idx ~= -1 and _marker_idx_to_edit ~= _first_marker_idx then
  local _, _, pos = reaper.EnumProjectMarkers(_first_marker_idx)

  reaper.DeleteProjectMarkerByIndex(0, _first_marker_idx)
  reaper.Main_OnCommand(_command_id__edit_marker_near_cursor, 0)
  
  local new_idx, successful = reaper.AddProjectMarker(0, false, pos, 0, _first_marker_name, -1)
  
  if successful then
    reaper.SetProjectMarkerByIndex(0, new_idx, false, pos, 0, new_idx, _first_marker_color)
  end
end


reaper.UpdateTimeline()
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("MB_Edit project marker with highest index at position", -1)