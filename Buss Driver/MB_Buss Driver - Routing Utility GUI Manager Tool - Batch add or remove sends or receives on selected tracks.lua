-- @description MB_Buss Driver - Batch add or remove send(s) or receive(s) on selected track(s)
-- @author MonkeyBars
-- @version 2.6.2
-- @changelog Replace more simple condition assignments with short-circuit evaluations
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


-- Copyright (C) MonkeyBars 2024
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your routing_option) any later version.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.


-- ==== MB_BUSS DRIVER SCRIPT ARCHITECTURE NOTES ====
-- MB_Buss Driver uses the great GUI library Reaper Toolkit (rtk). (https://reapertoolkit.dev/)
-- MB_Buss Driver uses Serpent, a serialization library for LUA, for table-string and string-table conversion. (https://github.com/pkulchenko/serpent)


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"

-- for dev only
-- require("mb-dev-functions")


local rtk = require("rtk")
local serpent = require("serpent")


rtk.set_theme_overrides({
  tooltip_font = {"Segoe UI (TrueType)", 13}
})


local _regex = {

  routing = {

    midi = {
      channel = "/%-?%d+",
      bus = "%-?%d+/"
    }
  }
}


local _unicode = {
  right_arrow = "\u{2192}",
  left_arrow = "\u{2190}"
}


local _api = {
  current_project = 0,
  msg_type_ok = 0,

  channels = {
    mono_base = 1024,

    src = {

      stereo = {
        default = 0
      },

      multichannel = {
        base = 2048,
        addl = 1024
      }
    },

    dest = {
      default = 0
    },

    midi = {
      max_value = 16
    }
  },

  routing = {
    
    param = {
      src_track = "P_SRCTRACK",
      dest_track = "P_DESTTRACK"
    },

    category = {
      receive = -1,
      send = 0
    },

    set_new_value = 1
  },

  track = {
    channel_count = "I_NCHAN",
    icon = "P_ICON",
    num = "IP_TRACKNUMBER",
    name = "P_NAME"
  },
  
  all_routing_settings = {"B_MUTE", "B_PHASE", "B_MONO", "D_VOL", "D_PAN", "D_PANLAW", "I_SENDMODE", "I_SRCCHAN", "I_DSTCHAN", "I_MIDI_SRCCHAN", "I_MIDI_DSTCHAN", "I_MIDI_SRCBUS", "I_MIDI_DSTBUS", "I_MIDI_LINK_VOLPAN"}
}


local _constant = {

  brand = {
    script = "MB_Buss Driver",
    script_ext_name = "MB_Buss-Driver",
    save_options_key_name = "save_options"
  },

  path = {
    logo_img = "bussdriver_logo_nobg.png"
  },

  default_routing_settings_values = {
    mute = 0,
    phase = 0,
    mono_stereo = 0,
    send_mode = 0,
    volume = 2.8285,
    pan = 0,
    midi_velpan = 0,
    audio_src_channel = 0,
    audio_dest_channel = 0,
    midi_src = "0/0",
    midi_dest = "0/0"
  },

  reaper_max_track_channels = 128,
  selected_tracks_count = reaper.CountSelectedTracks(_api.current_project),
  configure_btn_rendered_height = 19
}


local _state = {
  enough_audio_channels_are_available = true,

  tracks = {
    all = nil,
    selected = nil,

    selected = {
      current_idx = nil
    },

    target = {
      current_idx = nil
    }
  },

  routing = {
    newly_created_idx = nil,
    
    option_choice = {
      action = nil,
      type = nil
    },

    options_objs = nil,
    settings_objs = nil
  }
}




function storeRetrieveProjectData(key, val)
  local retrieve, store, retval, state_data_val

  retrieve = not val
  store = val

  if retrieve then
    retval, state_data_val = reaper.GetProjExtState(_api.current_project, _constant.brand.script_ext_name, key)

  elseif store then
    reaper.SetProjExtState(_api.current_project, _constant.brand.script_ext_name, key, val)
  end

  return state_data_val
end


function toggleSaveOptions(initialize)
  local current_save_options_setting, save_options_checkbox_value, new_option_val

  if initialize == "initialize" then
    current_save_options_setting = storeRetrieveProjectData(_constant.brand.save_options_key_name)

    if current_save_options_setting == "" or not current_save_options_setting then
      storeRetrieveProjectData(_constant.brand.save_options_key_name, "true")
    end

  else
    save_options_checkbox_value = _state.routing.options_objs.save_options.value
    new_option_val = save_options_checkbox_value and "true" or "false"

    storeRetrieveProjectData(_constant.brand.save_options_key_name, new_option_val)
  end
end

toggleSaveOptions("initialize")



function getSelectedTracks()
  local selected_tracks, this_selected_track

  selected_tracks = {}

  for i = 0, _constant.selected_tracks_count-1 do
    this_selected_track = reaper.GetSelectedTrack(_api.current_project, i)

    table.insert(selected_tracks, this_selected_track)
  end

  return selected_tracks
end

_state.tracks.selected = getSelectedTracks(_constant.selected_tracks_count)



function storeRetrieveAllTracksCount(val)
  local store, retrieve, stored_tracks_count_on_open, all_tracks_count

  store = val
  retrieve = not val

  if store then
    storeRetrieveProjectData("all_tracks_count", val)

  elseif retrieve then
    stored_tracks_count_on_open = storeRetrieveProjectData("all_tracks_count")

    if not stored_tracks_count_on_open or stored_tracks_count_on_open == "" then
      all_tracks_count = reaper.CountTracks(_api.current_project)

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
  defineRoutingOptionsEventHandlers()
  setUpRadioCheckboxHandlers()
  _state.routing.options_objs.window:open()
  storeRetrieveUserOptions("retrieve")
  propagateSavedUserOptions()
end


function getRoutingOptionsObjects()

  _state.routing.options_objs = {
    window = rtk.Window{title = _constant.brand.script .. " - Batch add or remove sends or receives on selected tracks", w = 0.4, maxh = rtk.Attribute.NIL},
    viewport = rtk.Viewport{halign = "center", bpadding = 5},
    brand = rtk.VBox{halign = "center", padding = "2 2 1", border = "1px #878787", bg = "#505050"},
    title = rtk.Heading{"Buss Driver", fontscale = "0.6"},
    logo = rtk.ImageBox{rtk.Image():load(_constant.path.logo_img), w = 47, halign = "center", margin = "1 0"},
    configure_btn_wrapper = rtk.Container{w = 1, halign = "right", margin = "5 3 0 0"},
    configure_btn = rtk.Button{label = "Configure send settings", tooltip = "Pop up routing settings to be applied to all sends or receives created", h = _constant.configure_btn_rendered_height, padding = "4 5 6", fontscale = 0.67},
    content = rtk.VBox{halign = "center", padding = "10 0 0"},
    selected_tracks_box = rtk.VBox{maxw = 0.67, halign = "center", padding = "4 6 2", border = "1px #555555"},
    selected_tracks_heading = rtk.Text{"Selected track(s)", bmargin = 4, fontscale = 0.8, fontflags = rtk.font.UNDERLINE, color = "#D6D6D6"},
    selected_tracks_list = getSelectedTracksList(),
    action_sentence_wrapper = rtk.Container{w = 1, halign = "center"},
    action_sentence = rtk.HBox{valign = "center", tmargin = 9},
    action_text_start = rtk.Text{"I want to "},
    addremove_wrapper = rtk.VBox{margin = "0 5"},
    add_checkbox = rtk.CheckBox{"add +", h = 17, fontscale = 0.925, margin = "0 5 1 2", padding = "0 2 3 2", spacing = 3, valign = "center", value = true, ref = "add_checkbox"},
    remove_checkbox = rtk.CheckBox{"remove -", h = 17, fontscale = 0.925, margin = "0 5 1 2", padding = "0 2 3 2", spacing = 3, valign = "center", ref = "remove_checkbox"},
    type_wrapper = rtk.VBox{rmargin = 5},
    send_checkbox = rtk.CheckBox{"sends" .. _unicode.right_arrow, h = 17, fontscale = 0.925, margin = "0 5 1 2", padding = "0 2 3 2", spacing = 3, valign = "center", value = true, ref = "send_checkbox"},
    receive_checkbox = rtk.CheckBox{"receives" .. _unicode.left_arrow, h = 17, fontscale = 0.925, margin = "0 5 1 2", padding = "0 2 3 2", spacing = 3, valign = "center", ref = "receive_checkbox"},
    action_text_end = rtk.Text{" to the selected tracks."},
    select_all_tracks = rtk.CheckBox{"Select/deselect all tracks", position = "absolute", h = 18, tmargin = 21, padding = "1 2 3", border = "1px #555555", spacing = 3, valign = "center", fontscale = 0.75, color = "#bbbbbb", textcolor2 = "#bbbbbb", ref = "select_all_tracks"},
    target_tracks_subheading = rtk.Text{"Which tracks do you want the new sends to send to?", w = 1, tmargin = 14, fontscale = 0.95, fontflags = rtk.font.BOLD, halign = "center", fontflags = rtk.font.BOLD},
    form_fields = rtk.VBox{padding = "10 10 5", spacing = 10},
    target_tracks_box = populateTargetTracksBox(),
    form_bottom = rtk.Container{w = 1, margin = 10},
    form_buttons = rtk.HBox{spacing = 10},
    save_options_wrapper = rtk.HBox{tmargin = 5},
    save_options = rtk.CheckBox{"Save choices & settings on close", h = 17, padding = "0 2 3 2", spacing = 3, valign = "center", fontscale = 0.67, color = "#bbbbbb", textcolor2 = "#bbbbbb", ref = "save_options_checkbox"},
    form_submit = rtk.Button{"Add", disabled = true},
    form_cancel = rtk.Button{"Cancel"},
    reset_wrapper = rtk.HBox{valign = "center"},
    reset_btn = rtk.Button{"Reset all options", tooltip = "Return all tracks and settings to initial state", padding = "4 5 6", color = "#8A4C00R", fontscale = 0.67, textcolor = "#D6D6D6"}
  }
end


function getSelectedTracksList()
  local selected_tracks_list, this_track, retval, this_track_name, this_track_num, this_track_color

  selected_tracks_list = rtk.FlowBox{hspacing = 10}

  for i = 1, #_state.tracks.selected do
    this_track = _state.tracks.selected[i]
    retval, this_track_name = reaper.GetTrackName(this_track)
    this_track_num = math.tointeger(reaper.GetMediaTrackInfo_Value(this_track, _api.track.num))
    this_track_color = reaper.GetTrackColor(this_track)
    this_track_color = rtk.color.convert_native(this_track_color)
    
    selected_tracks_list:add(rtk.Text{this_track_num .. ": " .. this_track_name, padding = "1 4 3", fontscale = 0.67, color = "#D6D6D6", bg = this_track_color})
  end

  return selected_tracks_list
end


function populateTargetTracksBox()
  local routing_option_target_tracks_box, this_track_line
  
  routing_option_target_tracks_box = rtk.FlowBox{w = 1, tmargin = 7, ref = "routing_option_target_tracks_box"}

  if not _state.tracks.all then
    getAllTracks()
  end

  for i = 1, #_state.tracks.all do
    this_track_line = createTargetTrackLine(_state.tracks.all[i])

    routing_option_target_tracks_box:add(this_track_line)
  end

  return routing_option_target_tracks_box
end


function getAllTracks()
  _state.tracks.all = {}

  for i = 0, _all_tracks_count_on_launch-1 do
    table.insert(_state.tracks.all, reaper.GetTrack(_api.current_project, i))
  end
end


function createTargetTrackLine(this_track)
  local this_track_line, this_track_icon, this_track_color, this_track_checkbox

  this_track_line, this_track_icon, this_track_color, this_track_checkbox = getTrackObjs(this_track)

  if this_track_color ~= 0 then
    this_track_color = rtk.color.convert_native(this_track_color)

    this_track_checkbox:attr("bg", this_track_color)

    this_track_checkbox = correctTrackColor(this_track_checkbox, this_track_color)
  end

  this_track_checkbox.onchange = function(self)
    toggleSubmitButton(self.value)
  end

  this_track_line:add(this_track_icon)
  this_track_line:add(this_track_checkbox)
  
  return this_track_line
end


function getTrackObjs(this_track)
  local this_track_line, retval, this_track_icon_path, this_track_icon, this_track_num, this_track_name, this_track_color, this_track_checkbox

  this_track_line = rtk.HBox{valign = "center", data__class = "target_track_line"}
  retval, this_track_icon_path = reaper.GetSetMediaTrackInfo_String(this_track, _api.track.icon, "", false)
  this_track_icon = rtk.ImageBox{rtk.Image():load(this_track_icon_path), w = 18, minw = 18}
  this_track_num = math.tointeger(reaper.GetMediaTrackInfo_Value(this_track, _api.track.num))
  retval, this_track_name = reaper.GetSetMediaTrackInfo_String(this_track, _api.track.name, "", 0)
  this_track_color = reaper.GetTrackColor(this_track)
  this_track_checkbox = rtk.CheckBox{this_track_num .. ": " .. this_track_name, h = 17, fontscale = 0.75, margin = "0 5 1 2", padding = "0 2 3 2", spacing = 3, valign = "center", ref = "target_track_" .. this_track_num, data__class = "target_track_checkbox"}
  this_track_line.data__track_is_selected = reaper.IsTrackSelected(this_track)
  this_track_line.data__track_num = reaper.GetMediaTrackInfo_Value(this_track, _api.track.num)
  this_track_line.data__track_guid = reaper.BR_GetMediaTrackGUID(this_track)

  return this_track_line, this_track_icon, this_track_color, this_track_checkbox
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
  local is_color_dark = rgb < 3 * 256 / 2

  return is_color_dark
end


function toggleSubmitButton(checkbox_val)
  local no_target_tracks_are_selected

  if checkbox_val then
    disableSubmitButton(false)

  else
    getCurrentTargetTrackChoices()

    no_target_tracks_are_selected = #_state.routing.options_objs.target_track_choices < 1
    
    if no_target_tracks_are_selected then
      disableSubmitButton(true)
    end
  end
end


function disableSubmitButton(disable)
  _state.routing.options_objs.form_submit:attr("disabled", disable)
end


function defineRoutingOptionsEventHandlers()

  _state.routing.options_objs.window.onblur = function(self)
    self:close()
  end

  _state.routing.options_objs.window.onclose = function()
    storeRetrieveUserOptions("store")
    restoreUserSelectedTracks()
    storeRetrieveAllTracksCount("")
  end

  _state.routing.options_objs.configure_btn.onclick = function()
    launchRoutingSettings()
  end

  _state.routing.options_objs.select_all_tracks.onchange = function(self)
    selectDeselectAllTargetTracks(self.value)
  end

  _state.routing.options_objs.save_options.onchange = function()
    toggleSaveOptions()
  end

  _state.routing.options_objs.form_submit.onclick = function()
    submitRoutingOptionChanges()
  end
  
  _state.routing.options_objs.form_cancel.onclick = function()
    _state.routing.options_objs.window:close()
  end

  _state.routing.options_objs.reset_btn.onclick = function()
    selectDeselectAllTargetTracks(false)
    populateRoutingSettingsFormValues("reset")
    disableSubmitButton(true)
  end
end


function storeRetrieveUserOptions(store_retrieve)
  local retval, current_save_options_setting, all_user_options

  retval, current_save_options_setting = reaper.GetProjExtState(_api.current_project, _constant.brand.script_ext_name, _constant.brand.save_options_key_name)

  if current_save_options_setting == "true" then

    if store_retrieve == "store" then
      all_user_options = getSetMainActionChoices("get")

      getCurrentTargetTrackChoices()

      all_user_options.target_track_choices = _state.routing.options_objs.target_track_choices

      if _state.routing.settings_objs and _state.routing.settings_objs.all_values then
        all_user_options.routing_settings = _state.routing.settings_objs.all_values
      end

      all_user_options = serpent.dump(all_user_options)

      storeRetrieveProjectData("all_user_options", all_user_options)

    elseif store_retrieve == "retrieve" then
      all_user_options = storeRetrieveProjectData("all_user_options")
      retval, all_user_options = serpent.load(all_user_options)
      _state.routing.options_objs.all_user_options = all_user_options
    end

  elseif current_save_options_setting == "false" and 
    store_retrieve == "retrieve" then
    
    showHideTargetTrackLines(_state.routing.options_objs.target_tracks_box.children, "hide", "selected")
  end
end


function propagateSavedUserOptions()
  local retval, current_save_options_setting

  retval, current_save_options_setting = reaper.GetProjExtState(_api.current_project, _constant.brand.script_ext_name, _constant.brand.save_options_key_name)

  if current_save_options_setting == "true" then
    _state.routing.options_objs.save_options:attr("value", true)

    if _state.routing.options_objs and _state.routing.options_objs.all_user_options then
      getSetMainActionChoices("set")

      if _state.routing.options_objs.all_user_options.target_track_choices then

        if #_state.routing.options_objs.all_user_options.target_track_choices > 0 then
          setTargetTrackChoices(_state.routing.options_objs.all_user_options.target_track_choices)
        end
      end

      if _state.routing.options_objs.all_user_options.routing_settings then

        if not _state.routing.settings_objs then
          initRoutingSettings()
        end

        _state.routing.settings_objs.all_values = _state.routing.options_objs.all_user_options.routing_settings

        getSetRoutingSettingsValues("set", _state.routing.settings_objs.all_values)
      end
    end

  elseif current_save_options_setting == "false" then
    _state.routing.options_objs.save_options:attr("value", false)
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

      main_action_choices[this_checkbox_name] = _state.routing.options_objs[this_checkbox_name].value
    end

    return main_action_choices

  elseif get_set == "set" then

    for i = 1, #checkbox_labels do
      this_checkbox_name = checkbox_labels[i] .. checkbox_string_suffix

      _state.routing.options_objs[this_checkbox_name]:attr("value", false)

      if _state.routing.options_objs.all_user_options[this_checkbox_name] then
        _state.routing.options_objs[this_checkbox_name]:attr("value", _state.routing.options_objs.all_user_options[this_checkbox_name])
      end
    end

    updateRoutingForm("is_action_change")
  end
end


function restoreUserSelectedTracks()

  for i = 1, #_state.tracks.selected do
    reaper.SetTrackSelected(_state.tracks.selected[i], true)
  end
end


function setUpRadioCheckboxHandlers()
  local checkbox_sets = {
    {"add_checkbox", "remove_checkbox"},
    {"send_checkbox", "receive_checkbox"}
  }

  for i = 1, #checkbox_sets do
    populateRadioCheckboxHandlers(checkbox_sets[i][1], checkbox_sets[i][2])
    populateRadioCheckboxHandlers(checkbox_sets[i][2], checkbox_sets[i][1])
  end
end


function populateRadioCheckboxHandlers(checkbox1, checkbox2)
  _state.routing.options_objs[checkbox1].onclick = function()

    _state.routing.options_objs[checkbox1].onchange = function()
      _state.routing.options_objs[checkbox2]:toggle()
      updateRoutingForm("is_action_change")

      _state.routing.options_objs[checkbox1].onchange = nil
    end
  end
end


function updateRoutingForm(is_action_change)
  local routing_action, routing_type, target_tracks_subheading_text_intro, target_tracks_subheading_routing_action_text, type_preposition, action_preposition, action_text_end, new_target_tracks_subheading_text

  selectDeselectAllTargetTracks(false)

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

  _state.routing.options_objs.target_tracks_subheading:attr("text", new_target_tracks_subheading_text)
  _state.routing.options_objs.configure_btn:attr("label", "Configure " .. routing_type .. " settings")
  _state.routing.options_objs.action_text_end:attr("text", action_text_end)
  updateButtons(routing_action, is_action_change, routing_type)
end


function getRoutingChoices()
  local routing_action, routing_type

  if _state.routing.options_objs.add_checkbox.value == true then
    routing_action = "add"

  elseif _state.routing.options_objs.remove_checkbox.value == true then
    routing_action = "remove"
  end

  if _state.routing.options_objs.send_checkbox.value == true then
    routing_type = "send"

  elseif _state.routing.options_objs.receive_checkbox.value == true then
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
  local configure_btn_height, routing_options_submit_btn_text

  if is_action_change == "is_action_change" then

    if routing_action == "add" then
      configure_btn_height = _constant.configure_btn_rendered_height
      routing_options_submit_btn_text = "Add"
    
    elseif routing_action == "remove" then
      configure_btn_height = 0
      routing_options_submit_btn_text = "Remove"
    end

    updateTargetTrackDisplay(routing_action, selected_routing_type)
    _state.routing.options_objs.configure_btn:animate{"h", dst = configure_btn_height, duration = 0.33}
    _state.routing.options_objs.form_submit:attr("label", routing_options_submit_btn_text)
  end
end


function updateTargetTrackDisplay(routing_action, selected_routing_type)
  local target_track_lines, this_track, api_routing_category, api_routing_param, this_track_routing_count, this_routing_track, this_routing_track_guid

  target_track_lines = _state.routing.options_objs.target_tracks_box.children

  if routing_action == "add" then
    showHideTargetTrackLines(target_track_lines, "show", "all")
    showHideTargetTrackLines(target_track_lines, "hide", "selected")
    setTargetTrackChoices(_state.routing.options_objs.saved_target_track_choices)

  elseif routing_action == "remove" then
    showHideTargetTrackLines(target_track_lines, "hide", "all")

    for i = 1, #_state.tracks.selected do
      this_track = _state.tracks.selected[i]
      api_routing_category, api_routing_param = getRoutingValues(selected_routing_type)
      this_track_routing_count = reaper.GetTrackNumSends(this_track, api_routing_category)

      for j = 0, this_track_routing_count-1 do
        this_routing_track = reaper.GetTrackSendInfo_Value(this_track, api_routing_category, j, api_routing_param)
        this_routing_track_guid = reaper.BR_GetMediaTrackGUID(this_routing_track)

        showTargetTrackWithMatchingRouting(this_routing_track_guid)
      end
    end
  end
end


function showHideTargetTrackLines(target_track_lines, show_hide, which_tracks)
  local this_track_line

  for i = 1, #target_track_lines do
    this_track_line = target_track_lines[i][1]

    if which_tracks == "selected" then

      if not this_track_line.data__track_is_selected then

        goto skip_to_next
      end
    end

    if show_hide == "show" then
      this_track_line:show()

    elseif show_hide == "hide" then
      this_track_line:hide()
    end

    ::skip_to_next::
  end

  return target_track_lines
end


function getRoutingValues(selected_routing_type)
  local api_routing_category, api_routing_param

  if selected_routing_type == "send" then
    api_routing_category = _api.routing.category.send
    api_routing_param = _api.routing.param.dest_track

  elseif selected_routing_type == "receive" then
    api_routing_category = _api.routing.category.receive
    api_routing_param = _api.routing.param.src_track
  end

  return api_routing_category, api_routing_param
end


function showTargetTrackWithMatchingRouting(this_routing_track_guid)
  local this_track_line, this_track_line_matches_current_track

  for i = 1, #_state.routing.options_objs.target_tracks_box.children do
    this_track_line = _state.routing.options_objs.target_tracks_box:get_child(i)

    if this_track_line then
      this_track_line_matches_current_track = this_track_line.data__track_guid == this_routing_track_guid

      if this_track_line_matches_current_track then
        this_track_line:show()

        break
      end
    end
  end
end


function launchRoutingSettings()
  
  if not _state.routing.settings_objs then
    initRoutingSettings()
  end

  _state.routing.settings_objs.popup:open()
end


function initRoutingSettings()
  populateRoutingSettingsObjs()
  gatherRoutingSettingsFormFields()
  setRoutingSettingsPopupEventHandlers()
  populateRoutingSettingsFormValues()
  populateRoutingSettingsPopup()
  setRoutingSettingsFormEventHandlers()
  populateAudioDestChannelDefaultOptions()
end


function populateRoutingSettingsObjs()
  local audio_channel_src_options, midi_channel_src_options, midi_channel_dest_options

  audio_channel_src_options = defineAudioSrcChannelOptions()
  midi_channel_src_options, midi_channel_dest_options = defineMIDIChannelOptions()

  _state.routing.settings_objs = {
    popup = rtk.Popup{w = _state.routing.options_objs.window.w / 3, minw = 341, overlay = "#303030cc", padding = 0},
    content = rtk.VBox(),
    close_btn = rtk.Button{"X", position = "absolute", z = 10, w = 14, h = 16, margin = "4 0 0 4", padding = 2, color = "#555555", halign = "center", fontscale = 0.7, textcolor = "#BBBBBB"},
    title = rtk.Heading{"Configure settings for routing to be added", w = 1, halign = "center", padding = 6, bg = "#777777", fontscale = 0.67},
    form = rtk.VBox{padding = "20 10 10"},
    row1 = rtk.HBox(),
    volume_val = rtk.Text{"+0.00", w = 45, h = 19, padding = 3, border = "1px #777888", fontscale = 0.63},
    pan_val = rtk.Text{"center", w = 35, h = 19, valign = "center", halign = "center", lmargin = 5, padding = 3, border = "1px #777888", fontscale = 0.63},
    mute = rtk.Button{icon = "table_mute_off", w = 23, h = 20, lmargin = 5, padding = 0, surface = false, tooltip = "Mute", data__class = "routing_setting_field"},
    phase = rtk.Button{icon = "gen_phase_off", w = 10, h = 10, tooltip = "Reverse phase", margin = "4 0 0 5", padding = 0, circular = true, data__class = "routing_setting_field"},
    mono_stereo = rtk.Button{icon = "gen_mono_off", w = 23, h = 20, tooltip = "Mono/Stereo", lmargin = 5, padding = 0, surface = false, data__class = "routing_setting_field"},
    send_mode = rtk.OptionMenu{menu = {
        {"Postfader (Post-Pan)", id = 0},
        {"Prefader (Post-FX)", id = 3},
        {"PreX", id = 1}
      }, h = 20, margin = "-1 0 0 2", padding = "0 0 4 4", spacing = 6, fontscale = 0.63, data__class = "routing_setting_field"},
    row2 = rtk.HBox{tmargin = 8},
    volume = rtk.Slider{"0.0", tooltip = "Volume", min = 0, max = 4, tmargin = 8, color = "orange", data__class = "routing_setting_field"},
    pan = rtk.Slider{tooltip = "Pan", min = -1, max = 1, tmargin = 8, color = "lightgreen", data__class = "routing_setting_field"},
    --pan_law = rtk.Slider{tooltip = "Pan Law", tmargin = 8},
    midi_velpan = rtk.Button{icon = "gen_midi_off", valign = "center", surface = false, tooltip = "Toggle Midi Volume/Pan", data__class = "routing_setting_field"},
    row3 = rtk.HBox{tmargin = 8},
    audio_block = rtk.VBox(),
    audio_channels = rtk.HBox{spacing = 3, valign = "center"},
    audio_txt = rtk.Text{"Audio:", bmargin = "2", fontscale = 0.63},
    audio_src_channel = rtk.OptionMenu{menu = audio_channel_src_options, h = 20, margin = "-1 0 0 2", padding = "0 0 4 4", spacing = 6, fontscale = 0.63, data__class = "routing_setting_field", ref = "audio_src_channel"},
    audio_dest_channel = rtk.OptionMenu{h = 20, margin = "-1 0 0 2", padding = "0 0 4 4", spacing = 6, fontscale = 0.63, data__class = "routing_setting_field", ref = "audio_dest_channel"},
    audio_incrementing = rtk.CheckBox{"Increment audio source channels up", spacing = 2, fontscale = 0.63, valign = "center", data__class = "routing_setting_field"},
    midi_block = rtk.VBox{margin = "0 0 2 5", lpadding = 7, lborder = "1px #676767"},
    midi_channels = rtk.HBox{spacing = 3, valign = "center"},
    midi_txt = rtk.Text{"MIDI:", fontscale = 0.63},
    midi_src = rtk.OptionMenu{menu = midi_channel_src_options, h = 20, margin = "-1 0 0 2", padding = "0 0 4 4", spacing = 6, fontscale = 0.63, ref = "midi_src", data__class = "routing_setting_field"},
    midi_dest = rtk.OptionMenu{menu = midi_channel_dest_options, h = 20, margin = "-1 0 0 2", padding = "0 0 4 4", spacing = 6, fontscale = 0.63, ref = "midi_dest", data__class = "routing_setting_field"},
    midi_incrementing = rtk.CheckBox{"Increment MIDI destination channels up", spacing = 2, fontscale = 0.63, valign = "center", data__class = "routing_setting_field", disabled = true}
  }
end


function defineAudioSrcChannelOptions()
  local audio_channel_submenu_mono_options, audio_channel_submenu_stereo_options, audio_channel_all_multichannel_options, audio_channel_src_options

  audio_channel_submenu_mono_options = getAudioChannelSubmenuMonoOrStereoOptions("mono")
  audio_channel_submenu_stereo_options = getAudioChannelSubmenuMonoOrStereoOptions("stereo")
  audio_channel_all_multichannel_options = getAudioChannelSubmenuMultichannelOptions()

  audio_channel_src_options = {
    {"None", id = "-1", data__channel_count = "0"},
    {"Mono source", submenu = audio_channel_submenu_mono_options},
    {"Stereo source", submenu = audio_channel_submenu_stereo_options},
    {
      label = "Multichannel source",
      submenu = audio_channel_all_multichannel_options
    }
  }

  return audio_channel_src_options
end


function getAudioChannelSubmenuMonoOrStereoOptions(mono_or_stereo)
  local audio_channel_submenu_basic_options, last_option_to_create, submenu_audio_channel_selected, submenu_audio_option_label, submenu_audio_option_val, submenu_channel_count

  audio_channel_submenu_basic_options = {}
  last_option_to_create = getLastOptionToCreate(mono_or_stereo)

  for i = 0, last_option_to_create do
    submenu_audio_channel_selected = i + 1
    submenu_audio_option_label, submenu_audio_option_val, submenu_channel_count = getAudioChannelSubmenuOptionInfo(mono_or_stereo, submenu_audio_channel_selected, i)

    audio_channel_submenu_basic_options[submenu_audio_channel_selected] = {
      label = tostring(submenu_audio_option_label),
      id = tostring(submenu_audio_option_val),
      data__channel_count = submenu_channel_count
    }

    if i == last_option_to_create then
      audio_channel_submenu_basic_options[submenu_audio_channel_selected].data__is_highest_option = true
    end
  end

  return audio_channel_submenu_basic_options
end


function getLastOptionToCreate(mono_or_stereo)
  local last_option_to_create

  if mono_or_stereo == "mono" then
    last_option_to_create = _constant.reaper_max_track_channels - 1

  elseif mono_or_stereo == "stereo" then
    last_option_to_create = _constant.reaper_max_track_channels - 2
  end

  return last_option_to_create
end


function getAudioChannelSubmenuOptionInfo(mono_or_stereo, submenu_audio_channel_selected, submenu_option_idx)
  local submenu_audio_option_label, submenu_audio_option_val, submenu_channel_count

  if mono_or_stereo == "mono" then
    submenu_audio_option_label = submenu_audio_channel_selected
    submenu_audio_option_val = _api.channels.mono_base + submenu_option_idx
    submenu_channel_count = 1

  elseif mono_or_stereo == "stereo" then
    submenu_audio_option_label = submenu_audio_channel_selected .. "/" .. submenu_audio_channel_selected + 1
    submenu_audio_option_val = submenu_option_idx
    submenu_channel_count = 2
  end

  return submenu_audio_option_label, submenu_audio_option_val, submenu_channel_count
end


function getAudioChannelSubmenuMultichannelOptions()
  local audio_channel_all_multichannel_options, multichannel_count_options, submenu_audio_channel_selected, audio_channel_submenu_multichannel_subsubmenu_options_label, audio_channel_submenu_multichannel_subsubmenu_options

  audio_channel_all_multichannel_options = {}
  multichannel_count_options = (_constant.reaper_max_track_channels - 2) / 2

  for i = 1, multichannel_count_options do
    submenu_audio_channel_selected = (i + 1) * 2
    audio_channel_submenu_multichannel_subsubmenu_options_label = submenu_audio_channel_selected .. " channels"
    audio_channel_submenu_multichannel_subsubmenu_options = getAudioChannelSubmenuMultichannelSubsubmenuOptions(submenu_audio_channel_selected, i, multichannel_count_options)

    audio_channel_all_multichannel_options[i] = {
      label = audio_channel_submenu_multichannel_subsubmenu_options_label,
      submenu = audio_channel_submenu_multichannel_subsubmenu_options
    }
  end

  return audio_channel_all_multichannel_options
end


function getAudioChannelSubmenuMultichannelSubsubmenuOptions(submenu_audio_channel_selected, multichannel_count_option_idx, multichannel_count_options)
  local multichannel_choices_count, audio_channel_submenu_multichannel_subsubmenu_options, multichannel_option_id_val

  multichannel_choices_count = _constant.reaper_max_track_channels - submenu_audio_channel_selected
  audio_channel_submenu_multichannel_subsubmenu_options = {}

  for i = 0, multichannel_choices_count do
    multichannel_option_id_val = (_api.channels.src.multichannel.addl * (submenu_audio_channel_selected / 2) ) + i

    audio_channel_submenu_multichannel_subsubmenu_options[i+1] = {
      label = (i+1) .. "-" .. (i + submenu_audio_channel_selected),
      id = tostring(multichannel_option_id_val),
      data__channel_count = submenu_audio_channel_selected
    }

    if multichannel_count_option_idx == multichannel_count_options then
      audio_channel_submenu_multichannel_subsubmenu_options[i+1].data__is_highest_option = true
    end
  end

  return audio_channel_submenu_multichannel_subsubmenu_options
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
  local midi_channel_submenu_bus_options, midi_channel_submenu_bus_option_val, midi_channel_src_options, midi_channel_rcv_options

  midi_channel_src_options = {
    {
      label = "None",
      id = -1 .. "/" .. -1
    },
    {
      label = "All",
      id = 0 .. "/" .. 0,
      data__is_highest_option = true
    }
  }

  for i = 3, 18 do
    midi_channel_src_options[i] = {
      label = tostring(i-2),
      id = 0 .. "/" .. i-2
    }

    if i == 18 then
      midi_channel_src_options[i].data__is_highest_option = true
    end
  end

  for i = 19, 34 do
    midi_channel_submenu_bus_options = {
      {
        label = "B" .. i-18,
        id = i-18 .. "/" .. 0
      }
    }

    for j = 1, 16 do
      midi_channel_submenu_bus_option_val = i-18 .. "/" .. j

      midi_channel_submenu_bus_options[j] = {
        label = midi_channel_submenu_bus_option_val,
        id = midi_channel_submenu_bus_option_val
      }

      if j == 16 then
        midi_channel_submenu_bus_options[j].data__is_highest_option = true
      end
    end

    midi_channel_src_options[i] = {
      label = "Bus " .. i-18,
      submenu = midi_channel_submenu_bus_options
    }
  end

  midi_channel_rcv_options = deepTableCopy(midi_channel_src_options)

  table.remove(midi_channel_rcv_options, 1)

  return midi_channel_src_options, midi_channel_rcv_options
end


function gatherRoutingSettingsFormFields()

  if not _state.routing.settings_objs.form_fields then
    _state.routing.settings_objs.form_fields = {}

    for routing_setting_obj_name, routing_setting_obj_value in pairs(_state.routing.settings_objs) do
      
      if routing_setting_obj_value.data__class == "routing_setting_field" then
        _state.routing.settings_objs.form_fields[routing_setting_obj_name] = routing_setting_obj_value
      end
    end
  end
end


function setRoutingSettingsPopupEventHandlers()

  _state.routing.settings_objs.popup.onclose = function()

    if not _state.routing.settings_objs.all_values then
      _state.routing.settings_objs.all_values = {}
    end

    getSetRoutingSettingsValues("get")
  end
  
  _state.routing.settings_objs.popup.onkeypress = function(self, event)
  
    if not event.handled and event.keycode == rtk.keycodes.ESCAPE then
      event:set_handled(self)
      _state.routing.settings_objs.popup:close()
    end
  end
end


function getSetRoutingSettingsValues(get_set, new_routing_settings_values)
  local this_form_field_class, this_field_is_type_value, this_field_is_type_selected, routing_setting_field

  for routing_setting_name, routing_setting_value in pairs(_state.routing.settings_objs.form_fields) do
    this_form_field_class = routing_setting_value.class.name
    this_field_is_type_value = this_form_field_class ~= "rtk.OptionMenu"
    this_field_is_type_selected = this_form_field_class == "rtk.OptionMenu"
    routing_setting_field = _state.routing.settings_objs[routing_setting_name]

    if get_set == "get" then
      getRoutingSettingsValue(this_field_is_type_value, routing_setting_field, this_field_is_type_selected, routing_setting_name)

    elseif get_set == "set" then
      setRoutingSettingsValue(new_routing_settings_values, routing_setting_name, this_field_is_type_value, routing_setting_field, this_field_is_type_selected)
    end
  end
end


function getRoutingSettingsValue(this_field_is_type_value, routing_setting_field, this_field_is_type_selected, routing_setting_name)
  local this_form_field_value

  if this_field_is_type_value then
    this_form_field_value = routing_setting_field.value

  elseif this_field_is_type_selected then
    this_form_field_value = routing_setting_field.selected_id
  end

  _state.routing.settings_objs.all_values[routing_setting_name] = this_form_field_value
end


function setRoutingSettingsValue(new_routing_settings_values, routing_setting_name, this_field_is_type_value, routing_setting_field, this_field_is_type_selected)
  local new_form_field_value

  new_form_field_value = new_routing_settings_values[routing_setting_name]

  if this_field_is_type_value then
    routing_setting_field:attr("value", new_form_field_value)
    
  elseif this_field_is_type_selected then
    routing_setting_field:select(new_form_field_value)
  end

  updateRoutingSettingsBtns()
end



function setRoutingSettingsFormEventHandlers()
  local new_volume_value

  _state.routing.settings_objs.close_btn.onclick = function(self)
    _state.routing.settings_objs.popup:close()
  end

  _state.routing.settings_objs.mute.onclick = function(self)
    toggleBtnState(self, "table_mute")
  end

  _state.routing.settings_objs.phase.onclick = function(self)
    toggleBtnState(self, "gen_phase")
  end

  _state.routing.settings_objs.mono_stereo.onclick = function(self)
    toggleBtnState(self, "gen_mono")
  end

  _state.routing.settings_objs.volume.onchange = function(self)
    new_volume_value = getAPIVolume(self.value)

    _state.routing.settings_objs.volume_val:attr("text", reaper.mkvolstr("", new_volume_value))
  end

  _state.routing.settings_objs.pan.onchange = function(self)
    _state.routing.settings_objs.pan_val:attr("text", reaper.mkpanstr("", self.value))
  end

  _state.routing.settings_objs.midi_velpan.onclick = function(self)
    toggleBtnState(self, "gen_midi")
  end

  _state.routing.settings_objs.audio_src_channel.onchange = function(self)
    handleChannelDropdown(self)
  end

  _state.routing.settings_objs.midi_src.onchange = function(self)
    handleChannelDropdown(self)
  end

  _state.routing.settings_objs.midi_dest.onchange = function(self)
    handleIncrementingToggle(self, "midi")
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


function handleChannelDropdown(active_dropdown)
  local none_value, affected_dropdown, arrow_ref, affected_incrementing_checkbox, active_dropdown_is_audio

  if active_dropdown.ref == "audio_src_channel" then
    none_value, affected_dropdown, arrow_ref, affected_incrementing_checkbox, active_dropdown_is_audio = getAudioSrcChannelDropdownInfo(active_dropdown)

    handleIncrementingToggle(active_dropdown, "audio")

  elseif active_dropdown.ref == "midi_src" then
    none_value, affected_dropdown, arrow_ref, affected_incrementing_checkbox = getMidiSrcChannelDropdownInfo()
  end

  toggleChannelDropdown(active_dropdown, none_value, affected_dropdown, arrow_ref, affected_incrementing_checkbox, active_dropdown_is_audio)
end


function getAudioSrcChannelDropdownInfo(active_dropdown)
  local none_value, affected_dropdown, arrow_ref, affected_incrementing_checkbox, active_dropdown_is_audio

  none_value = "-1"
  affected_dropdown = _state.routing.settings_objs.audio_dest_channel
  arrow_ref = "audio_arrow"
  affected_incrementing_checkbox = _state.routing.settings_objs.audio_incrementing
  active_dropdown_is_audio = true

  return none_value, affected_dropdown, arrow_ref, affected_incrementing_checkbox, active_dropdown_is_audio
end


function handleIncrementingToggle(active_dropdown, midi_or_audio)
  local this_incrementing_box

  if midi_or_audio == "midi" then
    this_incrementing_box = _state.routing.settings_objs.midi_incrementing

  elseif midi_or_audio == "audio" then
    this_incrementing_box = _state.routing.settings_objs.audio_incrementing
  end

  if active_dropdown.selected_item then
    
    if active_dropdown.selected_item.data__is_highest_option then
      this_incrementing_box:attr("value", false)
      this_incrementing_box:attr("disabled", true)

    else
      this_incrementing_box:attr("disabled", false)
    end
  end
end


function getMidiSrcChannelDropdownInfo()
  local none_value, affected_dropdown, arrow_ref, affected_incrementing_checkbox

  none_value = "-1/-1"
  affected_dropdown = _state.routing.settings_objs.midi_dest
  arrow_ref = "midi_arrow"
  affected_incrementing_checkbox = _state.routing.settings_objs.midi_incrementing

  return none_value, affected_dropdown, arrow_ref, affected_incrementing_checkbox
end


function toggleChannelDropdown(active_dropdown, none_value, affected_dropdown, arrow_ref, affected_incrementing_checkbox, active_dropdown_is_audio)

  if active_dropdown.selected_id == none_value then
    affected_dropdown:attr("ghost", true)
    affected_dropdown.refs[arrow_ref]:attr("ghost", true)
    affected_incrementing_checkbox:hide()

  else
    affected_dropdown:attr("ghost", false)
    affected_dropdown.refs[arrow_ref]:attr("ghost", false)
    affected_incrementing_checkbox:show()

    if active_dropdown_is_audio then
      populateAudioDestChannelDefaultOptions(true)
    end
  end
end


function populateAudioDestChannelDefaultOptions(this_is_refresh)
  local multichannel_choices_count, src_multichannel_is_selected, src_selected_channel_count, target_tracks_channel_count_min, audio_dest_channel_all_options, new_dest_selected_idx

  multichannel_choices_count, src_multichannel_is_selected, src_selected_channel_count, target_tracks_channel_count_min = getAudioDestChannelInfo(this_is_refresh)
  audio_dest_channel_all_options = createAudioDestChannelAllOptions(multichannel_choices_count, src_multichannel_is_selected, src_selected_channel_count, target_tracks_channel_count_min)

  _state.routing.settings_objs.audio_dest_channel:attr("menu", audio_dest_channel_all_options)

  new_dest_selected_idx = tostring(_api.channels.dest.default)

  _state.routing.settings_objs.audio_dest_channel:select(new_dest_selected_idx)
end


function getAudioDestChannelInfo(this_is_refresh)
  local src_selected_channel_count, src_multichannel_is_selected, target_tracks_channel_count_min, multichannel_choices_count

  src_selected_channel_count = getSrcSelectedChannelCount()
  src_multichannel_is_selected = src_selected_channel_count > 2
  target_tracks_channel_count_min = this_is_refresh and _constant.reaper_max_track_channels or getTargetTracksLeastChannelCount()
  multichannel_choices_count = src_multichannel_is_selected and target_tracks_channel_count_min - src_selected_channel_count + 1 or target_tracks_channel_count_min - 1

  return multichannel_choices_count, src_multichannel_is_selected, src_selected_channel_count, target_tracks_channel_count_min
end


function getSrcSelectedChannelCount()
  local src_selected_option, src_channel_option_val, src_is_stereo, src_is_mono, src_selected_channel_count

  src_selected_option = tonumber(_state.routing.settings_objs.audio_src_channel.selected_id)

  if not src_selected_option then 
    src_selected_option = _api.channels.src.stereo.default
  end

  src_channel_option_val = src_selected_option / _api.channels.mono_base
  src_is_stereo = src_channel_option_val < 1
  src_is_mono = src_channel_option_val >= 1 and src_channel_option_val < 2

  if src_is_stereo then
    src_selected_channel_count = 2

  elseif src_is_mono then
    src_selected_channel_count = 1

  else
    src_selected_channel_count = src_channel_option_val * 2
  end

  return math.floor(src_selected_channel_count)
end


function getTargetTracksLeastChannelCount()
  local target_tracks, target_tracks_least_channel_count, this_target_track_api_idx, this_target_track, this_target_track_channel_count

  getCurrentTargetTrackChoices()

  target_tracks = _state.routing.options_objs.target_track_choices
  target_tracks_least_channel_count = _constant.reaper_max_track_channels

  if target_tracks then

    for i = 1, #target_tracks do
      this_target_track_api_idx = target_tracks[i].idx - 1
      this_target_track = reaper.GetTrack(_api.current_project, this_target_track_api_idx)
      this_target_track_channel_count = reaper.GetMediaTrackInfo_Value(this_target_track, _api.track.channel_count)

      if this_target_track_channel_count < target_tracks_least_channel_count then
        target_tracks_least_channel_count = this_target_track_channel_count
      end
    end
  end

  return target_tracks_least_channel_count
end


function createAudioDestChannelAllOptions(multichannel_choices_count, src_multichannel_is_selected, src_selected_channel_count, target_tracks_channel_count_min)
  local audio_dest_channel_all_options, mono_option_idx, mono_option_val

  audio_dest_channel_all_options = createAudioDestStereoOrMultichannelChoices(multichannel_choices_count, src_multichannel_is_selected, src_selected_channel_count)
  multichannel_choices_count = math.floor(multichannel_choices_count)

  for i = 0, target_tracks_channel_count_min-1 do
    mono_option_idx = multichannel_choices_count + i + 1
    mono_option_val = _api.channels.mono_base + i

    audio_dest_channel_all_options[mono_option_idx] = {
      label = tostring(i+1),
      id = tostring(mono_option_val),
      data__channel_count = 1
    }
  end

  return audio_dest_channel_all_options
end


function createAudioDestStereoOrMultichannelChoices(multichannel_choices_count, src_multichannel_is_selected, src_selected_channel_count)
  local audio_dest_channel_all_options, divider, audio_dest_multichannel_option_label, multichannel_option_id_val, audio_dest_multichannel_option_channel_count

  audio_dest_channel_all_options = {}
  divider = getAudioChannelChoiceDivider(src_selected_channel_count)

  for i = 0, multichannel_choices_count do
    audio_dest_multichannel_option_label, multichannel_option_id_val, audio_dest_multichannel_option_channel_count = getMultichannelOrStereoOptionInfo(src_multichannel_is_selected, src_selected_channel_count, divider, i)
    
    audio_dest_channel_all_options[i+1] = {
      label = audio_dest_multichannel_option_label,
      id = tostring(multichannel_option_id_val),
      data__channel_count = audio_dest_multichannel_option_channel_count
    }
  end

  return audio_dest_channel_all_options
end


function getAudioChannelChoiceDivider(src_selected_channel_count)
  local this_is_stereo, divider

  this_is_stereo = src_selected_channel_count == 2
  divider = this_is_stereo and "/" or "-"

  return divider
end


function getMultichannelOrStereoOptionInfo(src_multichannel_is_selected, src_selected_channel_count, divider, multichannel_choice_idx)
  local mono_or_stereo_is_selected, multichannel_lowest_in_option, multichannel_highest_in_option, audio_dest_multichannel_option_label, multichannel_option_id_val, audio_dest_multichannel_option_channel_count

  mono_or_stereo_is_selected = not src_multichannel_is_selected
  multichannel_lowest_in_option = multichannel_choice_idx + 1

  if src_multichannel_is_selected then
    multichannel_highest_in_option = src_selected_channel_count + multichannel_choice_idx

  elseif mono_or_stereo_is_selected then
    multichannel_highest_in_option = multichannel_choice_idx + 2
  end

  multichannel_highest_in_option = math.floor(multichannel_highest_in_option)
  audio_dest_multichannel_option_label = multichannel_lowest_in_option .. divider .. multichannel_highest_in_option
  multichannel_option_id_val = multichannel_choice_idx
  audio_dest_multichannel_option_channel_count = multichannel_highest_in_option - multichannel_lowest_in_option + 1

  return audio_dest_multichannel_option_label, multichannel_option_id_val, audio_dest_multichannel_option_channel_count
end


function reaperFade(ftype,t,s,e,c,inout)
  local reaperFade1, reaperFade2, reaperFade3, reaperFadeg, reaperFadeh, reaperFadeIn, x, ret

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
  x = (t-s)/(e-s)
  ret = reaperFadeIn[ftype](table.unpack(inout and {x,c} or {1-x,-c}))
  return ret * 4
end


function getAPIVolume(slider_value)

  return reaperFade(5, slider_value, 0, 4, 1, true)
end


function populateRoutingSettingsFormValues(reset)
  local new_routing_settings_values

  if _state.routing.settings_objs then
    new_routing_settings_values = (_state.routing.settings_objs.all_values and reset ~= "reset") and _state.routing.settings_objs.all_values or _constant.default_routing_settings_values
    
    getSetRoutingSettingsValues("set", new_routing_settings_values)

    if reset == "reset" then
      updateRoutingSettingsBtns(reset)
    end
  end
end


function updateRoutingSettingsBtns(reset)
  local all_btn_img_filename_bases, this_btn, this_btn_value, new_btn_img_base_state

  all_btn_img_filename_bases = {
    mute = "table_mute",
    phase = "gen_phase",
    mono_stereo = "gen_mono",
    midi_velpan = "gen_midi"
  }

  for btn_name, btn_img_base in pairs(all_btn_img_filename_bases) do
    this_btn = _state.routing.settings_objs[btn_name]
    this_btn_value = this_btn.value
    new_btn_img_base_state = (reset == "reset" or this_btn_value == 0) and "_off" or "_on"

    this_btn:attr("icon", btn_img_base .. new_btn_img_base_state)
  end
end


function populateRoutingSettingsPopup()
  _state.routing.settings_objs.content:add(_state.routing.settings_objs.close_btn)
  _state.routing.settings_objs.content:add(_state.routing.settings_objs.title)
  _state.routing.settings_objs.row1:add(_state.routing.settings_objs.volume_val)
  _state.routing.settings_objs.row1:add(_state.routing.settings_objs.pan_val)
  _state.routing.settings_objs.row1:add(_state.routing.settings_objs.mute)
  _state.routing.settings_objs.row1:add(_state.routing.settings_objs.phase)
  _state.routing.settings_objs.row1:add(_state.routing.settings_objs.mono_stereo)
  _state.routing.settings_objs.row1:add(_state.routing.settings_objs.send_mode)
  _state.routing.settings_objs.form:add(_state.routing.settings_objs.row1)
  _state.routing.settings_objs.row2:add(_state.routing.settings_objs.volume, {expand = 3})
  _state.routing.settings_objs.row2:add(_state.routing.settings_objs.pan, {expand = 1.25})
  -- _state.routing.settings_objs.row2:add(_state.routing.settings_objs.panlaw)
  _state.routing.settings_objs.row2:add(_state.routing.settings_objs.midi_velpan)
  _state.routing.settings_objs.form:add(_state.routing.settings_objs.row2)
  _state.routing.settings_objs.audio_channels:add(_state.routing.settings_objs.audio_txt)
  _state.routing.settings_objs.audio_channels:add(_state.routing.settings_objs.audio_src_channel)
  _state.routing.settings_objs.audio_channels:add(rtk.Text{_unicode.right_arrow, bmargin = "3", fontscale = 1.2, ref = "audio_arrow"})
  _state.routing.settings_objs.audio_channels:add(_state.routing.settings_objs.audio_dest_channel)
  _state.routing.settings_objs.audio_block:add(_state.routing.settings_objs.audio_channels)
  _state.routing.settings_objs.audio_block:add(_state.routing.settings_objs.audio_incrementing)
  _state.routing.settings_objs.midi_channels:add(_state.routing.settings_objs.midi_txt)
  _state.routing.settings_objs.midi_channels:add(_state.routing.settings_objs.midi_src)
  _state.routing.settings_objs.midi_channels:add(rtk.Text{_unicode.right_arrow, bmargin = "3", fontscale = 1.2, ref = "midi_arrow"})
  _state.routing.settings_objs.midi_channels:add(_state.routing.settings_objs.midi_dest)
  _state.routing.settings_objs.midi_block:add(_state.routing.settings_objs.midi_channels)
  _state.routing.settings_objs.midi_block:add(_state.routing.settings_objs.midi_incrementing)
  _state.routing.settings_objs.row3:add(_state.routing.settings_objs.audio_block)
  _state.routing.settings_objs.row3:add(_state.routing.settings_objs.midi_block)
  _state.routing.settings_objs.form:add(_state.routing.settings_objs.row3)
  _state.routing.settings_objs.content:add(_state.routing.settings_objs.form)
  _state.routing.settings_objs.popup:attr("child", _state.routing.settings_objs.content)
end


function selectDeselectAllTargetTracks(select_deselect)
  local target_track_lines, this_track_line, this_track_checkbox

  target_track_lines = _state.routing.options_objs.target_tracks_box.children

  for j = 1, #target_track_lines do
    this_track_line = target_track_lines[j][1]

    if this_track_line then
      this_track_checkbox = this_track_line.children[2][1]
      this_track_checkbox:attr("value", select_deselect)
    end
  end
end


function submitRoutingOptionChanges()
  local buss_driven, undo_string

  getCurrentTargetTrackChoices()

  buss_driven = addRemoveRouting(_state.routing.options_objs.form_fields)
  
  if buss_driven then
    undo_string = getUndoString()

    reaper.Undo_BeginBlock()
    _state.routing.options_objs.window:close()
    reaper.Undo_EndBlock(undo_string, 1)

  elseif not _state.enough_audio_channels_are_available then
    reaper.ShowMessageBox("You are trying to use more channels than the " .. _constant.reaper_max_track_channels .. " Reaper makes available. Change your source track selection and/or routing settings and try again.", "Too many channels", _api.msg_type_ok)

  else
    reaper.ShowMessageBox("No routing is available to remove on the selected track(s).", "Buss Driver", _api.msg_type_ok)
  end
end


function getCurrentTargetTrackChoices()
  local this_track_line, this_track_checkbox

  _state.routing.options_objs.target_track_choices = {}

  for i = 1, #_state.routing.options_objs.target_tracks_box.children do
    this_track_line = _state.routing.options_objs.target_tracks_box:get_child(i)
    this_track_checkbox = this_track_line:get_child(2)
    
    if this_track_checkbox.value then

      table.insert(_state.routing.options_objs.target_track_choices, {
        idx = this_track_line.data__track_num,
        guid = this_track_line.data__track_guid
      })
    end
  end
end


function getUndoString()
  local action_choice, type_choice, undo_string

  if _state.routing.option_choice.action == "add" then
    action_choice = "Add"

  elseif _state.routing.option_choice.action == "remove" then
    action_choice = "Remove"
  end

  if _state.routing.option_choice.type == "send" then
    type_choice = "send(s)"

  elseif _state.routing.option_choice.type == "receive" then
    type_choice = "receive(s)"
  end

  undo_string = _constant.brand.script .. ": " .. action_choice .. " " .. type_choice

  return undo_string
end


function setTargetTrackChoices(new_choices)
  local target_track_lines, this_track_guid, this_track_line, this_track_line_guid, this_track_checkbox

  if new_choices then

    for i = 1, #new_choices do
      target_track_lines = _state.routing.options_objs.target_tracks_box.children
      this_track_guid = new_choices[i].guid

      for j = 1, #target_track_lines do
        this_track_line = target_track_lines[j][1]

        if this_track_line then
          this_track_line_guid = this_track_line.data__track_guid

          if this_track_line_guid == this_track_guid then
            this_track_checkbox = this_track_line.children[2][1]

            this_track_checkbox:attr("value", true)

            break
          end
        end
      end
    end
  end
end


function addRemoveRouting(routing_options_form_fields)
  local this_selected_track, this_target_track, buss_driven

  _state.routing.option_choice.action, _state.routing.option_choice.type = getRoutingChoices()

  if incrementingAudioChannelsExceedMax() then return false end

  for i = 1, #_state.tracks.selected do
    _state.tracks.selected.current_idx = i
    this_selected_track = _state.tracks.selected[i]

    for j = 1, #_state.routing.options_objs.target_track_choices do
      _state.tracks.target.current_idx = j
      this_target_track = reaper.GetTrack(_api.current_project, _state.routing.options_objs.target_track_choices[j].idx-1)

      if _state.routing.option_choice.action == "add" then
        addRouting(this_selected_track, this_target_track)

        buss_driven = true

      elseif _state.routing.option_choice.action == "remove" then
        buss_driven = removeRouting(this_selected_track, this_target_track)
      end
    end
  end

  return buss_driven
end


function incrementingAudioChannelsExceedMax()
  local incrementing_channels_exceed_max, incrementing_is_enabled, dest_tracks_count, api_routing_src_idx, channel_count_type, routing_type, send_channel_count, addl_channels_above_count, src_track_top_channel_after_incrementing

  incrementing_channels_exceed_max = false

  if _state.routing.settings_objs then
    incrementing_is_enabled = _state.routing.settings_objs.audio_incrementing.value

    if incrementing_is_enabled then
      dest_tracks_count = getDestTracksCountFromUserSelection()
      api_routing_src_idx = 8
      channel_count_type, routing_type, send_channel_count, addl_channels_above_count = getAudioRoutingInfo(api_routing_src_idx, _state.routing.settings_objs.audio_src_channel.selected_id)

      src_track_top_channel_after_incrementing = addl_channels_above_count + (send_channel_count * dest_tracks_count)
      
      if src_track_top_channel_after_incrementing > _constant.reaper_max_track_channels then
        _state.enough_audio_channels_are_available = false
        incrementing_channels_exceed_max = true
      end
    end
  end

  return incrementing_channels_exceed_max
end


function getDestTracksCountFromUserSelection()
  local dest_tracks, this_target_track_api_idx, this_target_track

  if _state.routing.option_choice.type == "send" then
    dest_tracks = {}

    for i = 1, #_state.routing.options_objs.target_track_choices do
      this_target_track_api_idx = _state.routing.options_objs.target_track_choices[i].idx - 1
      this_target_track = reaper.GetTrack(_api.current_project, this_target_track_api_idx)

      table.insert(dest_tracks, this_target_track)
    end

  elseif _state.routing.option_choice.type == "receive" then
    dest_tracks = _state.tracks.selected
  end

  return #dest_tracks
end


function addRouting(selected_track, target_track)

  if _state.routing.option_choice.type == "send" then
    _state.routing.newly_created_idx = reaper.CreateTrackSend(selected_track, target_track)
    
    if _state.routing.settings_objs and _state.routing.settings_objs.all_values then
      applyRoutingSettings(selected_track, target_track)
    end

  elseif _state.routing.option_choice.type == "receive" then
    _state.routing.newly_created_idx = reaper.CreateTrackSend(target_track, selected_track)
    
    if _state.routing.settings_objs and _state.routing.settings_objs.all_values then
      applyRoutingSettings(target_track, selected_track)
    end
  end
end


function applyRoutingSettings(src_track, dest_track)
  local routing_settings_api_objs_converted_names, is_pan_law

  routing_settings_api_objs_converted_names = getRoutingSettingsAPIObjsConvertedNames()

  for routing_setting_idx = 1, 14 do
    is_pan_law = routing_setting_idx == 6

    if not is_pan_law then
      processRoutingSetting(routing_setting_idx, routing_settings_api_objs_converted_names, src_track, dest_track)
    end
  end
end


function getRoutingSettingsAPIObjsConvertedNames()
  local routing_settings_api_objs_converted_names, routing_settings_api_obj_names

  routing_settings_api_objs_converted_names = {}

  for i = 1, 14 do

    routing_settings_api_obj_names = {
      "mute",
      "phase",
      "mono_stereo",
      "volume",
      "pan",
      "pan_law",
      "send_mode",
      "audio_src_channel",
      "audio_dest_channel",
      "midi_src",
      "midi_dest",
      "midi_src",
      "midi_dest",
      "midi_velpan"
    }

    routing_settings_api_objs_converted_names[_api.all_routing_settings[i]] = routing_settings_api_obj_names[i]
  end

  return routing_settings_api_objs_converted_names
end


function processRoutingSetting(routing_setting_idx, routing_settings_api_objs_converted_names, src_track, dest_track)
  local is_volume, is_audio_channel, is_midi_channel, is_midi_dest_channel, is_midi_bus, this_api_routing_setting, this_routing_obj_name, this_routing_obj_value, this_user_routing_setting_value

  is_volume = routing_setting_idx == 4
  is_audio_channel = routing_setting_idx == 8 or routing_setting_idx == 9
  is_midi_channel = routing_setting_idx == 10 or routing_setting_idx == 11
  is_midi_dest_channel = routing_setting_idx == 11
  is_midi_bus = routing_setting_idx == 12 or routing_setting_idx == 13
  this_api_routing_setting = _api.all_routing_settings[routing_setting_idx]
  this_routing_obj_name = routing_settings_api_objs_converted_names[this_api_routing_setting]
  this_routing_obj_value = _state.routing.settings_objs.all_values[this_routing_obj_name]

  if is_volume then
    this_user_routing_setting_value = getAPIVolume(this_routing_obj_value)

  elseif is_midi_channel then
    this_user_routing_setting_value = stripOutMidiData(this_routing_obj_value, "bus")

    if is_midi_dest_channel then
      this_user_routing_setting_value = incrementChannels("midi", this_user_routing_setting_value)
    end
  
  elseif is_midi_bus then
    this_user_routing_setting_value = stripOutMidiData(this_routing_obj_value, "channel")

  elseif is_audio_channel then
    this_user_routing_setting_value = processAudioRoutingSetting(routing_setting_idx, this_routing_obj_value, src_track, dest_track)

  else
    this_user_routing_setting_value = this_routing_obj_value
  end

  reaper.BR_GetSetTrackSendInfo(src_track, _api.routing.category.send, _state.routing.newly_created_idx, this_api_routing_setting, _api.routing.set_new_value, this_user_routing_setting_value)
end


function stripOutMidiData(val, channel_or_bus)
  local data_to_strip

  if channel_or_bus == "channel" then
    data_to_strip = _regex.routing.midi.channel

  elseif channel_or_bus == "bus" then
    data_to_strip = _regex.routing.midi.bus
  end

  return string.gsub(val, data_to_strip, "")
end


function processAudioRoutingSetting(routing_setting_idx, this_routing_obj_value, src_track, dest_track)
  local is_audio_src_channel, this_user_routing_setting_value

  is_audio_src_channel = routing_setting_idx == 8
  this_user_routing_setting_value = this_routing_obj_value

  if is_audio_src_channel then
    this_user_routing_setting_value = incrementChannels("audio", this_user_routing_setting_value, routing_setting_idx, src_track)
  end

  createRequiredAudioChannels(routing_setting_idx, this_user_routing_setting_value, src_track, dest_track)

  return this_user_routing_setting_value
end


function incrementChannels(midi_or_audio, this_user_routing_setting_value, routing_setting_idx, src_track)
  local incrementing_is_enabled, num_to_increment_channels_by

  this_user_routing_setting_value = tonumber(this_user_routing_setting_value)

  if midi_or_audio == "midi" then
    incrementing_is_enabled = _state.routing.settings_objs.midi_incrementing.value

  elseif midi_or_audio == "audio" then
    incrementing_is_enabled = _state.routing.settings_objs.audio_incrementing.value
  end

  if incrementing_is_enabled then
    num_to_increment_channels_by = getNumToIncrementChannelsBy(midi_or_audio, routing_setting_idx)
    this_user_routing_setting_value = this_user_routing_setting_value + num_to_increment_channels_by

    if midi_or_audio == "midi" and this_user_routing_setting_value > _api.channels.midi.max_value then
      this_user_routing_setting_value = _api.channels.midi.max_value

    elseif midi_or_audio == "audio" then
      this_user_routing_setting_value = getMoreAudioChannelsToIncrement(this_user_routing_setting_value, routing_setting_idx, src_track)
    end
  end

  return this_user_routing_setting_value
end


function getNumToIncrementChannelsBy(midi_or_audio, routing_setting_idx)
  local send_or_receive, src_track_idx, dest_track_idx, num_to_increment_channels_by, channel_count_type, routing_type, channel_count

  send_or_receive = _state.routing.option_choice.type

  if midi_or_audio == "midi" then

    if send_or_receive == "send" then
      src_track_idx = _state.tracks.selected.current_idx

    elseif send_or_receive == "receive" then
      src_track_idx = _state.tracks.target.current_idx
    end

    num_to_increment_channels_by = src_track_idx - 1

  elseif midi_or_audio == "audio" then

    if send_or_receive == "send" then
      dest_track_idx = _state.tracks.target.current_idx

    elseif send_or_receive == "receive" then
      dest_track_idx = _state.tracks.selected.current_idx
    end

    channel_count_type, routing_type, channel_count = getAudioRoutingInfo(routing_setting_idx)

    if channel_count_type == "stereo" then
      num_to_increment_channels_by = (dest_track_idx * 2) - 2

    elseif channel_count_type == "mono" then
      num_to_increment_channels_by = dest_track_idx - 1
 
    elseif channel_count_type == "multichannel" then
      num_to_increment_channels_by = (dest_track_idx * channel_count) - channel_count
    end
  end

  return num_to_increment_channels_by
end


function getAudioRoutingInfo(routing_setting_idx, routing_setting_value)
  local routing_type, channel_count, channel_count_type, addl_channels_above_count

  routing_type, channel_count = getAudioRoutingTypeAndChannelCount(routing_setting_idx)
  channel_count_type = getAudioRoutingChannelCountType(channel_count)
  addl_channels_above_count = getAudioRoutingChannelsAboveCount(routing_setting_value, channel_count_type, channel_count, routing_type)

  return channel_count_type, routing_type, channel_count, addl_channels_above_count
end


function getAudioRoutingTypeAndChannelCount(routing_setting_idx)
  local this_is_src, this_is_dest, routing_type, channel_count

  this_is_src = routing_setting_idx == 8
  this_is_dest = routing_setting_idx == 9

  if this_is_src then
    routing_type = "src"
    channel_count = _state.routing.settings_objs.audio_src_channel.selected_item.data__channel_count

  elseif this_is_dest then
    routing_type = "dest"
    channel_count = _state.routing.settings_objs.audio_dest_channel.selected_item.data__channel_count
  end

  channel_count = math.floor(channel_count)

  return routing_type, channel_count
end


function getAudioRoutingChannelCountType(channel_count)
  local channel_count_type

  if channel_count == 1 then
    channel_count_type = "mono"

  elseif channel_count == 2 then
    channel_count_type = "stereo"

  elseif channel_count > 2 then
    channel_count_type = "multichannel"
  end

  return channel_count_type
end


function getAudioRoutingChannelsAboveCount(routing_setting_value, channel_count_type, channel_count, routing_type)
  local addl_channels_above_count, src_multichannel_addl_channels_above_count

  routing_setting_value = tonumber(routing_setting_value)
  addl_channels_above_count = 0

  if routing_setting_value then

    if channel_count_type == "mono" then
      addl_channels_above_count = routing_setting_value - _api.channels.mono_base

    elseif channel_count_type == "stereo" then
      addl_channels_above_count = routing_setting_value

    elseif channel_count_type == "multichannel" then

      if routing_type == "src" then
        src_multichannel_addl_channels_above_count = routing_setting_value - (_api.channels.src.multichannel.base + (_api.channels.src.multichannel.addl * ((channel_count / 2) - 2)))
        addl_channels_above_count = math.floor(src_multichannel_addl_channels_above_count)

      elseif routing_type == "dest" then
        addl_channels_above_count = routing_setting_value
      end
    end
  end

  return addl_channels_above_count
end


function createRequiredAudioChannels(routing_setting_idx, routing_setting_value, src_track, dest_track)
  local channel_count_type, routing_type, channel_count, addl_channels_above_count, target_track, current_track_channel_value, top_channel_num, track_needs_more_channels

  channel_count_type, routing_type, channel_count, addl_channels_above_count = getAudioRoutingInfo(routing_setting_idx, routing_setting_value)

  if routing_type == "src" then
    target_track = src_track

  elseif routing_type == "dest" and dest_track then
    target_track = dest_track
  end

  current_track_channel_value = reaper.GetMediaTrackInfo_Value(target_track, _api.track.channel_count)
  top_channel_num = (channel_count + addl_channels_above_count)
  track_needs_more_channels = top_channel_num > current_track_channel_value

  if track_needs_more_channels then
    reaper.SetMediaTrackInfo_Value(target_track, _api.track.channel_count, top_channel_num)
  end
end


function getMoreAudioChannelsToIncrement(routing_setting_value, routing_setting_idx, src_track)
  local channel_count_type, routing_type, channel_count, max_track_channels_value, incrementing_exceeds_available_audio_channels

  channel_count_type, routing_type, channel_count = getAudioRoutingInfo(routing_setting_idx)
  max_track_channels_value = getMaxTrackChannelsValue(channel_count_type, channel_count)
  incrementing_exceeds_available_audio_channels = routing_setting_value >= max_track_channels_value

  if incrementing_exceeds_available_audio_channels then

    if channel_count_type == "mono" then
      routing_setting_value = _api.channels.mono_base + _constant.reaper_max_track_channels - 1

    elseif channel_count_type == "stereo" then
      routing_setting_value = _constant.reaper_max_track_channels - 2

    elseif channel_count_type == "multichannel" then
      routing_setting_value = _api.channels.src.multichannel.base + ( _api.channels.src.multichannel.addl * ( (channel_count / 2) - 2) )
    end

    createRequiredAudioChannels(routing_setting_idx, routing_setting_value, src_track)
  end

  return routing_setting_value
end


function getMaxTrackChannelsValue(channel_count_type, channel_count)
  local max_track_channels_value

  if channel_count_type == "mono" then
    max_track_channels_value = _api.channels.mono_base + _constant.reaper_max_track_channels

  elseif channel_count_type == "stereo" then
    max_track_channels_value = _constant.reaper_max_track_channels

  elseif channel_count_type == "multichannel" then
    max_track_channels_value = _api.channels.src.multichannel.base + ( _api.channels.src.multichannel.addl * (channel_count - 4) ) + _constant.reaper_max_track_channels
  end

  return max_track_channels_value
end


function removeRouting(selected_track, target_track)
  local buss_driven, api_routing_category, api_routing_param, routing_count, this_track_target

  buss_driven = false
  api_routing_category, api_routing_param = getRoutingValues(_state.routing.option_choice.type)
  routing_count = reaper.GetTrackNumSends(selected_track, api_routing_category)

  for i = 0, routing_count-1 do
    this_track_target = reaper.GetTrackSendInfo_Value(selected_track, api_routing_category, i, api_routing_param)

    if this_track_target == target_track then
      reaper.RemoveTrackSend(selected_track, api_routing_category, i)

      buss_driven = true
    end
  end

  return buss_driven
end


function populateRoutingOptionsWindow()
  _state.routing.options_objs.selected_tracks_box:add(_state.routing.options_objs.selected_tracks_heading)
  _state.routing.options_objs.selected_tracks_box:add(_state.routing.options_objs.selected_tracks_list)
  _state.routing.options_objs.addremove_wrapper:add(_state.routing.options_objs.add_checkbox)
  _state.routing.options_objs.addremove_wrapper:add(_state.routing.options_objs.remove_checkbox)
  _state.routing.options_objs.type_wrapper:add(_state.routing.options_objs.send_checkbox)
  _state.routing.options_objs.type_wrapper:add(_state.routing.options_objs.receive_checkbox)
  _state.routing.options_objs.action_sentence:add(_state.routing.options_objs.action_text_start)
  _state.routing.options_objs.action_sentence:add(_state.routing.options_objs.addremove_wrapper)
  _state.routing.options_objs.action_sentence:add(_state.routing.options_objs.type_wrapper)
  _state.routing.options_objs.action_sentence:add(_state.routing.options_objs.action_text_end)
  _state.routing.options_objs.action_sentence_wrapper:add(_state.routing.options_objs.action_sentence)
  _state.routing.options_objs.form_fields:add(_state.routing.options_objs.action_sentence_wrapper)
  _state.routing.options_objs.form_fields:add(_state.routing.options_objs.select_all_tracks)
  _state.routing.options_objs.form_fields:add(_state.routing.options_objs.target_tracks_subheading)
  _state.routing.options_objs.form_fields:add(_state.routing.options_objs.target_tracks_box)
  _state.routing.options_objs.save_options_wrapper:add(_state.routing.options_objs.save_options)
  _state.routing.options_objs.form_buttons:add(_state.routing.options_objs.form_submit)
  _state.routing.options_objs.form_buttons:add(_state.routing.options_objs.form_cancel)
  _state.routing.options_objs.reset_wrapper:add(_state.routing.options_objs.reset_btn)
  _state.routing.options_objs.form_bottom:add(_state.routing.options_objs.save_options_wrapper, {halign = "left"})
  _state.routing.options_objs.form_bottom:add(_state.routing.options_objs.form_buttons, {halign = "center"})
  _state.routing.options_objs.form_bottom:add(_state.routing.options_objs.reset_wrapper, {halign = "right"})
  _state.routing.options_objs.content:add(_state.routing.options_objs.selected_tracks_box)
  _state.routing.options_objs.content:add(_state.routing.options_objs.form_fields)
  _state.routing.options_objs.content:add(_state.routing.options_objs.form_bottom)
  _state.routing.options_objs.viewport:attr("child", _state.routing.options_objs.content)
  _state.routing.options_objs.viewport:reflow()
  _state.routing.options_objs.configure_btn_wrapper:add(_state.routing.options_objs.configure_btn)
  _state.routing.options_objs.brand:add(_state.routing.options_objs.title)
  _state.routing.options_objs.brand:add(_state.routing.options_objs.logo)
  _state.routing.options_objs.window:add(_state.routing.options_objs.configure_btn_wrapper)
  _state.routing.options_objs.window:add(_state.routing.options_objs.brand)
  _state.routing.options_objs.window:add(_state.routing.options_objs.viewport)
end


function initBussDriver()

  if _constant.selected_tracks_count > 0 then
    launchBussDriverDialog()

  else
    reaper.ShowMessageBox("Select one or more tracks you want to create routing to/from and launch Buss Driver again.", _constant.brand.script .. ": No tracks are selected.", _api.msg_type_ok)
  end
end

initBussDriver()