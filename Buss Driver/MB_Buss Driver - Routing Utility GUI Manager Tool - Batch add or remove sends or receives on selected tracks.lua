-- @description MB_Buss Driver - Batch add or remove send(s) or receive(s) on selected track(s)
-- @author MonkeyBars
-- @version 1.21
-- @changelog Incrementing channels should be on source not destination (https://github.com/MonkeyBars3k/ReaScripts/issues/336); Add warning if incrementing tracks hit max channels (https://github.com/MonkeyBars3k/ReaScripts/issues/337)
-- @about Remove or set & add multiple sends or receives to/from multiple tracks in one go
-- @provides [main] .
--  [nomain] rtk.lua
--  [nomain] serpent.lua
--  [nomain] mb-dev-functions.lua
--  bussdriver_logo_nobg.png
--  gen_midi_off.png
--  gen_midi_on.png
--  gen_mono_off.png
--  gen_mono_on.png
--  gen_phase_off.png
--  gen_phase_on.png
--  table_mute_off.png
--  table_mute_on.png
--  gnu_license_v3.txt


-- Copyright (C) MonkeyBars 2023
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your routing_option) any later version.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.


-- ==== MB_BUSS DRIVER SCRIPT ARCHITECTURE NOTES ====
-- MB_Buss Driver uses the great GUI library Reaper Toolkit (rtk). (https://reapertoolkit.dev/)
-- Superglue uses Serpent, a serialization library for LUA, for table-string and string-table conversion. (https://github.com/pkulchenko/serpent)
-- Superglue uses Reaper's Master Track P_EXT to store project-wide script data because its changes are saved in Reaper's undo points, a feature that functions correctly since Reaper v6.43.


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"

-- for dev only
-- require("mb-dev-functions")


local rtk = require("rtk")
local serpent = require("serpent")


rtk.set_theme_overrides({
  tooltip_font = {"Segoe UI (TrueType)", 13}
})



local selected_tracks_count, _selected_tracks, _data_storage_track, _routing_options_objs, _api_routing_types, _api_all_routing_settings, _api_msg_type_ok, _all_tracks_count_on_launch, _routing_settings_objs, reaperFade1, reaperFade2, reaperFade3, reaperFadeg, reaperFadeh, reaperFadeIn, reaperFade, _right_arrow, _default_routing_settings_values, _api_script_ext_name, _api_save_options_key_name, _logo_img_path, _reaper_max_track_channels, _api_stereo_channel_base, _api_mono_channel_base, _api_4channel_base, _regex_digits_at_string_end, _regex_routing_midi_channel, _regex_routing_midi_bus, _enough_audio_channels_are_available

_selected_tracks_count = reaper.CountSelectedTracks(0)
_data_storage_track = reaper.GetMasterTrack(0)
_api_routing_types = {
  ["receive"] = -1,
  ["send"] = 0
}
_api_all_routing_settings = {"B_MUTE", "B_PHASE", "B_MONO", "D_VOL", "D_PAN", "D_PANLAW", "I_SENDMODE", "I_SRCCHAN", "I_DSTCHAN", "I_MIDI_SRCCHAN", "I_MIDI_DSTCHAN", "I_MIDI_SRCBUS", "I_MIDI_DSTBUS", "I_MIDI_LINK_VOLPAN"}
_api_msg_type_ok = 0
_right_arrow = "\u{2192}"
_default_routing_settings_values = {
  ["mute"] = 0,
  ["phase"] = 0,
  ["mono_stereo"] = 0,
  ["send_mode"] = 0,
  ["volume"] = 2.8285,
  ["pan"] = 0,
  ["midi_velpan"] = 0,
  ["audio_src_channel"] = 0,
  ["audio_rcv_channel"] = 0,
  ["midi_src"] = "0/0",
  ["midi_rcv"] = "0/0"
}
_api_script_ext_name = "MB_Buss-Driver"
_api_save_options_key_name = "save_options"
_logo_img_path = "bussdriver_logo_nobg.png"
_reaper_max_track_channels = 64
_api_stereo_channel_base = 0
_api_mono_channel_base = 1024
_api_4channel_base = 2048
_regex_digits_at_string_end = "%d+$"
_regex_routing_midi_channel = "/%-?%d+"
_regex_routing_midi_bus = "%-?%d+/"
_enough_audio_channels_are_available = true




function storeRetrieveProjectData(key, val)
  local retrieve, store, retval, state_data_val

  retrieve = not val
  store = val

  if retrieve then
    retval, state_data_val = reaper.GetProjExtState(0, _api_script_ext_name, key)

  elseif store then
    reaper.SetProjExtState(0, _api_script_ext_name, key, val)
  end

  return state_data_val
end


function toggleSaveOptions(initialize)
  local current_save_options_setting, save_options_checkbox_value

  if initialize == "initialize" then
    current_save_options_setting = storeRetrieveProjectData(_api_save_options_key_name)

    if current_save_options_setting == "" or not current_save_options_setting then
      storeRetrieveProjectData(_api_save_options_key_name, "true")
    end

  else
    save_options_checkbox_value = _routing_options_objs.save_options.value

    if save_options_checkbox_value then
      storeRetrieveProjectData(_api_save_options_key_name, "true")

    else
      storeRetrieveProjectData(_api_save_options_key_name, "false")
    end
  end
end

toggleSaveOptions("initialize")



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
  getRoutingOptionsObjects()
  populateRoutingOptionsWindow()
  defineRoutingOptionsMethods()
  setUpRadioCheckboxMethods()
  _routing_options_objs.window:open()
  storeRetrieveUserOptions("retrieve")
  propagateSavedUserOptions()
end


function getRoutingOptionsObjects()

  _routing_options_objs = {
    ["window"] = rtk.Window{title = "MB_Buss Driver - Batch add or remove sends or receives on selected tracks", w = 0.4, maxh = rtk.Attribute.NIL},
    ["viewport"] = rtk.Viewport{halign = "center", bpadding = 5},
    ["brand"] = rtk.VBox{halign = "center", padding = "2 2 1", border = "1px #878787", bg = "#505050"},
    ["title"] = rtk.Heading{"Buss Driver", fontscale = "0.6"},
    ["logo"] = rtk.ImageBox{rtk.Image():load(_logo_img_path), w = 47, halign = "center", margin = "1 0"},
    ["configure_btn_wrapper"] = rtk.Container{w = 1, halign = "right", margin = "5 3 0 0"},
    ["configure_btn"] = rtk.Button{label = "Configure send settings", tooltip = "Pop up routing settings to be applied to all sends or receives created", padding = "4 5 6", fontscale = 0.67},
    ["content"] = rtk.VBox{halign = "center", padding = "10 0 0"},
    ["selected_tracks_box"] = rtk.VBox{maxw = 0.67, halign = "center", padding = "4 6 2", border = "1px #555555"},
    ["selected_tracks_heading"] = rtk.Text{"Selected track(s)", bmargin = 4, fontscale = 0.8, fontflags = rtk.font.UNDERLINE, color = "#D6D6D6"},
    ["selected_tracks_list"] = getSelectedTracksList(),
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
    ["select_all_tracks"] = rtk.CheckBox{"Select/deselect all tracks", position = "absolute", h = 18, tmargin = 21, padding = "1 2 3", border = "1px #555555", spacing = 3, valign = "center", fontscale = 0.75, color = "#bbbbbb", textcolor2 = "#bbbbbb", ref = "select_all_tracks"},
    ["target_tracks_subheading"] = rtk.Text{"Which tracks do you want the new sends to send to?", w = 1, tmargin = 14, fontscale = 0.95, fontflags = rtk.font.BOLD, halign = "center", fontflags = rtk.font.BOLD},
    ["form_fields"] = rtk.VBox{padding = "10 10 5", spacing = 10},
    ["target_tracks_box"] = getUnselectedTracks(),
    ["form_bottom"] = rtk.Container{w = 1, margin = 10},
    ["form_buttons"] = rtk.HBox{spacing = 10},
    ["save_options_wrapper"] = rtk.HBox{tmargin = 5},
    ["save_options"] = rtk.CheckBox{"Save choices & settings on close", h = 17, padding = "0 2 3 2", spacing = 3, valign = "center", fontscale = 0.67, color = "#bbbbbb", textcolor2 = "#bbbbbb", ref = "save_options_checkbox"},
    ["form_submit"] = rtk.Button{"Add", disabled = true},
    ["form_cancel"] = rtk.Button{"Cancel"},
    ["reset_wrapper"] = rtk.HBox{valign = "center"},
    ["reset_btn"] = rtk.Button{"Reset all options", tooltip = "Return all tracks and settings to initial state", padding = "4 5 6", color = "#8A4C00R", fontscale = 0.67, textcolor = "#D6D6D6"}
  }
end


function getSelectedTracksList()
  local selected_tracks_list, this_track, retval, this_track_name, this_track_num

  selected_tracks_list = rtk.FlowBox{hspacing = 10}

  for i = 1, #_selected_tracks do
    this_track = _selected_tracks[i]
    retval, this_track_name = reaper.GetTrackName(this_track)
    this_track_num = math.tointeger(reaper.GetMediaTrackInfo_Value(this_track, "IP_TRACKNUMBER"))
    
    selected_tracks_list:add(rtk.Text{this_track_num .. ": " .. this_track_name, bpadding = 3, fontscale = 0.67, color = "#D6D6D6"})
  end

  return selected_tracks_list
end


function getUnselectedTracks()
  local routing_option_target_tracks_box, this_track

  routing_option_target_tracks_box = rtk.FlowBox{w = 1, tmargin = 7, ref = "routing_option_target_tracks_box"}

  for i = 0, _all_tracks_count_on_launch-1 do
    this_track = reaper.GetTrack(0, i)
    routing_option_target_tracks_box = populateTargetTrackField(this_track, routing_option_target_tracks_box)
  end

  return routing_option_target_tracks_box
end


function populateTargetTrackField(this_track, routing_option_target_tracks_box)
  local this_track_is_selected, this_track_line, this_track_icon_path, this_track_icon, this_track_num, this_track_name, this_track_color, this_track_checkbox

  this_track_is_selected = reaper.IsTrackSelected(this_track)

  if this_track_is_selected == false then
    this_track_line, this_track_icon_path, this_track_icon, this_track_num, this_track_name, this_track_color, this_track_checkbox = getTrackObjs(this_track)

    if this_track_color ~= 0 then
      this_track_color = rtk.color.convert_native(this_track_color)
      this_track_checkbox:attr("bg", this_track_color)

      this_track_checkbox = correctTrackColor(this_track_checkbox, this_track_color)
    end

    this_track_checkbox.onchange = function(self)

      if self.value then
        disableSubmitButton(false)
      end
    end

    this_track_line:add(this_track_icon)
    this_track_line:add(this_track_checkbox)
    routing_option_target_tracks_box:add(this_track_line)
  end

  return routing_option_target_tracks_box
end


function getTrackObjs(this_track)
  local this_track_line, retval, this_track_icon_path, this_track_icon, this_track_num, retval, this_track_name, this_track_color, this_track_checkbox

  this_track_line = rtk.HBox{valign = "center", data_class = "target_track_line"}
  retval, this_track_icon_path = reaper.GetSetMediaTrackInfo_String(this_track, "P_ICON", "", false)
  this_track_icon = rtk.ImageBox{rtk.Image():load(this_track_icon_path), w = 18, minw = 18}
  this_track_num = math.tointeger(reaper.GetMediaTrackInfo_Value(this_track, "IP_TRACKNUMBER"))
  this_track_guid = reaper.BR_GetMediaTrackGUID(this_track)
  retval, this_track_name = reaper.GetSetMediaTrackInfo_String(this_track, "P_NAME", "", 0)
  this_track_color = reaper.GetTrackColor(this_track)
  this_track_checkbox = rtk.CheckBox{this_track_num .. ": " .. this_track_name, h = 17, fontscale = 0.75, margin = "0 5 1 2", padding = "0 2 3 2", spacing = 3, valign = "center", ref = "target_track_" .. this_track_num, data_class = "target_track_checkbox"}
  this_track_line.data_guid = this_track_guid

  return this_track_line, this_track_icon_path, this_track_icon, this_track_num, this_track_name, this_track_color, this_track_checkbox
end


function correctTrackColor(track_checkbox, track_color)
  local this_track_color_r, this_track_color_g, this_track_color_b, this_track_color_rgb, this_track_color_is_dark

  this_track_color_r, this_track_color_g, this_track_color_b = reaper.ColorFromNative(track_color)
  this_track_color_rgb = this_track_color_r + this_track_color_g + this_track_color_b
  this_track_color_rgb = tonumber(this_track_color_rgb)
  this_track_color_is_dark = colorIsDark(this_track_color_rgb)

  if not this_track_color_is_dark then
    track_checkbox:attr("textcolor2", "#000000")
  end

  return track_checkbox
end


function colorIsDark(rgb)

  return rgb < 3 * 256 / 2
end


function disableSubmitButton(disable)
  _routing_options_objs.form_submit:attr("disabled", disable)
end


function defineRoutingOptionsMethods()

  _routing_options_objs.window.onblur = function(self)
    self:close()
  end

  _routing_options_objs.window.onclose = function()
    storeRetrieveUserOptions("store")
    restoreUserSelectedTracks()
    storeRetrieveAllTracksCount("")
  end

  _routing_options_objs.configure_btn.onclick = function()
    launchRoutingSettings()
  end

  _routing_options_objs.select_all_tracks.onchange = function(self)
    selectDeselectAllTargetTracks(self.value)
  end

  _routing_options_objs.save_options.onchange = function()
    toggleSaveOptions()
  end

  _routing_options_objs.form_submit.onclick = function()
    submitRoutingOptionChanges()
  end
  
  _routing_options_objs.form_cancel.onclick = function()
    _routing_options_objs.window:close()
  end

  _routing_options_objs.reset_btn.onclick = function()
    selectDeselectAllTargetTracks(false)
    populateRoutingSettingsFormValues("reset")
    disableSubmitButton(true)
  end
end


function storeRetrieveUserOptions(store)
  local retval, current_save_options_setting, all_user_options, retval

  retval, current_save_options_setting = reaper.GetProjExtState(0, _api_script_ext_name, _api_save_options_key_name)

  if current_save_options_setting == "true" then

    if store == "store" then
      all_user_options = getSetMainActionChoices("get")

      getSetTargetTracksChoices()

      all_user_options.target_track_choices = _routing_options_objs.target_track_choices

      if _routing_settings_objs and _routing_settings_objs.all_values then
        all_user_options.routing_settings = _routing_settings_objs.all_values
      end

      all_user_options = serpent.dump(all_user_options)

      storeRetrieveProjectData("all_user_options", all_user_options)

    elseif store == "retrieve" then
      all_user_options = storeRetrieveProjectData("all_user_options")
      retval, all_user_options = serpent.load(all_user_options)
      _routing_options_objs.all_user_options = all_user_options
    end
  end
end


function propagateSavedUserOptions()
  local retval, current_save_options_setting

  retval, current_save_options_setting = reaper.GetProjExtState(0, _api_script_ext_name, _api_save_options_key_name)

  if current_save_options_setting == "true" then
    _routing_options_objs.save_options:attr("value", true)

    if _routing_options_objs and _routing_options_objs.all_user_options then
      getSetMainActionChoices("set")

      if _routing_options_objs.all_user_options.target_track_choices then

        if #_routing_options_objs.all_user_options.target_track_choices > 0 then
          getSetTargetTracksChoices(_routing_options_objs.all_user_options.target_track_choices)
        end
      end

      if _routing_options_objs.all_user_options.routing_settings then

        if not _routing_settings_objs then
          initRoutingSettings()
        end

        _routing_settings_objs.all_values = _routing_options_objs.all_user_options.routing_settings

        getSetRoutingSettingsValues("set", _routing_settings_objs.all_values)
        updateRoutingSettingsBtns()
      end
    end

  elseif current_save_options_setting == "false" then
    _routing_options_objs.save_options:attr("value", false)
  end
end


function getSetMainActionChoices(get_set)
  local checkbox_labels, main_action_choices, checkbox_string_suffix, this_checkbox_name

  checkbox_labels = {"add", "remove", "send", "receive"}
  main_action_choices = {}
  checkbox_string_suffix = "_checkbox"

  if get_set == "get" then

    for i = 1, #checkbox_labels do
      this_checkbox_name = checkbox_labels[i] .. checkbox_string_suffix

      main_action_choices[this_checkbox_name] = _routing_options_objs[this_checkbox_name].value
    end

    return main_action_choices

  elseif get_set == "set" then

    for i = 1, #checkbox_labels do
      this_checkbox_name = checkbox_labels[i] .. checkbox_string_suffix

      _routing_options_objs[this_checkbox_name]:attr("value", false)

      if _routing_options_objs.all_user_options[this_checkbox_name] then
        _routing_options_objs[this_checkbox_name]:attr("value", _routing_options_objs.all_user_options[this_checkbox_name])
      end
    end

    updateRoutingForm("is_action_change")
  end
end


function restoreUserSelectedTracks()

  for i = 1, #_selected_tracks do
    reaper.SetTrackSelected(_selected_tracks[i], true)
  end
end


function setUpRadioCheckboxMethods()
  local checkbox_sets = {
    {"add_checkbox", "remove_checkbox"},
    {"send_checkbox", "receive_checkbox"}
  }

  for i = 1, #checkbox_sets do
    populateRadioCheckboxMethods(checkbox_sets[i][1], checkbox_sets[i][2])
    populateRadioCheckboxMethods(checkbox_sets[i][2], checkbox_sets[i][1])
  end
end


function populateRadioCheckboxMethods(checkbox1, checkbox2)
  _routing_options_objs[checkbox1].onclick = function()

    _routing_options_objs[checkbox1].onchange = function()
      _routing_options_objs[checkbox2]:toggle()
      updateRoutingForm("is_action_change")

      _routing_options_objs[checkbox1].onchange = nil
    end
  end
end


function updateRoutingForm(is_action_change)
  local routing_action, routing_type, target_tracks_subheading_text_intro, target_tracks_subheading_routing_action_text, type_preposition, action_preposition, action_text_end, new_target_tracks_subheading_text

  routing_action, routing_type = getRoutingChoices()

  if routing_action == "add" then
    target_tracks_subheading_text_intro = "Which tracks do you want the new " .. routing_type .. "s to "

  elseif routing_action == "remove" then
    target_tracks_subheading_text_intro = "Which tracks do the " .. routing_type .. "s you want to remove "
  end

  target_tracks_subheading_routing_action_text = routing_action .. " "
  type_preposition, action_preposition = getRoutingPrepositions(routing_action, routing_type)
  action_text_end = " " .. action_preposition .. " the selected tracks."
  new_target_tracks_subheading_text = target_tracks_subheading_text_intro .. routing_type .. " " .. type_preposition .. "?"

  _routing_options_objs.target_tracks_subheading:attr("text", new_target_tracks_subheading_text)
  _routing_options_objs.configure_btn:attr("label", "Configure " .. routing_type .. " settings")
  _routing_options_objs.action_text_end:attr("text", action_text_end)
  updateButtons(routing_action, is_action_change, routing_type)
end


function getRoutingChoices()
  local routing_action, routing_type

  if _routing_options_objs.add_checkbox.value == true then
    routing_action = "add"

  elseif _routing_options_objs.remove_checkbox.value == true then
    routing_action = "remove"
  end

  if _routing_options_objs.send_checkbox.value == true then
    routing_type = "send"

  elseif _routing_options_objs.receive_checkbox.value == true then
    routing_type = "receive"
  end

  return routing_action, routing_type
end


function getRoutingPrepositions(routing_action, routing_type)
  local type_preposition, action_preposition

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

  return type_preposition, action_preposition
end


function updateButtons(routing_action, is_action_change, selected_routing_type)
  local configure_btn_height, routing_options_submit_btn_text, saved_target_track_choices

  if is_action_change == "is_action_change" then

    if routing_action == "add" then
      configure_btn_height = nil
      routing_options_submit_btn_text = "Add"

      filterTargetTracks("reset")
    
    elseif routing_action == "remove" then
      configure_btn_height = 0
      routing_options_submit_btn_text = "Remove"

      filterTargetTracks(nil, selected_routing_type)
    end

    _routing_options_objs.configure_btn:animate{"h", dst = configure_btn_height, duration = 0.33}
    _routing_options_objs.form_submit:attr("label", routing_options_submit_btn_text)
  end
end



function filterTargetTracks(action, selected_routing_type)
  local this_track_choice, this_track_choice_guid, this_selected_track, this_selected_track_routing_count, api_routing_type, api_target_track_string, this_routing_track, this_routing_track_guid, this_track_choice_is_present_in_routing, target_track_lines

  if action == "reset" then
    showHideTargetTrackChoices("show")
    getSetTargetTracksChoices(_routing_options_objs.saved_target_track_choices)

  else
    target_track_lines = showHideTargetTrackChoices("hide")

    for i = 1, #_selected_tracks do
      this_selected_track = _selected_tracks[i]
      this_selected_track_routing_count, api_routing_type, api_target_track_string = getRoutingValues(this_selected_track, selected_routing_type)

      for j = 0, this_selected_track_routing_count-1 do
        this_routing_track = reaper.GetTrackSendInfo_Value(this_selected_track, api_routing_type, j, api_target_track_string)
        this_routing_track_guid = reaper.BR_GetMediaTrackGUID(this_routing_track)

        showTargetTracksWithExistingRouting(this_routing_track_guid, target_track_lines)
      end
    end
  end
end


function showHideTargetTrackChoices(show_hide)
  local target_track_lines, this_track_line

  target_track_lines = _routing_options_objs.target_tracks_box.children

  for i = 1, #target_track_lines do
    this_track_line = target_track_lines[i][1]

    if show_hide == "show" then
      this_track_line:show()

    elseif show_hide == "hide" then
      this_track_line:hide()
    end
  end

  return target_track_lines
end


function getRoutingValues(selected_track, selected_routing_type)
  local selected_track_routing_count, api_routing_type, api_target_track_string

  if selected_routing_type == "send" then
    selected_track_routing_count = reaper.GetTrackNumSends(selected_track, 0)
    api_routing_type = 0
    api_target_track_string = "P_DESTTRACK"

  elseif selected_routing_type == "receive" then
    selected_track_routing_count = reaper.GetTrackNumSends(selected_track, -1)
    api_routing_type = -1
    api_target_track_string = "P_SRCTRACK"
  end

  return selected_track_routing_count, api_routing_type, api_target_track_string
end


function showTargetTracksWithExistingRouting(this_routing_track_guid, target_track_lines)
  local this_track_line, this_track_line_guid, this_track_line_matches_current_track

  for i = 1, #target_track_lines do
    this_track_line = target_track_lines[i][1]

    if this_track_line then
      this_track_line_guid = this_track_line.data_guid
      this_track_line_matches_current_track = this_track_line_guid == this_routing_track_guid

      if this_track_line_matches_current_track then
        this_track_line:show()

        break
      end
    end
  end
end


function launchRoutingSettings()
  
  if not _routing_settings_objs then
    initRoutingSettings()
  end

  _routing_settings_objs.popup:open()
end


function initRoutingSettings()
  local audio_channel_src_options, audio_channel_rcv_options, midi_channel_src_options, midi_channel_rcv_options

  audio_channel_src_options, audio_channel_rcv_options = defineAudioChannelOptions()
  midi_channel_src_options, midi_channel_rcv_options = defineMIDIChannelOptions()

  populateRoutingSettingsObjs(audio_channel_src_options, audio_channel_rcv_options, midi_channel_src_options, midi_channel_rcv_options)
  gatherRoutingSettingsFormFields()
  setRoutingSettingsPopupEventHandlers()
  populateRoutingSettingsFormValues()
  setRoutingSettingsFormEventHandlers()
  populateRoutingSettingsPopup()
end


function defineAudioChannelOptions()
  local audio_channel_submenu_mono_options, audio_channel_submenu_stereo_options, audio_channel_src_options, audio_channel_rcv_options

  audio_channel_submenu_mono_options = {}
  audio_channel_submenu_stereo_options = {}

  for i = 0, 15 do
    audio_channel_submenu_mono_options[i+1] = {
      ["label"] = tostring(i+1),
      ["id"] = _api_mono_channel_base + i
    }
  end

  for i = 0, 14 do
    audio_channel_submenu_stereo_options[i+1] = {
      ["label"] = tostring(i+1) .. "/" .. tostring(i+2),
      ["id"] = i
    }
  end

  audio_channel_src_options = {
    {"None", id = -1},
    {"Mono source", submenu = audio_channel_submenu_mono_options},
    {"Stereo source", submenu = audio_channel_submenu_stereo_options}
  }

  audio_channel_rcv_options = {
    {"Mono receiving channels", submenu = audio_channel_submenu_mono_options},
    {"Stereo receiving channels", submenu = audio_channel_submenu_stereo_options}
  }

  return audio_channel_src_options, audio_channel_rcv_options
end


function deepTableCopy( original, copies )
  if type( original ) ~= 'table' then return original end
  copies = copies or {}
  if copies[original] then return copies[original] end
  local copy = {}
  copies[original] = copy
  for key, value in pairs( original ) do
      local dc_key, dc_value = deepTableCopy( key, copies ), deepTableCopy( value, copies )
      copy[dc_key] = dc_value
  end
  setmetatable(copy, deepTableCopy( getmetatable( original ), copies) )
  return copy
end


function defineMIDIChannelOptions()
  local midi_channel_submenu_bus_options, midi_channel_submenu_bus_option_val, midi_channel_rcv_options, midi_channel_src_options

  -- none -1 / stereo idx / mono 1024+idx / hwout 512+idx
  midi_channel_src_options = {
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
    midi_channel_src_options[i] = {
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

    for j = 1, 16 do
      midi_channel_submenu_bus_option_val = i-18 .. "/" .. j

      midi_channel_submenu_bus_options[j] = {
        ["label"] = midi_channel_submenu_bus_option_val,
        ["id"] = midi_channel_submenu_bus_option_val
      }
    end

    midi_channel_src_options[i] = {
      ["label"] = "Bus " .. i-18,
      ["submenu"] = midi_channel_submenu_bus_options
    }
  end

  midi_channel_rcv_options = deepTableCopy(midi_channel_src_options)

  table.remove(midi_channel_rcv_options, 1)

  return midi_channel_src_options, midi_channel_rcv_options
end


function populateRoutingSettingsObjs(audio_channel_src_options, audio_channel_rcv_options, midi_channel_src_options, midi_channel_rcv_options)
  
  _routing_settings_objs = {
    ["popup"] = rtk.Popup{w = _routing_options_objs.window.w / 3, minw = 341, overlay = "#303030cc", padding = 0},
    ["content"] = rtk.VBox(),
    ["title"] = rtk.Heading{"Configure settings for routing to be added", w = 1, halign = "center", padding = 6, bg = "#777777", fontscale = 0.67},
    ["form"] = rtk.VBox{padding = "20 10 10"},
    ["row1"] = rtk.HBox(),
    ["volume_val"] = rtk.Text{"+0.00", w = 45, h = 19, padding = 3, border = "1px #777888", fontscale = 0.63},
    ["pan_val"] = rtk.Text{"center", w = 35, h = 19, valign = "center", halign = "center", lmargin = 5, padding = 3, border = "1px #777888", fontscale = 0.63},
    ["mute"] = rtk.Button{icon = "table_mute_off", w = 23, h = 20, lmargin = 5, padding = 0, surface = false, tooltip = "Mute", data_class = "routing_setting_field"},
    ["phase"] = rtk.Button{icon = "gen_phase_off", w = 10, h = 10, tooltip = "Reverse phase", margin = "4 0 0 5", padding = 0, circular = true, data_class = "routing_setting_field"},
    ["mono_stereo"] = rtk.Button{icon = "gen_mono_off", w = 23, h = 20, tooltip = "Mono/Stereo", lmargin = 5, padding = 0, surface = false, data_class = "routing_setting_field"},
    ["send_mode"] = rtk.OptionMenu{menu = {
      {"Post-Fader (Post-Pan)", id = 0},
      {"Pre-Fader (Post-FX)", id = 3},
      {"Pre-FX", id = 1}
    }, h = 20, margin = "-1 0 0 2", padding = "0 0 4 4", spacing = 6, fontscale = 0.63, data_class = "routing_setting_field"},
    ["row2"] = rtk.HBox{tmargin = 8},
    ["volume"] = rtk.Slider{"0.0", tooltip = "Volume", min = 0, max = 4, tmargin = 8, color = "orange", data_class = "routing_setting_field"},
    ["pan"] = rtk.Slider{tooltip = "Pan", min = -1, max = 1, tmargin = 8, color = "lightgreen", data_class = "routing_setting_field"},
    -- ["pan_law"] = rtk.Slider{tooltip = "Pan Law", tmargin = 8},
    ["midi_velpan"] = rtk.Button{icon = "gen_midi_off", valign = "center", surface = false, tooltip = "Toggle Midi Volume/Pan", data_class = "routing_setting_field"},
    ["row3"] = rtk.HBox{tmargin = 8},
    ["audio_block"] = rtk.VBox(),
    ["audio_channels"] = rtk.HBox{spacing = 3, valign = "center"},
    ["audio_txt"] = rtk.Text{"Audio:", bmargin = "2", fontscale = 0.63},
    ["audio_src_channel"] = rtk.OptionMenu{menu = audio_channel_src_options, h = 20, margin = "-1 0 0 2", padding = "0 0 4 4", spacing = 6, fontscale = 0.63, data_class = "routing_setting_field", ref = "audio_src_channel"},
    ["audio_rcv_channel"] = rtk.OptionMenu{menu = audio_channel_rcv_options, h = 20, margin = "-1 0 0 2", padding = "0 0 4 4", spacing = 6, fontscale = 0.63, data_class = "routing_setting_field", ref = "audio_rcv_channel"},
    ["audio_incrementing"] = rtk.CheckBox{"Increment audio channels up", spacing = 2, fontscale = 0.63, valign = "center", data_class = "routing_setting_field"},
    ["midi_block"] = rtk.VBox{margin = "0 0 2 5", lpadding = 7, lborder = "1px #676767"},
    ["midi_channels"] = rtk.HBox{spacing = 3, valign = "center"},
    ["midi_txt"] = rtk.Text{"MIDI:", fontscale = 0.63},
    ["midi_src"] = rtk.OptionMenu{menu = midi_channel_src_options, h = 20, margin = "-1 0 0 2", padding = "0 0 4 4", spacing = 6, fontscale = 0.63, ref = "midi_src", data_class = "routing_setting_field"},
    ["midi_rcv"] = rtk.OptionMenu{menu = midi_channel_rcv_options, h = 20, margin = "-1 0 0 2", padding = "0 0 4 4", spacing = 6, fontscale = 0.63, ref = "midi_rcv", data_class = "routing_setting_field"},
    ["midi_incrementing"] = rtk.CheckBox{"Increment MIDI channels up", spacing = 2, fontscale = 0.63, valign = "center", data_class = "routing_setting_field"}
  }
end


function gatherRoutingSettingsFormFields()

  if not _routing_settings_objs.form_fields then
    _routing_settings_objs.form_fields = {}

    for routing_setting_obj_name, routing_setting_obj_value in pairs(_routing_settings_objs) do
      
      if routing_setting_obj_value.data_class == "routing_setting_field" then
        _routing_settings_objs.form_fields[routing_setting_obj_name] = routing_setting_obj_value
      end
    end
  end
end


function setRoutingSettingsPopupEventHandlers()

  _routing_settings_objs.popup.onclose = function()

    if not _routing_settings_objs.all_values then
      _routing_settings_objs.all_values = {}
    end

    getSetRoutingSettingsValues("get")
  end
  
  _routing_settings_objs.popup.onkeypress = function(self, event)
  
    if not event.handled and event.keycode == rtk.keycodes.ESCAPE then
      event:set_handled(self)
      _routing_settings_objs.popup:close()
    end
  end
end


function getSetRoutingSettingsValues(get_set, new_routing_settings_values)
  local this_form_field_class, this_field_is_type_value, this_field_is_type_selected, this_form_field_value

  for routing_setting_name, routing_setting_value in pairs(_routing_settings_objs.form_fields) do
    this_form_field_class = routing_setting_value.class.name
    this_field_is_type_value = this_form_field_class == "rtk.CheckBox" or this_form_field_class == "rtk.Button" or this_form_field_class == "rtk.Slider"
    this_field_is_type_selected = this_form_field_class == "rtk.OptionMenu"

    if get_set == "get" then

      if this_field_is_type_value then
        this_form_field_value = _routing_settings_objs[routing_setting_name].value

      elseif this_field_is_type_selected then
        this_form_field_value = _routing_settings_objs[routing_setting_name].selected_id
      end

      _routing_settings_objs.all_values[routing_setting_name] = this_form_field_value

    elseif get_set == "set" then

      if this_field_is_type_value then
        _routing_settings_objs[routing_setting_name]:attr("value", new_routing_settings_values[routing_setting_name])

      elseif this_field_is_type_selected then
        _routing_settings_objs[routing_setting_name]:attr("selected", new_routing_settings_values[routing_setting_name])
      end
    end
  end
end


function setRoutingSettingsFormEventHandlers()
  local new_value

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
    new_value = getAPIVolume(self.value)

    _routing_settings_objs.volume_val:attr("text", reaper.mkvolstr("", new_value))
  end

  _routing_settings_objs.pan.onchange = function(self)
    _routing_settings_objs.pan_val:attr("text", reaper.mkpanstr("", self.value))
  end

  _routing_settings_objs.midi_velpan.onclick = function(self)
    toggleBtnState(self, "gen_midi")
  end

  _routing_settings_objs.audio_src_channel.onchange = function(self)
    toggleChannelDropdown(self)
  end

  _routing_settings_objs.midi_src.onchange = function(self)
    toggleChannelDropdown(self)
  end
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


function toggleChannelDropdown(active_dropdown)
  local none_value, affected_dropdown, arrow_ref, affected_incrementing_checkbox

  if active_dropdown.ref == "audio_src_channel" then
    none_value = -1
    affected_dropdown = _routing_settings_objs.audio_rcv_channel
    arrow_ref = "audio_arrow"
    affected_incrementing_checkbox = _routing_settings_objs.audio_incrementing

  elseif active_dropdown.ref == "midi_src" then
    none_value = "-1/-1"
    affected_dropdown = _routing_settings_objs.midi_rcv
    arrow_ref = "midi_arrow"
    affected_incrementing_checkbox = _routing_settings_objs.midi_incrementing
  end

  if active_dropdown.selected_id == none_value then
    affected_dropdown:attr("ghost", true)
    affected_dropdown.refs[arrow_ref]:attr("ghost", true)
    affected_incrementing_checkbox:hide()

  else
    affected_dropdown:attr("ghost", false)
    affected_dropdown.refs[arrow_ref]:attr("ghost", false)
    affected_incrementing_checkbox:show()
  end
end


reaperFade1 = function(x,c) return c<0 and (1+c)*x*(2-x)-c*(1-(1-x)^8)^.5 or (1-c)*x*(2-x)+c*x^4 end
reaperFade2 = function(x,c) return c<0 and (1+c)*x-c*(1-(1-x)^2) or (1-c)*x+c*x^2 end
reaperFade3 = function(x,c) return c<0 and (1+c)*x-c*(1-(1-x)^4) or (1-c)*x+c*x^4 end
reaperFadeg = function(x,t) return t==.5 and x or ((x*(1-2*t)+t^2)^.5-t)/(1-2*t) end
reaperFadeh = function(x,t) local g = reaperFadeg(x,t); return (2*t-1)*g^2+(2-2*t)*g end

reaperFadeIn = {
  function(x,c) c=c or 0; return reaperFade3(x,c) end,
  function(x,c) c=c or 0; return reaperFade1(x,c) end,
  function(x,c) c=c or 1; return reaperFade2(x,c) end,
  function(x,c) c=c or -1; return reaperFade3(x,c) end,
  function(x,c) c=c or 1; return reaperFade3(x,c) end,
  function(x,c) c=c or 0; local x1 = reaperFadeh(x,.25*(c+2)); return (3-2*x1)*x1^2 end,
  function(x,c) c=c or 0; local x2 = reaperFadeh(x,(5*c+8)/16); return x2<=.5 and 8*x2^4 or 1-8*(1-x2)^4 end,
}

reaperFade = function(ftype,t,s,e,c,inout)
  --
  -- Returns 0 to 1
  --
  -- ftype is the REAPER fade type 1-7 (Note: not 0-6 here)
  -- t - time code where fade is calculated
  -- s - time code of fade start
  -- e - time code of fade end
  -- c - REAPER curvature parameter (D_FADEINDIR, D_FADEOUTDIR)
  -- inout - true for fade in, false for fade out
  --
  if e<=s then return 1 end
  t = t<s and s or t>e and e or t
  local x = (t-s)/(e-s)
  local ret = reaperFadeIn[ftype](table.unpack(inout and {x,c} or {1-x,-c}))
  return ret * 4
end

function getAPIVolume(slider_value)

  return reaperFade(5, slider_value, 0, 4, 1, true)
end


function populateRoutingSettingsFormValues(reset)
  local new_routing_settings_values

  if _routing_settings_objs then

    if _routing_settings_objs.all_values and reset ~= "reset" then
      new_routing_settings_values = _routing_settings_objs.all_values

    else
      new_routing_settings_values = _default_routing_settings_values
    end

    getSetRoutingSettingsValues("set", new_routing_settings_values)

    if reset == "reset" then
      updateRoutingSettingsBtns("reset")
    end
  end
end


function updateRoutingSettingsBtns(reset)
  local all_btn_img_filename_bases, this_btn, this_btn_value, new_btn_img_base_state

  all_btn_img_filename_bases = {
    ["mute"] = "table_mute",
    ["phase"] = "gen_phase",
    ["mono_stereo"] = "gen_mono",
    ["midi_velpan"] = "gen_midi"
  }

  for btn_name, btn_img_base in pairs(all_btn_img_filename_bases) do
    this_btn = _routing_settings_objs[btn_name]
    this_btn_value = this_btn.value

    if reset == "reset" or this_btn_value == 0 then
      new_btn_img_base_state = "_off"

    elseif this_btn_value == 1 then
      new_btn_img_base_state = "_on"
    end

    this_btn:attr("icon", btn_img_base .. new_btn_img_base_state)
  end
end


function populateRoutingSettingsPopup()
  _routing_settings_objs.content:add(_routing_settings_objs.title)
  _routing_settings_objs.row1:add(_routing_settings_objs.volume_val)
  _routing_settings_objs.row1:add(_routing_settings_objs.pan_val)
  _routing_settings_objs.row1:add(_routing_settings_objs.mute)
  _routing_settings_objs.row1:add(_routing_settings_objs.phase)
  _routing_settings_objs.row1:add(_routing_settings_objs.mono_stereo)
  _routing_settings_objs.row1:add(_routing_settings_objs.send_mode)
  _routing_settings_objs.form:add(_routing_settings_objs.row1)
  _routing_settings_objs.row2:add(_routing_settings_objs.volume, {expand = 3})
  _routing_settings_objs.row2:add(_routing_settings_objs.pan, {expand = 1.25})
  -- _routing_settings_objs.row2:add(_routing_settings_objs.panlaw)
  _routing_settings_objs.row2:add(_routing_settings_objs.midi_velpan)
  _routing_settings_objs.form:add(_routing_settings_objs.row2)
  _routing_settings_objs.audio_channels:add(_routing_settings_objs.audio_txt)
  _routing_settings_objs.audio_channels:add(_routing_settings_objs.audio_src_channel)
  _routing_settings_objs.audio_channels:add(rtk.Text{_right_arrow, bmargin = "3", fontscale = 1.2, ref = "audio_arrow"})
  _routing_settings_objs.audio_channels:add(_routing_settings_objs.audio_rcv_channel)
  _routing_settings_objs.audio_block:add(_routing_settings_objs.audio_channels)
  _routing_settings_objs.audio_block:add(_routing_settings_objs.audio_incrementing)
  _routing_settings_objs.midi_channels:add(_routing_settings_objs.midi_txt)
  _routing_settings_objs.midi_channels:add(_routing_settings_objs.midi_src)
  _routing_settings_objs.midi_channels:add(rtk.Text{_right_arrow, bmargin = "3", fontscale = 1.2, ref = "midi_arrow"})
  _routing_settings_objs.midi_channels:add(_routing_settings_objs.midi_rcv)
  _routing_settings_objs.midi_block:add(_routing_settings_objs.midi_channels)
  _routing_settings_objs.midi_block:add(_routing_settings_objs.midi_incrementing)
  _routing_settings_objs.row3:add(_routing_settings_objs.audio_block)
  _routing_settings_objs.row3:add(_routing_settings_objs.midi_block)
  _routing_settings_objs.form:add(_routing_settings_objs.row3)
  _routing_settings_objs.content:add(_routing_settings_objs.form)
  _routing_settings_objs.popup:attr("child", _routing_settings_objs.content)
end


function selectDeselectAllTargetTracks(select_deselect)
  local target_track_lines, this_track_line, this_track_checkbox

  target_track_lines = _routing_options_objs.target_tracks_box.children

  for j = 1, #target_track_lines do
    this_track_line = target_track_lines[j][1]

    if this_track_line then
      this_track_checkbox = this_track_line.children[2][1]
      this_track_checkbox:attr("value", select_deselect)
    end
  end
end


function submitRoutingOptionChanges()
  local buss_driven

  getSetTargetTracksChoices()

  buss_driven = addRemoveRouting(_routing_options_objs.form_fields)
  
  if buss_driven then

    if not _enough_audio_channels_are_available then
      reaper.ShowMessageBox("Buss Driver has set the tracks exceeding channel limit to the top channel value.", "You have more destination tracks selected than the " .. _reaper_max_track_channels .. " incrementing channels available.", _api_msg_type_ok)
    end

    reaper.Undo_BeginBlock()
    _routing_options_objs.window:close()
    reaper.Undo_EndBlock("MB_Buss Driver", 1)

  else
    reaper.ShowMessageBox("No routing is available to remove on the selected track(s).", "Buss Driver", _api_msg_type_ok)
  end
end


function getSetTargetTracksChoices(new_choices)
  local set, get 

  if new_choices then
    set = true

  else
    get = true
  end

  if get then
    getTargetTrackChoices()

  elseif set then
    setTargetTrackChoices(new_choices)
  end
end


function getTargetTrackChoices()
  local this_track_line, this_track_checkbox, this_track_idx, this_track_guid

  _routing_options_objs.target_track_choices = {}

  for i = 1, #_routing_options_objs.target_tracks_box.children do
    this_track_line = _routing_options_objs.target_tracks_box:get_child(i)
    this_track_checkbox = this_track_line:get_child(2)
    
    if this_track_checkbox.value then
      this_track_idx = string.match(this_track_checkbox.ref, _regex_digits_at_string_end)
      this_track = reaper.GetTrack(0, this_track_idx-1)
      this_track_guid = reaper.BR_GetMediaTrackGUID(this_track)

      table.insert(_routing_options_objs.target_track_choices, {
        ["idx"] = this_track_idx,
        ["guid"] = this_track_guid
      })
    end
  end
end


function setTargetTrackChoices(new_choices)
  local target_track_lines, this_track_guid, this_track_line_guid, this_track_line, this_track_checkbox

  for i = 1, #new_choices do
    target_track_lines = _routing_options_objs.target_tracks_box.children
    this_track_guid = new_choices[i].guid

    for j = 1, #target_track_lines do
      this_track_line = target_track_lines[j][1]

      if this_track_line then
        this_track_line_guid = this_track_line.data_guid

        if this_track_line_guid == this_track_guid then
          this_track_checkbox = this_track_line.children[2][1]

          this_track_checkbox:attr("value", true)

          break
        end
      end
    end
  end
end


function addRemoveRouting(routing_options_form_fields)
  local routing_option_action_choice, routing_option_type_choice, this_selected_track, j, this_target_track, buss_driven

  routing_option_action_choice, routing_option_type_choice = getRoutingChoices()

  for i = 1, #_selected_tracks do
    this_selected_track = _selected_tracks[i]

    for j = 1, #_routing_options_objs.target_track_choices do
      this_target_track = reaper.GetTrack(0, _routing_options_objs.target_track_choices[j].idx-1)

      if routing_option_action_choice == "add" then
        addRouting(routing_option_type_choice, this_selected_track, this_target_track, j)

        buss_driven = true

      elseif routing_option_action_choice == "remove" then
        buss_driven = removeRouting(routing_option_type_choice, this_selected_track, this_target_track)
      end
    end
  end

  return buss_driven
end


function addRouting(routing_option_type_choice, selected_track, target_track, target_track_idx)
  
  if routing_option_type_choice == "send" then
    reaper.CreateTrackSend(selected_track, target_track)
    
    if _routing_settings_objs and _routing_settings_objs.all_values then
      applyRoutingSettings(selected_track, routing_option_type_choice, target_track, target_track_idx)
    end

  elseif routing_option_type_choice == "receive" then
    reaper.CreateTrackSend(target_track, selected_track)
    
    if _routing_settings_objs and _routing_settings_objs.all_values then
      applyRoutingSettings(target_track, routing_option_type_choice, selected_track, target_track_idx)
    end
  end
end


function applyRoutingSettings(src_track, routing_option_type_choice, dest_track, target_track_idx)
  local routing_settings_api_objs_converted_names, src_track_routing_count, is_pan_law

  routing_settings_api_objs_converted_names = getRoutingSettingsAPIObjsConvertedNames()
  src_track_routing_count = reaper.GetTrackNumSends(src_track, 0)

  for routing_setting_idx = 1, 14 do
    is_pan_law = routing_setting_idx == 6

    if is_pan_law then
      goto skip_to_next
    end

    processRoutingSetting(routing_setting_idx, routing_settings_api_objs_converted_names, src_track, dest_track, src_track_routing_count, target_track_idx)

    ::skip_to_next::
  end
end


function getRoutingSettingsAPIObjsConvertedNames()
  local routing_settings_api_objs_converted_names, routing_settings_api_obj_names

  routing_settings_api_objs_converted_names = {}

  for i = 1, 14 do
    routing_settings_api_obj_names = {"mute", "phase", "mono_stereo", "volume", "pan", "pan_law", "send_mode", "audio_src_channel", "audio_rcv_channel",  "midi_src",  "midi_rcv",  "midi_src",  "midi_rcv",  "midi_velpan"}
    routing_settings_api_objs_converted_names[_api_all_routing_settings[i]] = routing_settings_api_obj_names[i]
  end

  return routing_settings_api_objs_converted_names
end


function processRoutingSetting(routing_setting_idx, routing_settings_api_objs_converted_names, src_track, dest_track, dest_track_routing_count, target_track_idx)
  local is_volume, is_midi_channel, is_midi_rcv_channel, is_midi_bus, this_api_routing_setting, this_routing_obj_name, this_routing_obj_value, this_user_routing_setting_value

  is_volume = routing_setting_idx == 4
  is_midi_channel = routing_setting_idx == 10 or routing_setting_idx == 11
  is_midi_rcv_channel = routing_setting_idx == 11
  is_midi_bus = routing_setting_idx == 12 or routing_setting_idx == 13
  this_api_routing_setting = _api_all_routing_settings[routing_setting_idx]
  this_routing_obj_name = routing_settings_api_objs_converted_names[this_api_routing_setting]
  this_routing_obj_value = _routing_settings_objs.all_values[this_routing_obj_name]

  if is_volume then
    this_user_routing_setting_value = getAPIVolume(this_routing_obj_value)

  elseif is_midi_channel then
    this_user_routing_setting_value = stripOutMidiData(this_routing_obj_value, "bus")

    if is_midi_rcv_channel then
      this_user_routing_setting_value = incrementSrcChannels("midi", this_user_routing_setting_value, target_track_idx)
    end
  
  elseif is_midi_bus then
    this_user_routing_setting_value = stripOutMidiData(this_routing_obj_value, "channel")

  else
    this_user_routing_setting_value = processAudioRoutingSetting(routing_setting_idx, this_routing_obj_value, target_track_idx, src_track, dest_track)
  end

  reaper.BR_GetSetTrackSendInfo(src_track, _api_routing_types.send, dest_track_routing_count-1, this_api_routing_setting, 1, this_user_routing_setting_value)
end


function stripOutMidiData(val, channel_or_bus)
  local data_to_strip

  if channel_or_bus == "channel" then
    data_to_strip = _regex_routing_midi_channel

  elseif channel_or_bus == "bus" then
    data_to_strip = _regex_routing_midi_bus
  end

  return string.gsub(val, data_to_strip, "")
end


function processAudioRoutingSetting(routing_setting_idx, this_routing_obj_value, target_track_idx, src_track, dest_track)
  local is_audio_channel, is_audio_src_channel, this_user_routing_setting_value

  is_audio_channel = routing_setting_idx == 8 or routing_setting_idx == 9
  is_audio_src_channel = routing_setting_idx == 8
  this_user_routing_setting_value = this_routing_obj_value

  if is_audio_channel then

    if is_audio_src_channel then
      this_user_routing_setting_value = incrementSrcChannels("audio", this_user_routing_setting_value, target_track_idx)
    end

    createRequiredAudioChannels(routing_setting_idx, this_user_routing_setting_value, src_track, dest_track)
  end

  return this_user_routing_setting_value
end


function incrementSrcChannels(midi_or_audio, this_user_routing_setting_value, target_track_idx)
  local audio_channel_type, num_to_increment_by, incrementing_enabled, max_audio_channels_are_exceeded

  this_user_routing_setting_value = tonumber(this_user_routing_setting_value)

  if midi_or_audio == "midi" then
    num_to_increment_by = target_track_idx - 1
    incrementing_enabled = _routing_settings_objs.midi_incrementing.value

  elseif midi_or_audio == "audio" then
    audio_channel_type = getAudioChannelValueType(this_user_routing_setting_value)
  
    if audio_channel_type == "stereo" then
      num_to_increment_by = (target_track_idx * 2) - 2

    elseif audio_channel_type == "mono" then
      num_to_increment_by = target_track_idx - 1
    end

    incrementing_enabled = _routing_settings_objs.audio_incrementing.value
  end

  if incrementing_enabled then
    this_user_routing_setting_value = this_user_routing_setting_value + num_to_increment_by

    if midi_or_audio == "midi" and this_user_routing_setting_value > 16 then
      this_user_routing_setting_value = 16

    elseif midi_or_audio == "audio" then
      this_user_routing_setting_value = checkEnoughAudioChannelsAreAvailable(this_user_routing_setting_value)
    end
  end

  return this_user_routing_setting_value
end


function getAudioChannelValueType(val)

  if val >= _api_stereo_channel_base and val < _reaper_max_track_channels then
    return "stereo"

  elseif val >= _api_mono_channel_base and val < (_api_mono_channel_base + _reaper_max_track_channels) then

    return "mono"
  end
end


function createRequiredAudioChannels(routing_setting_idx, this_user_routing_setting_value, src_track, dest_track)
  local is_src_channel, is_dest_channel, audio_channel_type, target_track, current_track_channel_count, required_track_channel_count, track_needs_more_channels

  is_src_channel = routing_setting_idx == 8
  is_dest_channel = routing_setting_idx == 9
  audio_channel_type = getAudioChannelValueType(this_user_routing_setting_value)

  if is_src_channel then
    target_track = src_track

  elseif is_dest_channel then
    target_track = dest_track
  end

  current_track_channel_count = reaper.GetMediaTrackInfo_Value(target_track, "I_NCHAN")
  required_track_channel_count = getRequiredTrackChannelCount(audio_channel_type, this_user_routing_setting_value)
  track_needs_more_channels = required_track_channel_count > current_track_channel_count

  if track_needs_more_channels then
    reaper.SetMediaTrackInfo_Value(target_track, "I_NCHAN", required_track_channel_count)
  end
end


function getRequiredTrackChannelCount(audio_channel_type, this_user_routing_setting_value)
  local required_track_channel_count = 2

  if audio_channel_type == "stereo" then
    required_track_channel_count = this_user_routing_setting_value

  elseif audio_channel_type == "mono" then
    required_track_channel_count = this_user_routing_setting_value - _api_mono_channel_base
  end

  return required_track_channel_count
end


function checkEnoughAudioChannelsAreAvailable(routing_setting_value)
  local track_is_stereo, track_is_mono, incrementing_exceeds_available_audio_channels

  track_is_stereo = routing_setting_value < _api_mono_channel_base
  track_is_mono = routing_setting_value >= _api_mono_channel_base and routing_setting_value < _api_4channel_base

  if track_is_stereo then
    incrementing_exceeds_available_audio_channels = routing_setting_value >= _reaper_max_track_channels

  elseif track_is_mono then
    incrementing_exceeds_available_audio_channels = routing_setting_value >= _api_mono_channel_base + _reaper_max_track_channels

-- ADD MULTICHANNEL CASE HERE

  end

  if incrementing_exceeds_available_audio_channels then

    if track_is_stereo then
      routing_setting_value = _reaper_max_track_channels - 2

    elseif track_is_mono then
      routing_setting_value = _api_mono_channel_base + _reaper_max_track_channels - 1

  -- ADD MULTICHANNEL CASE HERE TOO

    end

    _enough_audio_channels_are_available = false
  end

  return routing_setting_value
end


function removeRouting(routing_option_type_choice, selected_track, target_track)
  local this_track_dest, this_track_src, buss_driven

  buss_driven = false

  if routing_option_type_choice == "send" then

    for i = 0, reaper.GetTrackNumSends(selected_track, 0)-1 do
      this_track_dest = reaper.GetTrackSendInfo_Value(selected_track, 0, i, "P_DESTTRACK")

      if this_track_dest == target_track then
        reaper.RemoveTrackSend(selected_track, 0, i)

        buss_driven = true
      end
    end

  elseif routing_option_type_choice == "receive" then

    for i = 0, reaper.GetTrackNumSends(selected_track, -1)-1 do
      this_track_src = reaper.GetTrackSendInfo_Value(selected_track, -1, i, "P_SRCTRACK")

      if this_track_src == target_track then
        reaper.RemoveTrackSend(selected_track, -1, i)

        buss_driven = true
      end
    end
  end

  return buss_driven
end


function populateRoutingOptionsWindow()
  _routing_options_objs.selected_tracks_box:add(_routing_options_objs.selected_tracks_heading)
  _routing_options_objs.selected_tracks_box:add(_routing_options_objs.selected_tracks_list)
  _routing_options_objs.addremove_wrapper:add(_routing_options_objs.add_checkbox)
  _routing_options_objs.addremove_wrapper:add(_routing_options_objs.remove_checkbox)
  _routing_options_objs.type_wrapper:add(_routing_options_objs.send_checkbox)
  _routing_options_objs.type_wrapper:add(_routing_options_objs.receive_checkbox)
  _routing_options_objs.action_sentence:add(_routing_options_objs.action_text_start)
  _routing_options_objs.action_sentence:add(_routing_options_objs.addremove_wrapper)
  _routing_options_objs.action_sentence:add(_routing_options_objs.type_wrapper)
  _routing_options_objs.action_sentence:add(_routing_options_objs.action_text_end)
  _routing_options_objs.action_sentence_wrapper:add(_routing_options_objs.action_sentence)
  _routing_options_objs.form_fields:add(_routing_options_objs.action_sentence_wrapper)
  _routing_options_objs.form_fields:add(_routing_options_objs.select_all_tracks)
  _routing_options_objs.form_fields:add(_routing_options_objs.target_tracks_subheading)
  _routing_options_objs.form_fields:add(_routing_options_objs.target_tracks_box)
  _routing_options_objs.save_options_wrapper:add(_routing_options_objs.save_options)
  _routing_options_objs.form_buttons:add(_routing_options_objs.form_submit)
  _routing_options_objs.form_buttons:add(_routing_options_objs.form_cancel)
  _routing_options_objs.reset_wrapper:add(_routing_options_objs.reset_btn)
  _routing_options_objs.form_bottom:add(_routing_options_objs.save_options_wrapper, {halign = "left"})
  _routing_options_objs.form_bottom:add(_routing_options_objs.form_buttons, {halign = "center"})
  _routing_options_objs.form_bottom:add(_routing_options_objs.reset_wrapper, {halign = "right"})
  _routing_options_objs.content:add(_routing_options_objs.selected_tracks_box)
  _routing_options_objs.content:add(_routing_options_objs.form_fields)
  _routing_options_objs.content:add(_routing_options_objs.form_bottom)
  _routing_options_objs.viewport:attr("child", _routing_options_objs.content)
  _routing_options_objs.viewport:reflow()
  _routing_options_objs.configure_btn_wrapper:add(_routing_options_objs.configure_btn)
  _routing_options_objs.brand:add(_routing_options_objs.title)
  _routing_options_objs.brand:add(_routing_options_objs.logo)
  _routing_options_objs.window:add(_routing_options_objs.configure_btn_wrapper)
  _routing_options_objs.window:add(_routing_options_objs.brand)
  _routing_options_objs.window:add(_routing_options_objs.viewport)
end


function initBussDriver()
  if _selected_tracks_count > 0 then
    launchBussDriverDialog()
  end
end

initBussDriver()
