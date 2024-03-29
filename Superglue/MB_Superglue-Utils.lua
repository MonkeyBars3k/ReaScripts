--@noindex


-- ==== SUPERGLUE UTILS SCRIPT ARCHITECTURE NOTES ====
-- Superglue requires Reaper SWS plug-in extension v2.13.1.0+ (https://www.sws-extension.org/download/pre-release) and js_ReaScript_API (https://github.com/ReaTeam/Extensions/raw/master/index.xml) to be installed in Reaper.
-- Superglue uses the great GUI library Reaper Toolkit (rtk). (https://reapertoolkit.dev/)
-- Superglue uses Serpent, a serialization library for LUA, for table-string and string-table conversion. (https://github.com/pkulchenko/serpent)
-- Superglue uses Reaper's Master Track P_EXT to store project-wide script data because its changes are saved in Reaper's undo points, a feature that functions correctly since Reaper v6.43.
-- Data is also stored in media items' & takes' P_EXT.
-- General utility functions at bottom


-- for dev only
-- require("mb-dev-functions")
 

local rtk = require('rtk')
local serpent = require("serpent")


local _script_path, _os_path_separator, _os_path_splitter_pattern, _custom_path_separator, _script_brand_logo_filename, _peak_data_filename_extension, _command_id_deselect_all_items, _command_id_glue_ignoring_time_selection_incl_fades, _command_id_apply_track_take_fx_to_items, _command_id_apply_fx_to_items_multichannel, _command_id_build_missing_peaks, _command_id_rebuild_peaks_for_selected_items, _command_id_delete_active_take_from_items, _command_id_set_item_to_one_random_color, _command_id_duplicate_selected_items, _command_id_crop_selected_items_to_active_takes, _command_id_scroll_to_selected_item, _script_brand_name, _glue_undo_block_string, _edit_undo_block_string, _unglue_undo_block_string, _depool_undo_block_string, _smart_action_undo_block_string, _color_undo_block_string, _sizing_region_label_prefix, _sizing_region_label_suffix, _sizing_region_color, _api_current_project, _api_command_flag, _api_dont_refresh_ui, _api_include_all_undo_states, _api_marker_region_undo_states, _api_item_image_full_height, _api_new_take_marker_idx, _api_time_value_decimal_resolution, _api_extstate_persist_enabled, _api_data_key, _api_project_region_guid_key_prefix, _api_item_loop_src_key, _api_item_mute_key, _api_item_position_key, _api_item_length_key, _api_item_notes_key, _api_item_color_key, _api_take_src_offset_key, _api_playrate_key, _api_take_name_key, _api_takenumber_key, _api_take_guid_key, _api_null_takes_val, _api_command_section_id_main, _supported_media_types, _global_script_prefix, _global_script_item_name_prefix, _separator, _superitem_name_prefix, _proj_renderpath, _superitem_bg_img_filename, _superitem_bg_img_path, _restored_item_bg_img_filename, _restored_item_bg_img_path, _restored_instance_bg_img_filename, _restored_instance_bg_img_path, _pool_key_prefix, _all_pool_ids_with_active_sizing_regions_key, _pool_contained_item_states_key_suffix, _pool_last_glue_contained_item_states_key_suffix, _pool_parent_position_key_suffix, _pool_parent_length_key_suffix, _instance_pool_id_key_suffix, _parent_pool_id_key_suffix, _descendant_pool_ids_key_suffix, _last_pool_id_key_suffix, _preglue_active_take_guid_key_suffix, _superglue_active_take_key_suffix, _glue_data_key_suffix, _edit_data_key_suffix, _superitem_params_suffix, _parent_pool_ids_data_key_suffix, _superitem_preglue_state_suffix, _first_child_delta_to_superitem_position_key_suffix, _freshly_depooled_superitem_flag, _postglue_action_step, _preedit_action_step, _superitem_name_default_prefix, _nested_item_default_name, _double_quotation_mark, _msg_type_ok, _msg_type_ok_cancel, _msg_type_yes_no, _msg_response_ok, _msg_response_yes, _msg_response_no, _msg_change_selected_items, _data_storage_track, _users_time_selection_before_action, _users_item_selection, _active_glue_pool_id, _position_start_of_project, _src_offset_default_value, _playrate_default_value, _loop_enabled_value, _sizing_region_1st_display_num, _superitem_position_delta_during_glue, _superitem_offset_delta_since_last_glue, _restored_items_near_project_start_position_delta, _last_glue_stored_item_states, _preglue_restored_item_states, _unselected_contained_items, _first_restored_item_last_glue_delta_to_parent, _ancestor_pools_params, _edited_pool_last_glue_params, _edited_pool_fresh_glue_params, _edited_pool_post_glue_params, _edited_pool_preedit_params, _current_pool_fresh_glue_params, _current_pool_preedit_params, _position_changed_since_last_glue, _offset_changed_since_last_glue, _propagation_user_responses, _user_wants_propagation_option, _active_instance_length_has_changed, _reglue_position_change_affect_on_length, _pool_parent_last_glue_length, _user_wants_to_depool_all_siblings, _this_depooled_superitem_has_not_been_edited, _noninstance_label, _global_options_section, _global_option_toggle_time_selection_sets_bounds_on_glue_key, _global_option_toggle_auto_increase_channel_count_key, _global_option_toggle_item_images_key, _global_option_toggle_new_superglue_random_color_key, _global_option_toggle_loop_source_sets_sizing_region_bounds_on_reglue_key, _global_option_toggle_depool_all_siblings_on_reglue_key, _global_option_toggle_depool_all_siblings_on_reglue_warning_key, _global_option_maintain_source_position_default_key, _global_option_propagate_position_default_key, _global_option_propagate_length_default_key, _global_option_length_propagation_type_default_key, _global_option_playrate_affects_propagation_default_key, _all_global_options_params

_script_path = string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$")
_os_path_separator = package.config:sub(1,1)
_os_path_splitter_pattern = "([^%" .. _os_path_separator .. "]+)"
_custom_path_separator = "_"
_script_brand_logo_filename = "mb_superglue_logo_nobg_sm.png"
_peak_data_filename_extension = ".reapeaks"
_command_id_deselect_all_items = 40289
_command_id_glue_ignoring_time_selection_incl_fades = 40257
_command_id_apply_track_take_fx_to_items = 40209
_command_id_apply_fx_to_items_multichannel = 41993
_command_id_build_missing_peaks = 40047
_command_id_rebuild_peaks_for_selected_items = 40441
_command_id_delete_active_take_from_items = 40129
_command_id_set_item_to_one_random_color = 40706
_command_id_duplicate_selected_items = 41295
_command_id_crop_selected_items_to_active_takes = 40131
_command_id_scroll_to_selected_item = reaper.NamedCommandLookup("_S&M_SCROLL_ITEM")
_script_brand_name = "MB_Superglue"
_glue_undo_block_string = "MB_Superglue"
_edit_undo_block_string = "MB_Superglue-Edit"
_unglue_undo_block_string = "MB_Superglue-Unglue"
_depool_undo_block_string = "MB_Superglue-DePool"
_smart_action_undo_block_string = "MB_Superglue-Smart-Action"
_color_undo_block_string = "MB_Superglue-Color"
_sizing_region_label_prefix = "SG: Pool #"
_sizing_region_label_suffix = " – DO NOT DELETE – Use to set Superitem edges"
_sizing_region_color = reaper.ColorToNative(255, 255, 255)|0x1000000
_api_current_project = 0
_api_command_flag = 0
_api_dont_refresh_ui = false
_api_include_all_undo_states = -1
_api_marker_region_undo_states = 8
_api_item_image_full_height = 5
_api_new_take_marker_idx = -1
_api_time_value_decimal_resolution = 12
_api_extstate_persist_enabled = true
_api_data_key = "P_EXT:"
_api_project_region_guid_key_prefix = "MARKER_GUID:"
_api_item_loop_src_key = "B_LOOPSRC"
_api_item_mute_key = "B_MUTE"
_api_item_position_key = "D_POSITION"
_api_item_length_key = "D_LENGTH"
_api_item_notes_key = "P_NOTES"
_api_item_color_key = "I_CUSTOMCOLOR"
_api_take_src_offset_key = "D_STARTOFFS"
_api_playrate_key = "D_PLAYRATE"
_api_take_name_key = "P_NAME"
_api_takenumber_key = "IP_TAKENUMBER"
_api_take_guid_key = "GUID"
_api_null_takes_val = "TAKE NULL"
_api_command_section_id_main = 0
_supported_media_types = "*.aif\0*.aiff\0*.avi\0*.bwf\0*.cda\0*.dat\0*.edl\0*.flac\0*.gif\0*.jpeg\0*.jpg\0*.kar\0*.lcf\0*.m4a\0*.m4v\0*.mid\0*.midi\0*.mkv\0*.mogg\0*.mov\0*.mp2\0*.mp3\0*.mp4\0*.mpeg\0*.mpg\0*.musicxml\0*.mxl\0*.ogg\0*.ogv\0*.opus\0*.png\0*.qt\0*.rcy\0*.rex\0*.rmi\0*.rpp\0*.rpp-prox\0*.rx2\0*.syx\0*.w64\0*.wav\0*.webm\0*.wma\0*.wmv\0*.wv\0*.xml\0\0"
_global_script_prefix = "SG_"
_global_script_item_name_prefix = "sg"
_separator = ":"
_superitem_name_prefix = _global_script_item_name_prefix .. _separator
_proj_renderpath = reaper.GetProjectPath(_api_current_project)
_superitem_bg_img_filename = "sg-bg-superitem.png"
_superitem_bg_img_path = _proj_renderpath .. _os_path_separator .. _superitem_bg_img_filename
_restored_item_bg_img_filename = "sg-bg-restored.png"
_restored_item_bg_img_path = _proj_renderpath .. _os_path_separator .. _restored_item_bg_img_filename
_restored_instance_bg_img_filename = "sg-bg-restoredinstance.png"
_restored_instance_bg_img_path = _proj_renderpath .. _os_path_separator .. _restored_instance_bg_img_filename
_pool_key_prefix = "pool-"
_all_pool_ids_with_active_sizing_regions_key = "pool-ids-with-active-sizing-regions"
_pool_contained_item_states_key_suffix = ":contained-item-states"
_pool_last_glue_contained_item_states_key_suffix = ":last-glue-contained-item-states"
_pool_parent_position_key_suffix = ":first-parent-instance-position"
_pool_parent_length_key_suffix = ":first-parent-instance-length"
_instance_pool_id_key_suffix = "instance-pool-id"
_parent_pool_id_key_suffix = "parent-pool-id"
_last_pool_id_key_suffix = "last-pool-id"
_preglue_active_take_guid_key_suffix = "preglue-active-take-guid"
_superglue_active_take_key_suffix = "_superitem-superglue-active-take"
_glue_data_key_suffix = ":glue"
_edit_data_key_suffix = ":pre-edit"
_superitem_params_suffix = "-superitem-params"
_parent_pool_ids_data_key_suffix = ":parent-pool-ids"
_descendant_pool_ids_key_suffix = ":descendant-pool-ids"
_superitem_preglue_state_suffix = ":preglue-state-chunk"
_first_child_delta_to_superitem_position_key_suffix = ":restored-items-position-offset"
_freshly_depooled_superitem_flag = ":freshly-depooled"
_postglue_action_step = "postglue"
_preedit_action_step = "preedit"
_superitem_name_default_prefix = "^" .. _global_script_item_name_prefix .. "%:%d+"
_nested_item_default_name = '%[".+%]'
_double_quotation_mark = "\u{0022}"
_msg_type_ok = 0
_msg_type_ok_cancel = 1
_msg_type_yes_no = 4
_msg_response_ok = 1
_msg_response_cancel = 2
_msg_response_yes = 6
_msg_response_no = 7
_msg_change_selected_items = "Change the items selected and try again."
_data_storage_track = reaper.GetMasterTrack(_api_current_project)
_users_time_selection_before_action = {}
_users_item_selection = nil
_active_glue_pool_id = nil
_position_start_of_project = 0
_src_offset_default_value = 0
_playrate_default_value = 1.0
_loop_enabled_value = 1.0
_sizing_region_1st_display_num = 0
_superitem_position_delta_during_glue = 0
_superitem_offset_delta_since_last_glue = 0
_restored_items_near_project_start_position_delta = 0
_last_glue_stored_item_states = nil
_preglue_restored_item_states = nil
_unselected_contained_items = nil
_first_restored_item_last_glue_delta_to_parent = nil
_ancestor_pools_params = {}
_edited_pool_last_glue_params = nil
_edited_pool_fresh_glue_params = nil
_edited_pool_post_glue_params = nil
_edited_pool_preedit_params = nil
_current_pool_fresh_glue_params = nil
_current_pool_preedit_params = nil
_position_changed_since_last_glue = false
_offset_changed_since_last_glue = false
_propagation_user_responses = {}
_user_wants_propagation_option = {}
_active_instance_length_has_changed = nil
_reglue_position_change_affect_on_length = nil
_pool_parent_last_glue_length = nil
_user_wants_to_depool_all_siblings = nil
_this_depooled_superitem_has_not_been_edited = nil
_noninstance_label = "noninstance-"
_global_options_section = "MB_SUPERGLUE-OPTIONS"
_global_option_toggle_time_selection_sets_bounds_on_glue_key = "time_selection_sets_superitem_bounds_on_initial_glue_enabled"
_global_option_toggle_auto_increase_channel_count_key = "auto_increase_channel_count_enabled"
_global_option_toggle_item_images_key = "item_images_enabled"
_global_option_toggle_new_superglue_random_color_key = "new_superglue_random_color_enabled"
_global_option_toggle_loop_source_sets_sizing_region_bounds_on_reglue_key = "loop_source_sets_sizing_region_bounds_enabled"
_global_option_toggle_depool_all_siblings_on_reglue_key = "depool_all_siblings_on_reglue_enabled"
_global_option_toggle_depool_all_siblings_on_reglue_warning_key = "depool_all_siblings_on_reglue_warning_enabled"
_global_option_maintain_source_position_default_key = "maintain_source_position_default"
_global_option_propagate_position_default_key = "propagate_position_default"
_global_option_propagate_length_default_key = "propagate_length_default"
_global_option_length_propagation_type_default_key = "length_propagation_type_default"
_global_option_playrate_affects_propagation_default_key = "playrate_affects_propagation_by_default"
_all_global_options_params = {
  {
    ["name"] = "time_selection_sets_superitem_bounds_on_initial_glue",
    ["type"] = "checkbox",
    ["ext_state_key"] = _global_option_toggle_time_selection_sets_bounds_on_glue_key,
    ["option_script_filename"] = "MB_Superglue - Options - Glue - Time selection determines Superitem bounds on initial glue (On-Off).lua",
    ["user_readable_text"] = "Glue: Time selection determines Superitem bounds on initial Superitem creation",
    ["default_value"] = "false"
  },
  {
    ["name"] = "auto_increase_channel_count_with_take_fx",
    ["type"] = "checkbox",
    ["ext_state_key"] = _global_option_toggle_auto_increase_channel_count_key,
    ["option_script_filename"] = "MB_Superglue - Options - Glue - Auto-increase channel count with take FX (On-Off).lua",
    ["user_readable_text"] = "Glue: Auto-increase channel count with take FX",
    ["default_value"] = "false"
  },
  {
    ["name"] = "loop_source_sets_sizing_region_bounds_on_reglue",
    ["type"] = "checkbox",
    ["ext_state_key"] = _global_option_toggle_loop_source_sets_sizing_region_bounds_on_reglue_key,
    ["option_script_filename"] = "MB_Superglue - Options - Reglue - Looped source of Superitem determines Sizing Region bounds (On-Off).lua",
    ["user_readable_text"] = "Reglue: Looped source of Superitem determines Sizing Region bounds",
    ["default_value"] = "true"
  },
  {
    ["name"] = "depool_all_siblings_on_reglue",
    ["type"] = "checkbox",
    ["ext_state_key"] = _global_option_toggle_depool_all_siblings_on_reglue_key,
    ["option_script_filename"] = "MB_Superglue - Options - Reglue - Remove Siblings from Edited Superitem's Pool, giving every Sibling its own new Pool (On-Off).lua",
    ["user_readable_text"] = "Reglue: Remove all sibling instances from pool (disable & undo pooling)",
    ["default_value"] = "false"
  },
  {
    ["name"] = "item_images",
    ["type"] = "checkbox",
    ["ext_state_key"] = _global_option_toggle_item_images_key,
    ["option_script_filename"] = "MB_Superglue - Options - Display - Background images on new Superglue items - Superitems diagonal, contained items horizontal stripes (On-Off).lua",
    ["user_readable_text"] = "Display: Insert item background images on Superglue and Edit, overwriting item notes",
    ["default_value"] = "true"
  },
  {
    ["name"] = "new_superglue_random_color",
    ["type"] = "checkbox",
    ["ext_state_key"] = _global_option_toggle_new_superglue_random_color_key,
    ["option_script_filename"] = "MB_Superglue - Options - Display - Randomly color newly Superglued Superitem (On-Off).lua",
    ["user_readable_text"] = "Display: Set newly glued Superitems to random color",
    ["default_value"] = "true"
  },
  {
    ["name"] = "maintain_source_position_default",
    ["type"] = "dropdown",
    ["ext_state_key"] = _global_option_maintain_source_position_default_key,
    ["option_script_filename"] = "MB_Superglue - Options - Reglue - Audio source position of Siblings is maintained (Enable-Ask-Disable).lua",
    ["user_readable_text"] = "Reglue: Audio source timeline location on Siblings is maintained",
    ["values"] = {
      {"always", "Maintain source location"},
      {"ask", "Ask"},
      {"no", "Source can change location"}
    },
    ["default_value"] = "always"
  },
  {
    ["name"] = "propagate_position_change_default",
    ["type"] = "dropdown",
    ["ext_state_key"] = _global_option_propagate_position_default_key,
    ["option_script_filename"] = "MB_Superglue - Options - Reglue - Position change of Edited Superitem's left edge propagates to Siblings (Enable-Ask-Disable).lua",
    ["user_readable_text"] = "Reglue: Left edge position change of edited Superitem propagates to Siblings",
    ["values"] = {
      {"always", "Always propagate position"},
      {"ask", "Ask"},
      {"no", "Don't propagate position"}
    },
    ["default_value"] = "ask"
  },
  {
    ["name"] = "propagate_length_change_default",
    ["type"] = "dropdown",
    ["ext_state_key"] = _global_option_propagate_length_default_key,
    ["option_script_filename"] = "MB_Superglue - Options - Reglue - Length change of Edited Superitem propagates to Siblings (Enable-Ask-Disable).lua",
    ["user_readable_text"] = "Reglue: Length change of edited Superitem propagates to Siblings",
    ["values"] = {
      {"always", "Always propagate length"},
      {"ask", "Ask"},
      {"no", "Don't propagate length"}
    },
    ["default_value"] = "always"
  },
  {
    ["name"] = "length_propagation_type_default",
    ["type"] = "dropdown",
    ["ext_state_key"] = _global_option_length_propagation_type_default_key,
    ["option_script_filename"] = "MB_Superglue - Options - Reglue - Absolute or relative propagation length change on Siblings (still altered by playrate) (Absolute-Ask-Relative).lua",
    ["user_readable_text"] = "Reglue: Absolute or relative length propagation on Siblings (can still be altered by playrate option)",
    ["values"] = {
      {"always", "Absolute length propagation"},
      {"ask", "Ask"},
      {"no", "Relative length propagation"}
    },
    ["default_value"] = "no"
  },
  {
    ["name"] = "playrate_affects_propagation_by_default",
    ["type"] = "dropdown",
    ["ext_state_key"] = _global_option_playrate_affects_propagation_default_key,
    ["option_script_filename"] = "MB_Superglue - Options - Reglue - Playrate of Siblings affects their length & position propagation values (Enable-Ask-Disable).lua",
    ["user_readable_text"] = "Reglue: Sibling playrate affects Sibling length & position propagation by default",
    ["values"] = {
      {"always", "Playrate always affects propagation"},
      {"ask", "Ask"},
      {"no", "Playrate doesn't affect propagation"}
    },
    ["default_value"] = "always"
  }
}


function logSuperglueProjectData()
  local master_track, retval, master_track_chunk

  master_track = reaper.GetMasterTrack(_api_current_project)
  retval, master_track_chunk = reaper.GetTrackStateChunk(master_track, "", false)

  log(master_track_chunk)
end



function updateOptionValue(option, val)
  local option_toggle_script_filepath, option_toggle_script_command_id, option_is_boolean, integer_val

  option_toggle_script_filepath = _script_path .. option.option_script_filename
  option_toggle_script_command_id = reaper.AddRemoveReaScript(true, _api_command_section_id_main, option_toggle_script_filepath, false)
  option_is_boolean = not option.values

  if option_is_boolean then

    if val == "true" then
      integer_val = 1

    else
      integer_val = 0
    end

    reaper.SetToggleCommandState(_api_command_section_id_main, option_toggle_script_command_id, integer_val)
    reaper.RefreshToolbar2(_api_command_section_id_main, option_toggle_script_command_id)
  end

  reaper.SetExtState(_global_options_section, option.ext_state_key, val, _api_extstate_persist_enabled)
end



function setDefaultOptionValues()
  local this_option_ext_state_key, this_option_exists_in_extstate, this_option_is_not_set_in_extstate

  for i = 1, #_all_global_options_params do
    this_option_ext_state_key = _all_global_options_params[i].ext_state_key
    this_option_exists_in_extstate = reaper.HasExtState(_global_options_section, this_option_ext_state_key)
    this_option_is_not_set_in_extstate = not this_option_exists_in_extstate or this_option_exists_in_extstate == "nil"

    if this_option_is_not_set_in_extstate then
      updateOptionValue(_all_global_options_params[i], _all_global_options_params[i].default_value)
    end
  end
end

setDefaultOptionValues()



function toggleOption(option_name)
  local active_option_idx, active_option, current_val, new_val

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

  updateOptionValue(active_option, new_val)
end


function openOptionsWindow()
  local option_window_widgets, all_option_controls

  option_window_widgets = createOptionsWidgets()

  populateOptionsWidgets(option_window_widgets)

  all_option_controls = populateOptionControls(option_window_widgets)

  populateOptionsEventHandlers(option_window_widgets, all_option_controls)
  populateOptionsWindow(option_window_widgets)
  option_window_widgets.options_window:open{align = "center"}
end


function createOptionsWidgets()
  local option_window_widgets

  option_window_widgets = {
    ["options_window"] = rtk.Window{w = 0.5, maxh = 0.85, title = _script_brand_name .. " Global Options"},
    ["options_window_inner"] = rtk.VBox(),
    ["options_window_top"] = rtk.Container{valign = "center"},
    ["options_window_branding"] = rtk.VBox{halign = "center", padding = "3 5", border = "1px #878787", bg = "#505050"},
    ["options_window_script_name"] = rtk.Text{_script_brand_name, halign = "center", fontscale = 0.8},
    ["options_window_logo"] = rtk.ImageBox{rtk.Image():load(_script_brand_logo_filename, 2), tmargin = 4},
    ["options_window_title"] = rtk.Heading{"Global Options", w = 1, halign = "center", bmargin = 25},
    ["options_viewport"] = rtk.Viewport(),
    ["options_window_content"] = rtk.VBox{padding = "27 38 7"},
    ["option_form_buttons"] = rtk.HBox{w = 1, margin = "40 10 10 10", spacing = 10, halign = "center"},
    ["option_form_submit"] = rtk.Button{"Submit", disabled = true},
    ["option_form_cancel"] = rtk.Button{"Cancel"},
    ["option_footer"] = rtk.HBox{w = 1, halign = "center"},
    ["options_repo_url"] = "https://github.com/MonkeyBars3k/ReaScripts"
  }

  option_window_widgets.option_repo_text = rtk.Text{option_window_widgets.options_repo_url ..  " [click to copy]", w = 1, halign = "center", fontscale = 0.67, color = "#989898"}

  return option_window_widgets
end


function populateOptionsWidgets(option_window_widgets)
  option_window_widgets.option_form_buttons:add(option_window_widgets.option_form_submit)
  option_window_widgets.option_form_buttons:add(option_window_widgets.option_form_cancel)
  option_window_widgets.option_footer:add(option_window_widgets.option_repo_text)
  option_window_widgets.options_window_branding:add(option_window_widgets.options_window_script_name)
  option_window_widgets.options_window_branding:add(option_window_widgets.options_window_logo)
  option_window_widgets.options_window_top:add(option_window_widgets.options_window_branding)
  option_window_widgets.options_window_top:add(option_window_widgets.options_window_title)
end


function populateOptionControls(option_window_widgets)
  local all_option_controls, this_option, this_option_name

  all_option_controls = {}

  for i = 1, #_all_global_options_params do
    this_option = _all_global_options_params[i]
    this_option_name = this_option.name

    if this_option.type == "checkbox" then
      all_option_controls[this_option_name] = getOptionCheckbox(this_option, option_window_widgets.option_form_submit)

    elseif this_option.type == "dropdown" then
      all_option_controls[this_option_name] = getOptionDropdown(this_option, option_window_widgets.option_form_submit)
    end

    option_window_widgets.options_window_content:add(all_option_controls[this_option_name])
  end

  return all_option_controls
end


function populateOptionsEventHandlers(option_window_widgets, all_option_controls)
  option_window_widgets.option_form_cancel.onclick = function()
    option_window_widgets.options_window:close()
  end

  option_window_widgets.option_repo_text.onclick = function()
    reaper.CF_SetClipboard(options_repo_url)

    option_window_widgets.option_repo_text:animate{"color", dst = "#FFFFFF", duration = 0.15}
      :done(function()
          option_window_widgets.option_repo_text:animate{"color", dst = "#FFFFFE", duration = 0.67}
            :done(function()
              option_window_widgets.option_repo_text:animate{"color", dst = "#989898", duration = 0.15}
            end)
      end)
  end

  option_window_widgets.option_form_submit.onclick = function()
    submitOptionChanges(all_option_controls, option_window_widgets.options_window)
  end
end


function populateOptionsWindow(option_window_widgets)
  local content_padding_adjustment, options_window_content_height

  option_window_widgets.options_window_content:add(option_window_widgets.option_form_buttons)
  option_window_widgets.options_window_content:add(option_window_widgets.option_footer)
  option_window_widgets.options_viewport:attr("child", option_window_widgets.options_window_content)
  option_window_widgets.options_window_inner:add(option_window_widgets.options_window_top)
  option_window_widgets.options_window_inner:add(option_window_widgets.options_viewport)
  option_window_widgets.options_window:add(option_window_widgets.options_window_inner)
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
  local option_saved_value, option_dropdown_box, dropdown_label, dropdown_control, dropdown_menu, this_option_value, this_option_value_menu_item

  option_saved_value = reaper.GetExtState(_global_options_section, option.ext_state_key)
  option_dropdown_box = rtk.HBox{spacing = 10}
  dropdown_label = rtk.Text{option.user_readable_text, margin = "15 0 5", wrap = "normal"}
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
  local this_option, this_option_saved_value, this_option_form_value, dropdown, option_has_changed

  for i = 1, #_all_global_options_params do
    this_option = _all_global_options_params[i]
    this_option_saved_value = reaper.GetExtState(_global_options_section, this_option.ext_state_key)

    if this_option.type == "checkbox" then
      this_option_form_value = tostring(all_option_controls[this_option.name].value)

    elseif this_option.type == "dropdown" then
      dropdown = all_option_controls[this_option.name]:get_child(1)
      this_option_form_value = dropdown.selected
    end

    option_has_changed = this_option_form_value ~= this_option_saved_value

    if option_has_changed then
      updateOptionValue(this_option, this_option_form_value)
      resetDePoolAllSiblingsWarning(this_option.ext_state_key)
    end
  end

  options_window:close()
end


function resetDePoolAllSiblingsWarning(ext_state_key)

  if ext_state_key == _global_option_toggle_depool_all_siblings_on_reglue_key then
    reaper.SetExtState(_global_options_section, _global_option_toggle_depool_all_siblings_on_reglue_warning_key, "true", _api_extstate_persist_enabled)
  end
end


function openItemInfoWindow()
  local selected_item_count, selected_superitem

  selected_item_count = reaper.CountSelectedMediaItems(_api_current_project)

  if selected_item_count == false then return end

  if selected_item_count > 1 then
    reaper.ShowMessageBox("Select only one item and try again.", "You have more than one item selected.", _msg_type_ok)

    return
  end

  selected_item = reaper.GetSelectedMediaItem(_api_current_project, 0)

  handleItemInfoWindow(selected_item)
end


function handleItemInfoWindow(selected_item)
  local selected_superitem_instance_pool_id, this_is_superitem, selected_item_parent_pool_id, this_is_child_item, selected_item_params

  selected_superitem_instance_pool_id = storeRetrieveItemData(selected_item, _instance_pool_id_key_suffix)
  this_is_superitem = selected_superitem_instance_pool_id and selected_superitem_instance_pool_id ~= ""
  selected_item_parent_pool_id = storeRetrieveItemData(selected_item, _parent_pool_id_key_suffix)
  this_is_child_item = selected_item_parent_pool_id and selected_item_parent_pool_id ~= ""

  if not this_is_superitem and not this_is_child_item then
    reaper.ShowMessageBox("Select a Superitem or contained item and try again.", _script_brand_name .. ": The item selected is not associated with " .. _script_brand_name .. ".", _msg_type_ok)

    return
  end

  if this_is_superitem then
    selected_item_params = prepareItemInfo(selected_superitem_instance_pool_id, selected_item_parent_pool_id)

  elseif this_is_child_item then
    selected_item_params = {
      {
        "Parent Pool ID: ",
        selected_item_parent_pool_id
      }
    }
  end

  for i = 1, #selected_item_params do

    if not selected_item_params[i][2] or selected_item_params[i][2] == "" then
      selected_item_params[i][2] = "none"
    end
  end

  populateItemInfoWindow(selected_item, selected_item_params)
end


function prepareItemInfo(selected_superitem_instance_pool_id, selected_item_parent_pool_id)
  local selected_superitem_descendant_pool_ids, retval, stored_item_state_chunks, selected_superitem_descendant_pool_ids_list, selected_superitem_contained_items_count, selected_item_params

  selected_superitem_descendant_pool_ids = storeRetrievePoolData(selected_superitem_instance_pool_id, _descendant_pool_ids_key_suffix)
  retval, selected_superitem_descendant_pool_ids = serpent.load(selected_superitem_descendant_pool_ids)
  stored_item_state_chunks = storeRetrievePoolData(selected_superitem_instance_pool_id, _pool_contained_item_states_key_suffix)
  retval, stored_item_state_chunks = serpent.load(stored_item_state_chunks)
  selected_superitem_descendant_pool_ids_list = stringifyArray(selected_superitem_descendant_pool_ids)
  selected_superitem_contained_items_count = getTableSize(stored_item_state_chunks)
  selected_item_params = {
    {
      "Pool ID: ",
      selected_superitem_instance_pool_id
    },
    {
      "Parent Pool ID: ",
      selected_item_parent_pool_id
    },
    {
      "Descendant (recursively contained instances) Pool IDs: ",
      selected_superitem_descendant_pool_ids_list
    },
    {
      "No. of directly contained items: ",
      selected_superitem_contained_items_count
    },
    {
      "Pool #" .. selected_superitem_instance_pool_id .. " Sibling positions: ",
      getSiblingPositions(selected_superitem_instance_pool_id)
    }
  }

  return selected_item_params
end


function storeRetrievePoolData(pool_id, key_suffix, new_value)
  local is_store, is_retrieve, key, retval, stored_value

  is_store = new_value
  is_retrieve = not new_value
  key = _pool_key_prefix .. pool_id .. key_suffix

  if is_store then
    storeRetrieveProjectData(key, new_value)

  elseif is_retrieve then
    retval, stored_value = storeRetrieveProjectData(key)
  end

  return stored_value
end


function getSiblingPositions(pool_id)
  local sibling_locations_text, all_items_count, this_sibling_num, this_item, this_instance_pool_id, this_active_take, retval, this_active_take_name, this_instance_position_time, measures, beats_since_new_bar

  sibling_locations_text = ""
  all_items_count = reaper.CountMediaItems(_api_current_project)
  this_sibling_num = 1

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)
    this_instance_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)

    if this_instance_pool_id and this_instance_pool_id ~= "" and this_instance_pool_id == pool_id then
      this_active_take = reaper.GetActiveTake(this_item)
      retval, this_active_take_name = reaper.GetSetMediaItemTakeInfo_String(this_active_take, _api_take_name_key, "", false)
      this_instance_position_time = reaper.GetMediaItemInfo_Value(this_item, _api_item_position_key)
      measures, beats_since_new_bar = convertSecondsToMusicTime(this_instance_position_time)
      sibling_locations_text = sibling_locations_text .. this_sibling_num .. ":  " .. this_active_take_name .. " – " .. measures .. "." .. beats_since_new_bar .. " / " .. round(this_instance_position_time, 3) .. "s" .. "\r\n"
      this_sibling_num = this_sibling_num + 1
    end
  end

  if sibling_locations_text == "" then
    sibling_locations_text = "none"
  end

  return sibling_locations_text
end


function convertSecondsToMusicTime(duration_in_seconds)
  local retval, measures, cml, fullbeats, beats_since_new_bar

  retval, measures, cml, fullbeats = reaper.TimeMap2_timeToBeats(_api_current_project, duration_in_seconds)
  beats_since_new_bar = fullbeats % measures

  return measures, round(beats_since_new_bar, 3)
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

  data_param_key = _api_data_key .. _global_script_prefix .. key
  retval, state_data_val = reaper.GetSetMediaTrackInfo_String(_data_storage_track, data_param_key, val, store_or_retrieve_state_data)

  return retval, state_data_val
end


function populateItemInfoWindow(selected_item, selected_item_params)
  local item_info_window, item_info_viewport, item_info_content, item_info_title, item_info, item_info_text, item_info_content_height

  item_info_window = rtk.Window{w = 0.3, maxh = 0.85, title = _script_brand_name .. " Item Info"}
  item_info_viewport = rtk.Viewport{halign = "center", padding = "0 38"}
  item_info_content = rtk.VBox{padding = "27 0 7"}
  item_info_title = rtk.Heading{_script_brand_name .. " Item Info", w = 1, bmargin = 35, halign = "center"}
  item_info_name = rtk.Text{getSetItemName(selected_item), w = 1, halign = "center", textalign = "center", bmargin = 20, fontscale = 1.2, wrap = "normal", color = "#599D8E"}
  item_info = ""

  for i = 1, #selected_item_params do
    item_info = item_info .. selected_item_params[i][1] .. "\n" .. selected_item_params[i][2] .. "\n\n"
  end
  
  item_info_text = rtk.Text{item_info, halign = "center", textalign = "left", wrap = "normal"}

  item_info_content:add(item_info_title)
  item_info_content:add(item_info_name)
  item_info_content:add(item_info_text)
  item_info_viewport:attr("child", item_info_content)
  item_info_window:add(item_info_viewport)
  item_info_window:open{align = "center"}
end


function initSuperglue()
  local selected_item_count, restored_items_pool_id, selected_items, first_selected_item, first_selected_item_track, superitem

  selected_item_count = initAction("glue")

  if not selected_item_count then return end

  restored_items_pool_id = getFirstParentPoolIdFromSelectedItems(selected_item_count)
  _active_glue_pool_id = restored_items_pool_id
  selected_items, first_selected_item = getSelectedItems(selected_item_count)
  first_selected_item_track = reaper.GetMediaItemTrack(first_selected_item)

  if itemsOnMultipleTracksAreSelected(selected_item_count) == true or
    superitemSelectionIsInvalid(selected_item_count, "Glue") == true or
    pureMidiItemIsSelected(selected_item_count, first_selected_item_track) == true then
      
      return
  end

  if restored_items_pool_id then
    handleRemovedItems(restored_items_pool_id, selected_items)
  end

  superitem = triggerSuperglue(selected_items, restored_items_pool_id, first_selected_item_track)
  
  if superitem then
    exclusiveSelectItem(superitem)
  end

  cleanUpAction(_glue_undo_block_string, restored_items_pool_id)
end


function initAction(action)
  local selected_item_count

  selected_item_count = doPreSuperglueChecks(action)

  if selected_item_count == false then return end

  prepareAction(action)
  
  selected_item_count = reaper.CountSelectedMediaItems(_api_current_project)

  if itemsAreSelected(selected_item_count) == false then return false end

  return selected_item_count
end


function doPreSuperglueChecks(action)
  local selected_item_count

  if renderPathIsValid() == false then return false end

  selected_item_count = reaper.CountSelectedMediaItems(_api_current_project)

  if not selected_item_count or selected_item_count == 0 then return false end

  if not itemsAreSelected(selected_item_count) then return false end

  if requiredLibsAreInstalled() == false then return false end

  copySuperglueBgImagesToProject()

  if action == "glue" then
    
    if checkItemsOffscreen(selected_item_count, action) == true then return false end
  end

  return selected_item_count
end


function renderPathIsValid()
  local platform, win_platform_regex, is_win, win_absolute_path_regex, is_win_absolute_path, is_win_local_path, nix_absolute_path_regex, is_nix_absolute_path, is_other_local_path

  platform = reaper.GetOS()
  win_platform_regex = "^Win"
  is_win = string.match(platform, win_platform_regex)
  win_absolute_path_regex = "^%u%:\\"
  is_win_absolute_path = string.match(_proj_renderpath, win_absolute_path_regex)
  is_win_local_path = is_win and not is_win_absolute_path
  nix_absolute_path_regex = "^/"
  is_nix_absolute_path = string.match(_proj_renderpath, nix_absolute_path_regex)
  is_other_local_path = not is_win and not is_nix_absolute_path
  
  if is_win_local_path or is_other_local_path then
    reaper.ShowMessageBox("Set an absolute path in Project Settings > Media > Path or save your new project and try again.", _script_brand_name .. " needs a valid file render path.", _msg_type_ok)
    
    return false

  else
    return true
  end
end


function itemsAreSelected(selected_item_count)
  local no_items_are_selected = selected_item_count < 1

  if not selected_item_count or no_items_are_selected then 
    return false

  else
    return true
  end
end


function requiredLibsAreInstalled()
  local can_get_sws_version, sws_version

  can_get_sws_version = reaper.CF_GetSWSVersion ~= nil

  if can_get_sws_version then
    sws_version = reaper.CF_GetSWSVersion()
  end

  if not can_get_sws_version or not sws_version then
    reaper.ShowMessageBox("Please install SWS from https://standingwaterstudios.com/ and try again.", _script_brand_name .. " requires the SWS plugin extension to work.", _msg_type_ok)
    
    return false
  end
end


function copySuperglueBgImagesToProject()
  local project_images_paths, script_image_paths, image_exists

  project_images_paths = {
    ["superitem_bg"] = _superitem_bg_img_path,
    ["restored_item_bg"] = _restored_item_bg_img_path,
    ["restored_instance_bg"] = _restored_instance_bg_img_path
  }

  script_image_paths = {
    ["superitem_bg"] = _script_path .. _superitem_bg_img_filename,
    ["restored_item_bg"] = _script_path .. _restored_item_bg_img_filename,
    ["restored_instance_bg"] = _script_path .. _restored_instance_bg_img_filename
  }

  for image_name, image_path in pairs(project_images_paths) do
    image_exists = fileExists(image_path)

    if not image_exists then
      copyFile(script_image_paths[image_name], project_images_paths[image_name])
    end
  end
end


function checkItemsOffscreen(item_count, action)
  local this_selected_item_is_before_arrange_view, this_selected_item_is_after_arrange_view, offscreen_msg_text_start, offscreen_msg_text_end, offscreen_msg_text_item_type, offscreen_msg_text, items_offscreen_response

  for i = 0, item_count-1 do
    this_selected_item_is_before_arrange_view, this_selected_item_is_after_arrange_view, offscreen_msg_text_start, offscreen_msg_text_end = getOffscreenItemParams(i)

    if this_selected_item_is_before_arrange_view or this_selected_item_is_after_arrange_view then
    
      if action == "glue" then
        offscreen_msg_text_item_type = "selected"
        offscreen_msg_text = _script_brand_name .. ": " .. offscreen_msg_text_start .. offscreen_msg_text_item_type .. offscreen_msg_text_end
        items_offscreen_response = reaper.ShowMessageBox("Select OK to continue with the items selected or Cancel to abort.", offscreen_msg_text, _msg_type_ok_cancel)

        if items_offscreen_response == _msg_response_ok then
          return false

        else
          return true
        end

      elseif action == "Edit" or action == "Unglue" then
        offscreen_msg_text_item_type = "restored"
        offscreen_msg_text = offscreen_msg_text_start .. offscreen_msg_text_item_type .. offscreen_msg_text_end

        reaper.ShowMessageBox(offscreen_msg_text, _script_brand_name .. " Warning", _msg_type_ok)

        break
      end
    end
  end
end


function getOffscreenItemParams(i)
  local this_selected_item, this_selected_item_position, this_selected_item_length, this_selected_item_end_point,  arrange_start_time, arrange_end_time, this_selected_item_is_before_arrange_view, this_selected_item_is_after_arrange_view, offscreen_msg_text_start, offscreen_msg_text_end

  this_selected_item = reaper.GetSelectedMediaItem(_api_current_project, i)
  this_selected_item_position = reaper.GetMediaItemInfo_Value(this_selected_item, _api_item_position_key)
  this_selected_item_length = reaper.GetMediaItemInfo_Value(this_selected_item, _api_item_length_key)
  this_selected_item_end_point = this_selected_item_position + this_selected_item_length
  arrange_start_time, arrange_end_time = reaper.GetSet_ArrangeView2(_api_current_project, false, 0, 0)
  this_selected_item_is_before_arrange_view = this_selected_item_position < arrange_start_time
  this_selected_item_is_after_arrange_view = this_selected_item_end_point > arrange_end_time
  offscreen_msg_text_start = "One or more "
  offscreen_msg_text_end = " items extend beyond the current visible Arrange window view."

  return this_selected_item_is_before_arrange_view, this_selected_item_is_after_arrange_view, offscreen_msg_text_start, offscreen_msg_text_end
end


function prepareAction(action)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  if action == "glue" then
    setResetUsersItemSelection(true)
  end
end


function setResetUsersItemSelection(set_reset)
  local set, reset, selected_items_count, this_selected_item

  set = set_reset
  reset = not set_reset

  if set then
    _users_item_selection = {}
    selected_items_count = reaper.CountSelectedMediaItems(_api_current_project)

    for i = 0, selected_items_count-1 do
      this_selected_item = reaper.GetSelectedMediaItem(_api_current_project, i)

      table.insert(_users_item_selection, this_selected_item)
    end

  elseif reset then
    reaper.Main_OnCommand(_command_id_deselect_all_items, _api_command_flag)

    for i = 1, #_users_item_selection do
      reaper.SetMediaItemSelected(_users_item_selection[i], true)
    end
  end
end


function getFirstPoolIdFromSelectedItems()
  local pool_id = getFirstParentPoolIdFromSelectedItems()

  if not pool_id then
    pool_id = getInstancePoolIdFromSelectedItems()
  end

  return pool_id
end


function getFirstParentPoolIdFromSelectedItems()
  local this_item, this_item_parent_pool_id, this_item_has_stored_parent_pool_id

  for i = 1, #_users_item_selection do
    this_item = _users_item_selection[i]
    this_item_parent_pool_id = storeRetrieveItemData(this_item, _parent_pool_id_key_suffix)
    this_item_has_stored_parent_pool_id = this_item_parent_pool_id and this_item_parent_pool_id ~= ""

    if this_item_has_stored_parent_pool_id then

      return this_item_parent_pool_id
    end
  end

  return false
end


function getInstancePoolIdFromSelectedItems()
  local this_item, this_item_instance_pool_id, this_item_has_stored_instance_pool_id

  for i = 1, #_users_item_selection do
    this_item = _users_item_selection[i]
    this_item_instance_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)
    this_item_has_stored_instance_pool_id = this_item_instance_pool_id and this_item_instance_pool_id ~= ""

    if this_item_has_stored_instance_pool_id then

      return this_item_instance_pool_id
    end
  end

  return false
