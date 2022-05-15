-- @description MB_Buss Driver - Batch add or remove send(s) or receive(s) on selected track(s)
-- @author MonkeyBars
-- @version 1.0.3
-- @changelog Initial upload
-- @provides [main] .
--  [nomain] rtk.lua
--  [nomain] serpent.lua
--  gen_midi_off.png
--  gen_midi_on.png
--  gen_mono_off.png
--  gen_mono_on.png
--  gen_phase_off.png
--  gen_phase_on.png
--  table_mute_off.png
--  table_mute_on.png
--  gnu_license_v3.txt
-- @about Remove or set & add multiple sends or receives to/from multiple tracks in one go

-- Copyright (C) MonkeyBars 2022
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your routing_option) any later version.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

-- ==== MB_BUSS DRIVER SCRIPT ARCHITECTURE NOTES ====
-- MB_Buss Driver uses the great GUI library Reaper Toolkit (rtk). (https://reapertoolkit.dev/)
-- Superglue uses Serpent, a serialization library for LUA, for table-string and string-table conversion. (https://github.com/pkulchenko/serpent)
-- Superglue uses Reaper's Master Track P_EXT to store project-wide script data because its changes are saved in Reaper's undo points, a feature that functions correctly since Reaper v6.43.

-- TO DO:
-- save last routing settings in extstate (checkbox to enable)
  -- reset settings button
-- add hardware routing type

package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"

-- for dev only
require("mb-dev-functions")


local rtk = require('rtk')
local serpent = require("serpent")



local selected_tracks_count, _selected_tracks, _data_storage_track, _api_routing_types, _api_all_routing_settings, _all_tracks_count_on_launch, _api_msg_answer_yes, _routing_settings_objs, _right_arrow

_selected_tracks_count = reaper.CountSelectedTracks(0)
_data_storage_track = reaper.GetMasterTrack(0)
_api_routing_types = {
  ["receive"] = -1,
  ["send"] = 0
}
_api_all_routing_settings = {"B_MUTE", "B_PHASE", "B_MONO", "D_VOL", "D_PAN", "D_PANLAW", "I_SENDMODE", "I_SRCCHAN", "I_DSTCHAN", "I_MIDI_SRCCHAN", "I_MIDI_DSTCHAN", "I_MIDI_SRCBUS", "I_MIDI_DSTBUS", "I_MIDI_LINK_VOLPAN"}
_api_msg_answer_yes = 6
_right_arrow = "\u{2192}"


rtk.set_theme_overrides({
    tooltip_font = {'Segoe UI (TrueType)', 13}
})



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


function storeRetrieveAllTracksCount(val)
  local store, retrieve, stored_tracks_count_on_open, all_tracks_count

  store = val
  retrieve = not val

  if store then
    storeRetrieveProjectData("all_tracks_count", val)

  elseif retrieve then
    stored_tracks_count_on_open = storeRetrieveProjectData("all_tracks_count")

    if not stored_tracks_count_on_open or stored_tracks_count_on_open == "" then
      all_tracks_count = reaper.CountTracks(0)

    else
      all_tracks_count = stored_tracks_count_on_open
      stored_tracks_count_on_open = tonumber(stored_tracks_count_on_open)
    end

    return all_tracks_count
  end
end

_all_tracks_count_on_launch = storeRetrieveAllTracksCount()



function launchBussDriverDialog()
  local routing_options_objs, routing_options_window_content_height

  routing_options_objs = getRoutingOptionsObjects()
  routing_options_objs = populateRoutingOptionsWindow(routing_options_objs)
  routing_options_objs = defineRoutingOptionsMethods(routing_options_objs)

  routing_options_objs.window:open{align="center"}



launchRoutingSettings(routing_options_objs)




end


function getRoutingOptionsObjects()
  local routing_options_objs = {
    ["window"] = rtk.Window{title = "MB_Buss Driver - Batch add or remove send(s) or receive(s) on selected track(s)", w = 1000, maxh = rtk.Attribute.NIL},
    ["viewport"] = rtk.Viewport{halign = "center", bpadding = 5},
    ["title"] = rtk.Heading{"Buss Driver", halign = "left", fontscale = "0.6", padding = "2 2 1", border = "1px #878787", bg = "#505050"},
    ["configure_wrapper"] = rtk.Container{w = 1, halign = "right", margin = "5 3 0 0"},
    ["configure_btn"] = rtk.Button{label = "Configure send settings", tooltip = "Pop up routing settings to be applied to all sends or receives created", padding = "4 5 6", fontscale = 0.67},
    ["content"] = rtk.VBox{halign = "center", padding = "10 0 0"},
    ["action_sentence_wrapper"] = rtk.Container{w = 1, halign = "center"},
    ["action_sentence"] = rtk.HBox{valign = "center", tmargin = 9},
    ["action_text_start"] = rtk.Text{"I want to "},
    ["addremove_wrapper"] = rtk.VBox{margin = "0 5"},
    ["add_checkbox"] = rtk.CheckBox{"add +", h = 17, fontscale = 0.925, margin = "0 5 1 2", padding = "0 2 3 2", spacing = 3, valign = "center", value = true, ref = "add_checkbox"},
    ["remove_checkbox"] = rtk.CheckBox{"remove -", h = 17, fontscale = 0.925, margin = "0 5 1 2", padding = "0 2 3 2", spacing = 3, valign = "center", ref = "remove_checkbox"},
    ["type_wrapper"] = rtk.VBox{rmargin = 5},
    ["send_checkbox"] = rtk.CheckBox{"sends", h = 17, fontscale = 0.925, margin = "0 5 1 2", padding = "0 2 3 2", spacing = 3, valign = "center", value = true, ref = "send_checkbox"},
    ["receive_checkbox"] = rtk.CheckBox{"receives", h = 17, fontscale = 0.925, margin = "0 5 1 2", padding = "0 2 3 2", spacing = 3, valign = "center", ref = "receive_checkbox"},
    ["action_text_end"] = rtk.Text{" to the selected tracks."},
    ["target_tracks_subheading"] = rtk.Text{"Which tracks do you want to add sends to?", w = 1, tmargin = 14, fontscale = 0.95, fontflags = rtk.font.BOLD, halign = "center", fontflags = rtk.font.BOLD},
    ["form_fields"] = rtk.VBox{padding = "10 10 5", spacing = 10},
    ["form_buttons"] = rtk.HBox{margin = 10, spacing = 10},
    ["form_submit"] = rtk.Button{"Add", disabled = true},
    ["form_cancel"] = rtk.Button{"Cancel"}
  }
  routing_options_objs.target_tracks_box = getUnselectedTracks(routing_options_objs.form_submit)

  return routing_options_objs
end


function getUnselectedTracks(routing_option_form_submit)
  local routing_option_target_tracks_box, this_track

  routing_option_target_tracks_box = rtk.FlowBox{w = 1, ref = "routing_option_target_tracks_box"}

  for i = 0, _all_tracks_count_on_launch-1 do
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
    this_track_checkbox = rtk.CheckBox{this_track_num .. ". " .. this_track_name, h = 17, fontscale = 0.75, margin = "0 5 1 2", padding = "0 2 3 2", spacing = 3, valign = "center", ref = "target_track_" .. this_track_num}

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

  routing_options_objs.window.onblur = function(self)
    self:close()
  end

  routing_options_objs.window.onclose = function()
    reselectTracks()
    storeRetrieveAllTracksCount("")
  end

  setUpRadioCheckboxMethods(routing_options_objs)

  routing_options_objs.configure_btn.onclick = function()
    launchRoutingSettings(routing_options_objs)
  end

  routing_options_objs.form_submit.onclick = function()
    submitRoutingOptionChanges(routing_options_objs.form_fields, routing_options_objs.window)
  end
  
  routing_options_objs.form_cancel.onclick = function()
    routing_options_objs.window:close()
  end

  return routing_options_objs
end


function setUpRadioCheckboxMethods(routing_options_objs)
  local checkbox_sets = {
    {"add_checkbox", "remove_checkbox"},
    {"send_checkbox", "receive_checkbox"}
  }

  for i = 1, #checkbox_sets do
    populateRadioCheckboxMethods(checkbox_sets[i][1], checkbox_sets[i][2], routing_options_objs)
    populateRadioCheckboxMethods(checkbox_sets[i][2], checkbox_sets[i][1], routing_options_objs)
  end
end


function populateRadioCheckboxMethods(checkbox1, checkbox2, routing_options_objs)
  routing_options_objs[checkbox1].onclick = function()

    routing_options_objs[checkbox1].onchange = function()
      routing_options_objs[checkbox2]:toggle()
      updateRoutingForm(routing_options_objs, "is_action_change")
      routing_options_objs[checkbox1].onchange = nil
    end
  end
end


function updateRoutingForm(routing_options_objs, is_action_change)
  local routing_action, routing_type, target_tracks_subheading_text_intro, target_tracks_subheading_routing_action_text, type_preposition, action_preposition, action_text_end, target_tracks_subheading_routing_type_text, new_target_tracks_subheading_text

  if routing_options_objs.add_checkbox.value then
    routing_action = "add"

  elseif routing_options_objs.remove_checkbox.value then
    routing_action = "remove"
  end

  if routing_options_objs.send_checkbox.value then
    routing_type = "send"

  elseif routing_options_objs.receive_checkbox.value then
    routing_type = "receive"
  end

  target_tracks_subheading_text_intro = "Which tracks do you want to "
  target_tracks_subheading_routing_action_text = routing_action .. " "

  if routing_type == "send" then
    type_preposition = "to"

  elseif routing_type == "receive" then
    type_preposition = "from"
  end

  if routing_action == "add" then
    action_preposition = "to"

  elseif routing_action == "remove" then
    action_preposition = "from"
  end

  action_text_end = " " .. action_preposition .. " the selected tracks."
  target_tracks_subheading_routing_type_text = " " .. routing_type .. "s "
  new_target_tracks_subheading_text = target_tracks_subheading_text_intro .. routing_action .. target_tracks_subheading_routing_type_text .. type_preposition .. "?"
  routing_options_objs.target_tracks_subheading:attr("text", new_target_tracks_subheading_text)

  routing_options_objs.configure_btn:attr("label", "Configure " .. routing_type .. " settings")
  routing_options_objs.action_text_end:attr("text", action_text_end)
  updateButtons(routing_action, routing_options_objs.configure_btn, routing_options_objs.form_submit, is_action_change)
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


function launchRoutingSettings(routing_options_objs)
  local audio_channel_submenu_mono_options, audio_channel_submenu_stereo_options, midi_channel_submenu_bus_options, midi_channel_submenu_bus_option_val, audio_channel_options, midi_channel_options, this_form_field_class, this_form_field_value

  audio_channel_submenu_mono_options = {}
  audio_channel_submenu_stereo_options = {}

  for i = 1, 16 do
    audio_channel_submenu_mono_options[i] = {
      ["label"] = tostring(i),
      ["id"] = 1024 + i
    }
  end

  for i = 1, 15 do
    audio_channel_submenu_stereo_options[i] = {
      ["label"] = tostring(i) .. "/" .. tostring(i+1),
      ["id"] = i
    }
  end

  audio_channel_options = {
    {"None", id = -1},
    {"Mono source", submenu = audio_channel_submenu_mono_options},
    {"Stereo source", submenu = audio_channel_submenu_stereo_options}
  }

  -- none -1 / stereo idx / mono 1024+idx / hwout 512+idx
  midi_channel_options = {
    {
      ["label"] = "None",
      ["id"] = -1 .. "/" .. -1
    },
    {
      ["label"] = "All",
      ["id"] = 0 .. "/" .. 0
    }
  }

  for i = 3, 18 do
    midi_channel_options[i] = {
      ["label"] = tostring(i-2),
      ["id"] = 0 .. "/" .. i-2
    }
  end

  for i = 19, 34 do
    midi_channel_submenu_bus_options = {
      {
        ["label"] = "B" .. i-18,
        ["id"] = i-18 .. "/" .. 0
      }
    }

    for j = 2, 17 do
      midi_channel_submenu_bus_option_val = i-18 .. "/" .. j-1

      midi_channel_submenu_bus_options[j] = {
        ["label"] = midi_channel_submenu_bus_option_val,
        ["id"] = midi_channel_submenu_bus_option_val
      }
    end

    midi_channel_options[i] = {
      ["label"] = "Bus " .. i-18,
      ["submenu"] = midi_channel_submenu_bus_options
    }
  end

  _routing_settings_objs = {
    ["popup"] = rtk.Popup{w = routing_options_objs.window.w / 3, overlay = "#303030cc", padding = 0--[[,    autoclose = false--]]},
    ["content"] = rtk.VBox(),
    ["title"] = rtk.Heading{"Configure settings for routing to be added", w = 1, halign = "center", padding = 6, bg = "#77777799", fontscale = 0.67},
    ["form"] = rtk.VBox{padding = "20 10 10"},
    ["toprow"] = rtk.HBox(),
    ["volume_val"] = rtk.Text{"+0.00", w = 45, h = 19, padding = 3, border = "1px #777888", fontscale = 0.63},
    ["pan_val"] = rtk.Text{"center", w = 35, h = 19, valign = "center", halign = "center", lmargin = 5, padding = 3, border = "1px #777888", fontscale = 0.63},
    ["mute"] = rtk.Button{icon = "table_mute_off", w = 23, h = 20, lmargin = 5, padding = 0, surface = false, tooltip = "Mute", data_class = "routing_setting_field"},
    ["phase"] = rtk.Button{icon = "gen_phase_off", w = 10, h = 10, tooltip = "Reverse phase", margin = "4 0 0 5", padding = 0, circular = true, data_class = "routing_setting_field"},
    ["mono_stereo"] = rtk.Button{icon = "gen_mono_off", w = 23, h = 20, tooltip = "Mono/Stereo", lmargin = 5, padding = 0, surface = false, data_class = "routing_setting_field"},
    ["send_mode"] = rtk.OptionMenu{menu = {
      {"Post-Fader (Post-Pan)", id = 1},
      {"Pre-Fader (Post-FX)", id = 4},
      {"Pre-FX", id = 2}
    }, h = 20, margin = "-1 0 0 2", padding = "0 0 4 4", spacing = 6, fontscale = 0.63, data_class = "routing_setting_field"},
    ["middlerow"] = rtk.HBox{tmargin = 8},
    ["volume"] = rtk.Slider{"0.0", tooltip = "Volume", min = 0, max = 4, tmargin = 8, color = "orange", data_class = "routing_setting_field"},
    ["pan"] = rtk.Slider{tooltip = "Pan", min = -1, max = 1, tmargin = 8, color = "lightgreen", data_class = "routing_setting_field"},
    -- ["pan_law"] = rtk.Slider{tooltip = "Pan Law", tmargin = 8},
    ["midi_velpan"] = rtk.Button{icon = "gen_midi_off", valign = "center", surface = false, tooltip = "Toggle Midi Volume/Pan", data_class = "routing_setting_field"},
    ["bottomrow"] = rtk.HBox{tmargin = 8, spacing = 3, valign = "center"},
    ["audio_txt"] = rtk.Text{"Audio:", bmargin = "2", fontscale = 0.63},
    ["audio_src_channel"] = rtk.OptionMenu{menu = audio_channel_options, h = 20, margin = "-1 0 0 2", padding = "0 0 4 4", spacing = 6, fontscale = 0.63, data_class = "routing_setting_field"},
    ["audio_rcv_channel"] = rtk.OptionMenu{menu = audio_channel_options, h = 20, margin = "-1 0 0 2", padding = "0 0 4 4", spacing = 6, fontscale = 0.63, data_class = "routing_setting_field"},
    ["midi_txt"] = rtk.Text{"MIDI:", margin = "0 0 2 10", fontscale = 0.63},
    ["midi_src"] = rtk.OptionMenu{menu = midi_channel_options, h = 20, margin = "-1 0 0 2", padding = "0 0 4 4", spacing = 6, fontscale = 0.63, data_class = "routing_setting_field"},
    ["midi_rcv"] = rtk.OptionMenu{menu = midi_channel_options, h = 20, margin = "-1 0 0 2", padding = "0 0 4 4", spacing = 6, fontscale = 0.63, data_class = "routing_setting_field"},
    ["form_fields"] = {}
  }

  for routing_setting_obj_name, routing_setting_obj_value in pairs(_routing_settings_objs) do
    
    if routing_setting_obj_value.data_class == "routing_setting_field" then
      _routing_settings_objs.form_fields[routing_setting_obj_name] = routing_setting_obj_value
    end
  end

  _routing_settings_objs.popup.onblur = function()

    if not _routing_settings_objs.all_values then
      _routing_settings_objs.all_values = {}
    end

    for routing_setting_name, routing_setting_value in pairs(_routing_settings_objs.form_fields) do
      this_form_field_class = routing_setting_value.class.name 

      if this_form_field_class == "rtk.Button" or this_form_field_class == "rtk.Slider" then
        this_form_field_value = routing_setting_value.value

      elseif this_form_field_class == "rtk.OptionMenu" then
        this_form_field_value = routing_setting_value.selected_id
      end

      _routing_settings_objs.all_values[routing_setting_name] = this_form_field_value
    end

    -- logTable(_routing_settings_objs.all_values)
  end
  
  _routing_settings_objs.popup.onkeypress = function(self, event)
  
    if not event.handled and event.keycode == rtk.keycodes.ESCAPE then
      event:set_handled(self)
      _routing_settings_objs.popup:close()
    end
  end

  _routing_settings_objs.mute.onclick = function(self)
    toggleBtnState(self, "table_mute")
  end

  _routing_settings_objs.phase.onclick = function(self)
    toggleBtnState(self, "gen_phase")
  end

  _routing_settings_objs.mono_stereo.onclick = function(self)
    toggleBtnState(self, "gen_mono")
  end

  _routing_settings_objs.volume.onchange = function(self)
    _routing_settings_objs.volume_val:attr("text", reaper.mkvolstr("", self.value))
  end

  _routing_settings_objs.pan.onchange = function(self)
    _routing_settings_objs.pan_val:attr("text", reaper.mkpanstr("", self.value))
  end

  _routing_settings_objs.midi_velpan.onclick = function(self)
    toggleBtnState(self, "gen_midi")
  end

  _routing_settings_objs.mute:attr("value", 0)
  _routing_settings_objs.phase:attr("value", 0)
  _routing_settings_objs.mono_stereo:attr("value", 0)
  _routing_settings_objs.midi_velpan:attr("value", 0)
  _routing_settings_objs.send_mode:select(1)
  _routing_settings_objs.volume:attr("value", 1)
  _routing_settings_objs.pan:attr("value", 0)
  _routing_settings_objs.audio_src_channel:select(1)
  _routing_settings_objs.audio_rcv_channel:select(1)
  _routing_settings_objs.midi_src:select("0/0")
  _routing_settings_objs.midi_rcv:select("0/0")
  _routing_settings_objs.content:add(_routing_settings_objs.title)
  _routing_settings_objs.toprow:add(_routing_settings_objs.volume_val)
  _routing_settings_objs.toprow:add(_routing_settings_objs.pan_val)
  _routing_settings_objs.toprow:add(_routing_settings_objs.mute)
  _routing_settings_objs.toprow:add(_routing_settings_objs.phase)
  _routing_settings_objs.toprow:add(_routing_settings_objs.mono_stereo)
  _routing_settings_objs.toprow:add(_routing_settings_objs.send_mode)
  _routing_settings_objs.form:add(_routing_settings_objs.toprow)
  _routing_settings_objs.middlerow:add(_routing_settings_objs.volume, {expand = 3})
  _routing_settings_objs.middlerow:add(_routing_settings_objs.pan, {expand = 1.25})
  -- _routing_settings_objs.middlerow:add(_routing_settings_objs.panlaw)
  _routing_settings_objs.middlerow:add(_routing_settings_objs.midi_velpan)
  _routing_settings_objs.form:add(_routing_settings_objs.middlerow)
  _routing_settings_objs.bottomrow:add(_routing_settings_objs.audio_txt)
  _routing_settings_objs.bottomrow:add(_routing_settings_objs.audio_src_channel)
  _routing_settings_objs.bottomrow:add(rtk.Text{_right_arrow, bmargin = "3", fontscale = 1.2})
  _routing_settings_objs.bottomrow:add(_routing_settings_objs.audio_rcv_channel)
  _routing_settings_objs.bottomrow:add(_routing_settings_objs.midi_txt)
  _routing_settings_objs.bottomrow:add(_routing_settings_objs.midi_src)
  _routing_settings_objs.bottomrow:add(rtk.Text{_right_arrow, bmargin = "3", fontscale = 1.2})
  _routing_settings_objs.bottomrow:add(_routing_settings_objs.midi_rcv)
  _routing_settings_objs.form:add(_routing_settings_objs.bottomrow)
  _routing_settings_objs.content:add(_routing_settings_objs.form)
  _routing_settings_objs.popup:attr("child", _routing_settings_objs.content)
  _routing_settings_objs.popup:open()



-- local track = reaper.GetTrack(0, 14)
-- local send_val = reaper.BR_GetSetTrackSendInfo(track, _api_routing_types.send, 0, _api_all_routing_settings[8], 0, 0)
-- log(send_val)

end


function toggleBtnState(btn, img_filename_base)

  if btn.value == 0 then
    btn:attr("value", 1)
    btn:attr("icon", img_filename_base .. "_on")

  elseif btn.value == 1 then
    btn:attr("value", 0)
    btn:attr("icon", img_filename_base .. "_off")
  end
end


function submitRoutingOptionChanges(routing_options_form_fields, routing_options_window)
  local routing_option_target_tracks_choices

  routing_option_target_tracks_choices = getTargetTracksChoices(routing_options_form_fields.refs.routing_option_target_tracks_box)

  addRemoveRouting(routing_options_form_fields, routing_option_target_tracks_choices)
  reaper.Undo_BeginBlock()
  routing_options_window:close()
  reaper.Undo_EndBlock("MB_Buss Driver", 1)
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

  if routing_options_form_fields.refs.add_checkbox.value then
    routing_option_action_choice = "add"

  elseif routing_options_form_fields.refs.remove_checkbox.value then
    routing_option_action_choice = "remove"
  end

  if routing_options_form_fields.refs.send_checkbox.value then
    routing_option_type_choice = "send"

  elseif routing_options_form_fields.refs.receive_checkbox.value then
    routing_option_type_choice = "receive"
  end

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
  
  if routing_option_type_choice == "send" then
    reaper.CreateTrackSend(selected_track, target_track)
    
    if _routing_settings_objs.all_values then
      applyRoutingSettings(selected_track, routing_option_type_choice)
    end

  elseif routing_option_type_choice == "receive" then
    reaper.CreateTrackSend(target_track, selected_track)
    
    if _routing_settings_objs.all_values then
      applyRoutingSettings(target_track, routing_option_type_choice)
    end
  end
end


function applyRoutingSettings(dest_track, routing_option_type_choice)
  local routing_settings_api_objs_conversion, dest_track_routing_count, this_api_routing_setting, this_user_routing_setting_value

  routing_settings_api_objs_conversion = {
    [_api_all_routing_settings[1]] = "mute",
    [_api_all_routing_settings[2]] = "phase",
    [_api_all_routing_settings[3]] = "mono_stereo",
    [_api_all_routing_settings[4]] = "volume",
    [_api_all_routing_settings[5]] = "pan",
    [_api_all_routing_settings[6]] = "pan_law",
    [_api_all_routing_settings[7]] = "send_mode",
    [_api_all_routing_settings[8]] = "audio_src_channel",
    [_api_all_routing_settings[9]] = "audio_rcv_channel",
    [_api_all_routing_settings[10]] = "midi_src",
    [_api_all_routing_settings[11]] = "midi_rcv",
    [_api_all_routing_settings[12]] = "midi_src",
    [_api_all_routing_settings[13]] = "midi_rcv",
    [_api_all_routing_settings[14]] = "midi_velpan"
  }
  dest_track_routing_count = reaper.GetTrackNumSends(dest_track, 0)

  if routing_option_type_choice == "send" then
    api_routing_type = 0

  elseif routing_option_type_choice == "receive" then
    api_routing_type = -1
  end

  for i = 1, 14 do

    -- skip PAN_LAW
    if i == 6 then
      goto skip_to_next
    end

    this_api_routing_setting = _api_all_routing_settings[i]
    this_obj_routing_name = routing_settings_api_objs_conversion[this_api_routing_setting]

    if i == 10 or i == 11 then
      this_user_routing_setting_value = string.gsub(_routing_settings_objs.all_values[this_obj_routing_name], "[%d+]/", "")
    
    elseif i == 12 or i == 13 then
      this_user_routing_setting_value = string.gsub(_routing_settings_objs.all_values[this_obj_routing_name], "/[%d+]", "")

    else
      this_user_routing_setting_value = _routing_settings_objs.all_values[this_obj_routing_name]
    end


    log(this_obj_routing_name)
    log(this_user_routing_setting_value)

    
      -- reaper.BR_GetSetTrackSendInfo(dest_track, api_routing_type, dest_track_routing_count-1, this_api_routing_setting, 1, this_user_routing_setting_value)

    ::skip_to_next::
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
  routing_options_objs.addremove_wrapper:add(routing_options_objs.add_checkbox)
  routing_options_objs.addremove_wrapper:add(routing_options_objs.remove_checkbox)
  routing_options_objs.type_wrapper:add(routing_options_objs.send_checkbox)
  routing_options_objs.type_wrapper:add(routing_options_objs.receive_checkbox)
  routing_options_objs.action_sentence:add(routing_options_objs.action_text_start)
  routing_options_objs.action_sentence:add(routing_options_objs.addremove_wrapper)
  routing_options_objs.action_sentence:add(routing_options_objs.type_wrapper)
  routing_options_objs.action_sentence:add(routing_options_objs.action_text_end)
  routing_options_objs.action_sentence_wrapper:add(routing_options_objs.action_sentence)
  routing_options_objs.form_fields:add(routing_options_objs.action_sentence_wrapper)
  routing_options_objs.form_fields:add(routing_options_objs.target_tracks_subheading)
  routing_options_objs.form_fields:add(routing_options_objs.target_tracks_box)
  routing_options_objs.form_buttons:add(routing_options_objs.form_submit)
  routing_options_objs.form_buttons:add(routing_options_objs.form_cancel)
  routing_options_objs.content:add(routing_options_objs.form_fields)
  routing_options_objs.content:add(routing_options_objs.form_buttons)
  routing_options_objs.viewport:attr("child", routing_options_objs.content)
  routing_options_objs.configure_wrapper:add(routing_options_objs.configure_btn)
  routing_options_objs.window:add(routing_options_objs.configure_wrapper)
  routing_options_objs.window:add(routing_options_objs.title)
  routing_options_objs.window:add(routing_options_objs.viewport)

  return routing_options_objs
end


function initBussDriver()
  if _selected_tracks_count > 0 then
    launchBussDriverDialog()
  end
end

initBussDriver()






--- UTILITY FUNCTIONS ---

function round(num, precision)
   return math.floor(num*(10^precision)+0.5) / 10^precision
end