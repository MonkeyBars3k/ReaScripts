-- @noindex

reaper.Undo_BeginBlock()

-- Initialize variables
local highest_marker_number = -1
local marker_idx_to_edit = -1
local first_marker_idx = -1

-- Get the edit cursor position
local cursor_pos = reaper.GetCursorPosition()

-- Get the number of markers in the project
local num_markers, num_regions = reaper.CountProjectMarkers(0)

-- Loop through all markers to find the one with the highest number at the cursor position
for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers(i)
    if not isrgn then
        if math.abs(pos - cursor_pos) < 1e-5 then  -- Compare positions considering float inaccuracies
            if first_marker_idx == -1 then
                first_marker_idx = i
            end
            if markrgnindexnumber > highest_marker_number then
                highest_marker_number = markrgnindexnumber
                marker_idx_to_edit = i
            end
        end
    end
end

-- Temporarily move the first marker, edit the second, then move the first marker back
if marker_idx_to_edit ~= -1 and first_marker_idx ~= -1 and marker_idx_to_edit ~= first_marker_idx then
    local _, _, pos, _, _, _, _ = reaper.EnumProjectMarkers(first_marker_idx)
    reaper.DeleteProjectMarkerByIndex(0, first_marker_idx)
    reaper.Main_OnCommand(40614, 0)  -- Marker: Edit marker near cursor
    reaper.AddProjectMarker(0, false, pos, 0, "", -1)
end

reaper.Undo_EndBlock("MB_Edit project marker with highest index at position", -1)