end


function storeRetrieveItemData(item, key_suffix, val)
  local retrieve, store, data_param_key, retval

  retrieve = not val
  store = val
  data_param_key = _api_data_key .. _global_script_prefix .. key_suffix

  if retrieve then
    retval, val = reaper.GetSetMediaItemInfo_String(item, data_param_key, "", false)

    return val

  elseif store then
    reaper.GetSetMediaItemInfo_String(item, data_param_key, val, true)
  end
end


function getSelectedItems(selected_item_count)
  local selected_items, this_item, first_selected_item

  selected_items = {}
  
  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(_api_current_project, i)

    table.insert(selected_items, this_item)

    if not first_selected_item then
      first_selected_item = this_item
    end
  end

  return selected_items, first_selected_item
end


function handleRemovedItems(restored_items_pool_id, selected_items)
  local pool_contained_item_states_key_label, retval, last_glue_stored_item_states_string, last_glue_stored_item_states_table, this_stored_item_guid, this_item_last_glue_state, this_stored_item_is_unmatched, this_selected_item, this_selected_item_guid, this_unmatched_item

  pool_contained_item_states_key_label = _pool_key_prefix .. restored_items_pool_id .. _pool_contained_item_states_key_suffix
  retval, last_glue_stored_item_states_string = storeRetrieveProjectData(pool_contained_item_states_key_label)
    
  if retval then
    retval, last_glue_stored_item_states_table = serpent.load(last_glue_stored_item_states_string)

    for this_stored_item_guid, this_item_last_glue_state in pairs(last_glue_stored_item_states_table) do
      this_stored_item_is_unmatched = true

      for i = 1, #selected_items do
        this_selected_item = selected_items[i]
        this_selected_item_guid = reaper.BR_GetMediaItemGUID(this_selected_item)

        if this_selected_item_guid == this_stored_item_guid then
          this_stored_item_is_unmatched = false

          break
        end
      end

      if this_stored_item_is_unmatched then
        this_unmatched_item = reaper.BR_GetMediaItemByGUID(_api_current_project, this_stored_item_guid)

        if this_unmatched_item then
          addRemoveItemImage(this_unmatched_item, false)
          storeRetrieveItemData(this_unmatched_item, _parent_pool_id_key_suffix, "")
        end
      end
    end
  end
