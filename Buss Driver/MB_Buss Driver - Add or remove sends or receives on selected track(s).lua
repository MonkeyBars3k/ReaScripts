-- @description MB_Buss Driver - Add or remove send(s) or receive(s) on selected track(s)
-- @author MonkeyBars
-- @version 1.0
-- @changelog Initial upload
-- @provides [main] .
--   [nomain] rtk.lua
--   gnu_license_v3.txt
-- @link 
-- @about Add & set/remove multiple sends or receives to multiple tracks in one go

-- Copyright (C) MonkeyBars 2022
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your routing_option) any later version.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

-- to do:
-- add all send settings via dummy send popup
-- save last settings in extstate (checkbox to enable)
-- reset settings button

package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"

-- for dev only
require("mb-dev-functions")


local rtk = require('rtk')


local selected_tracks_count = reaper.CountSelectedTracks(0)


function launchDialog()
  local routing_options_objs, routing_options_window_content_height

  routing_options_objs = getRoutingOptionsObjects()
  routing_options_objs = populateRoutingOptionsWindow(routing_options_objs)
  routing_options_objs = defineRoutingOptionsMethods(routing_options_objs)

  routing_options_objs.window:open()
  routing_options_objs.window:close()

  routing_options_window_content_height = routing_options_objs.content:calc("h") / rtk.scale.framebuffer
  
  routing_options_objs.window:attr("h", routing_options_window_content_height)
  routing_options_objs.window:open{halign='center', valign='center'}
end


function getRoutingOptionsObjects()
  local routing_options_objs = {
    ["window"] = rtk.Window{title = "MB_Buss Driver - Add or remove send(s) or receive(s) on selected track(s)"},
    ["viewport"] = rtk.Viewport{halign = "center", padding = "0 38"},
    ["content"] = rtk.VBox{halign = "center", padding = "27 0 7"},
    ["title"] = rtk.Heading{"Buss Driver", w = 1, halign = "center", bmargin = 25},
    ["addremove_subheading"] = rtk.Text{"Do you want to add to or remove routing from the selected tracks?", fontsize = 17},
    ["addremove_dropdown"] = rtk.OptionMenu{menu = {{"add +", id = "add"}, {"remove -", id = "remove"}}, h = 20, tmargin = -5, padding = "1 0 0 5", spacing = 5, fontsize = 14, ref = "routing_option_addremove"},
    ["type_subheading"] = rtk.Text{"What kind of routing do you want to add to the selected tracks?", tmargin = 8, fontsize = 17},
    ["type_dropdown"] = rtk.OptionMenu{menu = {{"sends", id = "send"}, {"receives", id = "receive"}}, h = 20, tmargin = -5, padding = "1 0 0 5", spacing = 5, fontsize = 14, ref = "routing_option_type"},
    ["target_tracks_subheading"] = rtk.Text{"Which tracks do you want to add sends to?", w = 1, tmargin = 5, fontsize = 17, fontflags = rtk.font.BOLD, halign = "center"},
    ["form_fields"] = rtk.VBox{margin = 10, spacing = 10},
    ["form_buttons"] = rtk.HBox{margin = 10, spacing = 10},
    ["form_submit"] = rtk.Button{"Add", disabled = true},
    ["form_cancel"] = rtk.Button{"Cancel"}
  }
  routing_options_objs.target_tracks_box = getUnselectedTracks(routing_options_objs.form_submit)

  return routing_options_objs
end


function getUnselectedTracks(routing_option_form_submit)
  local all_tracks_count, routing_option_target_tracks_box, i, this_track

  all_tracks_count = reaper.CountTracks(0)
  routing_option_target_tracks_box = rtk.FlowBox{w = 1, ref = "routing_option_target_tracks_box"}

  for i = 0, all_tracks_count-1 do
    this_track = reaper.GetTrack(0, i)
    routing_option_target_tracks_box = populateTargetTrackField(routing_option_form_submit, this_track, routing_option_target_tracks_box)
  end

  return routing_option_target_tracks_box
end


function populateTargetTrackField(routing_option_form_submit, this_track, routing_option_target_tracks_box)
  local this_track_is_selected, this_track_line, retval, this_track_icon_path, this_track_icon, this_track_num, retval, this_track_name, this_track_color, this_track_checkbox

  this_track_is_selected = reaper.IsTrackSelected(this_track)

  if this_track_is_selected == false then
    this_track_line = rtk.HBox{}
    retval, this_track_icon_path = reaper.GetSetMediaTrackInfo_String(this_track, "P_ICON", "", false)
    this_track_icon = rtk.ImageBox{rtk.Image():load(this_track_icon_path), w = 18}
    this_track_num = math.tointeger(reaper.GetMediaTrackInfo_Value(this_track, "IP_TRACKNUMBER"))
    retval, this_track_name = reaper.GetSetMediaTrackInfo_String(this_track, "P_NAME", "", 0)
    this_track_color = reaper.GetTrackColor(this_track)
    this_track_checkbox = rtk.CheckBox{this_track_num .. " " .. this_track_name, margin = "2 0", fontsize = 13, margin = "2 5 2 2", padding = "1 2 1 2", spacing = 5, valign = "center", ref = "target_track_" .. this_track_num}

    if this_track_color ~= 0 then
      this_track_color = rtk.color.convert_native(this_track_color)
      this_track_checkbox:attr("bg", this_track_color)
    end

    this_track_checkbox.onchange = function()
      activateSubmitButton(routing_option_form_submit)
    end

    this_track_line:add(this_track_icon)
    this_track_line:add(this_track_checkbox)
    routing_option_target_tracks_box:add(this_track_line)
  end

  return routing_option_target_tracks_box
