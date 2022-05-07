-- @description MB_Buss Driver - Add routing to selected track(s)...
-- @author MonkeyBars
-- @version 1.1
-- @changelog Add undo blocks; add multisend script; organize metapackage
-- @provides [main] .
--   [nomain] rtk.lua
--   gnu_license_v3.txt
-- @link 
-- @about Allows setting multiple sends or receives to multiple tracks in one go


-- Copyright (C) MonkeyBars 2022
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your routing_option) any later version.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

-- to do:
-- get all tracks; filter out selected; list with checkboxes as target tracks

package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"

-- for dev only
require("mb-dev-functions")


local rtk = require('rtk')


local selected_tracks_count

selected_tracks_count = reaper.CountSelectedTracks(0)


function launchDialog()
  local routing_options_window, routing_options_viewport, routing_options_window_content, routing_option_type_subheading, routing_option_target_tracks_subheading, routing_options_window_title, routing_options_form_fields, routing_option_form_buttons, routing_option_type_dropdown, routing_option_form_submit, routing_option_form_cancel, routing_option_target_tracks_box, routing_options_window_content_height

  routing_options_window = rtk.Window{title = "MB_Buss Driver - Add routing to selected track(s)"}
  routing_options_viewport = rtk.Viewport{halign = "center", padding = "0 38"}
  routing_options_window_content = rtk.VBox{halign = "center", padding = "27 0 7"}
  routing_options_window_title = rtk.Heading{"Buss Driver", w = 1, halign = "center", bmargin = 25}
  routing_option_type_subheading = rtk.Text{"What kind of routing do you want to add to the selected track(s)?"}
  routing_option_type_dropdown = rtk.OptionMenu{menu = {{"send(s)", id = "send"}, {"receive(s)", id = "receive"}}, fontsize = 16, ref = "routing_option_type"}
  routing_option_target_tracks_subheading = rtk.Text{"Which track(s) do you want to send to?", tmargin = 20}
  routing_option_type_dropdown.onchange = function(self)
    local default_routing_msg, routing_type_text

    default_routing_msg = "Which track(s) do you want to "

    if self.selected_id == "send" then
      routing_type_text = "send to?"

    elseif self.selected_id == "receive" then
      routing_type_text = "receive from?"
    end

    routing_option_target_tracks_subheading:attr("text", default_routing_msg .. routing_type_text)
  end
  routing_options_form_fields = rtk.VBox{margin = 10, spacing = 10}
  routing_option_form_buttons = rtk.HBox{margin = 10, spacing = 10}
  routing_option_form_submit = rtk.Button{"Add", disabled = true}
  routing_option_form_cancel = rtk.Button{"Cancel"}
  routing_option_form_cancel.onclick = function() 
    routing_options_window:close()
  end
  routing_option_target_tracks_box = populateTargetTrackChoices(routing_option_form_submit)
  routing_option_form_submit.onclick = function()
    submitRoutingOptionChanges(routing_options_form_fields, routing_options_window)
  end

  routing_option_type_dropdown:attr("selected", 1)
  routing_options_window_content:add(routing_options_window_title)
  routing_options_form_fields:add(routing_option_type_subheading)
  routing_options_form_fields:add(routing_option_type_dropdown)
  routing_options_form_fields:add(routing_option_target_tracks_subheading)
  routing_options_form_fields:add(routing_option_target_tracks_box)
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
  local selected_tracks, all_tracks_count, routing_option_target_tracks_box, all_routing_options, i, this_track, this_track_is_selected, j, this_selected_track, this_track_num, retval, this_track_name

  selected_tracks = getSelectedTracks()
  all_tracks_count = reaper.CountTracks(0)
  routing_option_target_tracks_box = rtk.FlowBox{w = 1, ref = "routing_option_target_tracks_box"}

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
      this_track_num = math.tointeger(reaper.GetMediaTrackInfo_Value(this_track, "IP_TRACKNUMBER"))
      retval, this_track_name = reaper.GetSetMediaTrackInfo_String(this_track, "P_NAME", "", 0)
      this_track_checkbox = rtk.CheckBox{this_track_num .. " " .. this_track_name, margin = "2 0", fontsize = 14, ref = "target_track_" .. this_track_num}
      this_track_checkbox.onchange = function()
        activateSubmitButton(routing_option_form_submit)
      end

      routing_option_target_tracks_box:add(this_track_checkbox)
    end
  end

  return routing_option_target_tracks_box
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


function submitRoutingOptionChanges(routing_options_form_fields, routing_options_window)
  local routing_option_type_choice, routing_option_target_tracks_box, routing_option_target_tracks_choice, selected_tracks, i, this_track_checkbox, this_track_idx, this_selected_track, j, this_target_track

  routing_option_type_choice = routing_options_form_fields.refs.routing_option_type.selected_id
  routing_option_target_tracks_box = routing_options_form_fields.refs.routing_option_target_tracks_box
  routing_option_target_tracks_choice = {}
  selected_tracks = getSelectedTracks()

  for i = 1, #routing_option_target_tracks_box.children do
    this_track_checkbox = routing_option_target_tracks_box:get_child(i)

    if this_track_checkbox.value then
      this_track_idx = string.match(this_track_checkbox.ref, "%d+$")
      table.insert(routing_option_target_tracks_choice, this_track_idx)
    end
  end

  for i = 0, #selected_tracks-1 do
    this_selected_track = reaper.GetSelectedTrack(0, i)

    for j = 1, #routing_option_target_tracks_choice do
      this_target_track = reaper.GetTrack(0, routing_option_target_tracks_choice[j]-1)

      if routing_option_type_choice == "send" then
        reaper.CreateTrackSend(this_selected_track, this_target_track)

      elseif routing_option_type_choice == "receive" then
        reaper.CreateTrackSend(this_target_track, this_selected_track)
      end
    end
  end

  reaper.Undo_BeginBlock()
  routing_options_window:close()
  reaper.Undo_EndBlock("MB_Buss Driver", -1)
end


function initAddRouting()
  if selected_tracks_count > 0 then
    launchDialog()
  end
end

initAddRouting()