end


function getFirstSelectedItem()
  return reaper.GetSelectedMediaItem(_api_current_project, 0)
end


function itemsOnMultipleTracksAreSelected(selected_item_count)
  local items_on_multiple_tracks_are_selected = detectSelectedItemsOnMultipleTracks(selected_item_count)

  if items_on_multiple_tracks_are_selected == true then 
      reaper.ShowMessageBox(_msg_change_selected_items, _script_brand_name .. " only works on items on a single track.", _msg_type_ok)
      return true
  end
end


function detectSelectedItemsOnMultipleTracks(selected_item_count)
  local item_is_on_different_track_than_previous, this_item, this_item_track, prev_item_track

  item_is_on_different_track_than_previous = false

  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(_api_current_project, i)
    this_item_track = reaper.GetMediaItemTrack(this_item)
    item_is_on_different_track_than_previous = this_item_track and prev_item_track and this_item_track ~= prev_item_track
  
    if item_is_on_different_track_than_previous == true then
      return item_is_on_different_track_than_previous
    end
    
    prev_item_track = this_item_track
  end
end


function superitemSelectionIsInvalid(selected_item_count, action)
  local selected_item_groups, superitems, restored_items, siblings_are_selected, recursive_superitem_is_being_glued

  selected_item_groups = getSelectedSuperglueItemTypes(selected_item_count, {"superitem", "restored"})
  superitems = selected_item_groups["superitem"]["selected_items"]
  restored_items = selected_item_groups["restored"]["selected_items"]
  recursive_superitem_is_being_glued = recursiveSuperitemIsBeingGlued(superitems, restored_items) == true
  siblings_are_selected = detectSiblings(restored_items)

  if recursive_superitem_is_being_glued then return true end

  if siblings_are_selected then
    reaper.ShowMessageBox(_msg_change_selected_items, _script_brand_name .. " can only " .. action .. " one pool instance at a time.", _msg_type_ok)
    setResetUsersItemSelection(false)

    return true
  end
end


function getSelectedSuperglueItemTypes(selected_item_count, requested_types)
  local item_types_data, this_item, superitem_pool_id, restored_item_pool_id, this_requested_item_type

  item_types_data = getItemTypes()

  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(_api_current_project, i)
    superitem_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)
    restored_item_pool_id = storeRetrieveItemData(this_item, _parent_pool_id_key_suffix)
    item_types_data["superitem"]["is"] = superitem_pool_id and superitem_pool_id ~= ""
    item_types_data["restored"]["is"] = restored_item_pool_id and restored_item_pool_id ~= ""
    item_types_data["nonsuperitem"]["is"] = not item_types_data["superitem"]["is"]
    item_types_data["child_instance"]["is"] = item_types_data["superitem"]["is"] and item_types_data["restored"]["is"]
    item_types_data["parent_instance"]["is"] = item_types_data["superitem"]["is"] and not item_types_data["restored"]["is"]

    for j = 1, #requested_types do
      this_requested_item_type = requested_types[j]
      
      if item_types_data[this_requested_item_type]["is"] then
        table.insert(item_types_data[this_requested_item_type]["selected_items"], this_item)
      end
    end
  end

  return item_types_data
end


function getItemTypes()
  local item_types, item_types_data, this_item_type

  item_types = {"superitem", "restored", "nonsuperitem", "child_instance", "parent_instance"}
  item_types_data = {}

  for i = 1, #item_types do
    this_item_type = item_types[i]
    item_types_data[this_item_type] = {
      ["selected_items"] = {}
    }
  end

  return item_types_data
end


function detectSiblings(restored_items)
  local siblings_are_selected, this_restored_item, this_restored_item_parent_pool_id, this_is_2nd_or_later_restored_item_with_pool_id, this_item_belongs_to_different_pool_than_active_edit, last_restored_item_parent_pool_id 

  siblings_are_selected = false

  for i = 1, #restored_items do
    this_restored_item = restored_items[i]
    this_restored_item_parent_pool_id = storeRetrieveItemData(this_restored_item, _parent_pool_id_key_suffix)
    this_is_2nd_or_later_restored_item_with_pool_id = last_restored_item_parent_pool_id and last_restored_item_parent_pool_id ~= ""
    this_item_belongs_to_different_pool_than_active_edit = this_restored_item_parent_pool_id ~= last_restored_item_parent_pool_id

    if this_is_2nd_or_later_restored_item_with_pool_id then

      if this_item_belongs_to_different_pool_than_active_edit then
        siblings_are_selected = true

        break
      end

    else
      last_restored_item_parent_pool_id = this_restored_item_parent_pool_id
    end
  end

  return siblings_are_selected
end


function recursiveSuperitemIsBeingGlued(superitems, restored_items)
  local this_superitem, this_superitem_instance_pool_id, this_restored_item, this_restored_item_parent_pool_id, this_restored_item_is_from_same_pool_as_selected_superitem

  for i = 1, #superitems do
    this_superitem = superitems[i]
    this_superitem_instance_pool_id = storeRetrieveItemData(this_superitem, _instance_pool_id_key_suffix)

    for j = 1, #restored_items do
      this_restored_item = restored_items[j]
      this_restored_item_parent_pool_id = storeRetrieveItemData(this_restored_item, _parent_pool_id_key_suffix)
      this_restored_item_is_from_same_pool_as_selected_superitem = this_superitem_instance_pool_id == this_restored_item_parent_pool_id
      
      if this_restored_item_is_from_same_pool_as_selected_superitem then
        reaper.ShowMessageBox(_msg_change_selected_items, _script_brand_name .. " can't glue a Superitem to an instance from the same pool being Edited – that could destroy the universe!", _msg_type_ok)
        setResetUsersItemSelection(false)

        return true
      end
    end
  end
end


function pureMidiItemIsSelected(selected_item_count, first_selected_item_track)
  local this_item, this_item_take, midi_item_is_selected

  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(_api_current_project, i)
    this_item_take = reaper.GetActiveTake(this_item)
    midi_item_is_selected = midiItemIsSelected(this_item)

    if midi_item_is_selected then

      break
    end
  end

  if midi_item_is_selected == true then

    return virtualInstrumentIsInactive(this_item_take, first_selected_item_track)

  elseif midi_item_is_selected == "abort" then

    return true
  end
end


function midiItemIsSelected(item)
  local active_take, active_take_is_midi

  active_take = reaper.GetActiveTake(item)

  if not active_take then
    throwOfflineTakeWarning(false, true)

    return "abort"
  end

  active_take_is_midi = reaper.TakeIsMIDI(active_take)

  if active_take and active_take_is_midi then
    return true

  else
    return false
  end
end


function throwOfflineTakeWarning(recommend_undo, is_restored_item)
  local item_string, msg

  if is_restored_item then
    item_string = "restored item"

  else
    item_string = "Superitem"
  end

  if recommend_undo then
    msg = "It's recommended to undo, remove your " .. item_string .. "'s inactive takes manually, and try again."

  else
    msg = "Aborting."
  end

  reaper.ShowMessageBox(msg, _script_brand_name .. ": Your " .. item_string .. "'s inactive takes are empty, offline or have some other weird setting going on.", _msg_type_ok)
end


function virtualInstrumentIsInactive(item_take, first_selected_item_track)
  local track_virtual_instrument_idx, track_has_virtual_instrument, track_virtual_instrument_is_enabled, track_virtual_instrument_is_muted, take_first_virtual_instrument_idx, take_virtual_instrument_is_enabled, take_virtual_instrument_is_muted, user_response_ignore_muted_virtual_instrument

  track_virtual_instrument_idx = reaper.TrackFX_GetInstrument(first_selected_item_track)
  track_has_virtual_instrument = track_virtual_instrument_idx ~= -1
  track_virtual_instrument_is_enabled = reaper.TrackFX_GetEnabled(first_selected_item_track, track_virtual_instrument_idx)
  track_virtual_instrument_is_muted = track_has_virtual_instrument and not track_virtual_instrument_is_enabled
  take_first_virtual_instrument_idx, take_virtual_instrument_is_enabled = takeVirtualInstrumentIsActive(item_take)
  take_virtual_instrument_is_muted = take_first_virtual_instrument_idx and not take_virtual_instrument_is_enabled

  if track_virtual_instrument_is_muted or take_virtual_instrument_is_muted then
    user_response_ignore_muted_virtual_instrument = reaper.ShowMessageBox("Are you sure you want to Superglue the item(s)?", "The first virtual instrument in the FX chain is bypassed.", _msg_type_yes_no)

    if user_response_ignore_muted_virtual_instrument == _msg_response_no then

      return true
    end
  
  elseif not track_has_virtual_instrument and not take_virtual_instrument_is_enabled then
    reaper.ShowMessageBox("Add/enable a virtual instrument to render audio into the superitem or try a different item selection.", _script_brand_name .. " can't glue pure MIDI without a virtual instrument.", _msg_type_ok)

    return true
  end
end


function takeVirtualInstrumentIsActive(item_take)
  local take_fx_count, retval, take_fx_type, take_fx_is_virtual_instrument, take_first_virtual_instrument_idx, take_first_virtual_instrument_is_enabled

  take_fx_count = reaper.TakeFX_GetCount(item_take)

  for i = 0, take_fx_count-1 do
    retval, take_fx_type = reaper.TakeFX_GetNamedConfigParm(item_take, i, "fx_type")
    take_fx_is_virtual_instrument = string.match(take_fx_type, "i$")

    if take_fx_is_virtual_instrument then
      take_first_virtual_instrument_idx = i

      break
    end
  end

  if take_first_virtual_instrument_idx then
    take_first_virtual_instrument_is_enabled = reaper.TakeFX_GetEnabled(item_take, take_first_virtual_instrument_idx)

    return take_first_virtual_instrument_idx, take_first_virtual_instrument_is_enabled
  end
end


function triggerSuperglue(selected_items, restored_items_pool_id, first_selected_item_track)
  local this_is_reglue, superitem

  this_is_reglue = restored_items_pool_id

  if this_is_reglue then
    superitem = handleReglue(selected_items, first_selected_item_track, restored_items_pool_id)
  else
    superitem = handleGlue(selected_items, first_selected_item_track, nil, nil, nil, nil)
  end

  addRemoveItemImage(superitem, "superitem")

  return superitem
end


function exclusiveSelectItem(item)
  if item then
    reaper.Main_OnCommand(_command_id_deselect_all_items, _api_command_flag)
    reaper.SetMediaItemSelected(item, true)
  end
end


function cleanUpAction(undo_block_string, restored_items_pool_id)

  if restored_items_pool_id then
    undo_block_string = undo_block_string .. " - Pool #" .. restored_items_pool_id
  end

  refreshUI()
  reaper.Undo_EndBlock(undo_block_string, _api_include_all_undo_states)
end


function refreshUI()
  reaper.PreventUIRefresh(-1)
  reaper.UpdateTimeline()
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(true)
end


function handleGlue(selected_items, first_selected_item_track, pool_id, sizing_region_guid, depool_superitem_params, this_is_ancestor_superitem_update)
  local this_is_depool, first_selected_item, first_selected_item_name, sizing_params, this_is_reglue, selected_items_pool_params, offset_position, superitem

  this_is_depool = depool_superitem_params ~= nil
  first_selected_item = getFirstSelectedItem()
  first_selected_item_name = getSetItemName(first_selected_item)

  reaper.Main_OnCommand(_command_id_deselect_all_items, _api_command_flag)

  pool_id, sizing_params, this_is_reglue = setUpGlue(depool_superitem_params, this_is_ancestor_superitem_update, first_selected_item_track, pool_id, sizing_region_guid, selected_items)
  selected_items_pool_params = handlePreglueItems(selected_items, pool_id, sizing_params, this_is_reglue, this_is_ancestor_superitem_update, this_is_depool)
  superitem = glueSelectedItemsIntoSuperitem()
  
  handlePostGlue(selected_items, pool_id, first_selected_item_name, superitem, selected_items_pool_params, sizing_params, this_is_reglue, this_is_ancestor_superitem_update, offset_position)

  return superitem
end


function getSetItemName(item, new_name, add_or_remove)
  local set, get, add, remove, item_has_no_takes, take, current_name

  set = new_name
  get = not new_name
  add = add_or_remove == true
  remove = add_or_remove == false

  item_has_no_takes = reaper.GetMediaItemNumTakes(item) < 1

  if item_has_no_takes then return end

  take = reaper.GetActiveTake(item)

  if take then
    current_name = reaper.GetTakeName(take)

    if set then
      if add then
        new_name = current_name .. " " .. new_name

      elseif remove then
        new_name = string.gsub(current_name, new_name, "")
      end

      reaper.GetSetMediaItemTakeInfo_String(take, _api_take_name_key, new_name, true)

      return new_name, take

    elseif get then
      return current_name, take
    end
  end
end


function setUpGlue(depool_superitem_params, this_is_ancestor_superitem_update, first_selected_item_track, pool_id, sizing_region_guid, selected_items)
  local this_is_new_glue, this_is_depool, this_is_reglue, sizing_params, global_option_toggle_depool_all_siblings_on_reglue

  this_is_new_glue = not pool_id
  this_is_depool = depool_superitem_params
  this_is_reglue = pool_id ~= nil

  if this_is_new_glue then
    pool_id = handlePoolId()
    sizing_params = handleNewGlueSizing(selected_items, this_is_depool, pool_id, depool_superitem_params, first_selected_item_track)

  elseif this_is_reglue then
    sizing_params = setUpReglue(this_is_ancestor_superitem_update, first_selected_item_track, pool_id, sizing_region_guid, selected_items)
    global_option_toggle_depool_all_siblings_on_reglue = reaper.GetExtState(_global_options_section, _global_option_toggle_depool_all_siblings_on_reglue_key)

    if global_option_toggle_depool_all_siblings_on_reglue == "true" then
      _preglue_restored_item_states = storeRetrievePoolData(pool_id, _pool_contained_item_states_key_suffix)
    end
  end

  return pool_id, sizing_params, this_is_reglue
end


function handlePoolId()
  local retval, last_pool_id, new_pool_id
  
  retval, last_pool_id = storeRetrieveProjectData(_last_pool_id_key_suffix)
  new_pool_id = incrementPoolId(last_pool_id)

  storeRetrieveProjectData(_last_pool_id_key_suffix, new_pool_id)

  return new_pool_id
end


function handleNewGlueSizing(selected_items, this_is_depool, pool_id, depool_superitem_params, first_selected_item_track)
  local global_option_time_selection_sets_bounds_enabled, sizing_params
  
  global_option_time_selection_sets_bounds_enabled = reaper.GetExtState(_global_options_section, _global_option_toggle_time_selection_sets_bounds_on_glue_key)

  if global_option_time_selection_sets_bounds_enabled == "true" then
    _users_time_selection_before_action.position, _users_time_selection_before_action.end_point = reaper.GetSet_LoopTimeRange(false, false, nil, nil, false)
    sizing_params = {
      ["position"] = _users_time_selection_before_action.position,
      ["length"] = _users_time_selection_before_action.end_point - _users_time_selection_before_action.position,
      ["end_point"] = _users_time_selection_before_action.end_point
    }

  elseif global_option_time_selection_sets_bounds_enabled == "false" then
    sizing_params = getBoundsFromItems(selected_items)
  end

  if this_is_depool then
    sizing_params = setUpDePool(pool_id, depool_superitem_params, first_selected_item_track)

  else
    instantiateDummySizingItem(sizing_params, first_selected_item_track)
  end

  return sizing_params
end