end


function activateSubmitButton(submit_button)
  submit_button:attr("disabled", false)
end


function defineRoutingOptionsMethods(routing_options_objs)
  routing_options_objs.addremove_dropdown.onchange = function()
    updateRoutingTypeText(routing_options_objs)
  end

  routing_options_objs.type_dropdown.onchange = function()
    updateRoutingTypeText(routing_options_objs)
  end
  
  routing_options_objs.form_cancel.onclick = function() 
    routing_options_objs.window:close()
  end

  routing_options_objs.form_submit.onclick = function()
    submitRoutingOptionChanges(routing_options_objs.form_fields, routing_options_objs.window)
  end

  return routing_options_objs
end


function updateRoutingTypeText(routing_options_objs)
  local routing_type_subheading_text_intro, routing_action, routing_type_subheading_text_end, new_routing_type_subheading_text, target_tracks_subheading_text_intro, target_tracks_subheading_routing_action_text, routing_type, target_tracks_subheading_routing_type_text, target_tracks_subheading_text_end, new_target_tracks_subheading_text

  routing_type_subheading_text_intro = "What kind of routing do you want to "
  routing_action = routing_options_objs.addremove_dropdown.selected_id
  routing_type_subheading_text_end = " on the selected tracks?"
  new_routing_type_subheading_text = routing_type_subheading_text_intro .. routing_action .. routing_type_subheading_text_end
  target_tracks_subheading_text_intro = "Which track(s) do you want to "
  target_tracks_subheading_routing_action_text = routing_action .. " "
  routing_type = routing_options_objs.type_dropdown.selected_id
  target_tracks_subheading_routing_type_text = " " .. routing_type .. "s "

  if routing_type == "send" then
    target_tracks_subheading_text_end = "to?"

  elseif routing_type == "receive" then
    target_tracks_subheading_text_end = "from?"
  end

  new_target_tracks_subheading_text = target_tracks_subheading_text_intro .. routing_action .. target_tracks_subheading_routing_type_text .. target_tracks_subheading_text_end

  routing_options_objs.type_subheading:attr("text", new_routing_type_subheading_text)
  routing_options_objs.target_tracks_subheading:attr("text", new_target_tracks_subheading_text)
end


function submitRoutingOptionChanges(routing_options_form_fields, routing_options_window)
  local routing_option_target_tracks_box, routing_option_target_tracks_choice

  routing_option_target_tracks_box = routing_options_form_fields.refs.routing_option_target_tracks_box
  routing_option_target_tracks_choices = getTargetTracksChoices(routing_option_target_tracks_box)
  
  addRemoveRouting(routing_options_form_fields, routing_option_target_tracks_choices)
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


function addRemoveRouting(routing_options_form_fields, routing_option_target_tracks_choices)
  local selected_tracks, routing_option_action_choice, routing_option_type_choice, i, this_selected_track, j, this_target_track

  selected_tracks = getSelectedTracks()
  routing_option_action_choice = routing_options_form_fields.refs.routing_option_addremove.selected_id
  routing_option_type_choice = routing_options_form_fields.refs.routing_option_type.selected_id

  for i = 0, #selected_tracks-1 do
    this_selected_track = reaper.GetSelectedTrack(0, i)

    for j = 1, #routing_option_target_tracks_choices do
      this_target_track = reaper.GetTrack(0, routing_option_target_tracks_choices[j]-1)

      if routing_option_action_choice == "add" then
        addRouting(routing_option_type_choice, this_selected_track, this_target_track)

      elseif routing_option_action_choice == "remove" then
        removeRouting(routing_option_type_choice, this_selected_track, this_target_track)
      end
    end
  end
end


function addRouting(routing_option_type_choice, selected_track, target_track)

  if routing_option_type_choice == "send" then
    reaper.CreateTrackSend(selected_track, target_track)

  elseif routing_option_type_choice == "receive" then
    reaper.CreateTrackSend(target_track, selected_track)
  end
end


function removeRouting(routing_option_type_choice, selected_track, target_track)
  local k, this_track_dest, this_track_src

  if routing_option_type_choice == "send" then

    for k = 0, reaper.GetTrackNumSends(selected_track, 0)-1 do
      this_track_dest = reaper.GetTrackSendInfo_Value(selected_track, 0, k, "P_DESTTRACK")

      if this_track_dest == target_track then
        reaper.RemoveTrackSend(selected_track, 0, k)
      end
    end

  elseif routing_option_type_choice == "receive" then

    for k = 0, reaper.GetTrackNumSends(selected_track, -1)-1 do
      this_track_src = reaper.GetTrackSendInfo_Value(selected_track, -1, k, "P_SRCTRACK")

      if this_track_src == target_track then
        reaper.RemoveTrackSend(selected_track, -1, k)
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
  routing_options_objs.addremove_dropdown:attr("selected", 1)
  routing_options_objs.type_dropdown:attr("selected", 1)
  routing_options_objs.content:add(routing_options_objs.title)
  routing_options_objs.form_fields:add(routing_options_objs.addremove_subheading)
  routing_options_objs.form_fields:add(routing_options_objs.addremove_dropdown)
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


function initBussDriver()
  if selected_tracks_count > 0 then
    launchDialog()
  end
end

initBussDriver()