-- @description MB_Itemator-Utils: Codebase for MB_Itemator scripts' functionality
-- @author MonkeyBars
-- @version 0.001
-- @changelog Initial file creation
-- @provides [nomain] .
--   serpent.lua
--   rtk.lua
-- @link 
-- @about Code for Itemator scripts


-- Copyright (C) MonkeyBars 2022
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.



-- ==== ITEMATOR UTILS SCRIPT ARCHITECTURE NOTES ====
-- Superglue requires Reaper SWS plug-in extension (https://standingwaterstudios.com/) and js_ReaScript_API (https://github.com/ReaTeam/Extensions/raw/master/index.xml) to be installed in Reaper.
-- Superglue uses the great GUI library Reaper Toolkit (https://reapertoolkit.dev/) 
-- Superglue uses Serpent, a serialization library for LUA, for table-string and string-table conversion. https://github.com/pkulchenko/serpent
-- Superglue uses Reaper's Master Track P_EXT to store project-wide script data because its changes are saved in Reaper's undo points, a feature that functions correctly since Reaper v6.43.
-- Data is also stored in media items' & takes' P_EXT.
-- General utility functions at bottom


-- for dev only
-- require("sg-dev-functions")
 

local serpent = require("serpent")
local rtk = require('rtk')


local _script_path, _script_brand_name, _api_current_project, _api_command_flag, _api_include_all_undo_states, _api_item_image_full_height, _api_time_value_decimal_resolution, _api_extstate_persist_enabled, _api_data_key, _api_item_position_key, _api_item_length_key, _api_item_notes_key, _api_item_color_key, _api_take_src_offset_key, _api_playrate_key, _api_take_name_key, _api_takenumber_key, _api_null_takes_val, _global_script_prefix, _global_script_item_name_prefix, _separator, _msg_type_ok, _msg_type_ok_cancel, _msg_type_yes_no, _msg_response_ok, _msg_response_yes, _msg_response_no, _data_storage_track, _global_options_section, _all_global_options_params

_script_path = string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$")
_script_brand_name = "MB_Itemator"
_api_current_project = 0
_api_command_flag = 0
_api_include_all_undo_states = -1
_api_item_image_full_height = 5
_api_time_value_decimal_resolution = 12
_api_extstate_persist_enabled = true
_api_data_key = "P_EXT:"
_api_item_position_key = "D_POSITION"
_api_item_length_key = "D_LENGTH"
_api_item_notes_key = "P_NOTES"
_api_item_color_key = "I_CUSTOMCOLOR"
_api_take_src_offset_key = "D_STARTOFFS"
_api_playrate_key = "D_PLAYRATE"
_api_take_name_key = "P_NAME"
_api_takenumber_key = "IP_TAKENUMBER"
_api_null_takes_val = "TAKE NULL"
_global_script_prefix = "IT_"
_global_script_item_name_prefix = "it"
_separator = ":"
_msg_type_ok = 0
_msg_type_ok_cancel = 1
_msg_type_yes_no = 4
_msg_response_ok = 1
_msg_response_cancel = 2
_msg_response_yes = 6
_msg_response_no = 7
_data_storage_track = reaper.GetMasterTrack(_api_current_project)
_global_options_section = "MB_ITEMATOR-OPTIONS"
_all_global_options_params = {}



function viewSuperglueProjectData()
  local master_track, retval, master_track_chunk

  master_track = reaper.GetMasterTrack(_api_current_project)
  retval, master_track_chunk = reaper.GetTrackStateChunk(master_track, "", false)

  log(master_track_chunk)
end



function setDefaultOptionValues()
  local i, this_option_ext_state_key, this_option_exists_in_extstate

  for i = 1, #_all_global_options_params do
    this_option_ext_state_key = _all_global_options_params[i].ext_state_key
    this_option_exists_in_extstate = reaper.HasExtState(_global_options_section, this_option_ext_state_key)

    if not this_option_exists_in_extstate or this_option_exists_in_extstate == "nil" then
      reaper.SetExtState(_global_options_section, this_option_ext_state_key, _all_global_options_params[i].default_value, _api_extstate_persist_enabled)
    end
  end
end

setDefaultOptionValues()



function toggleOption(option_name)
  local i, active_option_idx, active_option, current_val, new_val

  for i = 1, #_all_global_options_params do

    if _all_global_options_params[i].name == option_name then
      active_option_idx = i

      break
    end
  end

  active_option = _all_global_options_params[active_option_idx]

  if not active_option then return end

  current_val = reaper.GetExtState(_global_options_section, active_option.ext_state_key)

  if current_val == "false" then
    new_val = "true"

  elseif current_val == "true" then
    new_val = "false"

  elseif current_val == "always" then
    new_val = "ask"

  elseif current_val == "ask" then
    new_val = "no"

  elseif current_val == "no" then
    new_val = "always"
  end

  reaper.SetExtState(_global_options_section, active_option.ext_state_key, new_val, true)
end


function openOptionsWindow()
  local all_option_controls, options_window, options_viewport, options_window_content, options_window_title, option_form_buttons, option_form_submit, option_form_cancel

  all_option_controls = {}
  options_window = rtk.Window{maxh = 0.85}
  options_viewport = rtk.Viewport{halign = "center"}
  options_window_content = rtk.VBox{w = 0.85, padding = "27 0 7"}
  options_window_title = rtk.Heading{_script_brand_name .. " Global Options", w = 1, halign = "center", bmargin = 25}
  option_form_buttons = rtk.HBox{margin = "40 10 10 10", spacing = 10}
  option_form_submit = rtk.Button{"Submit", disabled = true}
  option_form_cancel = rtk.Button{"Cancel"}
  option_form_cancel.onclick = function() 
    options_window:close()
  end

  option_form_buttons:add(option_form_submit)
  option_form_buttons:add(option_form_cancel)
  options_window_content:add(options_window_title)

  all_option_controls, options_window_content = populateOptionControls(all_option_controls, options_window_content,option_form_submit)
  option_form_submit.onclick = function()
    submitOptionChanges(all_option_controls, options_window)
  end

  populateOptionsWindow(option_form_buttons, options_window_content, options_window, options_viewport)
end


function populateOptionsWindow(option_form_buttons, options_window_content, options_window, options_viewport)
  local content_padding_adjustment, options_window_content_height

  options_window_content:add(option_form_buttons)
  options_viewport:attr("child", options_window_content)
  options_window:add(options_viewport)
  options_window:open()
  options_window:close()

  options_window_content_height = options_window_content:calc("h") / rtk.scale.framebuffer
  
  options_window:attr("h", options_window_content_height)
  options_window:open{halign='center', valign='center'}
end


function populateOptionControls(all_option_controls, options_window_content, option_form_submit)
  local i, this_option, this_option_name

  for i = 1, #_all_global_options_params do
    this_option = _all_global_options_params[i]
    this_option_name = this_option.name

    if this_option.type == "checkbox" then
      all_option_controls[this_option_name] = getOptionCheckbox(this_option, option_form_submit)

    elseif this_option.type == "dropdown" then
      all_option_controls[this_option_name] = getOptionDropdown(this_option, option_form_submit)
    end

    options_window_content:add(all_option_controls[this_option_name])
  end

  return all_option_controls, options_window_content
end


function getOptionCheckbox(option, option_form_submit)
  local option_saved_value, checkbox_value, option_checkbox

  option_saved_value = reaper.GetExtState(_global_options_section, option.ext_state_key)

  if option_saved_value == "true" then
    checkbox_value = true
  
  else
    checkbox_value = false
  end

  option_checkbox = rtk.CheckBox{option.user_readable_text, value = checkbox_value, margin = "10 0"}
  option_checkbox.onchange = function()
    activateOptionSubmitButton(option_form_submit)
  end

  return option_checkbox
end


function activateOptionSubmitButton(submit_button)
  submit_button:attr("disabled", false)
end


function getOptionDropdown(option, option_form_submit)
  local option_saved_value, option_dropdown_box, dropdown_label, dropdown_control, dropdown_menu, i, this_option_value, this_option_value_menu_item

  option_saved_value = reaper.GetExtState(_global_options_section, option.ext_state_key)
  option_dropdown_box = rtk.HBox{spacing = 10}
  dropdown_label = rtk.Text{option.user_readable_text, margin = "15 0 5", wrap = "wrap_normal"}
  dropdown_control = rtk.OptionMenu{margin = "15 0 5"}
  dropdown_menu = {}

  for i = 1, #option.values do
    this_option_value = option.values[i]
    this_option_value_menu_item = {this_option_value[2], id = this_option_value[1]}

    table.insert(dropdown_menu, this_option_value_menu_item)
  end

  dropdown_control:attr("menu", dropdown_menu)
  dropdown_control:select(option_saved_value)

  dropdown_control.onchange = function()
    activateOptionSubmitButton(option_form_submit)
  end
  
  option_dropdown_box:add(dropdown_control)
  option_dropdown_box:add(dropdown_label)

  return option_dropdown_box
end


function submitOptionChanges(all_option_controls, options_window)
  local i, this_option, this_option_saved_value, this_option_form_value, dropdown

  for i = 1, #_all_global_options_params do
    this_option = _all_global_options_params[i]
    this_option_saved_value = reaper.GetExtState(_global_options_section, this_option.ext_state_key)

    if this_option.type == "checkbox" then
      this_option_form_value = tostring(all_option_controls[this_option.name].value)

    elseif this_option.type == "dropdown" then
      dropdown = all_option_controls[this_option.name]:get_child(1)
      this_option_form_value = dropdown.selected
    end

    if this_option_form_value ~= this_option_saved_value then
      reaper.SetExtState(_global_options_section, this_option.ext_state_key, this_option_form_value, _api_extstate_persist_enabled)

      resetDePoolAllSiblingsWarning(this_option.ext_state_key)
    end
  end

  options_window:close()
end




--- UTILITY FUNCTIONS ---

function stringifyArray(t)
  local s = ""
  local this_item
  for i = 1, #t do
    this_item = t[i]
    s = s .. this_item
    if i ~= #t then
       s = s .. ", "
    end
  end
  if not s or s == "" then
    s = "none"
  end
  return s
end

function deduplicateTable(t)
  local hash = {}
  local res = {}
  for _, v in ipairs(t) do
    if (not hash[v]) then
      res[#res+1] = v
      hash[v] = true
    end
  end
  return res
end

function getTableSize(t)
    local count = 0
    for _, __ in pairs(t) do
        count = count + 1
    end
    return count
end

function numberizeAndRoundElements(tables, elems)
  local i, this_table, j

  for i = 1, #tables do
    this_table = tables[i]

    for j = 1, #elems do
      this_table[elems[j]] = round(tonumber(this_table[elems[j]]),_api_time_value_decimal_resolution)
    end
  end

  return table.unpack(tables)
end


function round(num, precision)
   return math.floor(num*(10^precision)+0.5) / 10^precision
end