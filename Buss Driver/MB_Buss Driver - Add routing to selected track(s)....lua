-- @description MB_Buss Driver - Add routing to selected track(s)...
-- @author MonkeyBars
-- @version 1.0
-- @changelog Initial upload
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
-- removal
-- add most send settings

package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"

-- for dev only
-- require("mb-dev-functions")


local rtk = require('rtk')


local selected_tracks_count = reaper.CountSelectedTracks(0)


function launchDialog()
  local routing_options_objs, routing_options_window_content_height

  routing_options_objs = getRoutingOptionsObjects()
  routing_options_objs = defineRoutingOptionsMethods(routing_options_objs)
  routing_options_objs = populateRoutingOptionsWindow(routing_options_objs)

  routing_options_objs.window:open()
  routing_options_objs.window:close()

  routing_options_window_content_height = routing_options_objs.window:calc("h") / rtk.scale.framebuffer
  
  routing_options_objs.window:attr("h", routing_options_window_content_height)
  routing_options_objs.window:open{halign='center', valign='center'}
end


function getRoutingOptionsObjects()
  local routing_options_objs = {}

  routing_options_objs.window = rtk.Window{title = "MB_Buss Driver - Add routing to selected track(s)"}
  routing_options_objs.viewport = rtk.Viewport{halign = "center", padding = "0 38"}
  routing_options_objs.content = rtk.VBox{halign = "center", padding = "27 0 7"}
  routing_options_objs.title =  rtk.Heading{"Buss Driver", w = 1, halign = "center", bmargin = 25}
  routing_options_objs.type_subheading = rtk.Text{"What kind of routing do you want to add to the selected track(s)?"}
  routing_options_objs.type_dropdown = rtk.OptionMenu{menu = {{"send(s)", id = "send"}, {"receive(s)", id = "receive"}}, fontsize = 16, ref = "routing_option_type"}
  routing_options_objs.target_tracks_subheading = rtk.Text{"Which track(s) do you want to send to?", tmargin = 20}
  routing_options_objs.form_fields = rtk.VBox{margin = 10, spacing = 10}
  routing_options_objs.form_buttons = rtk.HBox{margin = 10, spacing = 10}
  routing_options_objs.form_submit = rtk.Button{"Add", disabled = true}
  routing_options_objs.form_cancel = rtk.Button{"Cancel"}
  routing_options_objs.target_tracks_box = getUnselectedTracks(routing_options_objs.form_submit)

  return routing_options_objs
end


function getUnselectedTracks(routing_option_form_submit)
  local all_tracks_count, routing_option_target_tracks_box, i, this_track

  all_tracks_count = reaper.CountTracks(0)
  routing_option_target_tracks_box = rtk.FlowBox{w = 1, ref = "routing_option_target_tracks_box"}

  for i = 0, all_tracks_count-1 do
    this_track = reaper.GetTrack(0, i)
    routing_option_target_tracks_box = populateTargetTrack(routing_option_form_submit, this_track, routing_option_target_tracks_box)
  end

  return routing_option_target_tracks_box
end


function populateTargetTrack(routing_option_form_submit, this_track, routing_option_target_tracks_box)
  local this_track_is_selected, this_track_num, retval, this_track_name, this_track_checkbox

  this_track_is_selected = reaper.GetMediaTrackInfo_Value(this_track, "I_SELECTED")

  if this_track_is_selected == 0 then
    this_track_num = math.tointeger(reaper.GetMediaTrackInfo_Value(this_track, "IP_TRACKNUMBER"))
    retval, this_track_name = reaper.GetSetMediaTrackInfo_String(this_track, "P_NAME", "", 0)
    this_track_checkbox = rtk.CheckBox{this_track_num .. " " .. this_track_name, margin = "2 0", fontsize = 14, ref = "target_track_" .. this_track_num}
    this_track_checkbox.onchange = function()
      activateSubmitButton(routing_option_form_submit)
    end

    routing_option_target_tracks_box:add(this_track_checkbox)
  end

  return routing_option_target_tracks_box
end