function getBoundsFromItems(items)
  local last_item_position, last_item_length, items_params

  last_item_position = reaper.GetMediaItemInfo_Value(items[#items], _api_item_position_key, "", false)
  last_item_length = reaper.GetMediaItemInfo_Value(items[#items], _api_item_length_key, "", false)
  items_params = {
    ["position"] = reaper.GetMediaItemInfo_Value(items[1], _api_item_position_key, "", false),
    ["end_point"] = last_item_position + last_item_length
  }
  items_params.length = items_params.end_point - items_params.position

  return items_params
end


function setUpDePool(pool_id, depool_superitem_params, first_selected_item_track)
  local sizing_params

  _last_glue_stored_item_states = storeRetrievePoolData(pool_id, _pool_contained_item_states_key_suffix)
  sizing_params = {
    ["position"] = depool_superitem_params.position,
    ["end_point"] = depool_superitem_params.end_point
  }
  sizing_params.length = sizing_params.end_point - sizing_params.position

  storeRetrievePoolData(pool_id, _pool_last_glue_contained_item_states_key_suffix, _last_glue_stored_item_states)
  instantiateDummySizingItem(sizing_params, first_selected_item_track)

  return sizing_params
end


function instantiateDummySizingItem(sizing_params, first_selected_item_track)
  local dummy_sizing_item = reaper.AddMediaItemToTrack(first_selected_item_track)

  reaper.SetMediaItemPosition(dummy_sizing_item, sizing_params.position, _api_dont_refresh_ui)
  reaper.SetMediaItemLength(dummy_sizing_item, sizing_params.length, _api_dont_refresh_ui)
  reaper.SetMediaItemSelected(dummy_sizing_item, true)
end


function incrementPoolId(last_pool_id)
  local this_is_first_glue_in_project, new_pool_id

  this_is_first_glue_in_project = not last_pool_id or last_pool_id == ""

  if this_is_first_glue_in_project then
    new_pool_id = 1

  else
    last_pool_id = tonumber(last_pool_id)
    new_pool_id = math.floor(last_pool_id + 1)
  end

  return new_pool_id
end


function setUpReglue(this_is_ancestor_superitem_update, first_selected_item_track, pool_id, sizing_region_guid, selected_items)
  local user_selected_instance_is_being_reglued, sizing_params

  user_selected_instance_is_being_reglued = not this_is_ancestor_superitem_update
  _pool_parent_last_glue_length = storeRetrievePoolData(pool_id, _pool_parent_length_key_suffix)
  _pool_parent_last_glue_length = tonumber(_pool_parent_last_glue_length)

  if user_selected_instance_is_being_reglued then
    sizing_params = setUpUserSelectedInstanceReglueSizing(sizing_region_guid, first_selected_item_track, pool_id)

  elseif this_is_ancestor_superitem_update then
    sizing_params = setUpParentReglueSizing(first_selected_item_track, pool_id, selected_items)
  end
    
  return sizing_params
end


function setUpUserSelectedInstanceReglueSizing(sizing_region_guid, first_selected_item_track, pool_id)
  local sizing_params, is_active_superitem_reglue, time_selection_start, time_selection_end, time_selection_was_set_by_code

  sizing_params = getSetSizingRegion(sizing_region_guid)
  is_active_superitem_reglue = sizing_params

  if is_active_superitem_reglue then
    instantiateDummySizingItem(sizing_params, first_selected_item_track)
    getSetSizingRegion(sizing_region_guid, "delete")
    handleSizingRegionPoolData(nil, pool_id, "delete")
  end

  return sizing_params
end


function getSetSizingRegion(sizing_region_guid_or_pool_id, params_or_delete)
  local get_or_delete, set, region_idx, retval, sizing_region_params, sizing_region_guid
 
  get_or_delete = not params_or_delete or params_or_delete == "delete"
  set = params_or_delete and params_or_delete ~= "delete"
  region_idx = 0

  repeat

    if get_or_delete then
      retval, sizing_region_params = getParamsFrom_OrDelete_SizingRegion(sizing_region_guid_or_pool_id, params_or_delete, region_idx)

      if sizing_region_params then
        return sizing_region_params
      end

    elseif set then
      sizing_region_params = params_or_delete
      retval, sizing_region_guid = addSizingRegion(sizing_region_guid_or_pool_id, sizing_region_params, region_idx)

      if sizing_region_guid then
        return sizing_region_guid
      end
    end

    region_idx = region_idx + 1

  until retval == 0
end


function getParamsFrom_OrDelete_SizingRegion(sizing_region_guid_or_pool_id, params_or_delete, region_idx)
  local get, delete, sizing_region_guid, sizing_region_api_key, stored_guid_retval, this_region_guid, this_region_belongs_to_active_pool, sizing_region_params, retval, is_region 

  get = not params_or_delete
  delete = params_or_delete == "delete"
  sizing_region_guid = sizing_region_guid_or_pool_id
  sizing_region_api_key = _api_project_region_guid_key_prefix .. region_idx
  stored_guid_retval, this_region_guid = reaper.GetSetProjectInfo_String(_api_current_project, sizing_region_api_key, "", false)
  this_region_belongs_to_active_pool = this_region_guid == sizing_region_guid

  if this_region_belongs_to_active_pool then

    if get then
      sizing_region_params = {
        ["idx"] = region_idx
      }
      retval, is_region, sizing_region_params.position, sizing_region_params.end_point = reaper.EnumProjectMarkers3(_api_current_project, region_idx)
      sizing_region_params.length = sizing_region_params.end_point - sizing_region_params.position

      return retval, sizing_region_params

    elseif delete then
      reaper.DeleteProjectMarkerByIndex(_api_current_project, region_idx, true)

      retval = 0

      return retval
    end

  else
    return retval
  end
end


function addSizingRegion(sizing_region_guid_or_pool_id, params_or_delete, region_idx)
  local params, pool_id, sizing_region_name, sizing_region_label_num, retval, is_region, this_region_position, this_region_end_point, this_region_name, this_region_label_num, this_region_is_active

  params = params_or_delete
  params.end_point = params.position + params.length
  pool_id = sizing_region_guid_or_pool_id
  sizing_region_name = _sizing_region_label_prefix .. pool_id .. _sizing_region_label_suffix
  sizing_region_label_num = reaper.AddProjectMarker2(_api_current_project, true, params.position, params.end_point, sizing_region_name, _sizing_region_1st_display_num, _sizing_region_color)
  retval, is_region, this_region_position, this_region_end_point, this_region_name, this_region_label_num = reaper.EnumProjectMarkers3(_api_current_project, region_idx)

  if is_region then
    this_region_is_active = this_region_label_num == sizing_region_label_num

    if this_region_is_active then
      return handleSizingRegionPoolData(region_idx, pool_id)

    else
      return retval
    end

  else
    return retval
  end
end


function handleSizingRegionPoolData(region_idx, pool_id, delete)
  local all_pool_ids_with_active_sizing_regions_retval, all_pool_ids_with_active_sizing_regions, sizing_region_api_key, sizing_region_guid_retval, sizing_region_guid

  all_pool_ids_with_active_sizing_regions_retval, all_pool_ids_with_active_sizing_regions = storeRetrieveProjectData(_all_pool_ids_with_active_sizing_regions_key)

  if delete == "delete" then
    if all_pool_ids_with_active_sizing_regions then
      retval, all_pool_ids_with_active_sizing_regions = serpent.load(all_pool_ids_with_active_sizing_regions)
      all_pool_ids_with_active_sizing_regions[pool_id] = nil
      all_pool_ids_with_active_sizing_regions = serpent.dump(all_pool_ids_with_active_sizing_regions)

      storeRetrieveProjectData(_all_pool_ids_with_active_sizing_regions_key, all_pool_ids_with_active_sizing_regions)
    end

  else
    sizing_region_api_key = _api_project_region_guid_key_prefix .. region_idx
    sizing_region_guid_retval, sizing_region_guid = reaper.GetSetProjectInfo_String(_api_current_project, sizing_region_api_key, "", false)

    if all_pool_ids_with_active_sizing_regions_retval then
      retval, all_pool_ids_with_active_sizing_regions = serpent.load(all_pool_ids_with_active_sizing_regions)
      all_pool_ids_with_active_sizing_regions[pool_id] = sizing_region_guid

    else
      all_pool_ids_with_active_sizing_regions = {
        [pool_id] = sizing_region_guid
      }
    end

    all_pool_ids_with_active_sizing_regions = serpent.dump(all_pool_ids_with_active_sizing_regions)

    storeRetrieveProjectData(_all_pool_ids_with_active_sizing_regions_key, all_pool_ids_with_active_sizing_regions)

    return retval, sizing_region_guid
  end
end


function setUpParentReglueSizing(first_selected_item_track, pool_id, selected_items)
  local pool_parent_length_key_label, pool_parent_last_glue_position, pool_parent_last_glue_end_point, sizing_params

  pool_parent_last_glue_position = storeRetrievePoolData(pool_id, _pool_parent_position_key_suffix)
  pool_parent_last_glue_position = tonumber(pool_parent_last_glue_position)
  pool_parent_last_glue_end_point = pool_parent_last_glue_position + _pool_parent_last_glue_length
  sizing_params = {
    ["position"] = pool_parent_last_glue_position - _restored_items_near_project_start_position_delta,
    ["length"] = _pool_parent_last_glue_length - _restored_items_near_project_start_position_delta,
    ["end_point"] = pool_parent_last_glue_end_point - _restored_items_near_project_start_position_delta
  }

  instantiateDummySizingItem(sizing_params, first_selected_item_track)

  return sizing_params
end


function handlePreglueItems(selected_items, pool_id, sizing_params, this_is_reglue, this_is_ancestor_superitem_update, this_is_depool)
  local selected_item_states, selected_items_pool_params, last_selected_item_position, last_selected_item_length

  setPreglueItemsData(selected_items, pool_id, sizing_params, this_is_reglue, this_is_depool)

  selected_item_states, selected_items_pool_params = prepareAndGetItemStates(selected_items, pool_id)

  storeItemStates(pool_id, selected_item_states)
  selectDeselectItems(selected_items, true)

  return selected_items_pool_params
end


function setPreglueItemsData(preglue_items, pool_id, sizing_params, this_is_reglue, this_is_depool)
  local this_is_new_glue, global_option_time_selection_sets_bounds_enabled, this_item, this_item_position, first_item_position, first_child_position_delta_to_parent

  this_is_new_glue = not this_is_reglue
  global_option_time_selection_sets_bounds_enabled = reaper.GetExtState(_global_options_section, _global_option_toggle_time_selection_sets_bounds_on_glue_key)

  for i = 1, #preglue_items do
    this_item = preglue_items[i]
    this_item_position = reaper.GetMediaItemInfo_Value(this_item, _api_item_position_key)

    storeRetrieveItemData(this_item, _parent_pool_id_key_suffix, pool_id)

    if i == 1 or this_item_position < first_item_position then
      first_item_position = this_item_position
    end
  end

  if this_is_new_glue and not this_is_depool then
    first_child_position_delta_to_parent = 0

  else
    first_child_position_delta_to_parent = first_item_position - sizing_params.position
  end

  storeRetrievePoolData(pool_id, _first_child_delta_to_superitem_position_key_suffix, first_child_position_delta_to_parent)
end


function prepareAndGetItemStates(items, active_pool_id)
  local selected_item_states, selected_items_pool_params, item, this_item, this_item_instance_pool_id, this_item_parent_pool_id, this_item_guid, this_item_state

  selected_item_states = {}
  selected_items_pool_params = {}

  for i, item in ipairs(items) do
    this_item = items[i]
    this_item_instance_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)
    this_item_parent_pool_id = storeRetrieveItemData(this_item, _parent_pool_id_key_suffix)

    if not this_item_instance_pool_id or this_item_instance_pool_id == "" then
      this_item_instance_pool_id = _noninstance_label .. i
    end

    convertMidiItemToAudio(this_item)

    this_item_guid = reaper.BR_GetMediaItemGUID(item)
    this_item_state = getSetItemStateChunk(this_item)
    selected_item_states[this_item_guid] = this_item_state
    selected_items_pool_params[this_item_instance_pool_id] = {
      ["parent_pool_id"] = this_item_parent_pool_id,
      ["position"] = reaper.GetMediaItemInfo_Value(this_item, _api_item_position_key)
    }
  end

  return selected_item_states, selected_items_pool_params, this_item_instance_pool_id
end


function convertMidiItemToAudio(item)
  local item_takes_count, active_take, this_take_is_midi, retval, active_take_guid

  item_takes_count = reaper.GetMediaItemNumTakes(item)

  if item_takes_count > 0 then
    active_take = reaper.GetActiveTake(item)
    this_take_is_midi = active_take and reaper.TakeIsMIDI(active_take)

    if this_take_is_midi then      
      active_take = reaper.GetActiveTake(item)
      retval, active_take_guid = reaper.GetSetMediaItemTakeInfo_String(active_take, _api_take_guid_key, "", false)

      storeRetrieveItemData(item, _preglue_active_take_guid_key_suffix, active_take_guid)
      reaper.SetMediaItemSelected(item, true)
      reaper.Main_OnCommand(_command_id_apply_track_take_fx_to_items, _api_command_flag)
      reaper.SetMediaItemSelected(item, false)
      cleanNullTakes(item)

    else
      storeRetrieveItemData(item, _preglue_active_take_guid_key_suffix, "")
    end
  end
end


function cleanNullTakes(item, force)
  local item_state = getSetItemStateChunk(item)

  if string.find(item_state, _api_null_takes_val) or force then
    item_state = string.gsub(item_state, _api_null_takes_val, "")

    getSetItemStateChunk(item, item_state)
  end
end


function getSetItemStateChunk(item, state)
  local get, set, retval

  get = not state
  set = state

  if get then
    retval, state = reaper.GetItemStateChunk(item, "", true)

    return state

  elseif set then
    reaper.SetItemStateChunk(item, state, true)
  end
end


function storeItemStates(pool_id, item_states_table)
  item_states_table = serpent.dump(item_states_table)
  
  storeRetrievePoolData(pool_id, _pool_contained_item_states_key_suffix, item_states_table)
end


function selectDeselectItems(items, select_deselect)
  local this_item

  for i = 1, #items do
    this_item = items[i]

    if this_item then 
      reaper.SetMediaItemSelected(this_item, select_deselect)
    end
  end
end


function getSetItemParams(item, params)
  local get, set, track, retval, track_guid, active_take, active_take_num, item_params

  get = not params
  set = params

  if get then
    track = reaper.GetMediaItemTrack(item)
    retval, track_guid = reaper.GetSetMediaTrackInfo_String(track, _api_take_guid_key, "", false)
    active_take = reaper.GetActiveTake(item)

    if active_take then
      active_take_num = reaper.GetMediaItemTakeInfo_Value(active_take, _api_takenumber_key)
    end

    item_params = {
      ["item_guid"] = reaper.BR_GetMediaItemGUID(item),
      ["state"] = getSetItemStateChunk(item),
      ["track_guid"] = track_guid,
      ["active_take_num"] = active_take_num,
      ["position"] = reaper.GetMediaItemInfo_Value(item, _api_item_position_key),
      ["length"] = reaper.GetMediaItemInfo_Value(item, _api_item_length_key),
      ["instance_pool_id"] = storeRetrieveItemData(item, _instance_pool_id_key_suffix),
      ["parent_pool_id"] = storeRetrieveItemData(item, _parent_pool_id_key_suffix)
    }
    item_params.end_point = item_params.position + item_params.length

    if active_take then
      item_params.source_offset = reaper.GetMediaItemTakeInfo_Value(active_take, _api_take_src_offset_key)
    end

    return item_params

  elseif set then
    reaper.SetMediaItemInfo_Value(item, _api_item_position_key, params.position)
    reaper.SetMediaItemInfo_Value(item, _api_item_length_key, params.length)
  end
end


function glueSelectedItemsIntoSuperitem()
  local increase_channel_count_from_take_fx, superitem

  increase_channel_count_from_take_fx = reaper.GetExtState(_global_options_section, _global_option_toggle_auto_increase_channel_count_key)

  if increase_channel_count_from_take_fx == "true" then
    reaper.Main_OnCommand(_command_id_apply_fx_to_items_multichannel, _api_command_flag)
    reaper.Main_OnCommand(_command_id_crop_selected_items_to_active_takes, _api_command_flag)
  end

  reaper.Main_OnCommand(_command_id_glue_ignoring_time_selection_incl_fades, _api_command_flag)

  superitem = getFirstSelectedItem()

  return superitem
end


function handlePostGlue(selected_items, pool_id, first_selected_item_name, superitem, selected_items_pool_params, sizing_params, this_is_reglue, this_is_ancestor_superitem_update)
  local superitem_init_name

  superitem_init_name = handleAddtionalItemCountLabel(selected_items, pool_id, first_selected_item_name)

  handleSuperitemPostGlue(superitem, superitem_init_name, pool_id, sizing_params, this_is_reglue, this_is_ancestor_superitem_update)
  handleDescendantPoolReferences(pool_id, selected_items_pool_params)

  if not this_is_ancestor_superitem_update then
    handleParentPoolReferencesInChildPools(pool_id, selected_items_pool_params)
    deleteUnselectedContainedItems()
  end
end


function handleAddtionalItemCountLabel(selected_items, pool_id, first_selected_item_name)
  local selected_item_count, multiple_user_items_are_selected, other_selected_items_count, is_nested_superitem_name, has_nested_item_name, item_name_addl_count_str, superitem_init_name

  selected_item_count = getTableSize(selected_items)
  multiple_user_items_are_selected = selected_item_count > 1
  other_selected_items_count = selected_item_count - 1
  is_nested_superitem_name = string.find(first_selected_item_name, _superitem_name_default_prefix)
  has_nested_item_name = string.find(first_selected_item_name, _nested_item_default_name)
  
  if multiple_user_items_are_selected then
    item_name_addl_count_str = " +" .. other_selected_items_count ..  " more"

  else
    item_name_addl_count_str = ""
  end

  if is_nested_superitem_name and has_nested_item_name then
    first_selected_item_name = string.match(first_selected_item_name, _superitem_name_default_prefix)
  end

  superitem_init_name = pool_id .. " [" .. _double_quotation_mark .. first_selected_item_name .. _double_quotation_mark .. item_name_addl_count_str .. "]"

  return superitem_init_name
end


function handleSuperitemPostGlue(superitem, superitem_init_name, pool_id, sizing_params, this_is_reglue, this_is_ancestor_superitem_update)
  local this_is_fresh_glue, superitem_active_take, superitem_params

  this_is_fresh_glue = not this_is_reglue
  superitem_active_take = reaper.GetActiveTake(superitem)

  setSuperitemParams(superitem, superitem_active_take, sizing_params, this_is_reglue)

  superitem_params = getSetItemParams(superitem)

  if this_is_fresh_glue then
    renameSuperitemSource(superitem, pool_id)
    setSuperitemColor()

  else
    handleOfflineTake(superitem, "reglued")
  end

  if not _active_instance_length_has_changed then
    _active_instance_length_has_changed = _pool_parent_last_glue_length ~= superitem_params.length
  end

  setSuperitemName(superitem, superitem_init_name)
  handleSuperitemPostGlueData(pool_id, superitem, superitem_params, superitem_active_take)
end


function setSuperitemParams(superitem, superitem_active_take, sizing_params, this_is_reglue)
  local global_option_time_selection_sets_bounds_enabled, user_time_selection_is_active, superitem_new_left_edge, superitem_new_right_edge

  global_option_time_selection_sets_bounds_enabled = reaper.GetExtState(_global_options_section, _global_option_toggle_time_selection_sets_bounds_on_glue_key)
  user_time_selection_is_active = getTableSize(_users_time_selection_before_action) > 0

  if this_is_reglue then
    superitem_new_left_edge = sizing_params.position
    superitem_new_right_edge = sizing_params.end_point

  elseif global_option_time_selection_sets_bounds_enabled == "true" and user_time_selection_is_active then
    superitem_new_left_edge = _users_time_selection_before_action.position
    superitem_new_right_edge = _users_time_selection_before_action.end_point
  end

  if superitem_new_left_edge and superitem_new_right_edge then
    reaper.BR_SetItemEdges(superitem, superitem_new_left_edge, superitem_new_right_edge)
  end
end


function renameSuperitemSource(superitem, pool_id)
  local superitem_active_take, superitem_active_take_source_filepath, superitem_source_new_filepath, superitem_source_new_filepath_extension

  superitem_active_take, superitem_active_take_source_filepath, superitem_source_new_filepath = getSuperitemActiveTakeInfo(superitem, pool_id)

  for i in string.gmatch(superitem_source_new_filepath, "%..+") do
    superitem_source_new_filepath_extension = i
  end

  if fileExists(superitem_source_new_filepath) then
    superitem_source_new_filepath = string.gsub(superitem_source_new_filepath, superitem_source_new_filepath_extension, "-redo" .. superitem_source_new_filepath_extension)

    copyFile(superitem_active_take_source_filepath, superitem_source_new_filepath)
    os.remove(superitem_active_take_source_filepath)

  else
    os.rename(superitem_active_take_source_filepath, superitem_source_new_filepath)
  end

  reaper.BR_SetTakeSourceFromFile2(superitem_active_take, superitem_source_new_filepath, true, true)
  reaper.Main_OnCommand(_command_id_build_missing_peaks, _api_command_flag)
end


function getSuperitemActiveTakeInfo(superitem, pool_id)
  local project_path, superitem_active_take, superitem_active_take_source, superitem_active_take_source_peaks, superitem_active_take_source_filepath, superitem_active_take_source_filename, superitem_source_new_filepath

  project_path = reaper.GetProjectPath()
  superitem_active_take = reaper.GetActiveTake(superitem)
  superitem_active_take_source = reaper.GetMediaItemTake_Source(superitem_active_take)
  superitem_active_take_source_filepath = reaper.GetMediaSourceFileName(superitem_active_take_source)

  for i in string.gmatch(superitem_active_take_source_filepath, _os_path_splitter_pattern) do
    superitem_active_take_source_filename = i
  end

  superitem_source_new_filepath = project_path .. _os_path_separator .. _global_script_item_name_prefix .. _custom_path_separator .. _pool_key_prefix .. pool_id .. _custom_path_separator .. superitem_active_take_source_filename

  return superitem_active_take, superitem_active_take_source_filepath, superitem_source_new_filepath
end


function refreshActiveTakeFlag(item, active_take, pool_id)
  local all_takes, superitem_superglue_active_take_key, this_take

  all_takes = reaper.CountTakes(item)
  superitem_superglue_active_take_key = _api_data_key .. _global_script_prefix .. _pool_key_prefix .. pool_id .. _superglue_active_take_key_suffix

  for i = 0, all_takes-1 do
    this_take = reaper.GetTake(item, i)

    if this_take == active_take then
      reaper.GetSetMediaItemTakeInfo_String(this_take, superitem_superglue_active_take_key, "true", true)

    else
      reaper.GetSetMediaItemTakeInfo_String(this_take, superitem_superglue_active_take_key, "false", true)
    end
  end
end


function setSuperitemName(item, superitem_name_ending)
  local take, new_superitem_name

  take = reaper.GetActiveTake(item)
  new_superitem_name = _superitem_name_prefix .. superitem_name_ending

  reaper.GetSetMediaItemTakeInfo_String(take, _api_take_name_key, new_superitem_name, true)
end


function addRemoveItemImage(item, type_or_remove)
  local item_images_are_enabled = reaper.GetExtState(_global_options_section, _global_option_toggle_item_images_key) == "true"

  if item_images_are_enabled then
    local add, type, remove, img_path

    add = type_or_remove
    type = type_or_remove
    remove = type_or_remove == false

    if add then

      if type == "superitem" then
        img_path = _superitem_bg_img_path

      elseif type == "restored" then
        img_path = _restored_item_bg_img_path

      elseif type == "restored_instance" then
        img_path = _restored_instance_bg_img_path
      end

    elseif remove then
      img_path = ""
    end

    reaper.BR_SetMediaItemImageResource(item, img_path, _api_item_image_full_height)
  end
end


function handleSuperitemPostGlueData(pool_id, superitem, superitem_params, superitem_active_take)
  storeRetrieveSuperitemParams(pool_id, _postglue_action_step, superitem)
  storeRetrieveItemData(superitem, _instance_pool_id_key_suffix, pool_id)
  storeRetrievePoolData(pool_id, _pool_parent_position_key_suffix, superitem_params.position)
  storeRetrievePoolData(pool_id, _pool_parent_length_key_suffix, superitem_params.length)
  storeRetrievePoolData(pool_id, _freshly_depooled_superitem_flag, "false")
  refreshActiveTakeFlag(superitem, superitem_active_take, pool_id)
end


function storeRetrieveSuperitemParams(pool_id, action_step, superitem)
  local retrieve, store, superitem_params_key_label, retval, superitem_params

  retrieve = not superitem
  store = superitem
  superitem_params_key_label = _pool_key_prefix .. pool_id .. _separator .. action_step .. _superitem_params_suffix

  if retrieve then
    retval, superitem_params = storeRetrieveProjectData(superitem_params_key_label)
    retval, superitem_params = serpent.load(superitem_params)

    if superitem_params then
      superitem_params.track = reaper.BR_GetMediaTrackByGUID(_api_current_project, superitem_params.track_guid)
    end

    return superitem_params

  elseif store then
    superitem_params = getSetItemParams(superitem)
    superitem_params = serpent.dump(superitem_params)

    storeRetrieveProjectData(superitem_params_key_label, superitem_params)
  end
end


function setSuperitemColor()
  local global_option_toggle_new_superglue_random_color = reaper.GetExtState(_global_options_section, _global_option_toggle_new_superglue_random_color_key)

  if global_option_toggle_new_superglue_random_color == "true" then
    reaper.Main_OnCommand(_command_id_set_item_to_one_random_color, _api_command_flag)
  end
end


function handleOfflineTake(item, context)
  local active_take, active_src, active_take_is_online, src_filepath, src_exists, src_filename, src_filepath_in_project_folder, user_response, retval, user_chosen_file

  active_take = reaper.GetActiveTake(item)
  active_src = reaper.GetMediaItemTake_Source(active_take)
  active_take_is_online = reaper.CF_GetMediaSourceOnline(active_src)

  if not active_take_is_online then
    src_filepath = reaper.GetMediaSourceFileName(active_src)
    src_exists = fileExists(src_filepath)

    if not src_exists then
      src_filename = getFileNameFromPath(src_filepath)
      src_filepath_in_project_folder = _proj_renderpath .. _os_path_separator .. src_filename
      src_exists = fileExists(src_filepath_in_project_folder)

      if src_exists then
        reaper.BR_SetTakeSourceFromFile2(active_take, src_filepath_in_project_folder, true, true)

      else
        user_response = reaper.ShowMessageBox("Press OK to continue, or Cancel to leave it offline.", "Superglue can't find a media source. Choose a new source file for the offline " .. context .. " item.", _msg_type_ok_cancel)

        if user_response == _msg_response_ok then
          retval, user_chosen_file = reaper.JS_Dialog_BrowseForOpenFiles("Choose a new source file for the offline item.", _proj_renderpath, src_filename, _supported_media_types, false)

          reaper.BR_SetTakeSourceFromFile2(active_take, user_chosen_file, true, true)
        end
      end
    end
  end
end


function handleDescendantPoolReferences(pool_id, contained_items_pool_params)
  local this_pool_descendants, this_contained_item_instance_pool_id, this_contained_item_params, this_selected_item_is_superitem, this_child_pool_descendant_pool_ids, this_pool_descendants_string

  this_pool_descendants = {}

  for this_contained_item_instance_pool_id, this_contained_item_params in pairs(contained_items_pool_params) do
    this_selected_item_is_superitem = not string.find(this_contained_item_instance_pool_id, _noninstance_label)

    if this_selected_item_is_superitem then
      this_child_pool_descendant_pool_ids = storeRetrievePoolData(this_contained_item_instance_pool_id, _descendant_pool_ids_key_suffix)

      table.insert(this_pool_descendants, this_contained_item_instance_pool_id)

      for j = 1, #this_child_pool_descendant_pool_ids do
        table.insert(this_pool_descendants, this_child_pool_descendant_pool_ids[j])
      end
    end
  end

  this_pool_descendants = deduplicateTable(this_pool_descendants)
  this_pool_descendants_string = serpent.dump(this_pool_descendants)

  storeRetrievePoolData(pool_id, _descendant_pool_ids_key_suffix, this_pool_descendants_string)
end


function handleParentPoolReferencesInChildPools(active_pool_id, contained_items_pool_params)
  local this_contained_item_instance_pool_id, this_contained_item_params, this_selected_item_is_superitem

  for this_contained_item_instance_pool_id, this_contained_item_params in pairs(contained_items_pool_params) do
    this_selected_item_is_superitem = not string.find(this_contained_item_instance_pool_id, _noninstance_label)

    if this_selected_item_is_superitem then
      storeParentPoolReferencesInChildPool(this_contained_item_instance_pool_id, active_pool_id)
    end
  end
end


function storeParentPoolReferencesInChildPool(preglue_child_instance_pool_id, active_pool_id)
  local parent_pool_ids_data_key_label, retval, parent_pool_ids_referenced_in_child_pool, this_parent_pool_id, this_parent_pool_id_is_referenced_in_child_pool

  parent_pool_ids_data_key_label = _pool_key_prefix .. preglue_child_instance_pool_id .. _parent_pool_ids_data_key_suffix
  retval, parent_pool_ids_referenced_in_child_pool = storeRetrieveProjectData(parent_pool_ids_data_key_label)

  if retval == false then
    parent_pool_ids_referenced_in_child_pool = {}

  else
    retval, parent_pool_ids_referenced_in_child_pool = serpent.load(parent_pool_ids_referenced_in_child_pool)
  end

  for i = 1, #parent_pool_ids_referenced_in_child_pool do
    this_parent_pool_id = parent_pool_ids_referenced_in_child_pool[i]

    if this_parent_pool_id == active_pool_id then
      this_parent_pool_id_is_referenced_in_child_pool = true
    end
  end

  if not this_parent_pool_id_is_referenced_in_child_pool then
    active_pool_id = tostring(active_pool_id)

    table.insert(parent_pool_ids_referenced_in_child_pool, active_pool_id)

    parent_pool_ids_referenced_in_child_pool = serpent.dump(parent_pool_ids_referenced_in_child_pool)

    storeRetrieveProjectData(parent_pool_ids_data_key_label, parent_pool_ids_referenced_in_child_pool)
  end
end


function deleteUnselectedContainedItems()
  local this_contained_item_outside, this_contained_item_track

  if _unselected_contained_items then

    for i = 1, #_unselected_contained_items do
      this_contained_item_outside = _unselected_contained_items[i]
      this_contained_item_track = reaper.GetMediaItem_Track(this_contained_item_outside)
      
      reaper.DeleteTrackMediaItem(this_contained_item_track, this_contained_item_outside)
    end
  end

  _unselected_contained_items = nil
end


function handleReglue(selected_items, first_selected_item_track, restored_items_pool_id)
  local sizing_region_guid, superitem, superitem_params

  sizing_region_guid = checkSizingRegionExists(selected_items, restored_items_pool_id)

  if not sizing_region_guid then return false end

  cleanUnselectedRestoredItemsFromPool(restored_items_pool_id)

  _edited_pool_last_glue_params = storeRetrieveSuperitemParams(restored_items_pool_id, _postglue_action_step)
  superitem = handleGlue(selected_items, first_selected_item_track, restored_items_pool_id, sizing_region_guid, nil, nil)
  superitem_params = getSetItemParams(superitem)
  superitem_params.updated_src = getSetWipeItemAudioSrc(superitem)
  superitem_params.pool_id = restored_items_pool_id
  superitem = restoreSuperitemState(superitem, superitem_params)
  _edited_pool_fresh_glue_params = superitem_params
  _edited_pool_preedit_params = storeRetrieveSuperitemParams(_edited_pool_fresh_glue_params.pool_id, _preedit_action_step)

  setRegluePositionDeltas(superitem_params)
  adjustPostGlueTakeMarkersAndEnvelopes(superitem, nil, nil, true)
  editAncestors(superitem_params.pool_id, superitem)
  reaper.Main_OnCommand(_command_id_deselect_all_items, _api_command_flag)
  propagateChangesToSuperitems(sizing_region_guid)

  return superitem
end


function cleanUnselectedRestoredItemsFromPool(pool_id)
  local all_items_count, this_item, this_item_is_selected, this_item_parent_pool_id

  all_items_count = reaper.CountMediaItems(_api_current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)
    this_item_is_selected = reaper.IsMediaItemSelected(this_item)

    if not this_item_is_selected then
      this_item_parent_pool_id = storeRetrieveItemData(this_item, _parent_pool_id_key_suffix)

      if this_item_parent_pool_id == pool_id then
        storeRetrieveItemData(this_item, _parent_pool_id_key_suffix, "")
        addRemoveItemImage(this_item, false)
      end
    end
  end
end


function checkSizingRegionExists(selected_items, pool_id)
  local retval, all_pool_ids_with_active_sizing_regions, sizing_region_guid, region_idx, this_region_guid, sizing_region_user_result

  retval, all_pool_ids_with_active_sizing_regions = storeRetrieveProjectData(_all_pool_ids_with_active_sizing_regions_key)
  retval, all_pool_ids_with_active_sizing_regions = serpent.load(all_pool_ids_with_active_sizing_regions)
  sizing_region_guid = all_pool_ids_with_active_sizing_regions[pool_id]
  
  if sizing_region_guid and sizing_region_guid ~= "" then
    region_idx = 0

    repeat
      retval, this_region_guid = reaper.GetSetProjectInfo_String(_api_current_project, _api_project_region_guid_key_prefix .. region_idx, "", false)
      
      if retval and this_region_guid == sizing_region_guid then

        return this_region_guid
      end

      region_idx = region_idx + 1

    until retval == false

    sizing_region_user_result = handleNoSizingRegionExists(selected_items, pool_id)

    return sizing_region_user_result
  end
end


function handleNoSizingRegionExists(selected_items, pool_id)
  local global_option_time_selection_sets_bounds_enabled, time_selection_start, time_selection_end, no_time_selection_exists, user_response_create_time_selection

  global_option_time_selection_sets_bounds_enabled = reaper.GetExtState(_global_options_section, _global_option_toggle_time_selection_sets_bounds_on_glue_key)
  time_selection_start, time_selection_end = reaper.GetSet_LoopTimeRange(false, false, nil, nil, false)
  no_time_selection_exists = time_selection_end == _position_start_of_project

  if global_option_time_selection_sets_bounds_enabled == "false" then

    return handleNoSizer_TimeSelectionBoundsOptionDisabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)

  elseif global_option_time_selection_sets_bounds_enabled == "true" then

    return handleNoSizer_TimeSelectionBoundsOptionEnabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)
  end
end


function handleNoSizer_TimeSelectionBoundsOptionDisabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)
  local msg_title_sizing_region_deleted, user_response_reinstate_sizing_region, sizing_region_guid

  msg_title_sizing_region_deleted = "The sizing region for this Edited Superitem was removed somehow!"

  if no_time_selection_exists then
    reaper.ShowMessageBox("Superglue will now create a new sizing region at the bounds of the restored items.", msg_title_sizing_region_deleted, _msg_type_ok)
    createSizingRegionFromRestoredItems(selected_items, pool_id)

    return false

  else
    user_response_reinstate_sizing_region = reaper.ShowMessageBox("Select Yes to reglue to time selection, or No to create a new sizing region at the bounds of the restored items.", msg_title_sizing_region_deleted, _msg_type_yes_no)

    if user_response_reinstate_sizing_region == _msg_response_yes then
      sizing_region_guid = createSizingRegionFromTimeSelection(pool_id, time_selection_start, time_selection_end)

      return sizing_region_guid

    elseif user_response_reinstate_sizing_region == _msg_response_no then
      createSizingRegionFromRestoredItems(selected_items, pool_id)

      return false
    end
  end
