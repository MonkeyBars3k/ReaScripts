-- @description MB_Utilities: Various utility scripts for Reaper
-- @author MonkeyBars
-- @version 1.1
-- @changelog Add undo blocks; add multisend script; organize metapackage
-- @provides [main] .
--   [main] MB_Deselect child tracks & select their parent folder.lua
--   [main] MB_Select child tracks & deselect selected parent folder.lua
--   [nomain] benmrx_debug.lua
--   [nomain] serpent.lua
--   [nomain] rtk.lua
--   gnu_license_v3.txt
-- @link 
-- @about Allows setting multiple sends or receives in one go


-- Copyright (C) MonkeyBars 2022
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your routing_option) any later version.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

-- to do:
-- get all tracks; filter out selected; list with checkboxes as target tracks

package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"

-- for dev only
require("sg-dev-functions")


local rtk = require('rtk')


local selected_tracks_count

selected_tracks_count = reaper.CountSelectedTracks(0)


function launchDialog()
  local routing_options_window, routing_options_viewport, routing_options_window_content, routing_option_type_subheading, routing_option_target_tracks_subheading, routing_options_window_title, routing_options_form_fields, routing_option_form_buttons, routing_option_type_dropdown, routing_option_form_submit, routing_option_form_cancel, routing_option_target_tracks, routing_options_window_content_height

  routing_options_window = rtk.Window{title = "MB_Add routing to selected track(s)"}
  routing_options_viewport = rtk.Viewport{halign = "center", padding = "0 38", vscrollbar = "always"}
  routing_options_window_content = rtk.VBox{halign = "center", padding = "27 0 7"}
  routing_options_window_title = rtk.Heading{"Choose routing type and target from/to track(s)", w = 1, halign = "center", bmargin = 25, fontsize = 22}
  routing_option_type_subheading = rtk.Text{"What kind of routing do you want to add to the selected track(s)?"}
  routing_option_target_tracks_subheading = rtk.Text{"Which track(s) do you want to send to or receive from?", tmargin = 20}
  routing_options_form_fields = rtk.VBox{margin = 10, spacing = 10}
  routing_option_form_buttons = rtk.HBox{margin = 10, spacing = 10}
  routing_option_type_dropdown = rtk.OptionMenu{menu = {"send", "receive"}, fontsize = 16}
  routing_option_form_submit = rtk.Button{"Add", disabled = true}
  routing_option_form_cancel = rtk.Button{"Cancel"}
  routing_option_form_cancel.onclick = function() 
    routing_options_window:close()
  end
  routing_option_target_tracks = populateTargetTrackChoices(routing_option_form_submit)

  routing_option_type_dropdown:attr("selected", 1)
  routing_options_window_content:add(routing_options_window_title)
  routing_options_form_fields:add(routing_option_type_subheading)
  routing_options_form_fields:add(routing_option_type_dropdown)
  routing_options_form_fields:add(routing_option_target_tracks_subheading)
  routing_options_form_fields:add(routing_option_target_tracks)
  routing_options_window_content:add(routing_options_form_fields)
  routing_option_form_buttons:add(routing_option_form_submit)
  routing_option_form_buttons:add(routing_option_form_cancel)
  routing_options_window_content:add(routing_option_form_buttons)
  routing_options_viewport:attr("child", routing_options_window_content)
  routing_options_window:add(routing_options_viewport)
  routing_options_window:open()
  routing_options_window:close()

  routing_options_window_content_height = routing_options_window:calc("h") / rtk.scale.framebuffer
  
  routing_options_window:attr("h", routing_options_window_content_height)
  routing_options_window:open{halign='center', valign='center'}
end


function populateTargetTrackChoices(routing_option_form_submit)
  local selected_tracks, all_tracks_count, routing_option_target_tracks, i, this_track, this_track_is_selected, j, this_selected_track, this_track_num, retval, this_track_name

  selected_tracks = getSelectedTracks()
  all_tracks_count = reaper.CountTracks(0)
  routing_option_target_tracks = rtk.FlowBox{w = 1}

  for i = 0, all_tracks_count-1 do
    this_track = reaper.GetTrack(0, i)
    this_track_is_selected = false

    for j = 0, #selected_tracks-1 do
      this_selected_track = reaper.GetSelectedTrack(0, j)

      if this_track == this_selected_track then
        this_track_is_selected = true

        break
      end
    end

    if this_track_is_selected == false then
      this_track_num = reaper.GetMediaTrackInfo_Value(this_track, "IP_TRACKNUMBER")
      retval, this_track_name = reaper.GetSetMediaTrackInfo_String(this_track, "P_NAME", "", 0)
      this_track_checkbox = rtk.CheckBox{math.tointeger(this_track_num) .. " " .. this_track_name, margin = "2 0", fontsize = 14}
      this_track_checkbox.onchange = function()
        activateSubmitButton(routing_option_form_submit)
      end

      routing_option_target_tracks:add(this_track_checkbox)
    end
  end

  return routing_option_target_tracks
end


function getSelectedTracks()
  local selected_tracks, i, this_selected_track

  selected_tracks = {}

  for i = 0, selected_tracks_count-1 do
    this_selected_track = reaper.GetSelectedTrack(0, i)

    table.insert(selected_tracks, this_selected_track)
  end

  return selected_tracks
end


function activateSubmitButton(submit_button)
  submit_button:attr("disabled", false)
end


function initAddRouting()
  if selected_tracks_count > 0 then
    reaper.Undo_BeginBlock()
    launchDialog()
    reaper.Undo_EndBlock("MB_Add routing to selected tracks from/to...", -1)
  end
end

initAddRouting()