function activateSubmitButton(submit_button)
  submit_button:attr("disabled", false)
end


function defineRoutingOptionsMethods(routing_options_objs)
  routing_options_objs.type_dropdown.onchange = function(self)
    updateRoutingTypeText(self, routing_options_objs.target_tracks_subheading)
  end
  
  routing_options_objs.form_cancel.onclick = function() 
    routing_options_objs.window:close()
  end

  routing_options_objs.form_submit.onclick = function()
    submitRoutingOptionChanges(routing_options_objs.form_fields, routing_options_objs.window)
  end

  return routing_options_objs
end


function updateRoutingTypeText(dropdown, subheading)
  local default_routing_msg, routing_type_text

  default_routing_msg = "Which track(s) do you want to "

  if dropdown.selected_id == "send" then
    routing_type_text = "send to?"

  elseif dropdown.selected_id == "receive" then
    routing_type_text = "receive from?"
  end

  subheading:attr("text", default_routing_msg .. routing_type_text)
end


function submitRoutingOptionChanges(routing_options_form_fields, routing_options_window)
  local routing_option_target_tracks_box, routing_option_target_tracks_choice

  routing_option_target_tracks_box = routing_options_form_fields.refs.routing_option_target_tracks_box
  routing_option_target_tracks_choices = getTargetTracksChoices(routing_option_target_tracks_box)
  
  createRouting(routing_options_form_fields, routing_option_target_tracks_choices)
  reaper.Undo_BeginBlock()
  routing_options_window:close()
  reaper.Undo_EndBlock("MB_Buss Driver", -1)
end


function getTargetTracksChoices(routing_option_target_tracks_box)
  local routing_option_target_tracks_choices, i, this_track_checkbox, this_track_idx

  routing_option_target_tracks_choices = {}

  for i = 1, #routing_option_target_tracks_box.children do
    this_track_checkbox = routing_option_target_tracks_box:get_child(i)

    if this_track_checkbox.value then
      this_track_idx = string.match(this_track_checkbox.ref, "%d+$")
      table.insert(routing_option_target_tracks_choices, this_track_idx)
    end
  end

  return routing_option_target_tracks_choices
end


function createRouting(routing_options_form_fields, routing_option_target_tracks_choices)
  local selected_tracks, routing_option_type_choices, i, this_selected_track, j, this_target_track

  selected_tracks = getSelectedTracks()
  routing_option_type_choice = routing_options_form_fields.refs.routing_option_type.selected_id

  for i = 0, #selected_tracks-1 do
    this_selected_track = reaper.GetSelectedTrack(0, i)

    for j = 1, #routing_option_target_tracks_choices do
      this_target_track = reaper.GetTrack(0, routing_option_target_tracks_choices[j]-1)

      if routing_option_type_choice == "send" then
        reaper.CreateTrackSend(this_selected_track, this_target_track)

      elseif routing_option_type_choice == "receive" then
        reaper.CreateTrackSend(this_target_track, this_selected_track)
      end
    end
  end
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


function populateRoutingOptionsWindow(routing_options_objs)
  routing_options_objs.type_dropdown:attr("selected", 1)
  routing_options_objs.content:add(routing_options_objs.title)
  routing_options_objs.form_fields:add(routing_options_objs.type_subheading)
  routing_options_objs.form_fields:add(routing_options_objs.type_dropdown)
  routing_options_objs.form_fields:add(routing_options_objs.target_tracks_subheading)
  routing_options_objs.form_fields:add(routing_options_objs.target_tracks_box)
  routing_options_objs.content:add(routing_options_objs.form_fields)
  routing_options_objs.form_buttons:add(routing_options_objs.form_submit)
  routing_options_objs.form_buttons:add(routing_options_objs.form_cancel)
  routing_options_objs.content:add(routing_options_objs.form_buttons)
  routing_options_objs.viewport:attr("child", routing_options_objs.content)
  routing_options_objs.window:add(routing_options_objs.viewport)

  return routing_options_objs
end


function initAddRouting()
  if selected_tracks_count > 0 then
    launchDialog()
  end
end

initAddRouting()