end


function handleNoSizer_TimeSelectionBoundsOptionEnabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)
  local user_response_create_time_selection, sizing_region_guid

  if no_time_selection_exists then
    user_response_create_time_selection = reaper.ShowMessageBox("Select Yes to set time selection to the bounds of the restored items, or No to abort Reglue.", "There's no time selection to set Superitem bounds to.", _msg_type_yes_no)

    if user_response_create_time_selection == _msg_response_yes then
      createTimeSelectionFromRestoredItems(selected_items)
      createSizingRegionFromRestoredItems(selected_items, pool_id)

      return false

    else

      return false
    end

  else
    sizing_region_guid = createSizingRegionFromTimeSelection(pool_id, time_selection_start, time_selection_end)

    return sizing_region_guid
  end
end


function createSizingRegionFromRestoredItems(selected_items, pool_id)
  local sizing_region_params = getBoundsFromItems(selected_items)

  getSetSizingRegion(pool_id, sizing_region_params)
end


function createTimeSelectionFromRestoredItems(selected_items)
  local sizing_region_params = getBoundsFromItems(selected_items)

  reaper.GetSet_LoopTimeRange(true, false, sizing_region_params.position, sizing_region_params.end_point, false)
end


function createSizingRegionFromTimeSelection(pool_id, time_selection_start, time_selection_end)
  local sizing_region_params, sizing_region_guid

  sizing_region_params = {
    ["position"] = time_selection_start,
    ["end_point"] = time_selection_end
  }
  sizing_region_params.length = time_selection_end - time_selection_start
  sizing_region_guid = getSetSizingRegion(pool_id, sizing_region_params)

  return sizing_region_guid
end


function getSetWipeItemAudioSrc(item, src_or_wipe)
  local get, set, wipe, take, source, filename, filename_is_valid, src

  get = not src_or_wipe
  set = src_or_wipe and src_or_wipe ~= "wipe"
  wipe = src_or_wipe == "wipe"

  if get then
    take = reaper.GetActiveTake(item)
    source = reaper.GetMediaItemTake_Source(take)
    filename = reaper.GetMediaSourceFileName(source)
    filename_is_valid = string.len(filename) > 0

    if filename_is_valid then
      return filename
    end

  elseif set then
    src = src_or_wipe
    take = reaper.GetActiveTake(item)

    reaper.BR_SetTakeSourceFromFile2(take, src, false, true)

  elseif wipe then
    src = getSetWipeItemAudioSrc(item)

    os.remove(src)
    os.remove(src .. _peak_data_filename_extension)
  end
end


function restoreSuperitemState(superitem, superitem_params)
  local superitem_preglue_state_key_label, retval, superitem_last_glue_state, superitem_active_take

  superitem_preglue_state_key_label = _pool_key_prefix .. superitem_params.pool_id .. _superitem_preglue_state_suffix
  retval, superitem_last_glue_state = storeRetrieveProjectData(superitem_preglue_state_key_label)
  superitem_active_take = reaper.GetActiveTake(superitem)

  if retval == true and superitem_last_glue_state then
    getSetItemStateChunk(superitem, superitem_last_glue_state)
    getSetWipeItemAudioSrc(superitem, superitem_params.updated_src)
    getSetItemParams(superitem, superitem_params)
    reaper.SetMediaItemTakeInfo_Value(superitem_active_take, _api_take_src_offset_key, superitem_params.source_offset)
  end

  return superitem
end


function setRegluePositionDeltas()
  _edited_pool_fresh_glue_params, _edited_pool_preedit_params, _edited_pool_last_glue_params = numberizeAndRoundElements(
    {_edited_pool_fresh_glue_params, _edited_pool_preedit_params, _edited_pool_last_glue_params}, 
    {"position", "source_offset"}
  )
  _superitem_position_delta_during_glue = _edited_pool_fresh_glue_params.position - _edited_pool_preedit_params.position
  _superitem_position_delta_during_glue = round(_superitem_position_delta_during_glue, _api_time_value_decimal_resolution)
  _reglue_position_change_affect_on_length = _edited_pool_fresh_glue_params.length - _edited_pool_preedit_params.length
  _superitem_offset_delta_since_last_glue = _edited_pool_fresh_glue_params.source_offset - _edited_pool_last_glue_params.source_offset
  _superitem_offset_delta_since_last_glue = round(_superitem_offset_delta_since_last_glue, _api_time_value_decimal_resolution)

  if _superitem_position_delta_during_glue ~= 0 then
    _position_changed_since_last_glue = true
  end

  if _superitem_offset_delta_since_last_glue ~= 0 then
    _offset_changed_since_last_glue = true
  end
end


function adjustPostGlueTakeMarkersAndEnvelopes(instance, adjustment_near_project_start, fresh_glue_source_offset, this_is_edited_superitem)
  local instance_position, instance_active_take, instance_current_src_offset, instance_playrate, envelope_point_position_adjustment_delta, take_marker_position_adjustment_delta

  instance_position, instance_active_take, instance_current_src_offset, instance_playrate, fresh_glue_source_offset = getParamsForTakeMarkersAndEnvelopes(instance, instance_active_take, fresh_glue_source_offset)
  envelope_point_position_adjustment_delta, take_marker_position_adjustment_delta = getDeltasForTakeMarkersAndEnvelopes(adjustment_near_project_start, instance_position, instance_current_src_offset, instance_playrate, this_is_edited_superitem)

  adjustTakeEnvelopes(instance_active_take, envelope_point_position_adjustment_delta)
  adjustTakeMarkers(instance_active_take, take_marker_position_adjustment_delta, fresh_glue_source_offset)
  handleTakeStretchMarkers(instance_active_take, take_marker_position_adjustment_delta, fresh_glue_source_offset)
end


function getParamsForTakeMarkersAndEnvelopes(instance, instance_active_take, fresh_glue_source_offset)
  local instance_position, instance_active_take, instance_current_src_offset, instance_playrate

  instance_position = reaper.GetMediaItemInfo_Value(instance, _api_item_position_key)
  instance_active_take = reaper.GetActiveTake(instance)
  instance_current_src_offset = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _api_take_src_offset_key)
  instance_playrate = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _api_playrate_key)

  if not fresh_glue_source_offset then
    fresh_glue_source_offset = 0
  end

  return instance_position, instance_active_take, instance_current_src_offset, instance_playrate, fresh_glue_source_offset
end


function getDeltasForTakeMarkersAndEnvelopes(adjustment_near_project_start, instance_position, instance_current_src_offset, instance_playrate, this_is_edited_superitem)
  local envelope_point_position_adjustment_delta, take_marker_position_adjustment_delta

  if this_is_edited_superitem or _user_wants_propagation_option["position"] then
    envelope_point_position_adjustment_delta = -_superitem_offset_delta_since_last_glue
    take_marker_position_adjustment_delta = -_superitem_offset_delta_since_last_glue

  else
    envelope_point_position_adjustment_delta = 0
    take_marker_position_adjustment_delta = 0
  end

  if adjustment_near_project_start then

    if instance_position == 0 then
      envelope_point_position_adjustment_delta = 0 
      take_marker_position_adjustment_delta = adjustment_near_project_start - instance_current_src_offset

    else
      envelope_point_position_adjustment_delta = instance_position * instance_playrate
      take_marker_position_adjustment_delta = adjustment_near_project_start - instance_current_src_offset + (instance_position * instance_playrate)
    end
  end

  return envelope_point_position_adjustment_delta, take_marker_position_adjustment_delta
end


function adjustTakeEnvelopes(instance_active_take, position_adjustment_delta)
  local take_envelopes_count, this_take_envelope, envelope_points_count, j, retval, this_envelope_point_position, adjusted_envelope_point_position
  
  take_envelopes_count = reaper.CountTakeEnvelopes(instance_active_take)

  if take_envelopes_count > 0 then

    for i = 0, take_envelopes_count-1 do
      this_take_envelope = reaper.GetTakeEnvelope(instance_active_take, i)
      envelope_points_count = reaper.CountEnvelopePoints(this_take_envelope)

      for j = 0, envelope_points_count-1 do
        retval, this_envelope_point_position = reaper.GetEnvelopePoint(this_take_envelope, j)
        adjusted_envelope_point_position = this_envelope_point_position + position_adjustment_delta

        reaper.SetEnvelopePoint(this_take_envelope, j, adjusted_envelope_point_position, nil, nil, nil, nil, true)
      end
    end
  end
