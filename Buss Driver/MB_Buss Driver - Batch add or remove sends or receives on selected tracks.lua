-- @description MB_Buss Driver - Batch add or remove send(s) or receive(s) on selected track(s)
-- @author MonkeyBars
-- @version 1.0
-- @changelog Initial upload
-- @provides [main] .
--   [nomain] rtk.lua
--   [nomain] serpent.lua
--   gnu_license_v3.txt
-- @about Add & set – or remove – multiple sends or receives to/from multiple tracks in one go

-- Copyright (C) MonkeyBars 2022
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your routing_option) any later version.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

-- ==== MB_BUSS DRIVER SCRIPT ARCHITECTURE NOTES ====
-- MB_Buss Driver uses the great GUI library Reaper Toolkit (rtk). (https://reapertoolkit.dev/)
-- Superglue uses Serpent, a serialization library for LUA, for table-string and string-table conversion. (https://github.com/pkulchenko/serpent)
-- Superglue uses Reaper's Master Track P_EXT to store project-wide script data because its changes are saved in Reaper's undo points, a feature that functions correctly since Reaper v6.43.

-- TO DO:
-- check for track number change before submit & pop up Yes/No if changed
-- save last settings in extstate (checkbox to enable)
  -- reset settings button
-- add hardware routing type

package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"

-- for dev only
require("mb-dev-functions")


local rtk = require('rtk')
local serpent = require("serpent")


local selected_tracks_count, _selected_tracks, _data_storage_track, _api_routing_types, _all_routing_settings, _dummy_tracks_GUIDs

_selected_tracks_count = reaper.CountSelectedTracks(0)
_data_storage_track = reaper.GetMasterTrack(0)
_api_routing_types = {
  ["receive"] = -1,
  ["send"] = 0
}
_all_routing_settings = {"B_MUTE", "B_PHASE", "B_MONO", "D_VOL", "D_PAN", "D_PANLAW", "I_SENDMODE", "I_AUTOMODE", "I_SRCCHAN", "I_DSTCHAN", "I_MIDIFLAGS"}


function getSelectedTracks()
  local selected_tracks, this_selected_track

  selected_tracks = {}

  for i = 0, _selected_tracks_count-1 do
    this_selected_track = reaper.GetSelectedTrack(0, i)

    table.insert(selected_tracks, this_selected_track)
  end

  return selected_tracks
end

_selected_tracks = getSelectedTracks(_selected_tracks_count)


function launchBussDriverDialog()
  local routing_options_objs, routing_options_window_content_height

  routing_options_objs = getRoutingOptionsObjects()
  routing_options_objs = populateRoutingOptionsWindow(routing_options_objs)
  routing_options_objs = defineRoutingOptionsMethods(routing_options_objs)





  -- MANUAL SHRINKWRAPPING
  -- routing_options_objs.window:open()
  -- routing_options_objs.window:close()

  -- routing_options_window_content_height = routing_options_objs.content:calc("h") / rtk.scale.framebuffer
  
  -- routing_options_objs.window:attr("h", routing_options_window_content_height)
  -- ///



  routing_options_objs.window:open{halign='center', valign='center'}






    -- local w = rtk.Window()
    -- local viewport = rtk.Viewport()
    -- local vbox = rtk.VBox()
    -- vbox:add(rtk.Text{'Stuff before button', margin=20})
    -- local b = vbox:add(rtk.Button{'Animate me', margin=20})
    -- rtk.callafter(0.5, function()
    --     b:animate{'h', dst=0}:after(function()
    --         b:animate{'h', dst=nil}
    --     end)
    -- end)
    -- vbox:add(rtk.Text{'Stuff after button', margin=20})
    -- local flowbox = vbox:add(rtk.FlowBox())
    -- local i
    -- for i = 1, 20 do
    --   local innerrow = rtk.HBox{}
    --   innerrow:add(rtk.ImageBox{rtk.Image():load(""), w = 18, minw = 18})
    --   innerrow:add(rtk.CheckBox{"row with a very long title pushing out the width"})
    --   flowbox:add(innerrow)
    -- end
    -- viewport:attr("child", vbox)
    -- w:add(viewport)
    -- w:open{align='center'}



end


function getRoutingOptionsObjects()
  local routing_options_objs = {
    ["window"] = rtk.Window{title = "MB_Buss Driver - Batch add or remove send(s) or receive(s) on selected track(s)", maxh = 875},
    ["viewport"] = rtk.Viewport{halign = "center", padding = "0 25"},
    ["content"] = rtk.VBox{halign = "center", padding = "27 0 7"},
    ["title"] = rtk.Heading{"Buss Driver", w = 1, halign = "center", bmargin = 25},
    ["action_sentence_wrapper"] = rtk.Container{w = 1, halign = "center"},
    ["action_sentence"] = rtk.HBox{margin = "9 0 12"},
    ["action_text_start"] = rtk.Text{"I want to "},
    ["addremove_dropdown"] = rtk.OptionMenu{menu = {{"add +", id = "add"}, {"remove -", id = "remove"}}, h = 20, margin = "-5 4 0 0", padding = "1 0 0 5", spacing = 5, fontscale = 0.8, ref = "routing_option_addremove"},
    ["type_dropdown"] = rtk.OptionMenu{menu = {{"sends", id = "send"}, {"receives", id = "receive"}}, h = 20, tmargin = -5, padding = "1 0 0 5", spacing = 5, fontscale = 0.8, ref = "routing_option_type"},
    ["action_text_end"] = rtk.Text{" to the selected tracks."},
    ["configure_wrapper"] = rtk.Container{w = 1, halign = "center", margin = "10 0 15"},
    ["configure_btn"] = rtk.Button{label = "Configure send settings", tooltip = "Pop up routing settings to be applied to all sends or receives created"},
    ["target_tracks_subheading"] = rtk.Text{"Which tracks do you want to add sends to?", w = 1, tmargin = 5, fontscale = 0.95, fontflags = rtk.font.BOLD, halign = "center", fontflags = rtk.font.BOLD},
    ["form_fields"] = rtk.VBox{padding = 10, spacing = 10},
    ["form_buttons"] = rtk.HBox{margin = 10, spacing = 10},
    ["form_submit"] = rtk.Button{"Add", disabled = true},
    ["form_cancel"] = rtk.Button{"Cancel"}
  }
  routing_options_objs.target_tracks_box = getUnselectedTracks(routing_options_objs.form_submit)

  return routing_options_objs
end


function getUnselectedTracks(routing_option_form_submit)
  local all_tracks_count, routing_option_target_tracks_box, this_track

  all_tracks_count = reaper.CountTracks(0)
  routing_option_target_tracks_box = rtk.FlowBox{w = 0.85, ref = "routing_option_target_tracks_box"}

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
    this_track_line = rtk.HBox{valign = "center"}
    retval, this_track_icon_path = reaper.GetSetMediaTrackInfo_String(this_track, "P_ICON", "", false)
    this_track_icon = rtk.ImageBox{rtk.Image():load(this_track_icon_path), w = 18, minw = 18}
    this_track_num = math.tointeger(reaper.GetMediaTrackInfo_Value(this_track, "IP_TRACKNUMBER"))
    retval, this_track_name = reaper.GetSetMediaTrackInfo_String(this_track, "P_NAME", "", 0)
    this_track_color = reaper.GetTrackColor(this_track)
    this_track_checkbox = rtk.CheckBox{this_track_num .. ". " .. this_track_name, fontscale = 0.75, margin = "0 5 1 2", padding = "1 2 1 2", spacing = 5, valign = "center", ref = "target_track_" .. this_track_num}

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

  routing_options_objs.window.onclose = function()
    deleteDummyTracks()
    reselectTracks()
  end

  routing_options_objs.addremove_dropdown.onchange = function(self)
    updateRoutingForm(routing_options_objs, "is_action_change")

    if self.selected_id == "remove" then
      deleteDummyTracks()
    end
  end

  routing_options_objs.type_dropdown.onchange = function()
    updateRoutingForm(routing_options_objs)
  end

  routing_options_objs.configure_btn.onclick = function()
    launchRoutingSettings(routing_options_objs.type_dropdown.selected_id)
  end

  routing_options_objs.form_submit.onclick = function()
    submitRoutingOptionChanges(routing_options_objs.form_fields, routing_options_objs.window)
  end
  
  routing_options_objs.form_cancel.onclick = function()
    routing_options_objs.window:close()
  end

  return routing_options_objs
end


function deleteDummyTracks()
  local retval, dummy_track, dummy_track_exists

  if not _dummy_tracks_GUIDs or _dummy_tracks_GUIDs == "" then
    _dummy_tracks_GUIDs = storeRetrieveProjectData("dummy_tracks_GUIDs")
  end

  if _dummy_tracks_GUIDs and _dummy_tracks_GUIDs ~= "" then

    if type(_dummy_tracks_GUIDs) == "string" then
      retval, _dummy_tracks_GUIDs = serpent.load(_dummy_tracks_GUIDs)

      if not retval then

        return
      end
    end

    for dummy_track_type, dummy_track_guid in pairs(_dummy_tracks_GUIDs) do
      dummy_track = reaper.BR_GetMediaTrackByGUID(0, dummy_track_guid)
      dummy_track_exists = reaper.ValidatePtr(dummy_track, "MediaTrack*")

      if dummy_track_exists then
        reaper.DeleteTrack(dummy_track)
      end
    end
    
    storeRetrieveProjectData("dummy_tracks_GUIDs", "")
  end
end


function updateRoutingForm(routing_options_objs, is_action_change)
  local routing_action, routing_type, target_tracks_subheading_text_intro, target_tracks_subheading_routing_action_text, action_preposition, action_text_end, target_tracks_subheading_routing_type_text, new_target_tracks_subheading_text

  routing_action = routing_options_objs.addremove_dropdown.selected_id
  routing_type = routing_options_objs.type_dropdown.selected_id
  target_tracks_subheading_text_intro = "Which track(s) do you want to "
  target_tracks_subheading_routing_action_text = routing_action .. " "

  if routing_action == "add" then
    action_preposition = "to"

  elseif routing_action == "remove" then
    action_preposition = "from"
  end

  action_text_end = " " .. action_preposition .. " the selected tracks."
  target_tracks_subheading_routing_type_text = " " .. routing_type .. "s "
  new_target_tracks_subheading_text = target_tracks_subheading_text_intro .. routing_action .. target_tracks_subheading_routing_type_text .. action_preposition .. "?"
  routing_options_objs.target_tracks_subheading:attr("text", new_target_tracks_subheading_text)

  routing_options_objs.configure_btn:attr("label", "Configure " .. routing_type .. " settings")
  routing_options_objs.action_text_end:attr("text", action_text_end)
  updateButtons(routing_action, routing_options_objs.configure_btn, routing_options_objs.form_submit, is_action_change)


  -- local routing_type_subheading_text_intro, routing_action, routing_type_subheading_text_end, new_routing_type_subheading_text, target_tracks_subheading_text_intro, target_tracks_subheading_routing_action_text, routing_type, target_tracks_subheading_routing_type_text, target_tracks_subheading_text_end, new_target_tracks_subheading_text
  -- routing_type_subheading_text_intro = "What kind of routing do you want to "
  -- routing_action = routing_options_objs.addremove_dropdown.selected_id
  -- routing_type_subheading_text_end = " on the selected tracks?"
  -- new_routing_type_subheading_text = routing_type_subheading_text_intro .. routing_action .. routing_type_subheading_text_end
  -- target_tracks_subheading_text_intro = "Which track(s) do you want to "
  -- target_tracks_subheading_routing_action_text = routing_action .. " "
  -- routing_type = routing_options_objs.type_dropdown.selected_id
  -- target_tracks_subheading_routing_type_text = " " .. routing_type .. "s "

  -- if routing_type == "send" then
  --   target_tracks_subheading_text_end = "to?"

  -- elseif routing_type == "receive" then
  --   target_tracks_subheading_text_end = "from?"
  -- end

  -- new_target_tracks_subheading_text = target_tracks_subheading_text_intro .. routing_action .. target_tracks_subheading_routing_type_text .. target_tracks_subheading_text_end

  -- routing_options_objs.type_subheading:attr("text", new_routing_type_subheading_text)
  -- routing_options_objs.configure_btn:attr("label", "Configure " .. routing_type .. " settings")
  -- routing_options_objs.target_tracks_subheading:attr("text", new_target_tracks_subheading_text)

end


function updateButtons(routing_action, configure_btn, submit_btn, is_action_change)
  local configure_btn_height, routing_options_submit_btn_text

  if is_action_change == "is_action_change" then

    if routing_action == "add" then
      configure_btn_height = nil
      routing_options_submit_btn_text = "Add"
    
    elseif routing_action == "remove" then
      configure_btn_height = 0
      routing_options_submit_btn_text = "Remove"
    end

    configure_btn:animate{"h", dst = configure_btn_height, duration = 0.33}
    submit_btn:attr("label", routing_options_submit_btn_text)
  end
end


function getDummyTracks()
  local dummy_tracks, dummy_tracks_exist, all_tracks_count, this_dummy_track, retval, this_dummy_track_GUID

    dummy_tracks = {
      ["routing"] = 0,
      ["target"] = 0
    }

  if _dummy_tracks_GUIDs and type(_dummy_tracks_GUIDs) == "table" then
    dummy_tracks = getDummyTracksFromGUID(dummy_tracks)

  else
    _dummy_tracks_GUIDs = storeRetrieveProjectData("dummy_tracks_GUIDs")

    if _dummy_tracks_GUIDs and _dummy_tracks_GUIDs ~= "" and type(_dummy_tracks_GUIDs) == "string" then
      retval, _dummy_tracks_GUIDs = serpent.load(_dummy_tracks_GUIDs)
      dummy_tracks = getDummyTracksFromGUID(dummy_tracks)
      dummy_tracks_exist = reaper.ValidatePtr(dummy_tracks.routing, "MediaTrack*") and reaper.ValidatePtr(dummy_tracks.target, "MediaTrack*")
    end

    if not _dummy_tracks_GUIDs or _dummy_tracks_GUIDs == "" or not dummy_tracks_exist then
      _dummy_tracks_GUIDs = {}
      all_tracks_count = reaper.CountTracks(0)

      for dummy_track_type, dummy_track in pairs(dummy_tracks) do
        reaper.InsertTrackAtIndex(all_tracks_count, false)

        dummy_tracks[dummy_track_type] = reaper.GetTrack(0, all_tracks_count)
        this_dummy_track = dummy_tracks[dummy_track_type]
        retval, this_dummy_track_GUID = reaper.GetSetMediaTrackInfo_String(this_dummy_track, "GUID", "", false)
        _dummy_tracks_GUIDs[dummy_track_type] = this_dummy_track_GUID

        reaper.SetMediaTrackInfo_Value(this_dummy_track, "B_SHOWINMIXER", 0)
        reaper.SetMediaTrackInfo_Value(this_dummy_track, "B_SHOWINTCP", 0)
      end

      _dummy_tracks_GUIDs = serpent.dump(_dummy_tracks_GUIDs)

      reaper.GetSetMediaTrackInfo_String(dummy_tracks.routing, "P_NAME", "Enter Buss Driver Routing Settings", true)
      reaper.GetSetMediaTrackInfo_String(dummy_tracks.target, "P_NAME", "MB_Buss Driver target track", true)
      storeRetrieveProjectData("dummy_tracks_GUIDs", _dummy_tracks_GUIDs)
    end
  end

  return dummy_tracks
end


function getDummyTracksFromGUID(dummy_tracks)
  dummy_tracks.routing = reaper.BR_GetMediaTrackByGUID(0, _dummy_tracks_GUIDs.routing)
  dummy_tracks.track = reaper.BR_GetMediaTrackByGUID(0, _dummy_tracks_GUIDs.target)

  return dummy_tracks
end


function storeRetrieveProjectData(key, val)
  local retrieve, store, store_or_retrieve_state_data, data_param_key, retval, state_data_val

  retrieve = not val
  store = val

  if retrieve then
    val = ""
    store_or_retrieve_state_data = false

  elseif store then
    store_or_retrieve_state_data = true
  end

  data_param_key = "P_EXT:MB_Buss-Driver_" .. key
  retval, state_data_val = reaper.GetSetMediaTrackInfo_String(_data_storage_track, data_param_key, val, store_or_retrieve_state_data)

  return state_data_val
end


function launchRoutingSettings(routing_type)
  local set_1st_selected_track_last_touched, view_routing_for_last_touched_track, dummy_tracks, api_routing_type_val, dummy_target_track_routing_count, dest_track, src_track

  set_1st_selected_track_last_touched = 40914
  view_routing_for_last_touched_track = 40293
  dummy_tracks = getDummyTracks()
  dummy_target_track_routing_count = reaper.GetTrackNumSends(dummy_tracks.target, _api_routing_types[routing_type])

  if routing_type == "send" then
    dest_track = dummy_tracks.routing
    src_track = dummy_tracks.target

  elseif routing_type == "receive" then
    dest_track = dummy_tracks.target
    src_track = dummy_tracks.routing
  end

  if dummy_target_track_routing_count == 0 then
    reaper.CreateTrackSend(dest_track, src_track)
  end
  
  reaper.SetOnlyTrackSelected(dummy_tracks.routing)
  reaper.Main_OnCommand(set_1st_selected_track_last_touched, 0)
  reaper.Main_OnCommand(view_routing_for_last_touched_track, 0)
  preventUndoPoint()
end


function preventUndoPoint()
  reaper.defer(function() end)
end


function submitRoutingOptionChanges(routing_options_form_fields, routing_options_window)
  local routing_option_target_tracks_box, routing_option_target_tracks_choice

  routing_option_target_tracks_box = routing_options_form_fields.refs.routing_option_target_tracks_box
  routing_option_target_tracks_choices = getTargetTracksChoices(routing_option_target_tracks_box)
  
  reaper.Undo_BeginBlock()
  addRemoveRouting(routing_options_form_fields, routing_option_target_tracks_choices)
  routing_options_window:close()
  reaper.Undo_EndBlock("MB_Buss Driver", -1)
end


function getTargetTracksChoices(routing_option_target_tracks_box)
  local routing_option_target_tracks_choices, this_track_row, this_track_checkbox, this_track_idx

  routing_option_target_tracks_choices = {}

  for i = 1, #routing_option_target_tracks_box.children do
    this_track_row = routing_option_target_tracks_box:get_child(i)
    this_track_checkbox = this_track_row:get_child(2)

    if this_track_checkbox.value then
      this_track_idx = string.match(this_track_checkbox.ref, "%d+$")

      table.insert(routing_option_target_tracks_choices, this_track_idx)
    end
  end

  return routing_option_target_tracks_choices
end


function addRemoveRouting(routing_options_form_fields, routing_option_target_tracks_choices)
  local routing_option_action_choice, routing_option_type_choice, this_selected_track, j, this_target_track

  routing_option_action_choice = routing_options_form_fields.refs.routing_option_addremove.selected_id
  routing_option_type_choice = routing_options_form_fields.refs.routing_option_type.selected_id

  for i = 1, #_selected_tracks do
    this_selected_track = _selected_tracks[i]

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
  local dummy_tracks, dummy_routing_track_exists

  dummy_tracks = getDummyTracks()
  dummy_routing_track_exists = reaper.ValidatePtr(dummy_tracks.routing, "MediaTrack*")

  if routing_option_type_choice == "send" then
    reaper.CreateTrackSend(selected_track, target_track)
    
    if dummy_routing_track_exists then
      copyRoutingSettings(dummy_tracks.routing, selected_track, routing_option_type_choice)
    end

  elseif routing_option_type_choice == "receive" then
    reaper.CreateTrackSend(target_track, selected_track)
    
    if dummy_routing_track_exists then
      copyRoutingSettings(dummy_tracks.routing, target_track, routing_option_type_choice)
    end
  end
end


function copyRoutingSettings(src_track, dest_track, routing_option_type_choice)
  local dest_track_routing_count, src_track_routing_value

  dest_track_routing_count = reaper.GetTrackNumSends(dest_track, 0)

  if routing_option_type_choice == "send" then
    api_routing_type = 0

  elseif routing_option_type_choice == "receive" then
    api_routing_type = -1
  end

  for i = 1, #_all_routing_settings do
    src_track_routing_value = reaper.GetTrackSendInfo_Value(src_track, api_routing_type, 0, _all_routing_settings[i])

    reaper.SetTrackSendInfo_Value(dest_track, api_routing_type, dest_track_routing_count-1, _all_routing_settings[i], src_track_routing_value)
  end
end


function removeRouting(routing_option_type_choice, selected_track, target_track)
  local this_track_dest, this_track_src

  if routing_option_type_choice == "send" then

    for i = 0, reaper.GetTrackNumSends(selected_track, 0)-1 do
      this_track_dest = reaper.GetTrackSendInfo_Value(selected_track, 0, i, "P_DESTTRACK")

      if this_track_dest == target_track then
        reaper.RemoveTrackSend(selected_track, 0, i)
      end
    end

  elseif routing_option_type_choice == "receive" then

    for i = 0, reaper.GetTrackNumSends(selected_track, -1)-1 do
      this_track_src = reaper.GetTrackSendInfo_Value(selected_track, -1, i, "P_SRCTRACK")

      if this_track_src == target_track then
        reaper.RemoveTrackSend(selected_track, -1, i)
      end
    end
  end
end


function reselectTracks()

  for i = 1, #_selected_tracks do
    reaper.SetTrackSelected(_selected_tracks[i], true)
  end
end


function populateRoutingOptionsWindow(routing_options_objs)
  routing_options_objs.addremove_dropdown:attr("selected", 1)
  routing_options_objs.type_dropdown:attr("selected", 1)
  routing_options_objs.action_sentence:add(routing_options_objs.action_text_start)
  routing_options_objs.action_sentence:add(routing_options_objs.addremove_dropdown)
  routing_options_objs.action_sentence:add(routing_options_objs.type_dropdown)
  routing_options_objs.action_sentence:add(routing_options_objs.action_text_end)
  routing_options_objs.action_sentence_wrapper:add(routing_options_objs.action_sentence)
  routing_options_objs.form_fields:add(routing_options_objs.action_sentence_wrapper)
  routing_options_objs.configure_wrapper:add(routing_options_objs.configure_btn)
  routing_options_objs.form_fields:add(routing_options_objs.configure_wrapper)
  routing_options_objs.form_fields:add(routing_options_objs.target_tracks_subheading)
  routing_options_objs.form_fields:add(routing_options_objs.target_tracks_box)
  routing_options_objs.form_buttons:add(routing_options_objs.form_submit)
  routing_options_objs.form_buttons:add(routing_options_objs.form_cancel)
  routing_options_objs.content:add(routing_options_objs.title)
  routing_options_objs.content:add(routing_options_objs.form_fields)
  routing_options_objs.content:add(routing_options_objs.form_buttons)
  routing_options_objs.viewport:attr("child", routing_options_objs.content)
  routing_options_objs.window:add(routing_options_objs.viewport)

  return routing_options_objs
end


function initBussDriver()
  if _selected_tracks_count > 0 then
    launchBussDriverDialog()
  end
end

initBussDriver()





function wipeDummyRoutingTrackRouting()
  local dummy_tracks, dummy_routing_track_routing_count

  dummy_tracks = getDummyTracks()

  for i = -1, 0 do
    dummy_routing_track_routing_count = reaper.GetTrackNumSends(dummy_tracks.routing, i)

    for j = 0, dummy_routing_track_routing_count-1 do
      reaper.RemoveTrackSend(dummy_tracks.routing, i, j)
    end
  end
end