end


function adjustTakeMarkers(instance_active_take, position_adjustment_delta, fresh_glue_source_offset)
  local take_markers_count, all_take_markers, this_marker_position, this_marker_name, retval, adjusted_marker_position

  take_markers_count = reaper.GetNumTakeMarkers(instance_active_take)

  if take_markers_count > 0 then
    all_take_markers = {}

    for i = 0, take_markers_count-1 do
      this_marker_position, this_marker_name = reaper.GetTakeMarker(instance_active_take, i)

      table.insert(all_take_markers, {
        ["position"] = this_marker_position,
        ["name"] = this_marker_name
      })
    end

    repeat
      retval = reaper.DeleteTakeMarker(instance_active_take, 0)
    
    until retval == false

    for i = 1, #all_take_markers do
      adjusted_marker_position = all_take_markers[i]["position"] + position_adjustment_delta + fresh_glue_source_offset

      reaper.SetTakeMarker(instance_active_take, _api_new_take_marker_idx, all_take_markers[i]["name"], adjusted_marker_position)
    end
  end
end


function handleTakeStretchMarkers(instance_active_take, position_adjustment_delta, fresh_glue_source_offset)
  local stretch_markers_count, marker_position_adjustment, marker_source_position_adjustment

  stretch_markers_count = reaper.GetTakeNumStretchMarkers(instance_active_take)

  if stretch_markers_count > 0 then
    _user_wants_propagation_option["source_position"] = getUserPropagationChoice("source_position", _global_option_maintain_source_position_default_key)

    if _user_wants_propagation_option["source_position"] then
      marker_position_adjustment = position_adjustment_delta
      marker_source_position_adjustment = position_adjustment_delta + fresh_glue_source_offset

    else
      marker_position_adjustment = 0
      marker_source_position_adjustment = 0
    end

    adjustTakeStretchMarkers(instance_active_take, stretch_markers_count, marker_position_adjustment, marker_source_position_adjustment)
  end
end


function adjustTakeStretchMarkers(instance_active_take, stretch_markers_count, marker_position_adjustment, marker_source_position_adjustment)
  local all_stretch_markers, this_marker_position, this_marker_source_position, adjusted_marker_position, adjusted_marker_source_position

  all_stretch_markers = {}

  for i = 0, stretch_markers_count-1 do
    retval, this_marker_position, this_marker_source_position = reaper.GetTakeStretchMarker(instance_active_take, i)

    table.insert(all_stretch_markers, {
      ["position"] = this_marker_position,
      ["source_position"] = this_marker_source_position
    })
  end

  reaper.DeleteTakeStretchMarkers(instance_active_take, 0, stretch_markers_count)

  for i = 1, #all_stretch_markers do
    adjusted_marker_position = all_stretch_markers[i]["position"] + marker_position_adjustment
    adjusted_marker_source_position = all_stretch_markers[i]["source_position"] + marker_source_position_adjustment

    reaper.SetTakeStretchMarker(instance_active_take, _api_new_take_marker_idx, adjusted_marker_position, adjusted_marker_source_position)
  end
end


function editAncestors(pool_id, superitem, descendant_nesting_depth_of_active_parent)
  local parent_pool_ids_data_key_label, retval, parent_pool_ids, parent_pool_ids_data_found_for_active_pool, this_parent_pool_id, parent_edit_temp_track, restored_items, this_parent_instance_params, no_parent_instances_were_found

  parent_pool_ids_data_key_label = _pool_key_prefix .. pool_id .. _parent_pool_ids_data_key_suffix
  retval, parent_pool_ids = storeRetrieveProjectData(parent_pool_ids_data_key_label)
  parent_pool_ids_data_found_for_active_pool = retval == true

  if not descendant_nesting_depth_of_active_parent then
    descendant_nesting_depth_of_active_parent = 1
  end

  if parent_pool_ids_data_found_for_active_pool then
    retval, parent_pool_ids = serpent.load(parent_pool_ids)

    if #parent_pool_ids > 0 then
      _users_time_selection_before_action.position, _users_time_selection_before_action.end_point = reaper.GetSet_LoopTimeRange(false, false, nil, nil, false)

      for i = 1, #parent_pool_ids do
        this_parent_pool_id = parent_pool_ids[i]

        if _ancestor_pools_params[this_parent_pool_id] then
          assignParentNestingDepth(this_parent_pool_id, descendant_nesting_depth_of_active_parent)

        else
          traverseAncestorsUsingTempTracks(this_parent_pool_id, superitem, descendant_nesting_depth_of_active_parent)
        end
      end

      reaper.GetSet_LoopTimeRange(true, false, _users_time_selection_before_action.position, _users_time_selection_before_action.end_point, false)
    end
  end
end


function assignParentNestingDepth(this_parent_pool_id, descendant_nesting_depth_of_active_parent)
  _ancestor_pools_params[this_parent_pool_id].children_nesting_depth = math.max(descendant_nesting_depth_of_active_parent, _ancestor_pools_params[this_parent_pool_id].children_nesting_depth)
end


function traverseAncestorsUsingTempTracks(this_parent_pool_id, superitem, descendant_nesting_depth_of_active_parent)
  local this_parent_is_ancestor_in_project, this_parent_instance_params, this_parent_instance_is_item_in_project

  this_parent_instance_params = getFirstPoolInstanceParams(this_parent_pool_id)
  this_parent_instance_is_item_in_project = this_parent_instance_params

  if not this_parent_instance_is_item_in_project then
    this_parent_is_ancestor_in_project = checkParentPoolIsAncestorInProject(this_parent_pool_id)

    if this_parent_is_ancestor_in_project then
      this_parent_instance_params = {}
    end
  end

  if this_parent_instance_is_item_in_project or this_parent_is_ancestor_in_project then
    setUpAncestorEdits(this_parent_instance_params, this_parent_pool_id, descendant_nesting_depth_of_active_parent, superitem)
  end
end


function getFirstPoolInstanceParams(pool_id)
  local all_items_count, this_item, this_item_instance_pool_id, parent_instance_params

  all_items_count = reaper.CountMediaItems(_api_current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)
    this_item_instance_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)
    this_item_instance_pool_id = tonumber(this_item_instance_pool_id)

    if this_item_instance_pool_id == pool_id then
      parent_instance_params = getSetItemParams(this_item)

      return parent_instance_params
    end
  end

  return false
end


function checkParentPoolIsAncestorInProject(this_parent_pool_id)
  local all_pool_ids_in_project, this_pool, this_pool_descendant_pool_ids, retval

  all_pool_ids_in_project = getAllPoolIdsInProject()

  for i = 1, #all_pool_ids_in_project do
    this_pool = all_pool_ids_in_project[i]

    if this_pool == this_parent_pool_id then
      return true
    end

    this_pool_descendant_pool_ids = storeRetrievePoolData(this_pool, _descendant_pool_ids_key_suffix)
    retval, this_pool_descendant_pool_ids = serpent.load(this_pool_descendant_pool_ids)

    for j = 1, #this_pool_descendant_pool_ids do
      this_pool_descendant_pool_id = tonumber(this_pool_descendant_pool_ids[j])

      if this_pool_descendant_pool_id == this_parent_pool_id then
        return true
      end
    end
  end

  deletePoolDescendantsData(this_parent_pool_id)
   
  return false
end


function getAllPoolIdsInProject()
  local all_items_count, all_pool_ids_in_project, this_item, this_item_instance_pool_id

  all_items_count = reaper.CountMediaItems(_api_current_project)
  all_pool_ids_in_project = {}

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)
    this_item_instance_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)

    if this_item_instance_pool_id and this_item_instance_pool_id ~= "" then
      table.insert(all_pool_ids_in_project, this_item_instance_pool_id)
    end
  end

  return deduplicateTable(all_pool_ids_in_project)
end


function deletePoolDescendantsData(pool_id)
  storeRetrievePoolData(pool_id, _descendant_pool_ids_key_suffix, "")
end


function setUpAncestorEdits(parent_instance_params, parent_pool_id, descendant_nesting_depth_of_active_parent, superitem)
  local parent_edit_temp_track, restored_items, next_nesting_depth

  parent_instance_params.pool_id = parent_pool_id
  parent_instance_params.children_nesting_depth = descendant_nesting_depth_of_active_parent

  reaper.InsertTrackAtIndex(0, false)

  parent_edit_temp_track = reaper.GetTrack(_api_current_project, 0)

  reaper.Main_OnCommand(_command_id_deselect_all_items, _api_command_flag)

  restored_items = restoreStoredItems(parent_pool_id, parent_edit_temp_track, superitem, true, nil)
  parent_instance_params.track = parent_edit_temp_track
  parent_instance_params.restored_items = restored_items
  _ancestor_pools_params[parent_pool_id] = parent_instance_params
  next_nesting_depth = descendant_nesting_depth_of_active_parent + 1

  editAncestors(parent_pool_id, superitem, next_nesting_depth)
end


function restoreStoredItems(pool_id, active_track, superitem, this_is_ancestor_superitem_update, action)
  local stored_item_states_table, restored_items, restored_instances_near_project_start, restored_item, looped_source_sets_sizing_region_enabled, superitem_loop_is_enabled

  stored_item_states_table = getStoredItemStatesTable(pool_id, action)
  restored_items = {}
  restored_instances_near_project_start = {}

  defineStoredItemsParams(pool_id)

  for item_guid, stored_item_state in pairs(stored_item_states_table) do

    if stored_item_state then
      _unglued_pool_preunglue_params = getSetItemParams(superitem)
      restored_item, restored_instances_near_project_start, looped_source_sets_sizing_region_enabled, superitem_loop_is_enabled = handleRestoredItem(superitem, active_track, stored_item_state, restored_instances_near_project_start, this_is_ancestor_superitem_update, action)

      table.insert(restored_items, restored_item)
    end
  end

  handleRestoredInstancesNearProjectStart(restored_instances_near_project_start, superitem)

  return restored_items, looped_source_sets_sizing_region_enabled, superitem_loop_is_enabled
end


function getStoredItemStatesTable(pool_id, action)
  local this_is_unglue, this_is_depool, retval, stored_item_states_table, stored_item_states

  this_is_unglue = action == "Unglue"
  this_is_depool = action == "DePool"

  if (this_is_unglue or this_is_depool) and _preglue_restored_item_states then
    retval, stored_item_states_table = serpent.load(_preglue_restored_item_states)

  else
    stored_item_states = storeRetrievePoolData(pool_id, _pool_contained_item_states_key_suffix)
    stored_item_states_table = retrieveStoredItemStates(stored_item_states)
  end

  return stored_item_states_table
end


function retrieveStoredItemStates(item_state_chunks_string)
  local retval, item_state_chunks_table

  retval, item_state_chunks_table = serpent.load(item_state_chunks_string)
  item_state_chunks_table.track = reaper.BR_GetMediaTrackByGUID(_api_current_project, item_state_chunks_table.track_guid)

  return item_state_chunks_table
end


function defineStoredItemsParams(pool_id)
  _first_restored_item_last_glue_delta_to_parent = storeRetrievePoolData(pool_id, _first_child_delta_to_superitem_position_key_suffix)
  _this_depooled_superitem_has_not_been_edited = storeRetrievePoolData(pool_id, _freshly_depooled_superitem_flag)

  if not _edited_pool_post_glue_params then
    _edited_pool_post_glue_params = storeRetrieveSuperitemParams(pool_id, _postglue_action_step)
  end

  if not _edited_pool_preedit_params then
    _edited_pool_preedit_params = storeRetrieveSuperitemParams(pool_id, _preedit_action_step)
  end
  
  if not _first_restored_item_last_glue_delta_to_parent or _first_restored_item_last_glue_delta_to_parent == "" then
    _first_restored_item_last_glue_delta_to_parent = 0
  end
end


function handleRestoredItem(superitem, active_track, stored_item_state, restored_instances_near_project_start, this_is_ancestor_superitem_update, action)
  local restored_item, restored_instance_pool_id, restored_item_negative_position_delta, this_is_first_edit_after_auto_depool

  restored_item = restoreItem(active_track, stored_item_state, this_is_ancestor_superitem_update)
  restored_instance_pool_id = storeRetrieveItemData(restored_item, _instance_pool_id_key_suffix)

  handleOfflineTake(restored_item, "restored")
  reaper.SetMediaItemSelected(restored_item, true)
  handleRestoredItemImage(restored_item, restored_instance_pool_id, action)

  if not this_is_ancestor_superitem_update then
    restored_item, looped_source_sets_sizing_region_enabled, superitem_loop_is_enabled = adjustRestoredItem(superitem, restored_item, action)
  end

  restored_instances_near_project_start[restored_instance_pool_id] = defineRestoredInstanceNearProjectStartParams(restored_instances_near_project_start, restored_instance_pool_id, restored_item, restored_item_negative_position_delta)

  if action == "Unglue" then
    storeRetrieveItemData(restored_item, _parent_pool_id_key_suffix, "")
  end

  return restored_item, restored_instances_near_project_start, looped_source_sets_sizing_region_enabled, superitem_loop_is_enabled
end


function handleRestoredItemImage(restored_item, restored_instance_pool_id, action)
  local this_restored_item_is_instance

  this_restored_item_is_instance = restored_instance_pool_id and restored_instance_pool_id ~= ""

  if action == "Unglue" then

    if this_restored_item_is_instance then
      addRemoveItemImage(restored_item, "superitem")

    else
      addRemoveItemImage(restored_item, false)
    end

  else

    if this_restored_item_is_instance then
      addRemoveItemImage(restored_item, "restored_instance")

    else
      addRemoveItemImage(restored_item, "restored")
    end
  end
end


function handleRestoredInstancesNearProjectStart(restored_instances_near_project_start, superitem)
  local restored_instance_pool_id, this_instance_params, superitem_params, this_restored_instance_last_glue_delta_to_parent, this_instance_adjusted_position, this_instance_is_closer_to_project_start_than_negative_position_change, this_instance_active_take, this_instance_current_src_offset, this_instance_adjusted_src_offset
  
  for restored_instance_pool_id, this_instance_params in pairs(restored_instances_near_project_start) do
    superitem_params = getSetItemParams(superitem)
    this_restored_instance_last_glue_delta_to_parent = storeRetrieveItemData(this_instance_params.item, _first_child_delta_to_superitem_position_key_suffix)
    this_restored_instance_last_glue_delta_to_parent = tonumber(this_restored_instance_last_glue_delta_to_parent)
    this_instance_adjusted_position = superitem_params.position + this_instance_params.negative_position_delta
    this_instance_is_closer_to_project_start_than_negative_position_change = this_instance_adjusted_position < -this_instance_params.negative_position_delta

    if this_instance_is_closer_to_project_start_than_negative_position_change then
      this_instance_adjusted_position = _position_start_of_project

    else
      this_instance_adjusted_position = this_instance_params.negative_position_delta
    end

    this_instance_active_take = reaper.GetActiveTake(this_instance_params.item)
    this_instance_current_src_offset = reaper.GetMediaItemTakeInfo_Value(this_instance_active_take, _api_take_src_offset_key)
    this_instance_adjusted_src_offset = this_instance_current_src_offset - this_instance_params.negative_position_delta

    reaper.SetMediaItemInfo_Value(this_instance_params.item, _api_item_position_key, this_instance_adjusted_position)
    reaper.SetMediaItemTakeInfo_Value(this_instance_active_take, _api_take_src_offset_key, this_instance_adjusted_src_offset)
  end
end


function restoreItem(track, state, this_is_ancestor_superitem_update)
  local restored_item

  restored_item = reaper.AddMediaItemToTrack(track)

  getSetItemStateChunk(restored_item, state)

  if not this_is_ancestor_superitem_update then
    restoreOriginalMidiTake(restored_item)
  end

  return restored_item
end


function restoreOriginalMidiTake(item)
  local item_takes_count, preglue_active_midi_take_guid, preglue_active_midi_take, rendered_audio_take, rendered_audio_take_num

  item_takes_count = reaper.GetMediaItemNumTakes(item)
  
  if item_takes_count > 0 then
    preglue_active_midi_take_guid = storeRetrieveItemData(item, _preglue_active_take_guid_key_suffix)
    preglue_active_midi_take = reaper.SNM_GetMediaItemTakeByGUID(_api_current_project, preglue_active_midi_take_guid)

    if preglue_active_midi_take then
      rendered_audio_take = reaper.GetActiveTake(item)
      rendered_audio_take_num = reaper.GetMediaItemTakeInfo_Value(rendered_audio_take, "IP_TAKENUMBER")

      getSetWipeItemAudioSrc(item, "wipe")
      reaper.NF_DeleteTakeFromItem(item, rendered_audio_take_num)
      reaper.SetActiveTake(preglue_active_midi_take)
      cleanNullTakes(item)
    end
  end
end


function adjustRestoredItem(superitem, restored_item, action)
  local restored_item_params, adjusted_restored_item_position_is_before_project_start, restored_item_negative_position

  restored_item_params = getSetItemParams(restored_item)
  restored_item_params.position, looped_source_sets_sizing_region_enabled, superitem_loop_is_enabled = getRestoredItemPositionDeltaSinceLastGlue(superitem, restored_item, restored_item_params, action)
  adjusted_restored_item_position_is_before_project_start = restored_item_params.position < 0

  if adjusted_restored_item_position_is_before_project_start then
    restored_item_negative_position = restored_item_params.position

    return restored_item, restored_item_negative_position
  end

  reaper.SetMediaItemPosition(restored_item, restored_item_params.position, _api_dont_refresh_ui)

  return restored_item, looped_source_sets_sizing_region_enabled, superitem_loop_is_enabled
end


function getRestoredItemPositionDeltaSinceLastGlue(superitem, restored_item, restored_item_params, action)
  local this_item_position_delta_to_last_glue_superitem_instance, superitem_loop_is_enabled, superitem_active_take, superitem_source, superitem_source_length, superitem_loop_starts_in_later_half, restored_item_altered_position

  looped_source_sets_sizing_region_enabled = reaper.GetExtState(_global_options_section, _global_option_toggle_loop_source_sets_sizing_region_bounds_on_reglue_key)
  superitem_loop_is_enabled = reaper.GetMediaItemInfo_Value(superitem, _api_item_loop_src_key) == _loop_enabled_value
  superitem_active_take = reaper.GetActiveTake(superitem)
  superitem_source = reaper.GetMediaItemTake_Source(superitem_active_take)
  superitem_source_length = reaper.GetMediaSourceLength(superitem_source)

  if action == "Edit" or action == "Unglue" then
    superitem_loop_starts_in_later_half = _unglued_pool_preunglue_params.source_offset > (superitem_source_length / 2)

    if _this_depooled_superitem_has_not_been_edited == "true" then
      this_item_position_delta_to_last_glue_superitem_instance = _unglued_pool_preunglue_params.position - _edited_pool_post_glue_params.position - _unglued_pool_preunglue_params.source_offset
    
    else
      this_item_position_delta_to_last_glue_superitem_instance = _unglued_pool_preunglue_params.position - _edited_pool_post_glue_params.position - _unglued_pool_preunglue_params.source_offset + _edited_pool_post_glue_params.source_offset
    end

    if looped_source_sets_sizing_region_enabled == "true" and superitem_loop_is_enabled and superitem_loop_starts_in_later_half then
      this_item_position_delta_to_last_glue_superitem_instance = this_item_position_delta_to_last_glue_superitem_instance + superitem_source_length
    end

  elseif action == "DePool" then
    this_item_position_delta_to_last_glue_superitem_instance = _edited_pool_post_glue_params.position - _unglued_pool_preunglue_params.position + _edited_pool_post_glue_params.source_offset
  end

  restored_item_altered_position = restored_item_params.position + this_item_position_delta_to_last_glue_superitem_instance

  return restored_item_altered_position, looped_source_sets_sizing_region_enabled, superitem_loop_is_enabled
end


function defineRestoredInstanceNearProjectStartParams(restored_instances_near_project_start, restored_instance_pool_id, restored_item, restored_item_negative_position_delta)
  local this_restored_instance_position_is_earlier_than_prev_sibling

  if restored_item_negative_position_delta then

    if restored_instance_pool_id and not restored_instances_near_project_start[restored_instance_pool_id] then
      restored_instances_near_project_start[restored_instance_pool_id] = {
        ["item"] = restored_item,
        ["negative_position_delta"] = restored_item_negative_position_delta
      }

    elseif restored_instances_near_project_start[restored_instance_pool_id] then
      this_restored_instance_position_is_earlier_than_prev_sibling = restored_item_negative_position_delta < restored_instances_near_project_start[restored_instance_pool_id].negative_position_delta

      if this_restored_instance_position_is_earlier_than_prev_sibling then
        restored_instances_near_project_start[restored_instance_pool_id] = {
          ["item"] = restored_item,
          ["negative_position_delta"] = restored_item_negative_position_delta
        }
      end
    end
  end

  return restored_instances_near_project_start[restored_instance_pool_id]
end


function propagateChangesToSuperitems(sizing_region_guid)
  local this_is_ancestor_superitem_update, ancestor_pools_near_project_start, ancestor_pools_params_sorted_by_ascending_nesting_depth, this_ancestor_pool_id

  this_is_ancestor_superitem_update = false
  ancestor_pools_near_project_start = handleSuperitemsChangedByReglue(this_is_ancestor_superitem_update)
  ancestor_pools_params_sorted_by_ascending_nesting_depth = sortAncestorUpdatesByNestingDepth()

  for i = 1, #ancestor_pools_params_sorted_by_ascending_nesting_depth do
    _current_pool_fresh_glue_params = ancestor_pools_params_sorted_by_ascending_nesting_depth[i]
    this_ancestor_pool_id = tostring(_current_pool_fresh_glue_params.pool_id)
    _restored_items_near_project_start_position_delta = ancestor_pools_near_project_start[this_ancestor_pool_id]
    _current_pool_preedit_params = storeRetrieveSuperitemParams(this_ancestor_pool_id, _preedit_action_step)

    if _restored_items_near_project_start_position_delta then
      adjustParentPoolChildrenNearProjectStart(this_ancestor_pool_id, _edited_pool_fresh_glue_params.pool_id)

    else
      _restored_items_near_project_start_position_delta = 0
    end
      
    reglueAncestor(sizing_region_guid)
  end

  reaper.ClearPeakCache()
end


function handleSuperitemsChangedByReglue(this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  local all_items_count, ancestor_pools_near_project_start, this_item, this_active_pool_instance, global_option_toggle_depool_all_siblings_on_reglue, this_instance_active_take

  all_items_count = reaper.CountMediaItems(_api_current_project)
  ancestor_pools_near_project_start = {}

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)
    this_active_pool_instance = getSuperitemChangedByReglue(this_item, this_is_ancestor_superitem_update)

    if this_active_pool_instance then
      global_option_toggle_depool_all_siblings_on_reglue = reaper.GetExtState(_global_options_section, _global_option_toggle_depool_all_siblings_on_reglue_key)

      if global_option_toggle_depool_all_siblings_on_reglue == "true" and not this_is_ancestor_superitem_update then
        global_option_toggle_depool_all_siblings_on_reglue = handleDePoolSibling(this_active_pool_instance)
      
      elseif global_option_toggle_depool_all_siblings_on_reglue == "false" then
        this_instance_active_take = reaper.GetActiveTake(this_active_pool_instance)
        ancestor_pools_near_project_start = updateSuperitemChangedByReglue(this_active_pool_instance, this_instance_active_take, this_item, ancestor_pools_near_project_start, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
      end
    end
  end

  return ancestor_pools_near_project_start
end


function getSuperitemChangedByReglue(item, this_is_ancestor_superitem_update)
  local item_instance_pool_id, item_is_instance, fresh_glue_params, item_is_active_pool_instance, instance_current_src, this_instance_needs_update

  item_instance_pool_id = storeRetrieveItemData(item, _instance_pool_id_key_suffix)
  item_is_instance = item_instance_pool_id and item_instance_pool_id ~= ""

  if this_is_ancestor_superitem_update then
    fresh_glue_params = _current_pool_fresh_glue_params

  else
    fresh_glue_params = _edited_pool_fresh_glue_params
  end

  if item_is_instance then

    if not fresh_glue_params.instance_pool_id or fresh_glue_params.instance_pool_id == "" then
      fresh_glue_params.instance_pool_id = fresh_glue_params.pool_id
      fresh_glue_params.instance_pool_id = tostring(fresh_glue_params.instance_pool_id)
    end

    item_is_active_pool_instance = item_instance_pool_id == fresh_glue_params.instance_pool_id
    
    if item_is_active_pool_instance then
      instance_current_src = getSetWipeItemAudioSrc(item)
      this_instance_needs_update = instance_current_src ~= fresh_glue_params.updated_src

      if this_instance_needs_update then

        return item
      end
    end
  end
end


function handleDePoolSibling(active_pool_sibling)
  local global_option_toggle_depool_all_siblings_on_reglue_warning, global_option_toggle_depool_all_siblings_on_reglue

  global_option_toggle_depool_all_siblings_on_reglue_warning = reaper.GetExtState(_global_options_section, _global_option_toggle_depool_all_siblings_on_reglue_warning_key)

  if global_option_toggle_depool_all_siblings_on_reglue_warning == "true" and _user_wants_to_depool_all_siblings == nil then
    _user_wants_to_depool_all_siblings = reaper.ShowMessageBox("Select yes to continue and remove all of this item's siblings from its pool, or no to disable this option.", _script_brand_name .. " Warning: You have the option to remove all sibling instances from pool enabled.", _msg_type_yes_no)

    if _user_wants_to_depool_all_siblings == _msg_response_no then
      reaper.SetExtState(_global_options_section, _global_option_toggle_depool_all_siblings_on_reglue_key, "false", _api_extstate_persist_enabled)
      
      global_option_toggle_depool_all_siblings_on_reglue = "false"

    elseif _user_wants_to_depool_all_siblings == _msg_response_yes then
      reaper.SetExtState(_global_options_section, _global_option_toggle_depool_all_siblings_on_reglue_warning_key, "false", _api_extstate_persist_enabled)

      initDePool(active_pool_sibling)
    end

  else
    initDePool(active_pool_sibling)
  end

  return global_option_toggle_depool_all_siblings_on_reglue
end


function updateSuperitemChangedByReglue(active_pool_instance, instance_active_take, item, ancestor_pools_near_project_start, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  local siblings_are_being_updated, current_pool_updated_src, attempted_negative_instance_position, instance_parent_pool_id, parent_active_take, parent_playrate, parent_current_src_offset, parent_adjusted_src_offset

  siblings_are_being_updated = not this_is_ancestor_superitem_update

  if this_is_ancestor_superitem_update then
    current_pool_updated_src = _current_pool_fresh_glue_params.updated_src

  elseif siblings_are_being_updated then
    current_pool_updated_src = _edited_pool_fresh_glue_params.updated_src
  end

  getSetWipeItemAudioSrc(active_pool_instance, current_pool_updated_src)

  attempted_negative_instance_position = adjustSuperitemChangedByReglue(active_pool_instance, instance_active_take, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)

  if attempted_negative_instance_position ~= 0 then
    instance_parent_pool_id = storeRetrieveItemData(item, _parent_pool_id_key_suffix)
    ancestor_pools_near_project_start[instance_parent_pool_id] = attempted_negative_instance_position
  end

  return ancestor_pools_near_project_start
end


function adjustSuperitemChangedByReglue(instance, instance_active_take, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  local this_is_sibling_instance_update, this_instance_parent_pool_id, this_instance_is_child, instance_current_src_offset, instance_playrate, instance_would_get_adjusted_before_project_start

  this_is_sibling_instance_update = not this_is_ancestor_superitem_update
  this_instance_parent_pool_id = storeRetrieveItemData(instance, _parent_pool_id_key_suffix)
  this_instance_is_child = this_instance_parent_pool_id and this_instance_parent_pool_id ~= ""
  instance_current_src_offset = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _api_take_src_offset_key, "", false)
  instance_playrate = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _api_playrate_key)

  getSuperitemPropagationOptionChoices()

  if this_is_sibling_instance_update then
    instance_would_get_adjusted_before_project_start = adjustSuperitemPosition(instance, instance_active_take, instance_current_src_offset, instance_playrate)

    adjustSuperitemLength(instance, instance_playrate, this_instance_is_child)
  end

  if (this_is_sibling_instance_update or this_is_direct_parent_instance_update) and _user_wants_propagation_option["source_position"] and not instance_would_get_adjusted_before_project_start then
    adjustSuperitemSourceOffset(instance, instance_active_take, instance_current_src_offset, this_is_direct_parent_instance_update, this_is_sibling_instance_update)
  end
end


function getSuperitemPropagationOptionChoices()
  _user_wants_propagation_option["playrate_toggle"] = getUserPropagationChoice("playrate_toggle", _global_option_playrate_affects_propagation_default_key)
  
  if _position_changed_since_last_glue then
    _user_wants_propagation_option["position"] = getUserPropagationChoice("position", _global_option_propagate_position_default_key)
  end

  if _offset_changed_since_last_glue then
    _user_wants_propagation_option["source_position"] = getUserPropagationChoice("source_position", _global_option_maintain_source_position_default_key)
  end
end


function getUserPropagationChoice(propagation_option, ext_state_key)
  local option_value, user_choice

  option_value = reaper.GetExtState(_global_options_section, ext_state_key)

  if not _propagation_user_responses[propagation_option] and option_value == "ask" then
    _propagation_user_responses[propagation_option] = launchPropagateDialog(propagation_option)
  end

  user_choice = option_value == "always" or _propagation_user_responses[propagation_option] == _msg_response_yes

  return user_choice
end


function launchPropagateDialog(param)
  local propagate_dialog_params, global_option_propagate_default, msg_title, msg_content

  propagate_dialog_params = getPropagateDialogValues()
  global_option_propagate_default = reaper.GetExtState(_global_options_section, propagate_dialog_params[param]["global_option_param_key"])
  msg_title = "The " .. propagate_dialog_params[param]["message_title_string"] .. " of the Superitem you're regluing has changed!"
  msg_content = "Do you want to adjust pool sibling Superitems' " .. propagate_dialog_params[param]["message_content_string"]

  if global_option_propagate_default == "ask" then
    return reaper.ShowMessageBox(msg_content, msg_title, _msg_type_yes_no)

  elseif global_option_propagate_default == "always" then
    return _msg_response_yes

  elseif global_option_propagate_default == "no" then
    return _msg_response_no
  end
end


function getPropagateDialogValues()
  local propagate_dialog_data, propagate_dialog_params

  propagate_dialog_data = {
    {"source_position", _global_option_maintain_source_position_default_key, "audio source timeline locations so they remain in the same place?", "source position"},
    {"length", _global_option_propagate_length_default_key, "lengths to match?", "length"},
    {"position", _global_option_propagate_position_default_key, "left edge to adjust as well?", "left edge position"},
    {"absolute_length_propagation", _global_option_length_propagation_type_default_key, "length to match the Edited Superitem? (No = alter sibling length relatively by the length change amount)", "length"},
    {"playrate_toggle", _global_option_playrate_affects_propagation_default_key, "position and/or length in proportion to their playrates?", "length and/or position"}
  }
  propagate_dialog_params = {}

  for i = 1, #propagate_dialog_data do
    propagate_dialog_params[propagate_dialog_data[i][1]] = {
      ["global_option_param_key"] = propagate_dialog_data[i][2],
      ["message_content_string"] = propagate_dialog_data[i][3],
      ["message_title_string"] = propagate_dialog_data[i][4]
    }
  end

  return propagate_dialog_params
end


function adjustSuperitemPosition(instance, instance_active_take, instance_current_src_offset, instance_playrate)
  local instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start, take_markers_source_offset

  instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start = getPositionPropagationParams(instance, instance_current_src_offset, instance_playrate)

  if _user_wants_propagation_option["position"] then

    if instance_would_get_adjusted_before_project_start then
      handleSuperitemNearProjectStart(instance, instance_current_position, instance_active_take, instance_current_src_offset, instance_playrate)

    else
      take_markers_source_offset = _edited_pool_fresh_glue_params.source_offset - _edited_pool_preedit_params.source_offset

      adjustPostGlueTakeMarkersAndEnvelopes(instance, nil, take_markers_source_offset)
      reaper.SetMediaItemPosition(instance, instance_adjusted_position, _api_dont_refresh_ui)

      if _user_wants_propagation_option["source_position"] then
        reaper.SetMediaItemTakeInfo_Value(instance_active_take, _api_take_src_offset_key, instance_current_src_offset)
      end

      _sibling_position_change_affect_on_length = 0
    end

  else
    adjustPostGlueTakeMarkersAndEnvelopes(instance)
  end

  return instance_would_get_adjusted_before_project_start
end


function getPositionPropagationParams(instance, instance_current_src_offset, instance_playrate)
  local instance_current_position, instance_position_adjustment_delta, instance_adjusted_position, instance_would_get_adjusted_before_project_start

  instance_current_position = reaper.GetMediaItemInfo_Value(instance, _api_item_position_key)
  instance_position_adjustment_delta = _superitem_position_delta_during_glue

  if _user_wants_propagation_option["playrate_toggle"] then
    instance_position_adjustment_delta = instance_position_adjustment_delta / instance_playrate
  end

  instance_adjusted_position = instance_current_position + instance_position_adjustment_delta
  instance_would_get_adjusted_before_project_start = instance_adjusted_position < _position_start_of_project

  return instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start
end


function handleSuperitemNearProjectStart(instance, instance_current_position, instance_active_take, instance_current_src_offset, instance_playrate)
  local instance_is_exactly_at_project_start, this_is_edited_pool_update, instance_src_offset_adjustment_delta, instance_adjusted_src_offset

  instance_is_exactly_at_project_start = instance_current_position == _position_start_of_project

  if _user_wants_propagation_option["source_position"] == nil then
    _user_wants_propagation_option["source_position"] = getUserPropagationChoice("source_position", _global_option_maintain_source_position_default_key)
  end

  if _user_wants_propagation_option["source_position"] then

    if instance_is_exactly_at_project_start then
      instance_src_offset_adjustment_delta = _edited_pool_fresh_glue_params.source_offset - _edited_pool_preedit_params.source_offset - _superitem_position_delta_during_glue

    else
      instance_src_offset_adjustment_delta = _edited_pool_fresh_glue_params.source_offset - _edited_pool_preedit_params.source_offset - _superitem_position_delta_during_glue - (instance_current_position * instance_playrate)
    end

  else
    instance_src_offset_adjustment_delta = 0
  end

  instance_adjusted_src_offset = instance_current_src_offset + instance_src_offset_adjustment_delta

  adjustPostGlueTakeMarkersAndEnvelopes(instance, instance_adjusted_src_offset)
  reaper.SetMediaItemPosition(instance, _position_start_of_project, _api_dont_refresh_ui)
  reaper.SetMediaItemTakeInfo_Value(instance_active_take, _api_take_src_offset_key, instance_adjusted_src_offset)
end


function adjustSuperitemSourceOffset(instance, instance_active_take, instance_current_src_offset, this_is_direct_parent_instance_update, this_is_sibling_instance_update)
  local instance_adjusted_src_offset, ancestor_position, ancestor_pool_id, active_child_position_delta_to_parent

  if this_is_direct_parent_instance_update then

    if _user_wants_propagation_option["position"] then

      if instance_current_src_offset >= 0 then
        instance_adjusted_src_offset = _current_pool_fresh_glue_params.source_offset

      else
        instance_adjusted_src_offset = instance_current_src_offset - _superitem_offset_delta_since_last_glue
      end

    else
      instance_adjusted_src_offset = instance_current_src_offset
    end

  elseif this_is_sibling_instance_update then
    instance_adjusted_src_offset = _edited_pool_fresh_glue_params.source_offset
  end

  reaper.SetMediaItemTakeInfo_Value(instance_active_take, _api_take_src_offset_key, instance_adjusted_src_offset)

  _active_superitem_source_position_adjustment_delta = _edited_pool_fresh_glue_params.source_offset - _edited_pool_preedit_params.source_offset
end


function adjustSuperitemLength(instance, instance_playrate, this_instance_is_child)
  local instance_current_length, instance_length_adjustment_delta, user_wants_relative_length_propagation, instance_adjusted_length

  instance_current_length = reaper.GetMediaItemInfo_Value(instance, _api_item_length_key)
  _user_wants_propagation_option["length"] = getUserPropagationChoice("length", _global_option_propagate_length_default_key)

  if _user_wants_propagation_option["length"] then
    _user_wants_propagation_option["playrate_toggle"] = getUserPropagationChoice("playrate_toggle", _global_option_playrate_affects_propagation_default_key)
    _user_wants_propagation_option["absolute_length_propagation"] = getUserPropagationChoice("absolute_length_propagation", _global_option_length_propagation_type_default_key)
    user_wants_relative_length_propagation = not _user_wants_propagation_option["absolute_length_propagation"]

    if _user_wants_propagation_option["absolute_length_propagation"] then
      instance_adjusted_length = _edited_pool_fresh_glue_params.length

      if _user_wants_propagation_option["playrate_toggle"] then
        instance_adjusted_length = _edited_pool_fresh_glue_params.length / instance_playrate
      end

    elseif user_wants_relative_length_propagation then
      instance_adjusted_length = instance_current_length + _reglue_position_change_affect_on_length

      if _user_wants_propagation_option["playrate_toggle"] then
        instance_adjusted_length = instance_current_length + (_reglue_position_change_affect_on_length / instance_playrate)
      end
    end

    reaper.SetMediaItemLength(instance, instance_adjusted_length, _api_dont_refresh_ui)
  end
end


function sortAncestorUpdatesByNestingDepth()
  local pool_id, this_parent_instance_params, ancestor_pools_params_sorted_by_ascending_nesting_depth

  ancestor_pools_params_sorted_by_ascending_nesting_depth = {}

  for pool_id, this_parent_instance_params in pairs(_ancestor_pools_params) do
    table.insert(ancestor_pools_params_sorted_by_ascending_nesting_depth, this_parent_instance_params)
  end

  table.sort(ancestor_pools_params_sorted_by_ascending_nesting_depth, function(a, b)
    return a.children_nesting_depth < b.children_nesting_depth end
  )

  return ancestor_pools_params_sorted_by_ascending_nesting_depth
end


function adjustParentPoolChildrenNearProjectStart(parent_pool_id, active_pool_id)
  local all_items_count, this_item, this_item_parent_pool_id, this_item_is_pool_child, this_child_instance_pool_id, this_child_is_active_sibling, this_child_current_position, this_child_adjusted_position

  all_items_count = reaper.CountMediaItems(_api_current_project)
  
  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)
    this_item_parent_pool_id = storeRetrieveItemData(this_item, _parent_pool_id_key_suffix)
    this_item_is_pool_child = this_item_parent_pool_id == parent_pool_id

    if this_item_is_pool_child then
      this_child_instance_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)
      this_child_is_active_sibling = this_child_instance_pool_id == active_pool_id
      this_child_current_position = reaper.GetMediaItemInfo_Value(this_item, _api_item_position_key)

      if this_child_is_active_sibling then
        this_child_adjusted_position = this_child_current_position + _superitem_offset_delta_since_last_glue - _restored_items_near_project_start_position_delta

      else
        this_child_adjusted_position = this_child_current_position - _restored_items_near_project_start_position_delta
      end

      reaper.SetMediaItemPosition(this_item, this_child_adjusted_position, _api_dont_refresh_ui)
    end
  end
end


function reglueAncestor(sizing_region_guid)
  local this_is_ancestor_superitem_update, selected_items, this_selected_item, this_selected_item_params, this_selected_instance_pool_id, this_is_direct_parent_instance_update, parent_instance, parent_active_track

  reaper.Main_OnCommand(_command_id_deselect_all_items, _api_command_flag)
  refreshCurrentPoolStoredItemsPostDePool()
  selectDeselectItems(_current_pool_fresh_glue_params.restored_items, true)

  this_is_ancestor_superitem_update = true
  selected_items = getSelectedItems(#_current_pool_fresh_glue_params.restored_items)

  for i = 1, #selected_items do
    this_selected_item = selected_items[i]
    this_selected_item_params = getSetItemParams(this_selected_item)
    this_selected_instance_pool_id = this_selected_item_params.instance_pool_id

    if this_selected_instance_pool_id == _edited_pool_fresh_glue_params.pool_id then
      this_is_direct_parent_instance_update = true

      break
    end
  end

  parent_instance = handleGlue(selected_items, _current_pool_fresh_glue_params.track, _current_pool_fresh_glue_params.pool_id, sizing_region_guid, nil, this_is_ancestor_superitem_update)
  parent_active_track = _current_pool_fresh_glue_params.track
  _current_pool_fresh_glue_params = getSetItemParams(parent_instance)
  _current_pool_fresh_glue_params.updated_src = getSetWipeItemAudioSrc(parent_instance)

  reaper.Main_OnCommand(_command_id_deselect_all_items, _api_command_flag)
  handleSuperitemsChangedByReglue(this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  reaper.DeleteTrack(parent_active_track)
end


function refreshCurrentPoolStoredItemsPostDePool()
  local this_restored_item_exists, all_items_count, this_item, this_item_parent_pool_id, this_item_belongs_to_current_pool

  for i = 1, #_current_pool_fresh_glue_params.restored_items do
    this_restored_item_exists = reaper.ValidatePtr(_current_pool_fresh_glue_params.restored_items[i], "MediaItem*")

    if not this_restored_item_exists then
      _current_pool_fresh_glue_params.restored_items = {}
      all_items_count = reaper.CountMediaItems(_api_current_project)

      for j = 0, all_items_count-1 do
        this_item = reaper.GetMediaItem(_api_current_project, j)
        this_item_parent_pool_id = storeRetrieveItemData(this_item, _parent_pool_id_key_suffix)
        this_item_parent_pool_id = tonumber(this_item_parent_pool_id)
        this_item_belongs_to_current_pool = this_item_parent_pool_id == _current_pool_fresh_glue_params.pool_id

        if this_item_belongs_to_current_pool then
          table.insert(_current_pool_fresh_glue_params.restored_items, this_item)
        end
      end

      break
    end
  end
end
  

function initEditOrUnglue(action)
  local selected_item_count, selected_item_groups, superitems, this_pool_id, other_open_instance, superitem_is_multitake, superitem_takes_count, multitake_msg_user_response

  selected_item_count = initAction(action)

  if not selected_item_count then return end

  selected_item_groups = getSelectedSuperglueItemTypes(selected_item_count, {"superitem"})
  superitems = selected_item_groups["superitem"]["selected_items"]

  if not isNotSingleSuperitem(#superitems, action) then return end

  this_pool_id = storeRetrieveItemData(superitems[1], _instance_pool_id_key_suffix)
  other_open_instance = otherInstanceIsOpen(this_pool_id)

  if other_open_instance then
    handleOtherOpenInstance(other_open_instance, this_pool_id, action)

    return
  end

  superitem_is_multitake, superitem_takes_count = superitemHasMultipleTakes()

  if superitem_is_multitake then
    multitake_msg_user_response = handleMultitakeSuperitem(superitem_takes_count)

    if multitake_msg_user_response == "cancel" then return end
  end

  handleEditOrUnglue(this_pool_id, action)

  return this_pool_id
end


function isNotSingleSuperitem(superitems_count, action)
  local multiitem_result, user_wants_to_affect_1st_superitem

  if superitems_count == 0 then
    reaper.ShowMessageBox(_msg_change_selected_items, _script_brand_name .. " can only " .. action .. " previously Superglued Superitems." , _msg_type_ok)

    return false
  
  elseif superitems_count > 1 then
    multiitem_result = reaper.ShowMessageBox("Would you like to " .. action .. " the first selected superitem from the top track only?", _script_brand_name .. " can only " .. action .. " one Superitem per action call.", _msg_type_ok_cancel)
    user_wants_to_affect_1st_superitem = multiitem_result == _msg_response_ok

    if user_wants_to_affect_1st_superitem then
      return true
    end
  
  elseif superitems_count == 1 then
    return true
  end
end


function otherInstanceIsOpen(edit_pool_id)
  local all_items_count, this_item, restored_item_pool_id

  all_items_count = reaper.CountMediaItems(_api_current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)
    restored_item_pool_id = storeRetrieveItemData(this_item, _parent_pool_id_key_suffix)

    if restored_item_pool_id == edit_pool_id then
      return this_item
    end
  end
end


function handleOtherOpenInstance(instance, open_instance_pool_id, action)
  open_instance_pool_id = tostring(open_instance_pool_id)

  reaper.ShowMessageBox("Reglue the other open instance from pool " .. open_instance_pool_id .. " before trying to " .. action .. " this superitem. It will be selected and scrolled to now.", _script_brand_name .. " can only " .. action .. " one superitem pool instance at a time.", _msg_type_ok)
  reaper.Main_OnCommand(_command_id_deselect_all_items, _api_command_flag)
  reaper.SetMediaItemSelected(instance, true)
  reaper.Main_OnCommand(_command_id_scroll_to_selected_item, _api_command_flag)
end


function superitemHasMultipleTakes()
  local superitem, superitem_takes_count

  superitem = getFirstSelectedItem()
  superitem_takes_count = reaper.GetMediaItemNumTakes(superitem)

  if superitem_takes_count > 1 then
    return true, superitem_takes_count
  end
end


function handleMultitakeSuperitem(superitem_takes_count)
  local user_wants_to_explode_superitem_takes, user_response_explode_in_order

  user_wants_to_explode_superitem_takes = reaper.ShowMessageBox("Do you want to explode your Superitem takes before Editing?", "The Superitem selected has " .. superitem_takes_count .. " takes in it. " .. _script_brand_name .. " does not support multiple takes on Superitems.", _msg_type_ok_cancel)

  if user_wants_to_explode_superitem_takes == _msg_response_ok then
    user_response_explode_in_order = reaper.ShowMessageBox("Choose Yes to explode in order or No to explode in place.", "Do you want to explode in order?", _msg_type_yes_no)

    superitem, superitem_active_take = checkSuperitemTakesAreValid()

    if not superitem_active_take then
      return "cancel"
    end

    explodeSuperitem(superitem, superitem_active_take, user_response_explode_in_order)

  elseif user_wants_to_explode_superitem_takes == _msg_response_cancel then
    return "cancel"
  end
end


function checkSuperitemTakesAreValid()
  local superitem, superitem_active_take

  superitem = getFirstSelectedItem()
  superitem_active_take = reaper.GetActiveTake(superitem)

  if not superitem_active_take then
    throwOfflineTakeWarning()

    return false
  end

  return superitem, superitem_active_take
end


function explodeSuperitem(superitem, superitem_active_take, user_response_explode_in_order)
  local user_wants_to_explode_in_order, superitem_takes_count, superitem_params, duplicated_item_target_take_num, item_data_values, i, offline_takes_msg_shown

  superitem_takes_count, superitem_params, duplicated_item_target_take_num, item_data_values = getSuperitemExplodeParams(superitem)

  if user_response_explode_in_order == _msg_response_yes then
    user_wants_to_explode_in_order = true
  end

  for i = 0, superitem_takes_count-2 do
    duplicated_item_target_take_num, offline_takes_msg_shown = explodeSuperitemTakes(i, superitem, user_wants_to_explode_in_order, superitem_params, duplicated_item_target_take_num, item_data_values, offline_takes_msg_shown)
  end

  reaper.Main_OnCommand(_command_id_deselect_all_items, _api_command_flag)
  reaper.SetMediaItemSelected(superitem, true)
  reaper.Main_OnCommand(_command_id_crop_selected_items_to_active_takes, _api_command_flag)
end


function getSuperitemExplodeParams(superitem)
  local superitem_takes_count, superitem_params, duplicated_item_target_take_num, item_data_values, superitem_superglue_active_take_key, this_superitem_take, retval, this_superitem_take_active_flag

  superitem_takes_count = reaper.GetMediaItemNumTakes(superitem)
  superitem_params = getSetItemParams(superitem)
  duplicated_item_target_take_num = 0
  item_data_values = {_instance_pool_id_key_suffix, _parent_pool_id_key_suffix, _first_child_delta_to_superitem_position_key_suffix, _preglue_active_take_guid_key_suffix}
  superitem_superglue_active_take_key = _api_data_key .. _global_script_prefix .. _pool_key_prefix .. superitem_params.instance_pool_id .. _superglue_active_take_key_suffix
  superitem_params.superglue_active_take_num = -1

  for i = 0, superitem_takes_count-1 do
    this_superitem_take = reaper.GetTake(superitem, i)
    retval, this_superitem_take_active_flag = reaper.GetSetMediaItemTakeInfo_String(this_superitem_take, superitem_superglue_active_take_key, "", false)

    if this_superitem_take_active_flag == "true" then
      superitem_params.superglue_active_take_num = i

      reaper.SetActiveTake(this_superitem_take)

      break
    end
  end

  return superitem_takes_count, superitem_params, duplicated_item_target_take_num, item_data_values
end


function explodeSuperitemTakes(i, superitem, user_wants_to_explode_in_order, superitem_params, duplicated_item_target_take_num, item_data_values, offline_takes_msg_shown)
  local this_duplicated_item, this_duplicated_item_new_position, this_duplicated_item_new_active_take

  reaper.Main_OnCommand(_command_id_duplicate_selected_items, _api_command_flag)

  this_duplicated_item = getFirstSelectedItem()

  if user_wants_to_explode_in_order then
    this_duplicated_item_new_position = superitem_params.position + (superitem_params.length * (i + 1))

  else
    this_duplicated_item_new_position = superitem_params.position
  end

  reaper.SetMediaItemPosition(this_duplicated_item, this_duplicated_item_new_position, _api_dont_refresh_ui)

  for j = 1, #item_data_values do
    storeRetrieveItemData(this_duplicated_item, item_data_values[j], "")
  end

  duplicated_item_target_take_num, this_duplicated_item_new_active_take, offline_takes_msg_shown = handleDuplicatedItemTargetTake(i, this_duplicated_item, duplicated_item_target_take_num, superitem_params, offline_takes_msg_shown)

  removeSuperglueTakeNamePrefix(this_duplicated_item)
  addRemoveItemImage(this_duplicated_item, false)
  reaper.Main_OnCommand(_command_id_deselect_all_items, _api_command_flag)
  reaper.SetMediaItemSelected(superitem, true)

  return duplicated_item_target_take_num, offline_takes_msg_shown
end


function handleDuplicatedItemTargetTake(i, this_duplicated_item, duplicated_item_target_take_num, superitem_params, offline_takes_msg_shown)
  local this_duplicated_item_new_active_take, targeted_take_is_offline

  duplicated_item_target_take_num = duplicated_item_target_take_num + i

  if duplicated_item_target_take_num == superitem_params.superglue_active_take_num then
    duplicated_item_target_take_num = duplicated_item_target_take_num + 1
  end

  this_duplicated_item_new_active_take = reaper.GetTake(this_duplicated_item, duplicated_item_target_take_num)
  targeted_take_is_offline = not this_duplicated_item_new_active_take

  if not targeted_take_is_offline then
    reaper.SetActiveTake(this_duplicated_item_new_active_take)
    reaper.Main_OnCommand(_command_id_crop_selected_items_to_active_takes, _api_command_flag)

  elseif not offline_takes_msg_shown then
    throwOfflineTakeWarning(true)

    offline_takes_msg_shown = true
  end

  return duplicated_item_target_take_num, this_duplicated_item_new_active_take, offline_takes_msg_shown
end


function removeSuperglueTakeNamePrefix(item)
  local active_take_name, superglue_name_prefix, new_take_name

  active_take_name = getSetItemName(item)
  superglue_name_prefix = string.match(active_take_name, _superitem_name_default_prefix)

  if superglue_name_prefix then
    new_take_name = string.gsub(active_take_name, _superitem_name_default_prefix, "")
    
    getSetItemName(item, new_take_name)
  end
end


function handleEditOrUnglue(pool_id, action)
  local superitem, undo_block_string, active_track, restored_items

  superitem = getFirstSelectedItem()

  if action == "Edit" then
    storeRetrieveSuperitemParams(pool_id, _preedit_action_step, superitem)

    undo_block_string = _edit_undo_block_string

  elseif action == "Unglue" then
    undo_block_string = _unglue_undo_block_string
  end

  active_track, restored_items = processEditOrUnglue(superitem, pool_id, action)

  if action ~= "DePool" then
    
    if action ~= "Unglue" then
      updateRestoredItemsData(restored_items, pool_id)
    end

    cleanUpAction(undo_block_string, pool_id)
  end

  checkItemsOffscreen(#restored_items, action)
end


function processEditOrUnglue(superitem, pool_id, action)
  local superitem_preedit_params, active_track, superitem_state, restored_items, sizing_region_guid

  superitem_preedit_params = getSetItemParams(superitem)

  reaper.Main_OnCommand(_command_id_deselect_all_items, _api_command_flag)

  active_track = reaper.BR_GetMediaTrackByGUID(_api_current_project, superitem_preedit_params.track_guid)

  if action == "Edit" then
    superitem_state = getSetItemStateChunk(superitem)

    storeRetrievePoolData(pool_id, _superitem_preglue_state_suffix, superitem_state)
  end

  restored_items, looped_source_sets_sizing_region_enabled, superitem_loop_is_enabled = restoreStoredItems(pool_id, active_track, superitem, nil, action)

  if action == "Edit" then
    sizing_region_guid = createSizingRegionFromSuperitem(superitem, pool_id, looped_source_sets_sizing_region_enabled, superitem_loop_is_enabled)
  end

  reaper.DeleteTrackMediaItem(active_track, superitem)

  return active_track, restored_items
end


function createSizingRegionFromSuperitem(superitem, pool_id, looped_source_sets_sizing_region_enabled, superitem_loop_is_enabled)
  local superitem_params, superitem_active_take, superitem_active_take_source, sizing_region_guid

  superitem_params = getSetItemParams(superitem)

  if looped_source_sets_sizing_region_enabled == "true" and superitem_loop_is_enabled then
    superitem_active_take = reaper.GetActiveTake(superitem)
    superitem_active_take_source = reaper.GetMediaItemTake_Source(superitem_active_take)
    superitem_params.length = reaper.GetMediaSourceLength(superitem_active_take_source)
    superitem_params.end_point = superitem_params.length - superitem_params.position
  end

  sizing_region_guid = getSetSizingRegion(pool_id, superitem_params)
  
  return sizing_region_guid
end


function updateRestoredItemsData(restored_items, pool_id)
  local this_restored_item

  for i = 1, #restored_items do
    this_restored_item = restored_items[i]

    storeRetrieveItemData(this_restored_item, _parent_pool_id_key_suffix, pool_id)
  end
end


function initSmartAction(edit_or_unglue)
  local selected_item_count, pool_id
  
  selected_item_count = doPreSuperglueChecks()
  
  if selected_item_count == false then return end

  prepareAction("glue")
  
  if itemsAreSelected(selected_item_count) == false then return end

  pool_id = getFirstPoolIdFromSelectedItems()
  
  if superitemSelectionIsInvalid(selected_item_count, edit_or_unglue) == true then return end

  if triggerAction(selected_item_count, edit_or_unglue) == false then
    reaper.ShowMessageBox(_msg_change_selected_items, _script_brand_name .. " Smart Action can't determine which script to run.", _msg_type_ok)
    setResetUsersItemSelection(false)

    return
  end

  if pool_id then
    _smart_action_undo_block_string = _smart_action_undo_block_string .. " - Pool #" .. pool_id
  end

  reaper.Undo_EndBlock(_smart_action_undo_block_string, _api_include_all_undo_states)
end


function getSmartAction(selected_item_count)
  local selected_item_groups, parent_instances_count, no_parent_instances_are_selected, single_parent_instance_is_selected, parent_instances_are_selected, multiple_parent_instances_are_selected, nonsuperitems_count, no_nonsuperitems_are_selected, nonsuperitems_are_selected, child_instances_count, no_child_instances_are_selected

  selected_item_groups = getSelectedSuperglueItemTypes(selected_item_count, {"nonsuperitem", "child_instance", "parent_instance"})
  parent_instances_count = #selected_item_groups["parent_instance"]["selected_items"]
  no_parent_instances_are_selected = parent_instances_count == 0
  single_parent_instance_is_selected = parent_instances_count == 1
  parent_instances_are_selected = parent_instances_count > 0
  multiple_parent_instances_are_selected = parent_instances_count > 1
  nonsuperitems_count = #selected_item_groups["nonsuperitem"]["selected_items"]
  no_nonsuperitems_are_selected = nonsuperitems_count == 0
  nonsuperitems_are_selected = nonsuperitems_count > 0
  child_instances_count = #selected_item_groups["child_instance"]["selected_items"]
  no_child_instances_are_selected = child_instances_count == 0
  single_child_instance_is_selected = child_instances_count == 1

  if single_parent_instance_is_selected and no_nonsuperitems_are_selected and no_child_instances_are_selected then
    return "edit_or_unglue"
  
  elseif parent_instances_are_selected and single_child_instance_is_selected then
    return "glue/abort"
  
  elseif (multiple_parent_instances_are_selected and no_nonsuperitems_are_selected and no_child_instances_are_selected) or (nonsuperitems_are_selected and no_child_instances_are_selected) or (no_parent_instances_are_selected and single_child_instance_is_selected) then
    return "glue"
  end
end


function triggerAction(selected_item_count, edit_or_unglue)
  local superglue_action, glue_abort_dialog

  superglue_action = getSmartAction(selected_item_count)

  if superglue_action == "edit_or_unglue" then
    initEditOrUnglue(edit_or_unglue)

  elseif superglue_action == "glue" then
    initSuperglue()

  elseif superglue_action == "glue/abort" then
    glue_abort_dialog = reaper.ShowMessageBox("Are you sure you want to Superglue them?", "You have selected both Superitem(s) and restored item(s) from an edited Superitem.", _msg_type_ok_cancel)

    if glue_abort_dialog == 2 then
      setResetUsersItemSelection(false)

      return
    
    else
      initSuperglue()
    end

  else
    return false
  end
end


function initDePool(target_item)
  local this_is_user_initiated_depool, this_is_sibling_depool, target_item_params, target_item_state, active_track, contained_item_states, restored_items, superitem, new_pool_id

  this_is_user_initiated_depool = not target_item
  this_is_sibling_depool = target_item

  if this_is_user_initiated_depool then
    target_item = getFirstSelectedItem()
  end

  target_item_params = getSetItemParams(target_item)
  target_item_state = getSetItemStateChunk(target_item)
  active_track, target_item_params, restored_items = processDePool(target_item, target_item_params, this_is_user_initiated_depool)

  if this_is_sibling_depool then
    contained_item_states = prepareAndGetItemStates(restored_items, target_item_params.pool_id)
  end

  superitem = handleGlue(restored_items, active_track, nil, nil, target_item_params, false)
  new_pool_id = handleDePoolPostGlue(superitem, target_item_state, target_item_params)

  if this_is_user_initiated_depool then
    cleanUpAction(_depool_undo_block_string, new_pool_id)
  
  elseif this_is_sibling_depool then
    storeItemStates(new_pool_id, contained_item_states)
  end
end


function processDePool(target_item, target_item_params, this_is_user_initiated_depool)
  local this_is_sibling_depool, target_item_instance_pool_id

  this_is_sibling_depool = not this_is_user_initiated_depool
  target_item_instance_pool_id = storeRetrieveItemData(target_item, _instance_pool_id_key_suffix)
  _first_restored_item_last_glue_delta_to_parent = storeRetrievePoolData(target_item_instance_pool_id, _first_child_delta_to_superitem_position_key_suffix)

  if this_is_user_initiated_depool then
    return processUserInitiatedDePool(target_item, target_item_params)

  elseif this_is_sibling_depool then
    return processSiblingDePool(target_item, target_item_params)
  end
end


function processUserInitiatedDePool(target_item, target_item_params)
  local restored_items, active_track, selected_items_count, this_restored_item
  
  restored_items = {}
  active_track = reaper.GetMediaItemTrack(target_item)
  target_item_params.pool_id = initEditOrUnglue("DePool")
  selected_items_count = reaper.CountSelectedMediaItems(_api_current_project)

  for i = 0, selected_items_count-1 do
    this_restored_item = reaper.GetSelectedMediaItem(_api_current_project, i)

    table.insert(restored_items, this_restored_item)
  end

  return active_track, target_item_params, restored_items
end


function processSiblingDePool(target_item, target_item_params)
  local restored_items, active_track, selected_items_count, this_restored_item

  restored_items = {}
  target_item_params.pool_id = storeRetrieveItemData(target_item, _instance_pool_id_key_suffix)
  active_track, restored_items = processEditOrUnglue(target_item, target_item_params.pool_id, "DePool")

  return active_track, target_item_params, restored_items
end


function handleDePoolPostGlue(superitem, target_item_state, target_item_params)
  local superitem_active_take, active_take_name, updated_src, new_pool_id

  superitem_active_take = reaper.GetActiveTake(superitem)
  active_take_name = getSetItemName(superitem)
  updated_src = getSetWipeItemAudioSrc(superitem)
  new_pool_id = storeRetrieveItemData(superitem, _instance_pool_id_key_suffix)

  storeRetrievePoolData(new_pool_id, _first_child_delta_to_superitem_position_key_suffix, _first_restored_item_last_glue_delta_to_parent)
  storeRetrievePoolData(new_pool_id, _freshly_depooled_superitem_flag, "true")
  getSetItemStateChunk(superitem, target_item_state)
  getSetItemName(superitem, active_take_name)
  storeRetrieveItemData(superitem, _instance_pool_id_key_suffix, new_pool_id)
  refreshActiveTakeFlag(superitem, superitem_active_take, new_pool_id)
  reaper.SetMediaItemSelected(superitem, true)
  setSuperitemColor()

  return new_pool_id
end


function setAllSuperitemsColor()
  local current_window, retval, color, all_items_count, this_item, this_item_instance_pool_id

  current_window = reaper.GetMainHwnd()
  retval, color = reaper.GR_SelectColor(current_window)

  if retval ~= 0 then
    prepareAction("color")

    all_items_count = reaper.CountMediaItems(_api_current_project)

    for i = 0, all_items_count-1 do
      this_item = reaper.GetMediaItem(_api_current_project, i)
      this_item_instance_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)

      if this_item_instance_pool_id and this_item_instance_pool_id ~= "" then
        reaper.SetMediaItemInfo_Value(this_item, _api_item_color_key, color|0x1000000)
      end
    end
    
    cleanUpAction(_color_undo_block_string, this_item_instance_pool_id)
  end
end



--- UTILITY FUNCTIONS ---

function copyFile(old_path, new_path)
  local old_file = io.open(old_path, "rb")
  local new_file = io.open(new_path, "wb")
  local old_file_sz, new_file_sz = 0, 0
  if not old_file or not new_file then
    return false
  end
  while true do
    local block = old_file:read(2^13)
    if not block then 
      old_file_sz = old_file:seek( "end" )
      break
    end
    new_file:write(block)
  end
  old_file:close()
  new_file_sz = new_file:seek( "end" )
  new_file:close()
  return new_file_sz == old_file_sz
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

function fileExists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function getFileNameFromPath(file)
    return file:match("^.+[/\\](.+)$")
end

function getTableSize(t)
    local count = 0
    for _, __ in pairs(t) do
        count = count + 1
    end
    return count
end

function numberizeAndRoundElements(tables, elems)
  local this_table
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