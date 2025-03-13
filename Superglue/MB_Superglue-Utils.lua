--@noindex


-- ==== SUPERGLUE UTILS SCRIPT ARCHITECTURE NOTES ====
-- Superglue requires Reaper SWS plug-in extension v2.13.1.0+ (https://www.sws-extension.org/download/pre-release) and js_ReaScript_API (https://github.com/ReaTeam/Extensions/raw/master/index.xml) to be installed in Reaper.
-- Superglue uses the great GUI library Reaper Toolkit (rtk). (https://reapertoolkit.dev/).
-- Superglue uses Serpent, a serialization library for LUA, for table-string and string-table conversion. (https://github.com/pkulchenko/serpent).
-- Superglue uses Reaper's Master Track P_EXT to store project-wide script data because its changes are saved in Reaper's undo points, a feature that functions correctly since Reaper v6.43.
-- Script data is also stored in media items' & takes' P_EXT.
-- General utility functions at bottom


-- DEV code must be first
local _test_logging_enabled = true
local _log_function_entry = false
local _log_function_exit = false
local _module_dev
local log

if _test_logging_enabled then
  _module_dev = require("mb-dev-functions")
  log = _module_dev.log

else
  log = function() return end
end
-- !DEV





local rtk = require('rtk')
local serpent = require("serpent")


local Superglue = {}
local _module_options = {}
local _module_data = {}
local _module_iteminfo = {}
local _module_init = {}
local _module_common = {}
local _module_multi = {}
local _module_single = {}
local _module_lanes = {}
local _module_midi = {}
local _module_vi = {}
local _module_glue = {}
local _module_overglue = {}
local _module_depool = {}
local _module_edit = {}
local _module_util = {}


local _regex = {
  nested_item_default_name = '%[".+%]',
  file_extension = "%.([^%.]+)$",
  string_start = "^",
  superitem_name_iterator = "%:%d+"
}


local _unicode = {
  double_quotation_mark = "\u{0022}",
  no_break_space = "\u{00a0}"
}


local _api = {
  current_project = 0,
  cmd_flag = 0,
  dont_refresh_ui = false,
  include_all_undo_states = -1,
  set_value = true,
  get_value = false,
  time_value_decimal_resolution = 12,
  data_key = "P_EXT:",

  command_section = {
    main = 0
  },

  extstate = {
    persist_enabled = true
  },

  -- UNUSED
  -- undo_states = {
  --   marker_region_undo_states = 8
  -- },

  datatype = {
    mediaitem = "MediaItem*"
  },

  msg = {

    type = {
      ok = 0,
      ok_cancel = 1,
      yes_no = 4
    },

    response = {
      ok = 1,
      cancel = 2,
      yes = 6,
      no = 7
    }
  },

  timeline = {
    loop_enabled = 1.0
  },

  regionmarker = {
    guid_key_prefix = "MARKER_GUID:",
  },

  track = {
    very_1st_track_of_project = 0,
    no_defaults = false,

    key = {
      name = "P_NAME"
    }
  },

  item = {
    image_full_height = 5,

    key = {
      loop_src = "B_LOOPSRC",
      -- mute = "B_MUTE", -- UNUSED
      position = "D_POSITION",
      length = "D_LENGTH",
      -- notes = "P_NOTES", -- UNUSED
      color = "I_CUSTOMCOLOR"
    }
  },

  take = {
    new_take_marker_idx = -1,
    null_takes_val = "TAKE NULL",

    key = {
      src_offset = "D_STARTOFFS",
      playrate = "D_PLAYRATE",
      name = "P_NAME",
      number = "IP_TAKENUMBER",
      guid = "GUID"
    }
  }
}


local _cmd = {
  deselect_all_items = 40289,
  glue_ignoring_time_selection_incl_fades = 40257,
  apply_track_take_fx_to_items = 40209,
  apply_fx_to_items_multichannel = 41993,
  build_missing_peaks = 40047,
  -- rebuild_peaks_for_selected_items = 40441, -- UNUSED
  -- delete_active_take_from_items = 40129, -- UNUSED
  set_item_to_one_random_color = 40706,
  duplicate_selected_items = 41295,
  crop_selected_items_to_active_takes = 40131,
  scroll_to_selected_item = reaper.NamedCommandLookup("_S&M_SCROLL_ITEM")
}


local _brand = {
  name = "MB_Superglue",
  separator = ":",

  prefix = {
    global = "SG_",
    item_name = "sg"
  }
}

_brand.prefix.superitem_name = _brand.prefix.item_name .. _brand.separator
_brand.prefix.superitem_name_default = _regex.string_start .. _brand.prefix.item_name .. _regex.superitem_name_iterator


local _file = {

  os = {
    separator = package.config:sub(1,1)
  },

  path = {
    script = string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$"),
    proj_render = reaper.GetProjectPath(_api.current_project)
  },

  name = {
    custom_separator = "_",
    superitem_bg_img = "sg-bg-superitem.png",
    restored_item_bg_img = "sg-bg-restored.png",
    restored_instance_bg_img = "sg-bg-restoredinstance.png",
    script_logo = "mb_superglue_logo_nobg_sm.png",
    peak_data_extension = ".reapeaks"
  },

  supported_media_types = "*.aif\0*.aiff\0*.avi\0*.bwf\0*.cda\0*.dat\0*.edl\0*.flac\0*.gif\0*.jpeg\0*.jpg\0*.kar\0*.lcf\0*.m4a\0*.m4v\0*.mid\0*.midi\0*.mkv\0*.mogg\0*.mov\0*.mp2\0*.mp3\0*.mp4\0*.mpeg\0*.mpg\0*.musicxml\0*.mxl\0*.ogg\0*.ogv\0*.opus\0*.png\0*.qt\0*.rcy\0*.rex\0*.rmi\0*.rpp\0*.rpp-prox\0*.rx2\0*.syx\0*.w64\0*.wav\0*.webm\0*.wma\0*.wmv\0*.wv\0*.xml\0\0"
}

_file.path.splitter = "([^%" .. _file.os.separator .. "]+)"
_file.path.superitem_bg_img = _file.path.proj_render .. _file.os.separator .. _file.name.superitem_bg_img
_file.path.restored_item_bg_img = _file.path.proj_render .. _file.os.separator .. _file.name.restored_item_bg_img
_file.path.restored_instance_bg_img = _file.path.proj_render .. _file.os.separator .. _file.name.restored_instance_bg_img


local _constant = {
  position_start_of_project = 0,
  noninstance_label = "noninstance-",

  reaper = {

    version = {
      fixed_lanes = 7
    }
  },

  support = {
    fixed_lanes = false
  },

  actionstep = {
    freshly_depooled_superitem_flag = ":freshly-depooled",
    postglue = "postglue",
    preedit = "preedit"
  },

  sizingregion = {

    label = {
      prefix = "SG: Pool #",
      suffix = " – DO NOT DELETE – Use to set Superitem edges"
    },

    color = reaper.ColorToNative(255, 255, 255)|0x1000000,
    first_display_num = 0
  },

  data = {
    storage_track = reaper.GetMasterTrack(_api.current_project),

    key = {

      options = {
        global_section = "MB_SUPERGLUE-OPTIONS",

        toggle = {
          time_selection_sets_bounds_on_glue = "time_selection_sets_superitem_bounds_on_initial_glue_enabled",
          auto_increase_channel_count = "auto_increase_channel_count_enabled",
          item_images = "item_images_enabled",
          new_superglue_random_color = "new_superglue_random_color_enabled",
          retain_only_last_glue_source = "retain_only_last_glue_source_enabled",
          loop_source_sets_sizing_region_bounds_on_reglue = "loop_source_sets_sizing_region__bounds_enabled",
          depool_all_siblings_on_reglue = "depool_all_siblings_on_reglue_enabled",
          multiitem_editing = "multiitem_editing_enabled",
          depool_all_siblings_on_reglue_warning = "depool_all_siblings_on_reglue_warning_enabled"
        },

        switch = {
          maintain_source_position = "maintain_source_position",
          propagate_position = "propagate_position",
          propagate_length = "propagate_length",
          length_propagation_type = "length_propagation_type",
          playrate_affects_propagation = "playrate_affects_propagation"
        },

        defaults = {}
      },

      all_pool_ids_with_active_sizing_regions = "pool-ids-with-active-sizing-regions",

      prefix = {
        pool = "pool-"
      },

      suffix = {

        pool = {
          contained_item_states = ":contained-item-states",

          last_glue = {
            contained_item_states = ":last-glue-contained-item-states"
          },

          parent_position = ":first-parent-instance-position",
          parent_length = ":first-parent-instance-length",
          instance_id = "instance-pool-id",
          parent_id = "parent-pool-id",
          last_id = "last-pool-id",
          parent_ids_data = ":parent-pool-ids",
          descendant_ids = ":descendant-pool-ids",
          top_lane = ":top-lane",
          top_lane_y_pos = ":top-lane-y-pos"
        },

        item = {
          lane_offset = ":lane-offset"
        },

        preglue = {
          active_take_guid = "preglue-active-take-guid",
          superitem_state = ":preglue-state-chunk"
        },

        superitem = {
          superglue_active_take = "_superitem-superglue-active-take",
          params = "-superitem-params",
          first_child_delta_to_superitem_position = ":restored-items-position-offset"
        }
      }
    }
  }
}

_constant.global_options = {

  {
    name = "time_selection_sets_superitem_bounds_on_initial_glue",
    type = "checkbox",
    ext_state_key = _constant.data.key.options.toggle.time_selection_sets_bounds_on_glue,
    option_script_filename = "MB_Superglue - Options - Glue - Time selection determines Superitem bounds on initial glue (On-Off).lua",
    user_readable_text = "Glue: Time selection determines Superitem bounds on initial Superitem creation",
    default_value = "false"
  },

  {
    name = "auto_increase_channel_count_with_take_fx",
    type = "checkbox",
    ext_state_key = _constant.data.key.options.toggle.auto_increase_channel_count,
    option_script_filename = "MB_Superglue - Options - Glue - Auto-increase channel count with take FX (On-Off).lua",
    user_readable_text = "Glue: Auto-increase channel count with take FX",
    default_value = "false"
  },

  {
    name = "loop_source_sets_sizing_region_bounds_on_reglue",
    type = "checkbox",
    ext_state_key = _constant.data.key.options.toggle.loop_source_sets_sizing_region_bounds_on_reglue,
    option_script_filename = "MB_Superglue - Options - Reglue - Looped source of Superitem determines Sizing Region bounds (On-Off).lua",
    user_readable_text = "Reglue: Looped source of Superitem determines Sizing Region bounds",
    default_value = "true"
  },

  {
    name = "depool_all_siblings_on_reglue",
    type = "checkbox",
    ext_state_key = _constant.data.key.options.toggle.depool_all_siblings_on_reglue,
    option_script_filename = "MB_Superglue - Options - Reglue - Remove Siblings from Edited Superitem's Pool, giving every Sibling its own new Pool (On-Off).lua",
    user_readable_text = "Reglue: Remove all sibling instances from pool (disable & undo pooling)",
    default_value = "false"
  },

  {
    name = "multiitem_editing",
    type = "checkbox",
    ext_state_key = _constant.data.key.options.toggle.multiitem_editing,
    option_script_filename = "MB_Superglue - Options - Edit-Unglue-DePool - Enable multi-item Edit, Unglue, or DePool in single action (On-Off).lua",
    user_readable_text = "Edit/Unglue/DePool: Enable multi-item Edit, Unglue, and DePool in single action (Disable for v1.x Smart Action)",
    default_value = "true"
  },

  {
    name = "item_images",
    type = "checkbox",
    ext_state_key = _constant.data.key.options.toggle.item_images,
    option_script_filename = "MB_Superglue - Options - Display - Background images on new Superglue items - Superitems diagonal, contained items horizontal stripes (On-Off).lua",
    user_readable_text = "Display: Insert item background images on Superglue and Edit, overwriting item notes",
    default_value = "true"
  },

  {
    name = "new_superglue_random_color",
    type = "checkbox",
    ext_state_key = _constant.data.key.options.toggle.new_superglue_random_color,
    option_script_filename = "MB_Superglue - Options - Display - Randomly color newly Superglued Superitem (On-Off).lua",
    user_readable_text = "Display: Set newly glued Superitems to random color",
    default_value = "true"
  },

  {
    name = "retain_only_last_glue_source",
    type = "checkbox",
    ext_state_key = _constant.data.key.options.toggle.retain_only_last_glue_source,
    option_script_filename = "MB_Superglue - Options - Files - Retain only the latest Superglue source media, leaving undo history offline (On-Off).lua",
    user_readable_text = "Files: Retain only the latest Superglue source media (leaving undo history offline)",
    default_value = "false"
  },

  {
    name = "maintain_source_position",
    type = "dropdown",
    ext_state_key = _constant.data.key.options.switch.maintain_source_position,
    option_script_filename = "MB_Superglue - Options - Reglue - Audio source position of Siblings is maintained (Enable-Ask-Disable).lua",
    user_readable_text = "Reglue: Audio source timeline location on Siblings is maintained",

    values = {
      {"always", "Maintain source location"},
      {"ask", "Ask"},
      {"no", "Source can change location"}
    },

    default_value = "always"
  },

  {
    name = "propagate_position_change",
    type = "dropdown",
    ext_state_key = _constant.data.key.options.switch.propagate_position,
    option_script_filename = "MB_Superglue - Options - Reglue - Position change of Edited Superitem's left edge propagates to Siblings (Enable-Ask-Disable).lua",
    user_readable_text = "Reglue: Left edge position change of edited Superitem propagates to Siblings",

    values = {
      {"always", "Always propagate position"},
      {"ask", "Ask"},
      {"no", "Don't propagate position"}
    },

    default_value = "ask"
  },

  {
    name = "propagate_length_change",
    type = "dropdown",
    ext_state_key = _constant.data.key.options.switch.propagate_length,
    option_script_filename = "MB_Superglue - Options - Reglue - Length change of Edited Superitem propagates to Siblings (Enable-Ask-Disable).lua",
    user_readable_text = "Reglue: Length change of edited Superitem propagates to Siblings",

    values = {
      {"always", "Always propagate length"},
      {"ask", "Ask"},
      {"no", "Don't propagate length"}
    },

    default_value = "always"
  },

  {
    name = "length_propagation_type",
    type = "dropdown",
    ext_state_key = _constant.data.key.options.switch.length_propagation_type,
    option_script_filename = "MB_Superglue - Options - Reglue - Absolute or relative propagation length change on Siblings (still altered by playrate) (Absolute-Ask-Relative).lua",
    user_readable_text = "Reglue: Absolute or relative length propagation on Siblings (can still be altered by playrate option)",

    values = {
      {"always", "Absolute length propagation"},
      {"ask", "Ask"},
      {"no", "Relative length propagation"}
    },

    default_value = "no"
  },

  {
    name = "playrate_affects_propagation",
    type = "dropdown",
    ext_state_key = _constant.data.key.options.switch.playrate_affects_propagation,
    option_script_filename = "MB_Superglue - Options - Reglue - Playrate of Siblings affects their length & position propagation values (Enable-Ask-Disable).lua",
    user_readable_text = "Reglue: Sibling playrate affects Sibling length & position propagation by default",

    values = {
      {"always", "Playrate always affects propagation"},
      {"ask", "Ask"},
      {"no", "Playrate doesn't affect propagation"}
    },

    default_value = "always"
  }
}


local _state = {

  user = {
    time_selection_before_action = {},
    item_selection = nil,
    wants_to_depool_all_siblings = nil
  },

  action = {

    edit_or_unglue = {
      restored_items = nil
    },

    edit = {
      changed_pool_ids = nil
    },

    glue = {
      all_glued_superitems = nil,
      changed_pool_ids = nil,
      current_track = nil,
      overglued_superitems = {}
    },

    depool = {
      new_pool_ids = nil
    }
  },

  pool = {
    active_glue_pool_id = nil,

    parent_pool_ids_on_this_track = {
      descendant_to_ancestor = nil
    }
  },

  superitem = {
    position_changed_since_last_glue = false,
    offset_changed_since_last_glue = false,
    active_instance_length_has_changed = nil,
    reglue_position_change_affect_on_length = nil,
    pool_parent_last_glue_length = nil,
    this_previously_depooled_superitem_has_not_been_edited = nil,

    delta = {
      position_during_glue = 0,
      offset_since_last_glue = 0
    },

    params = {
      ancestor_pools = {},

      last_glue = {
        edited_pool = nil
      },

      fresh_glue = {
        edited_pool = nil
      },

      post_glue = {
        edited_pool = nil
      },

      preedit = {
        edited_pool = nil,
        current_pool = nil
      },

      fresh_glue = {
        current_pool = nil
      }
    }
  },

  restored_items = {
    -- position_delta_near_project_start = 0,
    first_restored_item_last_glue_delta_to_parent = nil,
    last_glue_stored_item_states = nil,
    preglue_restored_item_states = nil,
    unselected_contained_items = nil
  },

  propagation = {
    user_responses = {},
    user_wants_option = {}
  }
}


-- UNUSED?
-- _src_offset_default_value = 0
-- _playrate_default_value = 1.0



function Superglue.initMainAction(action)
  local selected_item_count = _module_init.setUpAction(action)

  if not selected_item_count then return end

  if action == "Glue" then
    _module_init.doGlueAction(selected_item_count, action)

  elseif action == "Edit" or action == "Unglue" then
    _module_init.doEditOrUnglueAction(selected_item_count, action)

  elseif action == "DePool" then
    _module_init.doDePoolAction(selected_item_count, action)

  elseif action == "Smart Glue/Edit" or action == "Smart Glue/Unglue" then
    _module_init.doSmartAction(selected_item_count, action)
  end
end


function Superglue.initUtilityAction(action)

  if action == "Open Superglue Options Window" then
    _module_options.openOptionsWindow()

  elseif action == "Open Superglue Item Info Window" then
    _module_iteminfo.openItemInfoWindow()

  elseif action == "Set All Superitems Color" then
    _module_common.setAllSuperitemsColor(action)

  elseif action == "Log Superglue Project Data" then
    Superglue.logSuperglueProjectData()
  end
end


function Superglue.initOptionToggle(option_name)
  local active_option, current_val, new_val

  active_option = _module_options.getActiveOption(option_name)

  if not active_option then return end

  current_val = reaper.GetExtState(_constant.data.key.options.global_section, active_option.ext_state_key)

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

  _module_options.updateOptionValue(active_option, new_val)
end



function _module_options.populateOptionsDefaults()

  for _, option in ipairs(_constant.global_options) do
    _constant.data.key.options.defaults[option.name] = option.default_value
  end
end

_module_options.populateOptionsDefaults()


function _module_options.updateOptionValue(option, val)
  local option_toggle_script_filepath, option_toggle_script_command_id, option_is_boolean, integer_val

  option_toggle_script_filepath = _file.path.script .. option.option_script_filename
  option_toggle_script_command_id = reaper.AddRemoveReaScript(true, _api.command_section.main, option_toggle_script_filepath, false)
  option_is_boolean = not option.values

  if option_is_boolean then
    integer_val = val == "true" and 1 or 0

    reaper.SetToggleCommandState(_api.command_section.main, option_toggle_script_command_id, integer_val)
    reaper.RefreshToolbar2(_api.command_section.main, option_toggle_script_command_id)
  end

  reaper.SetExtState(_constant.data.key.options.global_section, option.ext_state_key, val, _api.extstate.persist_enabled)
end


_module_options.setDefaultOptionValues = (function()
  local this_option_ext_state_key, this_option_exists_in_extstate, this_option_is_not_set_in_extstate

  for i = 1, #_constant.global_options do
    this_option_ext_state_key = _constant.global_options[i].ext_state_key
    this_option_exists_in_extstate = reaper.HasExtState(_constant.data.key.options.global_section, this_option_ext_state_key)
    this_option_is_not_set_in_extstate = not this_option_exists_in_extstate or this_option_exists_in_extstate == "nil"

    if this_option_is_not_set_in_extstate then
      _module_options.updateOptionValue(_constant.global_options[i], _constant.global_options[i].default_value)
    end
  end
end)()


function _module_options.getActiveOption(option_name)
  local active_option_idx, active_option

  for i = 1, #_constant.global_options do

    if _constant.global_options[i].name == option_name then
      active_option_idx = i

      break
    end
  end

  active_option = _constant.global_options[active_option_idx]

  return active_option
end


function _module_options.openOptionsWindow()
  local option_window_widgets, all_option_controls

  option_window_widgets = _module_options.createOptionsWidgets()

  _module_options.populateOptionsWidgets(option_window_widgets)

  all_option_controls = _module_options.populateOptionControls(option_window_widgets)

  _module_options.populateOptionsEventHandlers(option_window_widgets, all_option_controls)
  _module_options.populateOptionsWindow(option_window_widgets)
  option_window_widgets.options_window:open{align = "center"}
end


function _module_options.createOptionsWidgets()
  local option_window_widgets

  option_window_widgets = {
    options_window = rtk.Window{w = 0.5, maxh = 0.85, title = _brand.name .. " Global Options"},
    options_window_inner = rtk.VBox(),
    options_window_top = rtk.Container{valign = "center"},
    options_window_branding = rtk.VBox{halign = "center", padding = "3 5", border = "1px #878787", bg = "#505050"},
    options_window_script_name = rtk.Text{_brand.name, halign = "center", fontscale = 0.8},
    options_window_logo = rtk.ImageBox{rtk.Image():load(_file.name.script_logo, 2), tmargin = 4},
    options_window_title = rtk.Heading{"Global Options", w = 1, halign = "center", bmargin = 25},
    options_viewport = rtk.Viewport(),
    options_window_content = rtk.VBox{padding = "27 38 7"},
    option_form_buttons = rtk.HBox{w = 1, margin = "40 10 10 10", spacing = 10, halign = "center"},
    option_form_save = rtk.Button{"Save", disabled = true},
    option_form_cancel = rtk.Button{"Cancel"},
    option_footer = rtk.HBox{w = 1, halign = "center"},
    options_repo_url = "https://github.com/MonkeyBars3k/ReaScripts"
  }

  option_window_widgets.option_repo_text = rtk.Text{option_window_widgets.options_repo_url ..  " [click to copy]", w = 1, halign = "center", fontscale = 0.67, color = "#989898"}

  return option_window_widgets
end


function _module_options.populateOptionsWidgets(option_window_widgets)
  option_window_widgets.option_form_buttons:add(option_window_widgets.option_form_save)
  option_window_widgets.option_form_buttons:add(option_window_widgets.option_form_cancel)
  option_window_widgets.option_footer:add(option_window_widgets.option_repo_text)
  option_window_widgets.options_window_branding:add(option_window_widgets.options_window_script_name)
  option_window_widgets.options_window_branding:add(option_window_widgets.options_window_logo)
  option_window_widgets.options_window_top:add(option_window_widgets.options_window_branding)
  option_window_widgets.options_window_top:add(option_window_widgets.options_window_title)
end


function _module_options.populateOptionControls(option_window_widgets)
  local all_option_controls, this_option, this_option_name

  all_option_controls = {}

  for i = 1, #_constant.global_options do
    this_option = _constant.global_options[i]
    this_option_name = this_option.name

    if this_option.type == "checkbox" then
      all_option_controls[this_option_name] = _module_options.getOptionCheckbox(this_option, option_window_widgets.option_form_save)

    elseif this_option.type == "dropdown" then
      all_option_controls[this_option_name] = _module_options.getOptionDropdown(this_option, option_window_widgets.option_form_save)
    end

    option_window_widgets.options_window_content:add(all_option_controls[this_option_name])
  end

  return all_option_controls
end


function _module_options.populateOptionsEventHandlers(option_window_widgets, all_option_controls)
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

  option_window_widgets.option_form_save.onclick = function()
    _module_options.submitOptionChanges(all_option_controls, option_window_widgets.options_window)
  end
end


function _module_options.populateOptionsWindow(option_window_widgets)
  local content_padding_adjustment, options_window_content_height

  option_window_widgets.options_window_content:add(option_window_widgets.option_form_buttons)
  option_window_widgets.options_window_content:add(option_window_widgets.option_footer)
  option_window_widgets.options_viewport:attr("child", option_window_widgets.options_window_content)
  option_window_widgets.options_window_inner:add(option_window_widgets.options_window_top)
  option_window_widgets.options_window_inner:add(option_window_widgets.options_viewport)
  option_window_widgets.options_window:add(option_window_widgets.options_window_inner)
end


function _module_options.getOptionCheckbox(option, option_form_save)
  local option_saved_value, checkbox_value, option_checkbox

  option_saved_value = reaper.GetExtState(_constant.data.key.options.global_section, option.ext_state_key)
  checkbox_value = option_saved_value == "true" and true or false
  option_checkbox = rtk.CheckBox{option.user_readable_text, value = checkbox_value, margin = "10 0"}
  option_checkbox.onchange = function()
    _module_options.activateOptionSubmitButton(option_form_save)
  end

  return option_checkbox
end


function _module_options.activateOptionSubmitButton(submit_button)
  submit_button:attr("disabled", false)
end


function _module_options.getOptionDropdown(option, option_form_save)
  local option_saved_value, option_dropdown_box, dropdown_label, dropdown_control, dropdown_menu, this_option_value, this_option_value_menu_item

  option_saved_value = reaper.GetExtState(_constant.data.key.options.global_section, option.ext_state_key)
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
    _module_options.activateOptionSubmitButton(option_form_save)
  end

  option_dropdown_box:add(dropdown_control)
  option_dropdown_box:add(dropdown_label)

  return option_dropdown_box
end


function _module_options.submitOptionChanges(all_option_controls, options_window)
  local this_option, this_option_saved_value, this_option_form_value, dropdown, option_has_changed

  for i = 1, #_constant.global_options do
    this_option = _constant.global_options[i]
    this_option_saved_value = reaper.GetExtState(_constant.data.key.options.global_section, this_option.ext_state_key)

    if this_option.type == "checkbox" then
      this_option_form_value = tostring(all_option_controls[this_option.name].value)

    elseif this_option.type == "dropdown" then
      dropdown = all_option_controls[this_option.name]:get_child(1)
      this_option_form_value = dropdown.selected
    end

    option_has_changed = this_option_form_value ~= this_option_saved_value

    if option_has_changed then
      _module_options.updateOptionValue(this_option, this_option_form_value)
      _module_options.resetDePoolAllSiblingsWarning(this_option.ext_state_key)
    end
  end

  options_window:close()
end


function _module_options.resetDePoolAllSiblingsWarning(ext_state_key)

  if ext_state_key == _constant.data.key.options.toggle.depool_all_siblings_on_reglue then
    reaper.SetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.depool_all_siblings_on_reglue_warning, "true", _api.extstate.persist_enabled)
  end
end



function _module_data.storeRetrieveProjectData(key, val)
  local retrieve, store, store_or_retrieve_state_data, data_param_key, retval, state_data_val

  retrieve = not val
  store = val

  if retrieve then
    val = ""
    store_or_retrieve_state_data = false

  elseif store then
    store_or_retrieve_state_data = true
  end

  data_param_key = _api.data_key .. _brand.prefix.global .. key
  retval, state_data_val = reaper.GetSetMediaTrackInfo_String(_constant.data.storage_track, data_param_key, val, store_or_retrieve_state_data)

  return retval, state_data_val
end


function _module_data.storeRetrievePoolData(pool_id, key_suffix, new_value)
  local is_store, is_retrieve, key, retval, stored_value

  is_store = new_value
  is_retrieve = not new_value
  key = _constant.data.key.prefix.pool .. pool_id .. key_suffix

  if is_store then
    _module_data.storeRetrieveProjectData(key, new_value)

  elseif is_retrieve then
    retval, stored_value = _module_data.storeRetrieveProjectData(key)
  end

  return stored_value
end


function _module_data.storeRetrieveItemData(item, key_suffix, val)
  local retrieve, store, data_param_key, retval

  retrieve = not val
  store = val
  data_param_key = _api.data_key .. _brand.prefix.global .. key_suffix

  if retrieve then
    retval, val = reaper.GetSetMediaItemInfo_String(item, data_param_key, "", false)

    return val

  elseif store then
    reaper.GetSetMediaItemInfo_String(item, data_param_key, val, _api.set_value)
  end
end



function _module_iteminfo.openItemInfoWindow()
  local selected_item_count, selected_items, no_superglue_items_are_selected, all_selected_items_window_data

  selected_item_count = reaper.CountSelectedMediaItems(_api.current_project)

  if selected_item_count == false then return end

  selected_items = _module_init.getSelectedItems(selected_item_count)
  no_superglue_items_are_selected, all_selected_items_window_data = _module_iteminfo.getAllSelectedItemsInfo(selected_items)

  if no_superglue_items_are_selected then
    reaper.ShowMessageBox("The selected items aren't associated with " .. _brand.name .. ". Select Superitems or restored items and try again.", "No " .. _brand.name .. " items selected", _api.msg.type.ok)

    return
  end

  if all_selected_items_window_data then
    _module_iteminfo.populateItemInfoWindow(all_selected_items_window_data)
  end
end


function _module_iteminfo.getAllSelectedItemsInfo(selected_items)
  local no_superglue_items_are_selected, all_selected_items_window_data, this_selected_item, this_selected_superitem_instance_pool_id, this_is_superitem, this_selected_item_parent_pool_id, this_is_child_item, this_selected_item_info_name, this_selected_item_info

  no_superglue_items_are_selected = true
  all_selected_items_window_data = {}

  for i = 1, #selected_items do
    this_selected_item = selected_items[i]
    this_selected_superitem_instance_pool_id = _module_data.storeRetrieveItemData(this_selected_item, _constant.data.key.suffix.pool.instance_id)
    this_is_superitem = this_selected_superitem_instance_pool_id and this_selected_superitem_instance_pool_id ~= ""
    this_selected_item_parent_pool_id = _module_data.storeRetrieveItemData(this_selected_item, _constant.data.key.suffix.pool.parent_id)
    this_is_child_item = this_selected_item_parent_pool_id and this_selected_item_parent_pool_id ~= ""

    if this_is_superitem or this_is_child_item then
      no_superglue_items_are_selected = false
      this_selected_item_info_name, this_selected_item_info = _module_iteminfo.getSelectedItemInfo(this_selected_item, this_selected_superitem_instance_pool_id, this_selected_item_parent_pool_id, this_is_superitem, this_is_child_item)

      all_selected_items_window_data[i] = {
        name = this_selected_item_info_name,
        info = this_selected_item_info
      }
    end
  end

  return no_superglue_items_are_selected, all_selected_items_window_data
end


function _module_iteminfo.getSelectedItemInfo(selected_item, selected_superitem_instance_pool_id, selected_item_parent_pool_id, this_is_superitem, this_is_child_item)
  local selected_item_info_name, selected_item_info, selected_item_params

  selected_item_info_name = _module_common.getSetItemName(selected_item)
  selected_item_info = ""

  if this_is_superitem then
    selected_item_params = _module_iteminfo.prepareItemInfo(selected_superitem_instance_pool_id, selected_item_parent_pool_id)

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

    selected_item_info = selected_item_info .. selected_item_params[i][1] .. "\n" .. selected_item_params[i][2] .. "\n\n"
  end

  return selected_item_info_name, selected_item_info
end


function _module_iteminfo.prepareItemInfo(selected_superitem_instance_pool_id, selected_item_parent_pool_id)
  local selected_superitem_descendant_pool_ids, retval, stored_item_state_chunks, selected_superitem_descendant_pool_ids_list, selected_superitem_contained_items_count, sibling_positions, selected_item_params

  selected_superitem_descendant_pool_ids = _module_data.storeRetrievePoolData(selected_superitem_instance_pool_id, _constant.data.key.suffix.pool.descendant_ids)
  retval, selected_superitem_descendant_pool_ids = serpent.load(selected_superitem_descendant_pool_ids)
  stored_item_state_chunks = _module_data.storeRetrievePoolData(selected_superitem_instance_pool_id, _constant.data.key.suffix.pool.contained_item_states)
  retval, stored_item_state_chunks = serpent.load(stored_item_state_chunks)
  selected_superitem_descendant_pool_ids_list = _module_util.stringifyArray(selected_superitem_descendant_pool_ids)
  selected_superitem_contained_items_count = _module_util.getTableSize(stored_item_state_chunks)
  sibling_positions = _module_iteminfo.getSiblingPositions(selected_superitem_instance_pool_id)
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
      "Pool #" .. selected_superitem_instance_pool_id .. " All Instance positions: ",
      sibling_positions
    }
  }

  return selected_item_params
end


function _module_iteminfo.getSiblingPositions(pool_id)
  local sibling_locations_text, all_items_count, this_sibling_num, this_item, this_instance_pool_id, this_active_take, retval, this_active_take_name, this_instance_position_time, measures, beats_since_new_bar

  sibling_locations_text = ""
  all_items_count = reaper.CountMediaItems(_api.current_project)
  this_sibling_num = 1

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api.current_project, i)
    this_instance_pool_id = _module_data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.instance_id)

    if this_instance_pool_id and this_instance_pool_id ~= "" and this_instance_pool_id == pool_id then
      this_active_take = reaper.GetActiveTake(this_item)
      retval, this_active_take_name = reaper.GetSetMediaItemTakeInfo_String(this_active_take, _api.take.key.name, "", false)
      this_instance_position_time = reaper.GetMediaItemInfo_Value(this_item, _api.item.key.position)
      measures, beats_since_new_bar = _module_iteminfo.convertSecondsToMusicTime(this_instance_position_time)
      sibling_locations_text = sibling_locations_text .. _unicode.no_break_space.._unicode.no_break_space .. this_sibling_num .. ":  " .. this_active_take_name .. " – " .. measures .. "." .. beats_since_new_bar .. " / " .. _module_common.round(this_instance_position_time, 3) .. "s" .. "\r\n"
      this_sibling_num = this_sibling_num + 1
    end
  end

  if sibling_locations_text == "" then
    sibling_locations_text = "none"
  end

  return sibling_locations_text
end


function _module_iteminfo.convertSecondsToMusicTime(duration_in_seconds)
  local retval, measures, cml, fullbeats, beats_since_new_bar

  retval, measures, cml, fullbeats = reaper.TimeMap2_timeToBeats(_api.current_project, duration_in_seconds)
  beats_since_new_bar = fullbeats % measures

  return measures, _module_common.round(beats_since_new_bar, 3)
end


function _module_iteminfo.populateItemInfoWindow(all_selected_items_window_data)
  local item_info_window, item_info_viewport, item_info_content, item_info_title, item_info_name, item_info_text, item_info_content_height

  item_info_window = rtk.Window{w = 0.3, maxh = 0.85, title = _brand.name .. " Item Info"}
  item_info_viewport = rtk.Viewport{halign = "center", padding = "0 38"}
  item_info_content = rtk.VBox{padding = "27 0 7"}
  item_info_title = rtk.Heading{_brand.name .. " Item Info", w = 1, bmargin = 35, halign = "center"}

  item_info_content:add(item_info_title)

  for i = 1, #all_selected_items_window_data do
    item_info_name = rtk.Text{all_selected_items_window_data[i].name, w = 1, bmargin = 8, tpadding = 12, tborder = "1px #666666", halign = "center", textalign = "center", fontscale = 1.2, wrap = "normal", color = "#599D8E"}
    item_info_text = rtk.Text{all_selected_items_window_data[i].info, w = 1, textalign = "left", wrap = "normal"}

    item_info_content:add(item_info_name)
    item_info_content:add(item_info_text)
  end

  item_info_viewport:attr("child", item_info_content)
  item_info_window:add(item_info_viewport)
  item_info_window:open{align = "center"}
end



function _module_init.setUpAction(action)
  local selected_item_count

  selected_item_count = _module_init.doPreSuperglueChecks(action)

  if selected_item_count == false then return end

  _module_init.prepareAction(action)

  selected_item_count = reaper.CountSelectedMediaItems(_api.current_project)

  if _module_init.itemsAreSelected(selected_item_count) == false then return false end

  return selected_item_count
end


function _module_init.doPreSuperglueChecks(action)
  local selected_item_count

  if _module_init.renderPathIsValid() == false then return false end

  selected_item_count = reaper.CountSelectedMediaItems(_api.current_project)

  if not selected_item_count or selected_item_count == 0 then return false end

  if not _module_init.itemsAreSelected(selected_item_count) then return false end

  if _module_init.requiredLibsAreInstalled() == false then return false end

  return selected_item_count
end


function _module_init.renderPathIsValid()
  local platform, win_platform_regex, is_win, win_absolute_path_regex, is_win_absolute_path, is_win_local_path, nix_absolute_path_regex, is_nix_absolute_path, is_other_local_path

  platform = reaper.GetOS()
  win_platform_regex = "^Win"
  is_win = string.match(platform, win_platform_regex)
  win_absolute_path_regex = "^%u%:\\"
  is_win_absolute_path = string.match(_file.path.proj_render, win_absolute_path_regex)
  is_win_local_path = is_win and not is_win_absolute_path
  nix_absolute_path_regex = "^/"
  is_nix_absolute_path = string.match(_file.path.proj_render, nix_absolute_path_regex)
  is_other_local_path = not is_win and not is_nix_absolute_path

  if is_win_local_path or is_other_local_path then
    reaper.ShowMessageBox(_brand.name .. " needs a valid file render path. Set an absolute path in Project Settings > Media > Path or save your new project and try again.", "No file render path", _api.msg.type.ok)

    return false

  else

    return true
  end
end


function _module_init.itemsAreSelected(selected_item_count)
  local no_items_are_selected = selected_item_count < 1

  if not selected_item_count or no_items_are_selected then

    return false

  else

    return true
  end
end


function _module_init.requiredLibsAreInstalled()
  local sws_version = reaper.CF_GetSWSVersion()

  if not sws_version then
    reaper.ShowMessageBox(_brand.name .. " requires the SWS plugin extension to work. Please install SWS from https://standingwaterstudios.com/ and try again.", "SWS not installed", _api.msg.type.ok)

    return false
  end
end


_module_init.checkFixedLanesSupport = (function()
  local version = reaper.GetAppVersion()
  local major = tonumber(version:match("^(%d+)"))

  if major >= _constant.reaper.version.fixed_lanes then
    _constant.support.fixed_lanes = true
  end
end)()


function _module_init.copySuperglueItemImagesToProject()
  local project_images_paths, script_image_paths

  project_images_paths = {
    superitem_bg = _file.path.superitem_bg_img,
    restored_item_bg = _file.path.restored_item_bg_img,
    restored_instance_bg = _file.path.restored_instance_bg_img
  }

  script_image_paths = {
    superitem_bg = _file.path.script .. _file.name.superitem_bg_img,
    restored_item_bg = _file.path.script .. _file.name.restored_item_bg_img,
    restored_instance_bg = _file.path.script .. _file.name.restored_instance_bg_img
  }

  for image_name, image_path in pairs(project_images_paths) do

    if not _module_util.fileExists(image_path) then
      _module_util.copyFile(script_image_paths[image_name], project_images_paths[image_name])
    end
  end
end


function _module_init.prepareAction(action)
  local api_undo_flag_track_configurations = 1

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(api_undo_flag_track_configurations)

  if action == "Glue" or string.find(action, "Smart") then
    _module_init.setResetUsersItemSelection(true)
  end
end


function _module_init.doGlueAction(selected_item_count, action)
  local selected_items

  selected_items = _module_init.getSelectedItems(selected_item_count)
  _state.action.glue.all_glued_superitems = {}
  _state.action.glue.changed_pool_ids = {}

  if _module_init.selectedItemsAreInvalid(selected_items, action) then return end

  if _module_init.checkItemsOffscreen(selected_items, "selected") == true then return end

  _module_init.completeGlueOrDePool(selected_items, action)
end


function _module_init.completeGlueOrDePool(selected_items, action)
  local pool_ids_changed

  if not _module_multi.setUpMultiTrackActions(selected_items, action) then return end

  if action == "Glue" then
    pool_ids_changed = _state.action.glue.changed_pool_ids

  elseif action == "DePool" then
    pool_ids_changed = _state.action.depool.new_pool_ids
  end

  _state.action.glue.all_glued_superitems = _module_init.removeItemsAbsentFromProjectFromArray(_state.action.glue.all_glued_superitems)

  _module_common.selectDeselectItems(_state.action.glue.all_glued_superitems, true)
  _module_init.cleanUpAction(action, pool_ids_changed)
end


-- CAN THIS BE USED ELSEWHERE TOO?
function _module_init.removeItemsAbsentFromProjectFromArray(array)
  local presentItems = {}

  for _, item in ipairs(array) do

    if reaper.ValidatePtr2(_api.current_project, item, _api.datatype.mediaitem) then
      table.insert(presentItems, item)
    end
  end

  return presentItems
end


function _module_init.doEditOrUnglueAction(selected_item_count, action)

  if selected_item_count == 0 then return end

  local selected_items = _module_init.getSelectedItems(selected_item_count)
  local selected_item_groups = _module_common.getSuperglueItemTypes(selected_items, {"superitem"})
  local superitems = selected_item_groups.superitem.items

  if #superitems == 0 then
    reaper.ShowMessageBox("The " .. action .. " action only works on Superitems. Select a Superitem and try again.", _brand.name .. " " .. action, _api.msg.type.ok)
    return
  end

  _state.action.edit.changed_pool_ids = {}

  if _module_init.checkItemsOffscreen(selected_items, "selected") == true then return end

  local selected_siblings = _module_init.getSelectedSiblings(selected_items, action)
  selected_items = _module_init.handleSelectedSiblings(selected_items, selected_siblings, action)

  if not selected_items then return end

  if not _module_multi.setUpMultiTrackActions(selected_items, action) then return end

  if _module_init.checkItemsOffscreen(_state.action.edit_or_unglue.restored_items, "restored") == true then return end

  _module_init.cleanUpAction(action, _state.action.edit.changed_pool_ids)
end


function _module_init.doDePoolAction(selected_item_count, action)
  local selected_items

  selected_items = _module_init.getSelectedItems(selected_item_count)
  _state.action.glue.all_glued_superitems = {}
  _state.action.depool.new_pool_ids = {}

  _module_init.completeGlueOrDePool(selected_items, action)
end


function _module_init.doSmartAction(selected_item_count, action)
  local selected_items, pool_id

  selected_items = _module_init.getSelectedItems(selected_item_count)
  _state.action.glue.all_glued_superitems = {}
  _state.action.glue.changed_pool_ids = {}
  _state.action.edit.changed_pool_ids = {}

  if _module_init.superitemSelectionIsInvalid(selected_items, action) then return end

  if not _module_multi.setUpMultiTrackActions(selected_items, action) then return end

  for i = 1, #_state.action.glue.changed_pool_ids do
    table.insert(_state.action.edit.changed_pool_ids, _state.action.glue.changed_pool_ids[i])
  end

  _module_init.cleanUpAction(action, _state.action.edit.changed_pool_ids)
end


function _module_init.getSelectedSiblings(selected_items, action)
  local unique_instance_ids, selected_siblings, this_selected_item_instance_pool_id, this_selected_item_instance_pool_id_is_unique, this_unique_instance_pool_id, this_sibling_instance_id

  unique_instance_ids = {}
  selected_siblings = {}

  for i = 1, #selected_items do
    this_selected_item_instance_pool_id = _module_data.storeRetrieveItemData(selected_items[i], _constant.data.key.suffix.pool.instance_id)
    this_selected_item_instance_pool_id_is_unique = true

    for j = 1, #unique_instance_ids do
      this_unique_instance_pool_id = unique_instance_ids[j]

      if this_selected_item_instance_pool_id == this_unique_instance_pool_id then
        this_selected_item_instance_pool_id_is_unique = false

        break
      end
    end

    if this_selected_item_instance_pool_id_is_unique then
      table.insert(unique_instance_ids, this_selected_item_instance_pool_id)

      for j = 1, #selected_items do

        if selected_items[j] ~= selected_items[i] then
          this_sibling_instance_id = _module_data.storeRetrieveItemData(selected_items[j], _constant.data.key.suffix.pool.instance_id)

          if this_sibling_instance_id == this_selected_item_instance_pool_id then
            table.insert(selected_siblings, selected_items[j])
          end
        end
      end
    end
  end

  return selected_siblings
end


function _module_init.handleSelectedSiblings(selected_items, selected_siblings, action)
  local siblings_are_selected, selected_items_without_siblings, user_response_sibling_deselect, selected_item_is_sibling

  siblings_are_selected = #selected_siblings > 0
  selected_items_without_siblings = {}

  if siblings_are_selected then
    user_response_sibling_deselect = reaper.ShowMessageBox(_brand.name .. " can only " .. action .. " one pool instance at a time. Press OK to deselect any Sibling superitems and " .. action .. ", or Cancel.", "Too many siblings selected", _api.msg.type.ok_cancel)

    if user_response_sibling_deselect == _api.msg.response.ok then

      for i = 1, #selected_items do
        selected_item_is_sibling = false

        for j = 1, #selected_siblings do

          if selected_siblings[j] == selected_items[i] then
            selected_item_is_sibling = true

            break
          end
        end

        if selected_item_is_sibling == false then
          table.insert(selected_items_without_siblings, selected_items[i])
        end
      end

      _module_common.selectDeselectItems(selected_siblings, false)

      return selected_items_without_siblings

    else

      return false
    end

  elseif not siblings_are_selected then

    return selected_items
  end
end


function _module_init.checkItemsOffscreen(items, item_type)
  local this_item, this_selected_item_is_before_arrange_view, this_selected_item_is_after_arrange_view, offscreen_msg__text_start, offscreen_msg__text_end, offscreen_msg__text, items_offscreen_response

  if items then

    for i = 1, #items do
      this_item = items[i]
      this_selected_item_is_before_arrange_view, this_selected_item_is_after_arrange_view, offscreen_msg__text_start, offscreen_msg__text_end = _module_init.getOffscreenItemParams(this_item)

      if this_selected_item_is_before_arrange_view or this_selected_item_is_after_arrange_view then

        if item_type == "selected" then
          offscreen_msg__text = _brand.name .. ": " .. offscreen_msg__text_start .. item_type .. offscreen_msg__text_end
          items_offscreen_response = reaper.ShowMessageBox(offscreen_msg__text .. " Select OK to continue with the items selected or Cancel to abort.", "Items selected offscreen", _api.msg.type.ok_cancel)

          if items_offscreen_response == _api.msg.response.ok then

            return false

          else

            return true
          end

        elseif item_type == "restored" then
          offscreen_msg__text = offscreen_msg__text_start .. item_type .. offscreen_msg__text_end

          reaper.ShowMessageBox(offscreen_msg__text, "Warning: Offscreen items", _api.msg.type.ok)

          break
        end
      end
    end
  end
end


function _module_init.getOffscreenItemParams(item)
  local item_position, item_length, item_end_point,  arrange_start_time, arrange_end_time, item_is_before_arrange_view, item_is_after_arrange_view, offscreen_msg__text_start, offscreen_msg__text_end

  item_position = reaper.GetMediaItemInfo_Value(item, _api.item.key.position)
  item_length = reaper.GetMediaItemInfo_Value(item, _api.item.key.length)
  item_end_point = item_position + item_length
  arrange_start_time, arrange_end_time = reaper.GetSet_ArrangeView2(_api.current_project, false, 0, 0)
  item_is_before_arrange_view = item_position < arrange_start_time
  item_is_after_arrange_view = item_end_point > arrange_end_time
  offscreen_msg__text_start = "One or more "
  offscreen_msg__text_end = " items extend(s) beyond the current visible Arrange window view."

  return item_is_before_arrange_view, item_is_after_arrange_view, offscreen_msg__text_start, offscreen_msg__text_end
end


function _module_init.setResetUsersItemSelection(set_reset)
  local set, reset, selected_items_count, this_selected_item

  set = set_reset
  reset = not set_reset

  if set then
    _state.user.item_selection = {}
    selected_items_count = reaper.CountSelectedMediaItems(_api.current_project)

    for i = 0, selected_items_count-1 do
      this_selected_item = reaper.GetSelectedMediaItem(_api.current_project, i)

      table.insert(_state.user.item_selection, this_selected_item)
    end

  elseif reset then
    reaper.Main_OnCommand(_cmd.deselect_all_items, _api.cmd_flag)

    for i = 1, #_state.user.item_selection do
      reaper.SetMediaItemSelected(_state.user.item_selection[i], true)
    end
  end
end


function _module_init.getFirstParentPoolIdFromSelectedItems(user_selected_items_on_this_track)
  local this_item, this_item_parent_pool_id, this_item_has_stored_parent_pool_id

  for i = 1, #user_selected_items_on_this_track do
    this_item = user_selected_items_on_this_track[i]
    this_item_parent_pool_id = _module_data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)
    this_item_has_stored_parent_pool_id = this_item_parent_pool_id and this_item_parent_pool_id ~= ""

    if this_item_has_stored_parent_pool_id then

      return this_item_parent_pool_id
    end
  end

  return false
end


function _module_init.selectedItemsAreInvalid(selected_items, action_text)

  if _module_init.superitemSelectionIsInvalid(selected_items, action_text) or
    _module_midi.pureMidiItemIsSelected(selected_items) then

      return true
  end
end


function _module_init.getSelectedItems(selected_item_count)
  local selected_items, this_item

  selected_items = {}

  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(_api.current_project, i)

    table.insert(selected_items, this_item)
  end

  return selected_items
end


function _module_init.superitemSelectionIsInvalid(selected_items, action)
  local selected_item_groups, superitems, restored_items, siblings_are_selected, recursive_superitem_is_being_glued

  selected_item_groups = _module_common.getSuperglueItemTypes(selected_items, {"superitem", "restored"})
  superitems = selected_item_groups.superitem.items
  restored_items = selected_item_groups.restored.items
  recursive_superitem_is_being_glued = _module_init.recursiveSuperitemIsBeingGlued(superitems, restored_items) == true

  if recursive_superitem_is_being_glued then return true end
end


-- function removeUnselectedRestoredItemsFromPool(restored_items_pool_id, selected_items)
--   local pool_contained_item_states_key_label, retval, last_glue_stored_item_states_string, last_glue_stored_item_states_table, this_stored_item_guid, this_item_last_glue_state, this_stored_item_is_unmatched, this_selected_item, this_selected_item_guid, this_unmatched_item

--   pool_contained_item_states_key_label = _constant.data.key.prefix.pool .. restored_items_pool_id .. _constant.data.key.suffix.pool.contained_item_states
--   retval, last_glue_stored_item_states_string = _module_data.storeRetrieveProjectData(pool_contained_item_states_key_label)

--   if retval then
--     retval, last_glue_stored_item_states_table = serpent.load(last_glue_stored_item_states_string)

--     for this_stored_item_guid, this_item_last_glue_state in pairs(last_glue_stored_item_states_table) do
--       this_stored_item_is_unmatched = true

--       for i = 1, #selected_items do
--         this_selected_item = selected_items[i]
--         this_selected_item_guid = reaper.BR_GetMediaItemGUID(this_selected_item)

--         if this_selected_item_guid == this_stored_item_guid then
--           this_stored_item_is_unmatched = false

--           break
--         end
--       end

--       if this_stored_item_is_unmatched then
--         this_unmatched_item = reaper.BR_GetMediaItemByGUID(_api.current_project, this_stored_item_guid)

--         if this_unmatched_item then
--           _module_common.addRemoveItemImage(this_unmatched_item, false)
--           _module_data.storeRetrieveItemData(this_unmatched_item, _constant.data.key.suffix.pool.parent_id, "")
--         end
--       end
--     end
--   end
-- end


function _module_init.getFirstSelectedItem()

  return reaper.GetSelectedMediaItem(_api.current_project, 0)
end



function _module_multi.setUpMultiTrackActions(selected_items, action)
  local all_tracks_with_user_selected_items = {}
  local this_track_idx = 1
  all_tracks_with_user_selected_items[this_track_idx] = {}
  all_tracks_with_user_selected_items[this_track_idx].items = {}
  local item_is_on_different_track_than_previous = false

  for item_idx = 1, #selected_items do
    local this_item = selected_items[item_idx]
    local this_item_track = reaper.GetMediaItemTrack(this_item)
    local prev_item = selected_items[item_idx - 1]
    local prev_item_track = prev_item and reaper.GetMediaItemTrack(prev_item)

    item_is_on_different_track_than_previous = this_item_track and prev_item_track and
                                             this_item_track ~= prev_item_track

    if item_is_on_different_track_than_previous then
      this_track_idx = this_track_idx + 1
      all_tracks_with_user_selected_items[this_track_idx] = {}
      all_tracks_with_user_selected_items[this_track_idx].items = {}
    end

    table.insert(all_tracks_with_user_selected_items[this_track_idx].items, this_item)
    all_tracks_with_user_selected_items[this_track_idx].track = this_item_track
  end

  all_tracks_with_user_selected_items = _module_multi.handleMultiitemCases(all_tracks_with_user_selected_items, action)

  if not all_tracks_with_user_selected_items then return false end

  if not _module_multi.iterateTracksWithSelectedItems(all_tracks_with_user_selected_items, action) then return false end

  return true
end


function _module_multi.handleMultiitemCases(all_tracks_with_user_selected_items, action)
  local global_option_toggle_multiitem_editing_enabled, multiitem_result, user_wants_to_affect_1st_superitem, user_selected_items_on_this_track

  if action == "Edit" or action == "Unglue" or action == "DePool" then

    for i = 1, #all_tracks_with_user_selected_items do

      if #all_tracks_with_user_selected_items[i].items > 1 then
        global_option_toggle_multiitem_editing_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.multiitem_editing)

        if global_option_toggle_multiitem_editing_enabled ~= "true" then
          multiitem_result = reaper.ShowMessageBox('The option "Multi-item Edit, Unglue, or DePool in single action" is disabled, but more than one item is selected on one or more tracks. Would you like to ' .. action .. ' the first selected superitem on each track only?', "Multiple items selected", _api.msg.type.ok_cancel)
          user_wants_to_affect_1st_superitem = multiitem_result == _api.msg.response.ok

          if user_wants_to_affect_1st_superitem then

            for j = 1, #all_tracks_with_user_selected_items do
              user_selected_items_on_this_track = all_tracks_with_user_selected_items[j].items

              for k = 2, #user_selected_items_on_this_track do
                table.remove(all_tracks_with_user_selected_items[j].items, k)
              end
            end

          else

            return false
          end
        end

        break
      end
    end
  end

  return all_tracks_with_user_selected_items
end


function _module_multi.iterateTracksWithSelectedItems(all_tracks_with_user_selected_items, action)
  local this_user_selected_items_track, user_selected_items_on_this_track

  for i = 1, #all_tracks_with_user_selected_items do
    this_user_selected_items_track = all_tracks_with_user_selected_items[i].track
    user_selected_items_on_this_track = all_tracks_with_user_selected_items[i].items

    if action == "Glue" then
      _module_multi.doSingleTrackGlue(user_selected_items_on_this_track, this_user_selected_items_track)

    elseif action == "Edit" or action == "Unglue" then
      _module_single.doSingleTrackEditOrUnglue(user_selected_items_on_this_track, action)

    elseif action == "DePool" then
      _module_single.doSingleTrackDePool(user_selected_items_on_this_track, this_user_selected_items_track, action)

    elseif action == "Smart Glue/Edit" or action == "Smart Glue/Unglue" then

      if not _module_single.doSingleTrackSmartAction(user_selected_items_on_this_track, this_user_selected_items_track, action) then return false end
    end
  end

  return true
end


-- removed a call at end to select glued items because such is already getting called in _module_init.completeGlueOrDePool()
function _module_multi.doSingleTrackGlue(user_selected_items_on_this_track, this_user_selected_items_track)
  local global_option_toggle_multiitem_editing_enabled, restored_items_pool_id

  _state.action.glue.current_track = this_user_selected_items_track
  global_option_toggle_multiitem_editing_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.multiitem_editing)

  _module_init.copySuperglueItemImagesToProject()

  if global_option_toggle_multiitem_editing_enabled == "true" then
    _module_multi.doSingleTrackMultiitemGlue(user_selected_items_on_this_track)

  else
    restored_items_pool_id = _module_init.getFirstParentPoolIdFromSelectedItems(user_selected_items_on_this_track)

    _module_single.triggerSingleTrackSinglePoolGlue(user_selected_items_on_this_track, restored_items_pool_id)
  end
end


function _module_multi.doSingleTrackMultiitemGlue(user_selected_items_on_this_track)
  local pool_ids_by_depth

  _state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor, pool_ids_by_depth = _module_multi.getPoolIdsFromItems(user_selected_items_on_this_track, "parent", "descendant to ancestor")

  if not _state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor then
    _module_single.triggerSingleTrackSinglePoolGlue(user_selected_items_on_this_track)

  else
    _module_multi.handleSingleTrackMultiPoolGlue(user_selected_items_on_this_track, pool_ids_by_depth)
  end
end


function _module_multi.getPoolIdsFromItems(items, type, sort_order)
  local pool_ids_from_items, type_key_suffix, this_item, this_item_pool_id, this_item_has_stored_pool_id, pool_ids_by_depth, pool_ids__descendant_to_ancestor

  pool_ids_from_items = {}

  if type == "instance" then
    type_key_suffix = _constant.data.key.suffix.pool.instance_id

  elseif type == "parent" then
    type_key_suffix = _constant.data.key.suffix.pool.parent_id
  end

-- GO AND LOOK FOR SPOTS IN CODEBASE WHERE THIS SORT CASE CAN BE USED TO REPLACE CUSTOM ITERATION
  if sort_order == "timeline earlier to later" then

    for i = 1, #items do
      this_item = items[i]
      this_item_pool_id = _module_data.storeRetrieveItemData(this_item, type_key_suffix)
      this_item_has_stored_pool_id = this_item_pool_id and this_item_pool_id ~= ""

      if this_item_has_stored_pool_id then
        table.insert(pool_ids_from_items, this_item_pool_id)
      end
    end

    if #pool_ids_from_items > 0 then

      return pool_ids_from_items

    elseif #pool_ids_from_items == 0 then

      return false
    end

  elseif sort_order == "descendant to ancestor" then

    for i = 1, #items do
      this_item = items[i]
      this_item_pool_id = _module_data.storeRetrieveItemData(this_item, type_key_suffix)

      if not pool_ids_from_items[this_item_pool_id] then
        this_item_has_stored_pool_id = this_item_pool_id and this_item_pool_id ~= ""

        if this_item_has_stored_pool_id then
          table.insert(pool_ids_from_items, this_item_pool_id)
        end
      end
    end

    if #pool_ids_from_items == 0 then

      return false

    else
      pool_ids_from_items = _module_util.deduplicateTable(pool_ids_from_items)
      pool_ids_by_depth = _module_multi.getPoolIdNestedDepths(pool_ids_from_items)
      pool_ids__descendant_to_ancestor = {}

      for this_pool_id, depth in pairs(pool_ids_by_depth) do
        table.insert(pool_ids__descendant_to_ancestor, this_pool_id)
      end

      table.sort(pool_ids__descendant_to_ancestor, function(a, b)
        return pool_ids_by_depth[a] > pool_ids_by_depth[b]
      end)

      return pool_ids__descendant_to_ancestor, pool_ids_by_depth
    end
  end
end


function _module_multi.getPoolIdNestedDepths(pool_ids)
  local pool_ids_by_depth, this_pool_id, depth_has_changed, this_pool_id__descendant_pool_ids, retval, this_descendant_pool_id

  pool_ids_by_depth = {}

  for i = 1, #pool_ids do
    this_pool_id = pool_ids[i]
    pool_ids_by_depth[this_pool_id] = 0
  end

  depth_has_changed = true

  while depth_has_changed do
    depth_has_changed = false

    for i = 1, #pool_ids do
      this_pool_id = pool_ids[i]
      this_pool_id__descendant_pool_ids = _module_data.storeRetrievePoolData(this_pool_id, _constant.data.key.suffix.pool.descendant_ids)
      retval, this_pool_id__descendant_pool_ids = serpent.load(this_pool_id__descendant_pool_ids)

      if this_pool_id__descendant_pool_ids then

        for j = 1, #this_pool_id__descendant_pool_ids do
          this_descendant_pool_id = this_pool_id__descendant_pool_ids[j]

          if pool_ids_by_depth[this_descendant_pool_id] ~= nil then

            if pool_ids_by_depth[this_descendant_pool_id] < pool_ids_by_depth[this_pool_id] + 1 then
              depth_has_changed = true
              pool_ids_by_depth[this_descendant_pool_id] = pool_ids_by_depth[this_pool_id] + 1
            end
          end
        end
      end
    end
  end

  return pool_ids_by_depth
end



-- function _module_lanes.getTopLaneFromItems(items)
--   -- Find the topmost lane among selected items
--   if not _constant.support.fixed_lanes then return 0 end

--   local topLane = 999999
--   for i = 1, #items do
--     local itemLane = reaper.GetMediaItemInfo_Value(items[i], "I_FIXEDLANE")
--     if itemLane < topLane then topLane = itemLane end
--   end
--   return topLane ~= 999999 and topLane or 0
-- end


-- function _module_lanes.storeTopLaneFromItems(items, pool_id)
--   if not _constant.support.fixed_lanes then return end

--   local topLane = 999
--   for i = 1, #items do
--     local itemLane = reaper.GetMediaItemInfo_Value(items[i], "I_FIXEDLANE")
--     if itemLane < topLane then topLane = itemLane end
--   end

--   -- Store the top lane with the pool data
--   _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.top_lane, tostring(topLane))
--   return topLane
-- end


function _module_lanes.getLaneYPosition(laneNum, item)
  -- Calculate Y position based on track's actual height and lane count
  local track = reaper.GetMediaItemTrack(item)
  local trackHeight = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
  local laneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
  if laneCount <= 0 then laneCount = 1 end

  local laneHeight = trackHeight / laneCount
  return laneNum * laneHeight
end


-- function _module_lanes.storeItemLaneOffset(item, referenceLane)
--   -- Store lane as offset relative to reference lane
--   if not _constant.support.fixed_lanes then return end

--   local itemLane = reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE")
--   local relativeLane = itemLane - referenceLane
--   _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.item.lane_offset, tostring(relativeLane))
-- end


-- function _module_lanes.storeItemLaneOffsets(items, pool_id)
--   if not _constant.support.fixed_lanes then return end
--   if #items == 0 then return end

--   -- Figure out the highest (lowest-numbered) lane among these items.
--   local minLane = 999999
--   for _, item in ipairs(items) do
--     local laneIdx = reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE")
--     if laneIdx < minLane then
--       minLane = laneIdx
--     end
--   end

--   -- For each item, store (currentLane - minLane).
--   for _, item in ipairs(items) do
--     local itemLane = reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE")
--     local relativeLane = itemLane - minLane
--     -- Save that in your extension field, e.g. "pool-lane-offset"
--     _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.item.lane_offset, tostring(relativeLane))
--   end
-- end


function _module_lanes.storeItemLaneOffsets(items, pool_id)
  if not _constant.support.fixed_lanes or #items == 0 then return end

  -- Get the track
  local track = reaper.GetMediaItemTrack(items[1])

  -- Save current track settings
  local originalMode = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
  local originalLaneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")

  -- Make sure track is in fixed lanes mode for accurate lane detection
  if originalMode ~= 2 then
    reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)
    reaper.UpdateArrange()
  end

  -- Find the topmost lane item (lowest lane number)
  local topLane = 255
  local topLaneItem = nil

  for _, item in ipairs(items) do
    local itemLane = reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE")
    if itemLane < topLane and itemLane < 100 then -- Avoid invalid values
      topLane = itemLane
      topLaneItem = item
    end
  end

  -- Default to lane 0 if we couldn't find a valid lane
  if topLane == 255 then
    topLane = 0
    topLaneItem = items[1] -- Just use the first item if no valid lane found
  end

  -- Store the top lane number
  _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.top_lane, tostring(topLane))

  -- Get and store the exact Y position of the top lane item
  local itemY = reaper.GetMediaItemInfo_Value(topLaneItem, "F_FREEMODE_Y")
  _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.top_lane_y_pos, tostring(itemY))

  -- Also store the original lane count
  _module_data.storeRetrievePoolData(pool_id, "original_lane_count", tostring(originalLaneCount))

  -- Store lane offsets relative to top lane
  for _, item in ipairs(items) do
    local itemLane = reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE")
    local offset = 0

    -- Only calculate offset if lane is valid
    if itemLane < 100 then
      offset = itemLane - topLane
    end

    -- Store the offset
    _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.item.lane_offset, tostring(offset))
  end

  -- Restore original track mode if needed
  if originalMode ~= 2 then
    reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", originalMode)
    reaper.UpdateArrange()
  end
end


function _module_lanes.restoreItemLaneOffsets(items, revertTrackAfter, pool_id)
  if not _constant.support.fixed_lanes or #items == 0 then return end

  local track = reaper.GetMediaItemTrack(items[1])
  if not track then return end

  -- Get the superitem's Y position at edit time
  local editYStr = _module_data.storeRetrievePoolData(pool_id, "edit_superitem_y")
  if not editYStr or editYStr == "" then
    _module_dev.log("ERROR: No edit_superitem_y found for pool " .. pool_id)
    return
  end

  local editY = tonumber(editYStr)
  local editLaneStr = _module_data.storeRetrievePoolData(pool_id, "edit_superitem_lane")
  local editLane = tonumber(editLaneStr) or 0

  -- Get the current track settings
  local currentLaneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")

  if _test_logging_enabled then
    _module_dev.log("RESTORE: Using editY=" .. editY .. ", editLane=" .. editLane .. ", currentLaneCount=" .. currentLaneCount)
  end

  -- Find maximum lane offset to calculate required lanes
  local maxLaneOffset = 0
  for _, item in ipairs(items) do
    local offsetStr = _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.item.lane_offset)
    local offset = tonumber(offsetStr) or 0
    maxLaneOffset = math.max(maxLaneOffset, offset)

    if _test_logging_enabled then
      _module_dev.log("Item offset: " .. offset .. ", max so far: " .. maxLaneOffset)
    end
  end

  -- Calculate required lanes and ensure we have enough
  -- Add +1 to account for 0-based indexing in lanes (need lanes 0-10 for 11 total lanes)
  local requiredLaneCount = editLane + maxLaneOffset + 1

  if _test_logging_enabled then
    _module_dev.log("Required lane count: " .. requiredLaneCount)
  end

  -- Ensure track is in fixed lanes mode
  reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)

  -- Increase lane count if needed - IMPORTANT: We need to add 1 for the right number of lanes
  if requiredLaneCount > currentLaneCount then
    local newLaneCount = requiredLaneCount
    if _test_logging_enabled then
      _module_dev.log("Increasing lane count from " .. currentLaneCount .. " to " .. newLaneCount)
    end
    reaper.SetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES", newLaneCount)
    reaper.UpdateArrange()

    -- Update variable after potentially changing it
    currentLaneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
  end

  -- Position each item according to its offset
  for _, item in ipairs(items) do
    local offsetStr = _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.item.lane_offset)
    local offset = tonumber(offsetStr) or 0

    -- Calculate target lane and Y position
    local targetLane = editLane + offset

    -- Make sure we use the actual current lane count for Y calculation
    local currentLaneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
    local targetY = targetLane / currentLaneCount

    if _test_logging_enabled then
      _module_dev.log("Setting item with offset " .. offset .. " to lane " .. targetLane .. " (Y=" .. targetY .. ")")
    end

    -- Set item positioning
    reaper.SetMediaItemInfo_Value(item, "B_FREEMODE", 1)
    reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_Y", targetY)
  end

  reaper.UpdateArrange()

  if _test_logging_enabled then
    _module_dev.log("Lane restoration complete")
  end
end


function _module_lanes.enableFixedLanesTemporarily(track, minLaneCount)
  if not track then return nil end

  local old_mode = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
  local old_laneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")

  -- Force track into fixed lanes mode
  reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)

  -- Set a reasonable lane count (3-5 is safe)
  local newCount = minLaneCount or 3
  newCount = math.max(3, math.min(newCount, 10)) -- Between 3 and 10
  reaper.SetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES", newCount)

  reaper.UpdateArrange()

  return {
    track = track,
    old_mode = old_mode,
    old_laneCount = old_laneCount
  }
end


function _module_lanes.restoreTrackMode(settings)
  if not settings or not settings.track then return end

  -- Always restore the original mode, regardless of what it was
  reaper.SetMediaTrackInfo_Value(settings.track, "I_FOLDERCOMPACT", settings.old_mode)

  -- Put back the old lane count
  reaper.SetMediaTrackInfo_Value(settings.track, "I_NUMFIXEDLANES", settings.old_laneCount)

  -- Put back the old freemode setting
  reaper.SetMediaTrackInfo_Value(settings.track, "B_FREEMODE", settings.old_freeMode)

  reaper.UpdateArrange()
end


function _module_lanes.applyLanePositionToItem(item, referenceLane)
  if not _constant.support.fixed_lanes then return end

  local laneOffsetStr = _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.item.lane_offset)
  local laneOffset = tonumber(laneOffsetStr) or 0

  -- Sanity check - don't allow extremely large offsets
  laneOffset = math.min(laneOffset, 20)  -- Cap at 20 lanes difference max
  local targetLane = referenceLane + laneOffset

  -- Get track info
  local track = reaper.GetMediaItemTrack(item)
  local trackHeight = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")

  -- Ensure track is in fixed lane mode
  local trackMode = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
  if trackMode ~= 2 then
    reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)
  end

  -- Ensure a reasonable lane count with a hard maximum
  local currentLaneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
  local neededLaneCount = math.min(targetLane + 1, 20)  -- +1 because lanes are zero-based, cap at 20

  if currentLaneCount < neededLaneCount then
    reaper.SetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES", neededLaneCount)
  end

  -- Calculate Y position with sanity checks
  local laneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
  local laneHeight = trackHeight / math.max(1, laneCount)

  -- Ensure target lane is within valid range
  targetLane = math.min(targetLane, laneCount - 1)
  targetLane = math.max(targetLane, 0)

  local yPosition = targetLane * laneHeight

  -- Set the item to free positioning mode
  reaper.SetMediaItemInfo_Value(item, "B_FREEMODE", 1)

  -- Set Y position - this is what actually controls the lane
  reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_Y", yPosition)

  -- Force REAPER to update visuals
  reaper.UpdateArrange()
end


function _module_lanes.fixItemLanePositions(items, track, desiredLane)
  if not _constant.support.fixed_lanes or #items == 0 then return end

  -- Get current lane count
  local currentLaneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")

  -- Default to lane 0 if not specified (lane indexing appears to be 0-based)
  desiredLane = desiredLane or 0
  desiredLane = math.max(0, math.min(desiredLane, currentLaneCount - 1)) -- Keep in safe range

  -- Force track to fixed lanes mode
  reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)

  -- Calculate lane height
  local trackH = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
  local laneHeight = trackH / math.max(1, currentLaneCount)

  -- Position all items in the specified lane
  for _, item in ipairs(items) do
    reaper.SetMediaItemInfo_Value(item, "B_FREEMODE", 1)
    reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_Y", desiredLane * laneHeight)
  end

  reaper.UpdateArrange()
end


function _module_lanes.debugLaneInfo(label, items, track, pool_id)
  _module_dev.log("==== LANE DEBUG: " .. label .. " ====")

  -- Track info
  local trackMode = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
  local laneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
  local trackHeight = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
  local trackFreeMode = reaper.GetMediaTrackInfo_Value(track, "B_FREEMODE")

  _module_dev.log(string.format("TRACK - Mode: %d, Lanes: %d, Height: %d, FreeMode: %d",
    trackMode, laneCount, trackHeight, trackFreeMode))

  -- Pool info
  local topLaneStr = _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.top_lane)
  _module_dev.log("Pool #" .. pool_id .. " top lane: " .. (topLaneStr or "nil"))

  -- Items info
  if items then
    for i, item in ipairs(items) do
      if reaper.ValidatePtr(item, "MediaItem*") then
        local name = _module_common.getSetItemName(item) or "unnamed"
        local fixedLane = reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE")
        local freeY = reaper.GetMediaItemInfo_Value(item, "F_FREEMODE_Y")
        local freeMode = reaper.GetMediaItemInfo_Value(item, "B_FREEMODE")
        local offsetStr = _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.item.lane_offset)

        _module_dev.log(string.format(
          "Item %d: %s - Lane: %d, FreeY: %.2f, FreeMode: %d, Offset: %s",
          i, name, fixedLane, freeY, freeMode, offsetStr or "nil"
        ))
      end
    end
  end

  _module_dev.log("==============================")
end



function _module_single.triggerSingleTrackSinglePoolGlue(items_to_glue, restored_items_pool_id)
  local this_is_reglue, superitem

  this_is_reglue = restored_items_pool_id

  if this_is_reglue then
    superitem = _module_glue.handleReglue(items_to_glue, restored_items_pool_id)

  else
    superitem = _module_glue.handleGlue(items_to_glue, nil, nil, nil, nil)
  end

  if superitem then
    table.insert(_state.action.glue.all_glued_superitems, superitem)
    table.insert(_state.action.glue.changed_pool_ids, _state.pool.active_glue_pool_id)
  end

  return superitem
end


function _module_multi.handleSingleTrackMultiPoolGlue(user_selected_items_on_this_track, pool_ids_by_depth)
  local this_is_single_reglue, this_is_overglue, superitem, selected_items_on_this_track__post_glue

  this_is_single_reglue = #_state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor == 1
  this_is_overglue = #_state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor > 1

  if this_is_single_reglue then
    superitem = _module_single.triggerSingleTrackSinglePoolGlue(user_selected_items_on_this_track, _state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor[1])
    selected_items_on_this_track__post_glue = {superitem}

  elseif this_is_overglue then
    selected_items_on_this_track__post_glue = _module_overglue.doOverglue(user_selected_items_on_this_track, pool_ids_by_depth)
  end

  reaper.Main_OnCommand(_cmd.deselect_all_items, _api.cmd_flag)
  _module_common.selectDeselectItems(selected_items_on_this_track__post_glue, true)
end


function _module_overglue.doOverglue(user_selected_items_on_this_track, pool_ids_by_depth)
    -- First, identify all pools and nonrestored items
    local all_pools = {}
    local outermost_pools = {}
    local non_outermost_pools = {}

    for pool_id, depth in pairs(pool_ids_by_depth) do
        all_pools[pool_id] = true
        if depth == 0 then
            table.insert(outermost_pools, pool_id)
        else
            table.insert(non_outermost_pools, {id = pool_id, depth = depth})
        end
    end

    -- Sort non-outermost pools by depth (deeper first)
    table.sort(non_outermost_pools, function(a, b) return a.depth > b.depth end)

    -- Get nonrestored items
    local all_nonrestored_items = {}
    for i = 1, #user_selected_items_on_this_track do
        local this_item = user_selected_items_on_this_track[i]
        local this_item_parent_pool_id = _module_data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)
        if not this_item_parent_pool_id or this_item_parent_pool_id == "" then
            table.insert(all_nonrestored_items, this_item)
        end
    end

    -- Calculate distances to determine outermost pool processing order
    local pool_distances = {}
    for _, pool_id in ipairs(outermost_pools) do
        local retval, sizing_regions = _module_data.storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions)
        retval, sizing_regions = serpent.load(sizing_regions)
        local sizing_region_guid = sizing_regions[pool_id]
        local pool_params = _module_common.getSetSizingRegion(sizing_region_guid)

        if pool_params then
            local pool_center = pool_params.position + (pool_params.end_point - pool_params.position) / 2
            local min_distance = math.huge

            for _, item in ipairs(all_nonrestored_items) do
                local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                local item_center = item_pos + (item_len / 2)
                local distance = math.abs(pool_center - item_center)
                min_distance = math.min(min_distance, distance)
            end

            pool_distances[pool_id] = min_distance
        end
    end

    -- Sort outermost pools by distance to nonrestored items
    table.sort(outermost_pools, function(a, b)
        return (pool_distances[a] or math.huge) < (pool_distances[b] or math.huge)
    end)

    -- Process pools in order
    local processing_order = {}
    -- First process nested pools from deepest to shallowest
    for _, pool_data in ipairs(non_outermost_pools) do
        table.insert(processing_order, pool_data.id)
    end
    -- Then process outermost pools in order of proximity to nonrestored items
    for _, pool_id in ipairs(outermost_pools) do
        table.insert(processing_order, pool_id)
    end

    -- Actual processing
    local selected_items_on_this_track__post_glue = {}
    _state.action.glue.overglued_superitems = {}

    for _, pool_id in ipairs(processing_order) do
        _state.pool.active_glue_pool_id = pool_id

        local is_outermost = pool_ids_by_depth[pool_id] == 0
        local restored_items = _module_overglue.getRestoredItems(user_selected_items_on_this_track, pool_id)
        local nonrestored_items__with_params = is_outermost
            and _module_overglue.getNonRestoredItemsWithParams(all_nonrestored_items)
            or _module_overglue.getNonRestoredItemsWithParams({})

        local outermost_pools = is_outermost and {pool_id} or {}
        local outermost_ancestor_pools__with_params = _module_overglue.getOutermostAncestorPoolsWithParams(outermost_pools)
        local pool_item_distances, nearest_nonrestored_items = _module_overglue.populateNonRestoredItemsDurationsData(outermost_ancestor_pools__with_params, nonrestored_items__with_params)
        local all_items_to_glue = _module_overglue.getItemsToOverglue(nearest_nonrestored_items, restored_items)

        local superitem = _module_single.triggerSingleTrackSinglePoolGlue(all_items_to_glue, pool_id)

        if superitem then
            _state.action.glue.overglued_superitems[pool_id] = {
                superitem = superitem,
                descendant_pool_ids = _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.descendant_ids),
                processed = true
            }

            selected_items_on_this_track__post_glue = _module_overglue.getSelectedItems_PostGlue(
                selected_items_on_this_track__post_glue,
                user_selected_items_on_this_track,
                superitem
            )
        end
    end

    return selected_items_on_this_track__post_glue
end


function _module_overglue.getRestoredItems(user_selected_items_on_this_track, requested_parent_pool_id)
    local restored_items = {}

    -- First get directly restored items
    for j = 1, #user_selected_items_on_this_track do
        local this_item = user_selected_items_on_this_track[j]
        if reaper.ValidatePtr(this_item, "MediaItem*") then
            local this_item_parent_pool_id = _module_data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)
            if this_item_parent_pool_id == requested_parent_pool_id then
                table.insert(restored_items, this_item)
            end
        end
    end

    -- Check if we have any descendant info before trying to parse it
    local descendant_data = _module_data.storeRetrievePoolData(requested_parent_pool_id, _constant.data.key.suffix.pool.descendant_ids)

    if descendant_data and descendant_data ~= "" then
        local retval, descendant_pool_ids = serpent.load(descendant_data)

        if retval and descendant_pool_ids and type(descendant_pool_ids) == "table" then
            for _, descendant_pool_id in ipairs(descendant_pool_ids) do

                -- Check for overglued superitem
                if _state.action.glue.overglued_superitems and
                   _state.action.glue.overglued_superitems[descendant_pool_id] then
                    local superitem_data = _state.action.glue.overglued_superitems[descendant_pool_id]

                    if superitem_data.superitem and superitem_data.processed then
                        table.insert(restored_items, superitem_data.superitem)
                    end
                end
            end
        end
    end

    return restored_items
end


function _module_overglue.getOutermostAncestorPools(pool_ids_by_depth)
  local outermost_ancestor_pools = {}

  for this_pool_id, depth in pairs(pool_ids_by_depth) do

    if depth == 0 then
      table.insert(outermost_ancestor_pools, this_pool_id)
    end
  end

  return outermost_ancestor_pools
end


function _module_overglue.getNonRestoredItemsWithParams(nonrestored_items)
    local nonrestored_items__with_params = {}

    for i = 1, #nonrestored_items do
        local this_item = nonrestored_items[i]

        if reaper.ValidatePtr(this_item, "MediaItem*") then
            nonrestored_items__with_params[this_item] = _module_data.getSetItemParams(this_item)
        end
    end

    return nonrestored_items__with_params
end


function _module_overglue.getOutermostAncestorPoolsWithParams(outermost_ancestor_pools, restored_items_with_this_parent_pool_id)
    local outermost_ancestor_pools__with_params = {}

    for _, this_outermost_ancestor_pool_id in ipairs(outermost_ancestor_pools) do
        local retval, all_pool_ids_with_active_sizing_regions = _module_data.storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions)
        retval, all_pool_ids_with_active_sizing_regions = serpent.load(all_pool_ids_with_active_sizing_regions)
        local sizing_region_guid = all_pool_ids_with_active_sizing_regions[this_outermost_ancestor_pool_id]

        if sizing_region_guid then
            local sizing_params = _module_common.getSetSizingRegion(sizing_region_guid)
            if sizing_params then
                outermost_ancestor_pools__with_params[this_outermost_ancestor_pool_id] = sizing_params
            end
        end
    end

    return outermost_ancestor_pools__with_params
end


function _module_overglue.populateNonRestoredItemsDurationsData(outermost_ancestor_pools__with_params, nonrestored_items__with_params)
    local pool_item_distances = {}
    local closest_pools = {}

    for pool_id, pool_params in pairs(outermost_ancestor_pools__with_params) do
        pool_item_distances[pool_id] = {}
    end

    for item, item_params in pairs(nonrestored_items__with_params) do
        if reaper.ValidatePtr(item, "MediaItem*") then
            local item_position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local item_center = item_position + (item_length / 2)

            for pool_id, pool_params in pairs(outermost_ancestor_pools__with_params) do
                local pool_position = pool_params.position
                local pool_length = pool_params.end_point - pool_params.position
                local pool_center = pool_position + (pool_length / 2)
                local distance = math.abs(pool_center - item_center)

                pool_item_distances[pool_id][item] = distance

                if not closest_pools[item] or
                   distance < pool_item_distances[closest_pools[item]][item] then
                    closest_pools[item] = pool_id
                end
            end
        end
    end

    -- Build final assignment structure
    local outermost_ancestor_pools__nearest_nonrestored_items = {}

    for item, closest_pool_id in pairs(closest_pools) do
        outermost_ancestor_pools__nearest_nonrestored_items[closest_pool_id] =
            outermost_ancestor_pools__nearest_nonrestored_items[closest_pool_id] or {}

        table.insert(outermost_ancestor_pools__nearest_nonrestored_items[closest_pool_id], item)
    end

    return pool_item_distances, outermost_ancestor_pools__nearest_nonrestored_items
end


function _module_overglue.getRelation_NonRestoredItemsBounds_OutermostAncestorBounds(this_outermost_ancestor_pool_id, this_outermost_ancestor_pool_id__sizing_params, nonrestored_items__with_params)
  local this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap, nonrestored_items_with_partial_overlap, nonrestored_items_to_add_to_glue, nonrestored_items_non_overlapping

  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds = {}
  nonrestored_items_with_both_sides_overlap = {}
  nonrestored_items_with_partial_overlap = {}
  nonrestored_items_to_add_to_glue = {}
  nonrestored_items_non_overlapping = {}

  for this_nonrestored_item, this_nonrestored_item__params in pairs(nonrestored_items__with_params) do
    _module_overglue.processNonRestoredItemBounds(this_nonrestored_item, this_nonrestored_item__params, this_outermost_ancestor_pool_id__sizing_params, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap, nonrestored_items_with_partial_overlap, nonrestored_items_to_add_to_glue, nonrestored_items_non_overlapping)
  end

  _module_overglue.addCategorizedNonRestoredItemsToMainTable(this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap, nonrestored_items_with_partial_overlap, nonrestored_items_to_add_to_glue, nonrestored_items_non_overlapping)

  return this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds
end


function _module_overglue.processNonRestoredItemBounds(this_nonrestored_item, this_nonrestored_item__params, this_outermost_ancestor_pool_id__sizing_params, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap, nonrestored_items_with_partial_overlap, nonrestored_items_to_add_to_glue, nonrestored_items_non_overlapping)
  local item_position, item_end_point, pool_position, pool_end_point

  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds[this_nonrestored_item] = this_nonrestored_item__params
  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds[this_nonrestored_item].overlaps = {}
  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds[this_nonrestored_item].deltas = {}
  item_position = this_nonrestored_item__params.position
  item_end_point = this_nonrestored_item__params.end_point
  pool_position = this_outermost_ancestor_pool_id__sizing_params.position
  pool_end_point = this_outermost_ancestor_pool_id__sizing_params.end_point

  _module_overglue.checkNonRestoredItemOverlapConditions(this_nonrestored_item, item_position, item_end_point, pool_position, pool_end_point, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap, nonrestored_items_with_partial_overlap, nonrestored_items_to_add_to_glue, nonrestored_items_non_overlapping)
  _module_overglue.calculateNonRestoredItemPoolDeltas(this_nonrestored_item, item_position, item_end_point, pool_position, pool_end_point, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds)
end


function _module_overglue.checkNonRestoredItemOverlapConditions(this_nonrestored_item, item_position, item_end_point, pool_position, pool_end_point, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap, nonrestored_items_with_partial_overlap, nonrestored_items_to_add_to_glue, nonrestored_items_non_overlapping)
  local item_is_within_pool, item_overlaps_both_sides, item_overlaps_pool_position, item_overlaps_pool_end_point, item_overlap_with_pool_start, item_overlap_with_pool_end

  item_is_within_pool = item_position >= pool_position and item_end_point <= pool_end_point
  item_overlaps_both_sides = item_position <= pool_position and item_end_point >= pool_end_point
  item_overlaps_pool_position = item_position <= pool_position and item_end_point > pool_position and item_end_point <= pool_end_point
  item_overlaps_pool_end_point = item_position >= pool_position and item_position < pool_end_point and item_end_point >= pool_end_point
  item_overlap_with_pool_start = item_end_point - pool_position
  item_overlap_with_pool_end = pool_end_point - item_position

  if item_is_within_pool then
    _module_overglue.processNonRestoredItemOverlapCondition("is_within", this_nonrestored_item, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_to_add_to_glue)

  elseif item_overlaps_both_sides then
    _module_overglue.processNonRestoredItemOverlapCondition("overlaps_both_sides", this_nonrestored_item, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap)

  elseif item_overlaps_pool_position then
    _module_overglue.processNonRestoredItemOverlapCondition("overlaps_pool_position", this_nonrestored_item, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_partial_overlap, item_overlap_with_pool_start)

  elseif item_overlaps_pool_end_point then
    _module_overglue.processNonRestoredItemOverlapCondition("overlaps_pool_end_point", this_nonrestored_item, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_partial_overlap, item_overlap_with_pool_end)

  else
    _module_overglue.processNonRestoredItemOverlapCondition("non_overlapping", this_nonrestored_item, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_non_overlapping)
  end
end


function _module_overglue.processNonRestoredItemOverlapCondition(overlap_type, nonrestored_item, outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, target_table, overlap_duration)
    -- Handle the overlap data storage
    outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds[nonrestored_item].overlaps[overlap_type] = overlap_duration or true

    -- Store the actual MediaItem, not just a reference
    table.insert(target_table, nonrestored_item)
end


function _module_overglue.calculateNonRestoredItemPoolDeltas(this_nonrestored_item, item_position, item_end_point, pool_position, pool_end_point, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds)
  local deltas = {
    item_position_to_pool_position = pool_position - item_position,
    item_position_to_pool_end = pool_end_point - item_position,
    item_end_to_pool_position = pool_position - item_end_point,
    item_end_to_pool_end = pool_end_point - item_end_point
  }

  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds[this_nonrestored_item].deltas = deltas
end


function _module_overglue.addCategorizedNonRestoredItemsToMainTable(this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap, nonrestored_items_with_partial_overlap, nonrestored_items_to_add_to_glue, nonrestored_items_non_overlapping)
  local dummy_local

  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds.nonrestored_items_with_both_sides_overlap = nonrestored_items_with_both_sides_overlap
  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds.nonrestored_items_with_partial_overlap = nonrestored_items_with_partial_overlap
  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds.nonrestored_items_to_add_to_glue = nonrestored_items_to_add_to_glue
  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds.nonrestored_items_non_overlapping = nonrestored_items_non_overlapping
end


function _module_overglue.getOutermostAncestorPools(pool_ids_by_depth)
    local outermost_ancestor_pools = {}

    for this_pool_id, depth in pairs(pool_ids_by_depth) do
        if depth == 0 then
            table.insert(outermost_ancestor_pools, this_pool_id)
        end
    end

    return outermost_ancestor_pools
end


function _module_overglue.assignNonRestoredItemsToPoolsBasedOnMaxOverlap(item_pool_assignments)
    local outermost_ancestor_pools__nearest_nonrestored_items = {}

    for nonrestored_item, pool_overlaps in pairs(item_pool_assignments) do
        if reaper.ValidatePtr(nonrestored_item, "MediaItem*") then
            local max_overlap = -math.huge
            local assigned_pool = nil

            for pool_id, overlap_amount in pairs(pool_overlaps) do

                if overlap_amount > max_overlap then
                    max_overlap = overlap_amount
                    assigned_pool = pool_id
                end
            end

            if assigned_pool then
                outermost_ancestor_pools__nearest_nonrestored_items[assigned_pool] = outermost_ancestor_pools__nearest_nonrestored_items[assigned_pool] or {}
                table.insert(outermost_ancestor_pools__nearest_nonrestored_items[assigned_pool], nonrestored_item)
            end
        end
    end

    return outermost_ancestor_pools__nearest_nonrestored_items
end


function _module_overglue.calculateAllNonRestoredItemPoolOverlaps(relation__nonrestored_items_bounds__outermost_ancestor_bounds)
  local item_pool_assignments = {}

  for this_outermost_ancestor_pool_id, this_outermost_ancestor_pool__params in pairs(relation__nonrestored_items_bounds__outermost_ancestor_bounds) do

    for this_nonrestored_item, this_nonrestored_item__params in pairs(this_outermost_ancestor_pool__params) do

      if type(this_nonrestored_item__params) ~= "table" then goto continue end

      item_pool_assignments[this_nonrestored_item] = item_pool_assignments[this_nonrestored_item] or {}
      item_pool_assignments[this_nonrestored_item][this_outermost_ancestor_pool_id] = _module_overglue.calculateNonRestoredItemPoolOverlap(this_nonrestored_item__params)

      ::continue::
    end
  end

  return item_pool_assignments
end


function _module_overglue.calculateNonRestoredItemPoolOverlap(nonrestored_item__params)
  -- If we're overlapping, make it a huge priority
  for overlap_type, overlap_value in pairs(nonrestored_item__params.overlaps or {}) do
    if overlap_type == "is_within" or overlap_type == "overlaps_both_sides" then
      return math.huge
    elseif overlap_type == "overlaps_pool_position" or overlap_type == "overlaps_pool_end_point" then
      return overlap_value
    end
  end

  -- For non-overlapping items, return negative distance (so closer items have higher values)
  return nonrestored_item__params.distance_to_pool_center
end

function _module_overglue.checkNonRestoredItemOverlapConditions(this_nonrestored_item, item_position, item_end_point, pool_position, pool_end_point, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap, nonrestored_items_with_partial_overlap, nonrestored_items_to_add_to_glue, nonrestored_items_non_overlapping)
  local item_center = item_position + ((item_end_point - item_position) / 2)
  local pool_center = pool_position + ((pool_end_point - pool_position) / 2)
  local distance_to_pool_center = math.abs(pool_center - item_center)

  local item_is_within_pool = item_position >= pool_position and item_end_point <= pool_end_point
  local item_overlaps_both_sides = item_position <= pool_position and item_end_point >= pool_end_point
  local item_overlaps_pool_position = item_position <= pool_position and item_end_point > pool_position and item_end_point <= pool_end_point
  local item_overlaps_pool_end_point = item_position >= pool_position and item_position < pool_end_point and item_end_point >= pool_end_point

  if item_is_within_pool then
    _module_overglue.processNonRestoredItemOverlapCondition("is_within", this_nonrestored_item, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_to_add_to_glue)
  elseif item_overlaps_both_sides then
    _module_overglue.processNonRestoredItemOverlapCondition("overlaps_both_sides", this_nonrestored_item, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap)
  elseif item_overlaps_pool_position then
    local overlap = item_end_point - pool_position
    _module_overglue.processNonRestoredItemOverlapCondition("overlaps_pool_position", this_nonrestored_item, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_partial_overlap, overlap)
  elseif item_overlaps_pool_end_point then
    local overlap = pool_end_point - item_position
    _module_overglue.processNonRestoredItemOverlapCondition("overlaps_pool_end_point", this_nonrestored_item, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_partial_overlap, overlap)
  else
    -- Store the negative distance (so closer items get higher values when compared)
    _module_overglue.processNonRestoredItemOverlapCondition("non_overlapping", this_nonrestored_item, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_non_overlapping)
    this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds[this_nonrestored_item].distance_to_pool_center = -distance_to_pool_center
  end
end


function _module_overglue.getItemsToOverglue(outermost_ancestor_pools__nearest_nonrestored_items, restored_items_with_this_parent_pool_id)
    local all_items_to_overglue = {}

    -- Add restored items first
    if restored_items_with_this_parent_pool_id then
        for _, item in ipairs(restored_items_with_this_parent_pool_id) do
            if reaper.ValidatePtr(item, "MediaItem*") then
                table.insert(all_items_to_overglue, item)
            end
        end
    end

    -- Add nonrestored items for this pool
    if outermost_ancestor_pools__nearest_nonrestored_items then
        for pool_id, items in pairs(outermost_ancestor_pools__nearest_nonrestored_items) do
            if type(items) == "table" then
                for _, item in ipairs(items) do
                    if reaper.ValidatePtr(item, "MediaItem*") then
                        table.insert(all_items_to_overglue, item)
                    end
                end
            end
        end
    end

    return all_items_to_overglue
end


function _module_overglue.getSelectedItems_PostGlue(selected_items_on_this_track__post_glue, user_selected_items_on_this_track, superitem)
  local selected_items_on_this_track__post_glue, this_item, this_item_still_exists_in_project

  selected_items_on_this_track__post_glue = {}

  for j = 1, #user_selected_items_on_this_track do
    this_item = user_selected_items_on_this_track[j]
    this_item_still_exists_in_project = reaper.ValidatePtr(this_item, _api.datatype.mediaitem)

    if this_item_still_exists_in_project then
      table.insert(selected_items_on_this_track__post_glue, this_item)
    end
  end

  if superitem then
    table.insert(selected_items_on_this_track__post_glue, superitem)
  end

  return selected_items_on_this_track__post_glue
end


-- function restoredItemsExist(pool_id)
--   local all_items_count, restored_items, this_item, this_item_is_selected, this_item_parent_pool_id

--   all_items_count = reaper.CountMediaItems(_api.current_project)
--   restored_items = {}

--   for i = 0, all_items_count-1 do
--     this_item = reaper.GetMediaItem(_api.current_project, i)
--     this_item_parent_pool_id = _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.pool.parent_id)

--     if this_item_parent_pool_id == pool_id then
--       table.insert(restored_items, this_item)
--     end
--   end

--   if restored_items ~= {} then

--     return restored_items
--   end
-- end


-- function itemsAreAllSelected(items)
--   local items_are_all_selected, this_item, this_item_is_selected

--   items_are_all_selected = true

--   for i = 1, #items do
--     this_item = items[i]
--     this_item_is_selected = reaper.IsMediaItemSelected(this_item)

--     if not this_item_is_selected then
--       items_are_all_selected = false

--       break
--     end
--   end

--   return items_are_all_selected
-- end



function _module_single.doSingleTrackEditOrUnglue(user_selected_items_on_this_track, action)
  local superitems = _module_single.setUpSingleTrackEditOrUnglueOrDePool(user_selected_items_on_this_track)

  for i = 1, #superitems do
    local this_superitem = superitems[i]
    local this_pool_id = _module_data.storeRetrieveItemData(this_superitem, _constant.data.key.suffix.pool.instance_id)

    local other_instance_being_edited = _module_single.otherInstanceIsOpen(this_pool_id)
    if other_instance_being_edited then
      _module_single.handleOtherInstanceBeingEdited(other_instance_being_edited, this_pool_id, action)
      return
    end

    local superitem_is_multitake, superitem_takes_count = _module_single.superitemHasMultipleTakes(this_superitem)
    if superitem_is_multitake then
      local multitake_msg__user_response = _module_single.handleMultitakeSuperitem(superitem_takes_count)
      if multitake_msg__user_response == "cancel" then return end
    end

    if _module_edit.handleEditOrUnglue(this_superitem, this_pool_id, action) ~= false then
      table.insert(_state.action.edit.changed_pool_ids, this_pool_id)
    end
  end
end


function _module_single.otherInstanceIsOpen(edit_pool_id)
  local all_items_count, this_item, restored_item_pool_id

  all_items_count = reaper.CountMediaItems(_api.current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api.current_project, i)
    restored_item_pool_id = _module_data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)

    if restored_item_pool_id == edit_pool_id then

      return this_item
    end
  end
end


function _module_single.doSingleTrackDePool(user_selected_items_on_this_track, this_user_selected_items_track, action)
  local superitems, selected_item_groups, restored_items, this_superitem, this_superitem_params, this_superitem_state, this_superitem_instance_pool_id, superitem, new_pool_id

  superitems = _module_single.setUpSingleTrackEditOrUnglueOrDePool(user_selected_items_on_this_track)
  selected_item_groups = _module_common.getSuperglueItemTypes(user_selected_items_on_this_track, {"restored"})
  restored_items = selected_item_groups.restored.items
  _state.action.glue.current_track = this_user_selected_items_track

  for i = 1, #superitems do
    this_superitem = superitems[i]
    this_superitem_params, this_superitem_state, this_superitem_instance_pool_id = _module_depool.setUpDePool(this_superitem)
    this_superitem_params.pool_id = _module_edit.processUnglue(this_superitem, this_superitem_instance_pool_id, action)
    superitem = _module_glue.handleGlue(_state.action.edit_or_unglue.restored_items, nil, nil, this_superitem_params, false)
    new_pool_id = _module_depool.handleDePoolPostGlue(superitem, this_superitem_state, this_superitem_params)

    table.insert(_state.action.glue.all_glued_superitems, superitem)
    table.insert(_state.action.depool.new_pool_ids, new_pool_id)
  end

  for i = 1, #restored_items do
    _module_common.dePoolRestoredItem(restored_items[i])
  end
end


function _module_single.setUpSingleTrackEditOrUnglueOrDePool(user_selected_items_on_this_track)
  local superglue_item_types, selected_item_groups, superitems

  superglue_item_types = {"superitem"}
  selected_item_groups = _module_common.getSuperglueItemTypes(user_selected_items_on_this_track, superglue_item_types)
  superitems = selected_item_groups.superitem.items

  return superitems
end


function _module_single.doSingleTrackSmartAction(user_selected_items_on_this_track, this_user_selected_items_track, action)
  local smart_action, glue_abort_dialog

  smart_action = _module_init.getSmartAction(user_selected_items_on_this_track)

  if smart_action == "glue" then
    _module_multi.doSingleTrackGlue(user_selected_items_on_this_track, this_user_selected_items_track, action)

  elseif smart_action == "edit_or_unglue" then
    _module_single.doSingleTrackEditOrUnglue(user_selected_items_on_this_track, action)

  elseif smart_action == "glue/abort" then
    glue_abort_dialog = reaper.ShowMessageBox("You have selected both Superitem(s) and restored item(s) from an edited Superitem. Are you sure you want to Superglue them?", "Mixed " .. _brand.name .. "items selected", _api.msg.type.ok_cancel)

    if glue_abort_dialog == _api.msg.response.cancel then
      _module_init.setResetUsersItemSelection(false)

      return false

    else
      _module_multi.doSingleTrackGlue(user_selected_items_on_this_track, this_user_selected_items_track, action)
      _module_common.selectDeselectItems(_state.action.glue.all_glued_superitems, true)
    end

  else

    return false
  end

  return true
end


-- function detectSiblingsOpenForEditing(restored_items)
--   local siblings_are_selected, this_restored_item, this_restored_item_parent_pool_id, this_is_2nd_or_later_restored_item_with_pool_id, this_item_belongs_to_different_pool_than_active_edit, last_restored_item_parent_pool_id

--   siblings_are_selected = false

--   for i = 1, #restored_items do
--     this_restored_item = restored_items[i]
--     this_restored_item_parent_pool_id = _module_data.storeRetrieveItemData(this_restored_item, _constant.data.key.suffix.pool.parent_id)
--     this_is_2nd_or_later_restored_item_with_pool_id = last_restored_item_parent_pool_id and last_restored_item_parent_pool_id ~= ""
--     this_item_belongs_to_different_pool_than_active_edit = this_restored_item_parent_pool_id ~= last_restored_item_parent_pool_id

--     if this_is_2nd_or_later_restored_item_with_pool_id then

--       if this_item_belongs_to_different_pool_than_active_edit then
--         siblings_are_selected = true

--         break
--       end

--     else
--       last_restored_item_parent_pool_id = this_restored_item_parent_pool_id
--     end
--   end

--   return siblings_are_selected
-- end


function _module_init.recursiveSuperitemIsBeingGlued(superitems, restored_items)
  local this_superitem, this_superitem_instance_pool_id, this_restored_item, this_restored_item_parent_pool_id, this_restored_item_is_from_same_pool_as_selected_superitem

  for i = 1, #superitems do
    this_superitem = superitems[i]
    this_superitem_instance_pool_id = _module_data.storeRetrieveItemData(this_superitem, _constant.data.key.suffix.pool.instance_id)

    for j = 1, #restored_items do
      this_restored_item = restored_items[j]
      this_restored_item_parent_pool_id = _module_data.storeRetrieveItemData(this_restored_item, _constant.data.key.suffix.pool.parent_id)
      this_restored_item_is_from_same_pool_as_selected_superitem = this_superitem_instance_pool_id == this_restored_item_parent_pool_id

      if this_restored_item_is_from_same_pool_as_selected_superitem then
        reaper.ShowMessageBox(_brand.name .. " can't glue a Superitem to an instance from the same pool being Edited – that could destroy the universe! Change the items selected and try again.", "Recursive Superitem warning", _api.msg.type.ok)
        _module_init.setResetUsersItemSelection(false)

        return true
      end
    end
  end
end


function _module_init.throwOfflineTakeWarning(recommend_undo, is_restored_item)
  local msg, item_string

  msg = _brand.name .. ": Your " .. item_string .. "'s inactive takes are empty, offline or have some other weird setting going on. "
  item_string = is_restored_item and "restored item" or "Superitem"
  msg = recommend_undo and msg .. "It's recommended to undo, remove your " .. item_string .. "'s inactive takes manually, and try again." or msg .. "Aborting."

  -- if is_restored_item then
  --   item_string = "restored item"

  -- else
  --   item_string = "Superitem"
  -- end

  -- if recommend_undo then
  --   msg = msg .. "It's recommended to undo, remove your " .. item_string .. "'s inactive takes manually, and try again."

  -- else
  --   msg = msg .. "Aborting."
  -- end

  reaper.ShowMessageBox(msg, "Warning: Offline takes", _api.msg.type.ok)
end


-- function _module_init.exclusiveSelectItem(item)

--   if item then
--     reaper.Main_OnCommand(_cmd.deselect_all_items, _api.cmd_flag)
--     reaper.SetMediaItemSelected(item, true)

--   else

--     return false
--   end
-- end


function _module_init.cleanUpAction(action, pool_ids)
  local undo_block_string, pool_ids_string

  undo_block_string = _brand.name .. " " .. action
  pool_ids_string = _module_init.getPoolIdsforUndoString(action, pool_ids)

  if pool_ids_string then
    undo_block_string = undo_block_string .. " - Pool #" .. pool_ids_string
  end

  _module_init.refreshUI()
  reaper.Undo_EndBlock(undo_block_string, _api.include_all_undo_states)
end


function _module_init.getPoolIdsforUndoString(action, pool_ids_changed)
  local pool_ids_for_string

  pool_ids_for_string = {}

  for i = 1, #pool_ids_changed do

    if pool_ids_changed[i] then
      table.insert(pool_ids_for_string, pool_ids_changed[i])
    end
  end

  pool_ids_for_string = _module_util.stringifyArray(pool_ids_for_string)

  return pool_ids_for_string
end


function _module_init.refreshUI()
  reaper.PreventUIRefresh(-1)
  reaper.UpdateTimeline()
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(true)
end



function _module_common.getSuperglueItemTypes(items, requested_types)
  local item_types_data, this_item, superitem_pool_id, restored_item_pool_id, this_requested_item_type

  item_types_data = _module_common.getItemTypes()

  for i = 1, #items do
    this_item = items[i]
    superitem_pool_id = _module_data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.instance_id)
    restored_item_pool_id = _module_data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)
    item_types_data.superitem.is = superitem_pool_id and superitem_pool_id ~= ""
    item_types_data.restored.is = restored_item_pool_id and restored_item_pool_id ~= ""
    item_types_data.nonsuperitem.is = not item_types_data.superitem.is
    item_types_data.child_instance.is = item_types_data.superitem.is and item_types_data.restored.is
    item_types_data.parent_instance.is = item_types_data.superitem.is and not item_types_data.restored.is
    item_types_data.nonsuperglue.is = not item_types_data.superitem.is and not item_types_data.restored.is

    for j = 1, #requested_types do
      this_requested_item_type = requested_types[j]

      if item_types_data[this_requested_item_type].is then
        table.insert(item_types_data[this_requested_item_type].items, this_item)
      end
    end
  end

  return item_types_data
end


function _module_common.getItemTypes()
  local item_types, item_types_data, this_item_type

  item_types = {"superitem", "restored", "nonsuperitem", "child_instance", "parent_instance", "nonsuperglue"}
  item_types_data = {}

  for i = 1, #item_types do
    this_item_type = item_types[i]
    item_types_data[this_item_type] = {
      items = {}
    }
  end

  return item_types_data
end


function _module_common.getSetItemName(item, new_name, add_or_remove)
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

      reaper.GetSetMediaItemTakeInfo_String(take, _api.take.key.name, new_name, _api.set_value)

      return new_name, take

    elseif get then

      return current_name, take
    end
  end
end



function _module_midi.pureMidiItemIsSelected(selected_items)
  local this_item, this_item_take, midi_item_is_selected

  for i = 1, #selected_items do
    this_item = selected_items[i]
    this_item_take = reaper.GetActiveTake(this_item)
    midi_item_is_selected = _module_midi.midiItemIsSelected(this_item)

    if midi_item_is_selected then

      break
    end
  end

  if midi_item_is_selected == true then

    return _module_vi.virtualInstrumentIsInactive(this_item, this_item_take)

  elseif midi_item_is_selected == "abort" then

    return true
  end
end


function _module_midi.midiItemIsSelected(item)
  local active_take, active_take_is_midi

  active_take = reaper.GetActiveTake(item)

  if not active_take then
    _module_init.throwOfflineTakeWarning(false, true)

    return "abort"
  end

  active_take_is_midi = reaper.TakeIsMIDI(active_take)

  if active_take and active_take_is_midi then

    return true

  else

    return false
  end
end



function _module_vi.virtualInstrumentIsInactive(item, item_take)
  local current_track, track_virtual_instrument_idx, track_has_virtual_instrument, track_virtual_instrument_is_enabled, track_virtual_instrument_is_muted, take_first_virtual_instrument_idx, take_virtual_instrument_is_enabled, take_virtual_instrument_is_muted, user_response_ignore_muted_virtual_instrument

  current_track = reaper.GetMediaItemTrack(item)
  track_virtual_instrument_idx = reaper.TrackFX_GetInstrument(current_track)
  track_has_virtual_instrument = track_virtual_instrument_idx ~= -1
  track_virtual_instrument_is_enabled = reaper.TrackFX_GetEnabled(current_track, track_virtual_instrument_idx)
  track_virtual_instrument_is_muted = track_has_virtual_instrument and not track_virtual_instrument_is_enabled
  take_first_virtual_instrument_idx, take_virtual_instrument_is_enabled = _module_vi.takeVirtualInstrumentIsActive(item_take)
  take_virtual_instrument_is_muted = take_first_virtual_instrument_idx and not take_virtual_instrument_is_enabled

  if track_virtual_instrument_is_muted or take_virtual_instrument_is_muted then
    user_response_ignore_muted_virtual_instrument = reaper.ShowMessageBox("The first virtual instrument in the FX chain is bypassed. Are you sure you want to Superglue the item(s)?", "Warning: Bypassed VI", _api.msg.type.yes_no)

    if user_response_ignore_muted_virtual_instrument == _api.msg.response.no then

      return true
    end

  elseif not track_has_virtual_instrument and not take_virtual_instrument_is_enabled then
    reaper.ShowMessageBox(_brand.name .. " can't glue pure MIDI without a virtual instrument. Add/enable a virtual instrument to render audio into the superitem or try a different item selection.", "Pure MIDI selected", _api.msg.type.ok)

    return true
  end
end


function _module_vi.takeVirtualInstrumentIsActive(item_take)
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



function _module_glue.handleGlue(selected_items, pool_id, sizing_region_guid, depool_superitem_params, this_is_ancestor_superitem_update)
    local this_is_depool = depool_superitem_params ~= nil
    local first_selected_item = selected_items[1]
    local first_selected_item_name = _module_common.getSetItemName(first_selected_item)

    pool_id, sizing_params, this_is_reglue = _module_glue.setUpGlue(depool_superitem_params, this_is_ancestor_superitem_update, pool_id, sizing_region_guid, selected_items)

    local selected_items_pool_params = _module_glue.handlePreglueItems(selected_items, pool_id, sizing_params, this_is_reglue, this_is_depool)

    local items_to_glue = reaper.CountSelectedMediaItems(0)
    for i = 0, items_to_glue-1 do
        local item = reaper.GetSelectedMediaItem(0, i)
    end

if _constant.support.fixed_lanes then
  _module_lanes.debugLaneInfo("BEFORE GLUE", selected_items, reaper.GetMediaItemTrack(selected_items[1]), pool_id)
end

    local superitem = _module_glue.glueSelectedItemsIntoSuperitem()

    _module_glue.handlePostGlue(selected_items, pool_id, first_selected_item_name, superitem, selected_items_pool_params, sizing_params, this_is_reglue, this_is_ancestor_superitem_update)

    return superitem
end


function _module_glue.setUpGlue(depool_superitem_params, this_is_ancestor_superitem_update, pool_id, sizing_region_guid, selected_items)
  local this_is_new_glue, this_is_depool, this_is_reglue, sizing_params, global_option_toggle_depool_all_siblings_on_reglue

  this_is_new_glue = not pool_id
  this_is_depool = depool_superitem_params
  this_is_reglue = pool_id ~= nil


-- DO DESELECTION *ONLY* ON THIS TRACK IF THIS GLUE IS MULTITRACK?? IF SO, EXPAND _module_common.selectDeselectItems() TO SUPPORT TRACK ARGUMENT AND CALL THAT INSTEAD
  reaper.Main_OnCommand(_cmd.deselect_all_items, _api.cmd_flag)

  if this_is_new_glue then
    pool_id = _module_glue.handlePoolId()
    sizing_params = _module_glue.handleNewGlueSizing(selected_items, this_is_depool, pool_id, depool_superitem_params)

  elseif this_is_reglue then
    sizing_params = _module_glue.getReglueSizing(pool_id, sizing_region_guid, selected_items, this_is_ancestor_superitem_update)
    -- global_option_toggle_depool_all_siblings_on_reglue = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.depool_all_siblings_on_reglue)

    -- if global_option_toggle_depool_all_siblings_on_reglue == "true" then


-- THIS LINE CAUSES SIBLING DEPOOLED SUPERITEM POSITION TO GO WEIRD – TEST FURTHER -- IS THIS STILL THE CASE??
      _state.restored_items.preglue_restored_item_states = _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.contained_item_states)


    -- end
  end

  return pool_id, sizing_params, this_is_reglue
end


function _module_glue.handlePoolId()
  local retval, last_pool_id, new_pool_id

  retval, last_pool_id = _module_data.storeRetrieveProjectData(_constant.data.key.suffix.pool.last_id)
  new_pool_id = _module_glue.incrementPoolId(last_pool_id)

  _module_data.storeRetrieveProjectData(_constant.data.key.suffix.pool.last_id, new_pool_id)

  return new_pool_id
end


function _module_glue.incrementPoolId(last_pool_id)
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


function _module_glue.handleNewGlueSizing(selected_items, this_is_depool, pool_id, depool_superitem_params)
  local global_option_time_selection_sets_bounds_enabled, sizing_params

  global_option_time_selection_sets_bounds_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.time_selection_sets_bounds_on_glue)

  if global_option_time_selection_sets_bounds_enabled == "true" then
    _state.user.time_selection_before_action.position, _state.user.time_selection_before_action.end_point = reaper.GetSet_LoopTimeRange(false, false, nil, nil, false)
    sizing_params = {
      position = _state.user.time_selection_before_action.position,
      length = _state.user.time_selection_before_action.end_point - _state.user.time_selection_before_action.position,
      end_point = _state.user.time_selection_before_action.end_point
    }

  elseif global_option_time_selection_sets_bounds_enabled == "false" then
    sizing_params = _module_common.getBoundsFromItems(selected_items)
  end

  if this_is_depool then
    sizing_params = _module_glue.setUpGlueWithDePool(pool_id, depool_superitem_params)

  else
    _module_glue.instantiateDummySizingItem(sizing_params)
  end

  return sizing_params
end


function _module_common.getBoundsFromItems(items)
  local last_item_position, last_item_length, items_params

  last_item_position = reaper.GetMediaItemInfo_Value(items[#items], _api.item.key.position, "", false)
  last_item_length = reaper.GetMediaItemInfo_Value(items[#items], _api.item.key.length, "", false)
  items_params = {
    position = reaper.GetMediaItemInfo_Value(items[1], _api.item.key.position, "", false),
    end_point = last_item_position + last_item_length
  }
  items_params.length = items_params.end_point - items_params.position

  return items_params
end


function _module_glue.setUpGlueWithDePool(pool_id, depool_superitem_params)
  local sizing_params

  _state.restored_items.last_glue_stored_item_states = _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.contained_item_states)
  sizing_params = {
    position = depool_superitem_params.position,
    end_point = depool_superitem_params.end_point
  }
  sizing_params.length = sizing_params.end_point - sizing_params.position

  _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.last_glue.contained_item_states, _state.restored_items.last_glue_stored_item_states)
  _module_glue.instantiateDummySizingItem(sizing_params)

  return sizing_params
end


function _module_glue.instantiateDummySizingItem(sizing_params)
  local dummy_sizing_item = reaper.AddMediaItemToTrack(
    _state.action.glue.current_track
  )

  reaper.SetMediaItemPosition(dummy_sizing_item, sizing_params.position, _api.dont_refresh_ui)
  reaper.SetMediaItemLength(dummy_sizing_item, sizing_params.length, _api.dont_refresh_ui)
  reaper.SetMediaItemSelected(dummy_sizing_item, true)

  return dummy_sizing_item
end


function _module_glue.getReglueSizing(pool_id, sizing_region_guid, selected_items, this_is_ancestor_superitem_update)
  local user_selected_instance_is_being_reglued, sizing_params

  user_selected_instance_is_being_reglued = not this_is_ancestor_superitem_update
  _state.superitem.pool_parent_last_glue_length = _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.parent_length)
  _state.superitem.pool_parent_last_glue_length = tonumber(_state.superitem.pool_parent_last_glue_length)

  if user_selected_instance_is_being_reglued then
    sizing_params = _module_glue.setUpUserSelectedInstanceReglueSizing(sizing_region_guid, pool_id)

  elseif this_is_ancestor_superitem_update then
    sizing_params = _module_glue.setUpParentReglueSizing(pool_id, selected_items)
  end

  return sizing_params
end


function _module_glue.setUpUserSelectedInstanceReglueSizing(sizing_region_guid, pool_id)
  local sizing_params, is_active_superitem_reglue

  sizing_params = _module_common.getSetSizingRegion(sizing_region_guid)
  is_active_superitem_reglue = sizing_params

  if is_active_superitem_reglue then
    _module_glue.instantiateDummySizingItem(sizing_params)
    _module_common.getSetSizingRegion(sizing_region_guid, "delete")
    _module_glue.handleSizingRegionPoolData(nil, pool_id, "delete")
  end

  return sizing_params
end


function _module_common.getSetSizingRegion(sizing_region_guid_or_pool_id, params_or_delete)
  local get_or_delete, set, region_idx, retval, all_markers_count, all_regions_count, retval, sizing_region_params, sizing_region_guid, all_regions_in_proj_have_been_iterated

  get_or_delete = not params_or_delete or params_or_delete == "delete"
  set = params_or_delete and params_or_delete ~= "delete"
  region_idx = 0
  retval, all_markers_count, all_regions_count = reaper.CountProjectMarkers(_api.current_project)

  repeat

    if get_or_delete then
      retval, sizing_region_params = _module_glue.getParamsFrom_OrDelete_SizingRegion(sizing_region_guid_or_pool_id, params_or_delete, region_idx)

      if sizing_region_params then

        return sizing_region_params
      end

    elseif set then
      sizing_region_params = params_or_delete
      retval, sizing_region_guid = _module_glue.addSizingRegion(sizing_region_guid_or_pool_id, sizing_region_params, region_idx)

      if sizing_region_guid then

        return sizing_region_guid
      end
    end

    region_idx = region_idx + 1
    all_regions_in_proj_have_been_iterated = region_idx > all_regions_count

  until retval == 0 or all_regions_in_proj_have_been_iterated
end


function _module_glue.getParamsFrom_OrDelete_SizingRegion(sizing_region_guid_or_pool_id, params_or_delete, region_idx)
  local get, delete, sizing_region_guid, sizing_region_api__key, stored_guid_retval, this_region_guid, this_region_belongs_to_active_pool, sizing_region_params, retval, is_region

  get = not params_or_delete
  delete = params_or_delete == "delete"
  sizing_region_guid = sizing_region_guid_or_pool_id
  sizing_region_api__key = _api.regionmarker.guid_key_prefix .. region_idx
  stored_guid_retval, this_region_guid = reaper.GetSetProjectInfo_String(_api.current_project, sizing_region_api__key, "", false)
  this_region_belongs_to_active_pool = this_region_guid == sizing_region_guid

  if this_region_belongs_to_active_pool then

    if get then
      sizing_region_params = {
        idx = region_idx
      }
      retval, is_region, sizing_region_params.position, sizing_region_params.end_point = reaper.EnumProjectMarkers3(_api.current_project, region_idx)
      sizing_region_params.length = sizing_region_params.end_point - sizing_region_params.position

      return retval, sizing_region_params

    elseif delete then
      reaper.DeleteProjectMarkerByIndex(_api.current_project, region_idx, true)

      retval = 0

      return retval
    end

  else
    retval = nil

    return retval
  end
end


function _module_glue.addSizingRegion(sizing_region_guid_or_pool_id, params_or_delete, region_idx)
  local params, pool_id, sizing_region_name, sizing_region_label_num, retval, is_region, this_region_position, this_region_end_point, this_region_name, this_region_label_num, this_region_is_active

  params = params_or_delete
  params.end_point = params.position + params.length
  pool_id = sizing_region_guid_or_pool_id
  sizing_region_name = _constant.sizingregion.label.prefix .. pool_id .. _constant.sizingregion.label.suffix
  sizing_region_label_num = reaper.AddProjectMarker2(_api.current_project, true, params.position, params.end_point, sizing_region_name, _constant.sizingregion.first_display_num, _constant.sizingregion.color)
  retval, is_region, this_region_position, this_region_end_point, this_region_name, this_region_label_num = reaper.EnumProjectMarkers3(_api.current_project, region_idx)

  if is_region then
    this_region_is_active = this_region_label_num == sizing_region_label_num

    if this_region_is_active then
      local guid_result, new_guid = _module_glue.handleSizingRegionPoolData(region_idx, pool_id)

      return guid_result, new_guid
    end
  end

  return retval
end


function _module_glue.handleSizingRegionPoolData(region_idx, pool_id, delete)
  local all_pool_ids_with_active_sizing_regions_retval, all_pool_ids_with_active_sizing_regions, sizing_region_api__key, sizing_region_guid_retval, sizing_region_guid

  all_pool_ids_with_active_sizing_regions_retval, all_pool_ids_with_active_sizing_regions = _module_data.storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions)

  if delete == "delete" then

    if all_pool_ids_with_active_sizing_regions then
      retval, all_pool_ids_with_active_sizing_regions = serpent.load(all_pool_ids_with_active_sizing_regions)
      all_pool_ids_with_active_sizing_regions[pool_id] = nil
      all_pool_ids_with_active_sizing_regions = serpent.dump(all_pool_ids_with_active_sizing_regions)

      _module_data.storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions, all_pool_ids_with_active_sizing_regions)
    end

  else
    sizing_region_api__key = _api.regionmarker.guid_key_prefix .. region_idx
    sizing_region_guid_retval, sizing_region_guid = reaper.GetSetProjectInfo_String(_api.current_project, sizing_region_api__key, "", false)

    if all_pool_ids_with_active_sizing_regions_retval then
      retval, all_pool_ids_with_active_sizing_regions = serpent.load(all_pool_ids_with_active_sizing_regions)
      all_pool_ids_with_active_sizing_regions[pool_id] = sizing_region_guid

    else
      all_pool_ids_with_active_sizing_regions = {
        [pool_id] = sizing_region_guid
      }
    end

    all_pool_ids_with_active_sizing_regions = serpent.dump(all_pool_ids_with_active_sizing_regions)

    _module_data.storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions, all_pool_ids_with_active_sizing_regions)

    return retval, sizing_region_guid
  end
end


function _module_glue.setUpParentReglueSizing(pool_id, selected_items)
  local pool_parent_length_key_label, pool_parent_last_glue_position, pool_parent_last_glue_end_point, sizing_params

  pool_parent_last_glue_position = _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.parent_position)
  pool_parent_last_glue_position = tonumber(pool_parent_last_glue_position)
  pool_parent_last_glue_end_point = pool_parent_last_glue_position + _state.superitem.pool_parent_last_glue_length
  sizing_params = {
    position = pool_parent_last_glue_position - _state.restored_items.delta.position_delta_near_project_start,
    length = _state.superitem.pool_parent_last_glue_length - _state.restored_items.delta.position_delta_near_project_start,
    end_point = pool_parent_last_glue_end_point - _state.restored_items.delta.position_delta_near_project_start
  }

-- THIS PROBABLY NEEDS TO BE REENABLED (CASE: RESTORED ITEMS SMALLER THAN SIZING PARAMS ON EITHER/BOTH SIDES) BUT MUST BE SELECTED AT THE RIGHT TIME BEFORE GLUE. CURRENTLY THERE IS NO SELECTION SO IT REMAINS AFTER GLUE
  -- _module_glue.instantiateDummySizingItem(sizing_params)

  return sizing_params
end


function _module_glue.handlePreglueItems(selected_items, pool_id, sizing_params, this_is_reglue, this_is_depool)
  local selected_item_states, selected_items_pool_params

  if _constant.support.fixed_lanes then
    _module_lanes.storeItemLaneOffsets(selected_items, pool_id)
  end

  -- Get states before storing them
  selected_item_states, selected_items_pool_params = _module_data.prepareAndGetItemStates(selected_items, pool_id)
  _module_data.storeItemStates(pool_id, selected_item_states)
  _module_common.selectDeselectItems(selected_items, true)

  return selected_items_pool_params
end


function _module_glue.setPreglueItemsData(preglue_items, pool_id, sizing_params, this_is_reglue, this_is_depool)
  local this_is_new_glue, global_option_time_selection_sets_bounds_enabled, this_item, this_item_position, first_item_position, first_child_position_delta_to_parent

  this_is_new_glue = not this_is_reglue
  global_option_time_selection_sets_bounds_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.time_selection_sets_bounds_on_glue)

  for i = 1, #preglue_items do
    this_item = preglue_items[i]
    this_item_position = reaper.GetMediaItemInfo_Value(this_item, _api.item.key.position)

    _module_data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id, pool_id)

    if i == 1 or this_item_position < first_item_position then
      first_item_position = this_item_position
    end
  end

  first_child_position_delta_to_parent = (this_is_new_glue and not this_is_depool) and 0 or first_item_position - sizing_params.position

  -- if this_is_new_glue and not this_is_depool then
  --   first_child_position_delta_to_parent = 0

  -- else
  --   first_child_position_delta_to_parent = first_item_position - sizing_params.position
  -- end

  _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.superitem.first_child_delta_to_superitem_position, first_child_position_delta_to_parent)
end


function _module_data.prepareAndGetItemStates(items, active_pool_id)
  local selected_item_states, selected_items_pool_params, item, this_item, this_item_instance_pool_id, this_item_parent_pool_id, this_item_guid, this_item_state

  selected_item_states = {}
  selected_items_pool_params = {}

  for i, item in ipairs(items) do
    this_item = items[i]
    this_item_instance_pool_id = _module_data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.instance_id)
    this_item_parent_pool_id = _module_data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)

    if not this_item_instance_pool_id or this_item_instance_pool_id == "" then
      this_item_instance_pool_id = _constant.noninstance_label .. i
    end

    _module_glue.convertMidiItemToAudio(this_item)

    this_item_guid = reaper.BR_GetMediaItemGUID(item)
    this_item_state = _module_data.getSetItemStateChunk(this_item)
    selected_item_states[this_item_guid] = this_item_state
    selected_items_pool_params[this_item_instance_pool_id] = {
      parent_pool_id = this_item_parent_pool_id,
      position = reaper.GetMediaItemInfo_Value(this_item, _api.item.key.position)
    }
  end

  return selected_item_states, selected_items_pool_params, this_item_instance_pool_id
end


function _module_glue.convertMidiItemToAudio(item)
  local item_takes_count, active_take, this_take_is_midi, retval, active_take_guid

  item_takes_count = reaper.GetMediaItemNumTakes(item)

  if item_takes_count > 0 then
    active_take = reaper.GetActiveTake(item)
    this_take_is_midi = active_take and reaper.TakeIsMIDI(active_take)

    if this_take_is_midi then
      active_take = reaper.GetActiveTake(item)
      retval, active_take_guid = reaper.GetSetMediaItemTakeInfo_String(active_take, _api.take.key.guid, "", false)

      _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.preglue.active_take_guid, active_take_guid)
      reaper.SetMediaItemSelected(item, true)
      reaper.Main_OnCommand(_cmd.apply_track_take_fx_to_items, _api.cmd_flag)
      reaper.SetMediaItemSelected(item, false)
      _module_glue.cleanNullTakes(item)

    else
      _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.preglue.active_take_guid, "")
    end
  end
end


function _module_glue.cleanNullTakes(item, force)
  local item_state = _module_data.getSetItemStateChunk(item)

  if string.find(item_state, _api.take.null_takes_val) or force then
    item_state = string.gsub(item_state, _api.take.null_takes_val, "")

    _module_data.getSetItemStateChunk(item, item_state)
  end
end


function _module_data.getSetItemStateChunk(item, state)
  local get = not state
  local set = state
  local retval

  if get then
    retval, state = reaper.GetItemStateChunk(item, "", true)
    return state

  elseif set then
    reaper.SetItemStateChunk(item, state, true)
  end
end


function _module_data.storeItemStates(pool_id, item_states_table)
  item_states_table = serpent.dump(item_states_table)

  _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.contained_item_states, item_states_table)
end


function _module_common.selectDeselectItems(items, select_deselect)
  local this_item

  for i = 1, #items do
    this_item = items[i]

    if this_item then
      reaper.SetMediaItemSelected(this_item, select_deselect)
    end
  end
end


function _module_data.getSetItemParams(item, params)
  local get, set, track, retval, track_guid, active_take, active_take_num, item_params

  get = not params
  set = params

  if get then
    track = reaper.GetMediaItemTrack(item)
    retval, track_guid = reaper.GetSetMediaTrackInfo_String(track, _api.take.key.guid, "", _api.get_value)
    active_take = reaper.GetActiveTake(item)

    if active_take then
      active_take_num = reaper.GetMediaItemTakeInfo_Value(active_take, _api.take.key.number)
    end

    item_params = {
      item_guid = reaper.BR_GetMediaItemGUID(item),
      state = _module_data.getSetItemStateChunk(item),
      track_guid = track_guid,
      active_take_num = active_take_num,
      position = reaper.GetMediaItemInfo_Value(item, _api.item.key.position),
      length = reaper.GetMediaItemInfo_Value(item, _api.item.key.length),
      instance_pool_id = _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.pool.instance_id),
      parent_pool_id = _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.pool.parent_id)
    }
    item_params.end_point = item_params.position + item_params.length

    if active_take then
      item_params.source_offset = reaper.GetMediaItemTakeInfo_Value(active_take, _api.take.key.src_offset)
    end

    return item_params

  elseif set then
    reaper.SetMediaItemInfo_Value(item, _api.item.key.position, params.position)
    reaper.SetMediaItemInfo_Value(item, _api.item.key.length, params.length)
  end
end


function _module_glue.glueSelectedItemsIntoSuperitem()
  local increase_channel_count_from_take_fx, superitem

  increase_channel_count_from_take_fx = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.auto_increase_channel_count)

  if increase_channel_count_from_take_fx == "true" then
    reaper.Main_OnCommand(_cmd.apply_fx_to_items_multichannel, _api.cmd_flag)
    reaper.Main_OnCommand(_cmd.crop_selected_items_to_active_takes, _api.cmd_flag)
  end

  reaper.Main_OnCommand(_cmd.glue_ignoring_time_selection_incl_fades, _api.cmd_flag)

  superitem = _module_init.getFirstSelectedItem()

  return superitem
end


function _module_glue.handlePostGlue(selected_items, pool_id, first_selected_item_name, superitem, selected_items_pool_params, sizing_params, this_is_reglue, this_is_ancestor_superitem_update)
  local superitem_init_name

  superitem_init_name = _module_glue.handleAddtionalItemCountLabel(selected_items, pool_id, first_selected_item_name)

  _state.pool.active_glue_pool_id = pool_id

  _module_glue.handleSuperitemPostGlue(superitem, superitem_init_name, pool_id, sizing_params, this_is_reglue)
  _module_glue.handleDescendantPoolReferences(pool_id, selected_items_pool_params)

  -- Position superitem in topmost lane
  -- Position superitem in topmost lane
  if _constant.support.fixed_lanes then
    local topLaneStr = _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.top_lane)
    local topLane = tonumber(topLaneStr) or 0

    local topYPosStr = _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.top_lane_y_pos)
    local exactYPos = topYPosStr and tonumber(topYPosStr)

    -- Get the original lane count
    local originalLaneCountStr = _module_data.storeRetrievePoolData(pool_id, "original_lane_count")
    local originalLaneCount = tonumber(originalLaneCountStr) or 0

    -- Get track information
    local track = reaper.GetMediaItemTrack(superitem)

    -- Ensure track is in fixed lanes mode
    reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)

    -- Restore original lane count if it was stored and is reasonable
    if originalLaneCount > 0 then
        reaper.SetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES", originalLaneCount)
    end

    -- Set free positioning mode
    reaper.SetMediaItemInfo_Value(superitem, "B_FREEMODE", 1)

    -- Use exact Y position if available, otherwise calculate
    if exactYPos then
        reaper.SetMediaItemInfo_Value(superitem, "F_FREEMODE_Y", exactYPos)
    else
        local trackHeight = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
        local laneCount = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
        local laneHeight = trackHeight / math.max(1, laneCount)
        reaper.SetMediaItemInfo_Value(superitem, "F_FREEMODE_Y", topLane * laneHeight)
    end

    reaper.UpdateArrange()

    if _test_logging_enabled then
      _module_dev.log("Lane positioning - Lane: " .. topLane .. ", Y: " ..
        (exactYPos or "(calculated)"))
    end

_module_lanes.debugLaneInfo("AFTER GLUE", {superitem}, reaper.GetMediaItemTrack(superitem), pool_id)
  end

  if not this_is_ancestor_superitem_update then
    _module_glue.handleParentPoolReferencesInChildPools(pool_id, selected_items_pool_params)
    _module_glue.deleteUnselectedContainedItems()
  end

  if not this_is_reglue then
    _module_common.addRemoveItemImage(superitem, "superitem")
  end
end


function _module_glue.handleAddtionalItemCountLabel(selected_items, pool_id, first_selected_item_name)
  local selected_item_count, multiple_user_items_are_selected, other_selected_items_count, is_nested_superitem_name, has_nested_item_name, item_name_addl_count_str, superitem_init_name

  selected_item_count = _module_util.getTableSize(selected_items)
  multiple_user_items_are_selected = selected_item_count > 1
  other_selected_items_count = selected_item_count - 1
  is_nested_superitem_name = string.find(first_selected_item_name, _brand.prefix.superitem_name_default)
  has_nested_item_name = string.find(first_selected_item_name, _regex.nested_item_default_name)

  if multiple_user_items_are_selected then
    item_name_addl_count_str = " +" .. other_selected_items_count ..  " more"

  else
    item_name_addl_count_str = ""
  end

  if is_nested_superitem_name and has_nested_item_name then
    first_selected_item_name = string.match(first_selected_item_name, _brand.prefix.superitem_name_default)
  end

  superitem_init_name = pool_id .. " [" .. _unicode.double_quotation_mark .. first_selected_item_name .. _unicode.double_quotation_mark .. item_name_addl_count_str .. "]"

  return superitem_init_name
end


function _module_glue.handleSuperitemPostGlue(superitem, superitem_init_name, pool_id, sizing_params, this_is_reglue)
  local this_is_fresh_glue, superitem_active_take, superitem_params

  this_is_fresh_glue = not this_is_reglue
  superitem_active_take = reaper.GetActiveTake(superitem)

  _module_glue.setSuperitemParams(superitem, superitem_active_take, sizing_params, this_is_reglue)

  superitem_params = _module_data.getSetItemParams(superitem)

  if this_is_fresh_glue then
    _module_glue.renameSuperitemSource(superitem, pool_id)
    _module_common.setSuperitemColor()

  elseif this_is_reglue then
    _module_common.handleOfflineTake(superitem, "reglued")
  end

  if not _state.superitem.active_instance_length_has_changed then
    _state.superitem.active_instance_length_has_changed = _state.superitem.pool_parent_last_glue_length ~= superitem_params.length
  end

  _module_glue.setSuperitemName(superitem, superitem_init_name)
  _module_glue.handleSuperitemPostGlueData(pool_id, superitem, superitem_params, superitem_active_take)
end


function _module_glue.setSuperitemParams(superitem, superitem_active_take, sizing_params, this_is_reglue)
  local global_option_time_selection_sets_bounds_enabled, user_time_selection_is_active, superitem_new_left_edge, superitem_new_right_edge

  global_option_time_selection_sets_bounds_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.time_selection_sets_bounds_on_glue)
  user_time_selection_is_active = _module_util.getTableSize(_state.user.time_selection_before_action) > 0

  if this_is_reglue then
    superitem_new_left_edge = sizing_params.position
    superitem_new_right_edge = sizing_params.end_point

  elseif global_option_time_selection_sets_bounds_enabled == "true" and user_time_selection_is_active then
    superitem_new_left_edge = _state.user.time_selection_before_action.position
    superitem_new_right_edge = _state.user.time_selection_before_action.end_point
  end

  if superitem_new_left_edge and superitem_new_right_edge then
    reaper.BR_SetItemEdges(superitem, superitem_new_left_edge, superitem_new_right_edge)
  end
end


function _module_glue.renameSuperitemSource(superitem, pool_id)
  local superitem_active_take, superitem_active_take_source_filepath, superitem_source_new_filepath, superitem_source_new_filepath_extension, escaped_extension

  superitem_active_take, superitem_active_take_source_filepath, superitem_source_new_filepath = _module_glue.getSuperitemActiveTakeInfo(superitem, pool_id)

  for i in string.gmatch(superitem_source_new_filepath, _regex.file_extension) do
    superitem_source_new_filepath_extension = "." .. i
  end

  escaped_extension = _module_util.escapeRegexSpecialCharacters(superitem_source_new_filepath_extension)

  if _module_util.fileExists(superitem_source_new_filepath) then
    superitem_source_new_filepath = string.gsub(superitem_source_new_filepath, escaped_extension, "-redo" .. superitem_source_new_filepath_extension)

    _module_util.copyFile(superitem_active_take_source_filepath, superitem_source_new_filepath)
    os.remove(superitem_active_take_source_filepath)

  else
    os.rename(superitem_active_take_source_filepath, superitem_source_new_filepath)
  end

  reaper.BR_SetTakeSourceFromFile2(superitem_active_take, superitem_source_new_filepath, true, true)
  reaper.Main_OnCommand(_cmd.build_missing_peaks, _api.cmd_flag)
end


function _module_glue.getSuperitemActiveTakeInfo(superitem, pool_id)
  local project_path, superitem_active_take, superitem_active_take_source, superitem_active_take_source_peaks, superitem_active_take_source_filepath, superitem_active_take_source_filename, superitem_source_new_filepath

  project_path = reaper.GetProjectPath()
  superitem_active_take = reaper.GetActiveTake(superitem)
  superitem_active_take_source = reaper.GetMediaItemTake_Source(superitem_active_take)
  superitem_active_take_source_filepath = reaper.GetMediaSourceFileName(superitem_active_take_source)

  for i in string.gmatch(superitem_active_take_source_filepath, _file.path.splitter) do
    superitem_active_take_source_filename = i
  end

  superitem_source_new_filepath = project_path .. _file.os.separator .. _brand.prefix.item_name .. _file.name.custom_separator .. _constant.data.key.prefix.pool .. pool_id .. _file.name.custom_separator .. superitem_active_take_source_filename

  return superitem_active_take, superitem_active_take_source_filepath, superitem_source_new_filepath
end


function _module_common.refreshActiveTakeFlag(item, active_take, pool_id)
  local all_takes, superitem_superglue_active_take_key, this_take, flag_value

  all_takes = reaper.CountTakes(item)
  superitem_superglue_active_take_key = _api.data_key .. _brand.prefix.global .. _constant.data.key.prefix.pool .. pool_id .. _constant.data.key.suffix.superitem.superglue_active_take

  for i = 0, all_takes-1 do
    this_take = reaper.GetTake(item, i)
    flag_value = this_take == active_take and "true" or "false"

    -- if this_take == active_take then
    --   reaper.GetSetMediaItemTakeInfo_String(this_take, superitem_superglue_active_take_key, "true", _api.set_value)

    -- else
    --   reaper.GetSetMediaItemTakeInfo_String(this_take, superitem_superglue_active_take_key, "false", _api.set_value)
    -- end

    reaper.GetSetMediaItemTakeInfo_String(this_take, superitem_superglue_active_take_key, flag_value, _api.set_value)
  end
end


function _module_glue.setSuperitemName(item, superitem_name_ending)
  local take, new_superitem_name

  take = reaper.GetActiveTake(item)
  new_superitem_name = _brand.prefix.superitem_name .. superitem_name_ending

  reaper.GetSetMediaItemTakeInfo_String(take, _api.take.key.name, new_superitem_name, _api.set_value)
end


function _module_common.addRemoveItemImage(item, type_or_remove)
  local item_images_are_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.item_images) == "true"

  if item_images_are_enabled then
    local add = type_or_remove
    local type = type_or_remove
    local remove = type_or_remove == false
    local img_path = ""

    if add then
      if type == "superitem" then
        img_path = _file.path.superitem_bg_img
      elseif type == "restored" then
        img_path = _file.path.restored_item_bg_img
      elseif type == "restored_instance" then
        img_path = _file.path.restored_instance_bg_img
      end
    elseif remove then
      img_path = ""
    end

    -- Use fixed height without lane calculations
    local base_height = _api.item.image_full_height

    reaper.BR_SetMediaItemImageResource(item, img_path, base_height)
  end
end


function _module_common.getImagePathForType(type_or_remove)
  if type_or_remove == false then return "" end

  local paths = {
    superitem = _file.path.superitem_bg_img,
    restored = _file.path.restored_item_bg_img,
    restored_instance = _file.path.restored_instance_bg_img
  }

  return paths[type_or_remove] or ""
end


function _module_glue.handleSuperitemPostGlueData(pool_id, superitem, superitem_params, superitem_active_take)
  _module_data.storeRetrieveSuperitemParams(pool_id, _constant.actionstep.postglue, superitem)
  _module_data.storeRetrieveItemData(superitem, _constant.data.key.suffix.pool.instance_id, pool_id)
  _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.parent_position, superitem_params.position)
  _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.parent_length, superitem_params.length)
  _module_data.storeRetrievePoolData(pool_id, _constant.actionstep.freshly_depooled_superitem_flag, "false")
  _module_common.refreshActiveTakeFlag(superitem, superitem_active_take, pool_id)
end


function _module_data.storeRetrieveSuperitemParams(pool_id, action_step, superitem)
  local retrieve, store, superitem_params_key_label, retval, superitem_params

  retrieve = not superitem
  store = superitem
  superitem_params_key_label = _constant.data.key.prefix.pool .. pool_id .. _brand.separator .. action_step .. _constant.data.key.suffix.superitem.params

  if retrieve then
    retval, superitem_params = _module_data.storeRetrieveProjectData(superitem_params_key_label)
    retval, superitem_params = serpent.load(superitem_params)

    if superitem_params then
      superitem_params.track = reaper.BR_GetMediaTrackByGUID(_api.current_project, superitem_params.track_guid)
    end

    return superitem_params

  elseif store then
    superitem_params = _module_data.getSetItemParams(superitem)
    superitem_params = serpent.dump(superitem_params)

    _module_data.storeRetrieveProjectData(superitem_params_key_label, superitem_params)
  end
end


function _module_common.setSuperitemColor()
  local global_option_toggle_new_superglue_random_color = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.new_superglue_random_color)

  if global_option_toggle_new_superglue_random_color == "true" then
    reaper.Main_OnCommand(_cmd.set_item_to_one_random_color, _api.cmd_flag)
  end
end


function _module_common.handleOfflineTake(item, context)
  local active_take, active_src, active_take_is_online, src_filepath, src_exists, src_filename, src_filepath_in_project_folder, user_response, retval, user_chosen_file

  active_take = reaper.GetActiveTake(item)
  active_src = reaper.GetMediaItemTake_Source(active_take)
  active_take_is_online = reaper.CF_GetMediaSourceOnline(active_src)

  if not active_take_is_online then
    src_filepath = reaper.GetMediaSourceFileName(active_src)
    src_exists = _module_util.fileExists(src_filepath)

    if not src_exists then
      src_filename = _module_util.getFileNameFromPath(src_filepath)
      src_filepath_in_project_folder = _file.path.proj_render .. _file.os.separator .. src_filename
      src_exists = _module_util.fileExists(src_filepath_in_project_folder)

      if src_exists then
        reaper.BR_SetTakeSourceFromFile2(active_take, src_filepath_in_project_folder, true, true)

      else
        user_response = reaper.ShowMessageBox(_brand.name .. " can't find a media source. Choose a new source file for the offline " .. context .. " item. Press OK to continue, or Cancel to leave it offline.", "Offline take selected", _api.msg.type.ok_cancel)

        if user_response == _api.msg.response.ok then
          retval, user_chosen_file = reaper.JS_Dialog_BrowseForOpenFiles("Choose a new source file for the offline item.", _file.path.proj_render, src_filename, _file.supported_media_types, false)

          reaper.BR_SetTakeSourceFromFile2(active_take, user_chosen_file, true, true)
        end
      end
    end
  end
end


function _module_glue.handleDescendantPoolReferences(pool_id, contained_items_pool_params)
  local this_pool_descendants, this_contained_item_instance_pool_id, this_contained_item_params, this_selected_item_is_superitem, this_child_pool_descendant_pool_ids, this_pool_descendants_string

  this_pool_descendants = {}

  for this_contained_item_instance_pool_id, this_contained_item_params in pairs(contained_items_pool_params) do
    this_selected_item_is_superitem = not string.find(this_contained_item_instance_pool_id, _constant.noninstance_label)

    if this_selected_item_is_superitem then
      this_child_pool_descendant_pool_ids = _module_data.storeRetrievePoolData(this_contained_item_instance_pool_id, _constant.data.key.suffix.pool.descendant_ids)

      table.insert(this_pool_descendants, this_contained_item_instance_pool_id)

      for j = 1, #this_child_pool_descendant_pool_ids do
        table.insert(this_pool_descendants, this_child_pool_descendant_pool_ids[j])
      end
    end
  end

  this_pool_descendants = _module_util.deduplicateTable(this_pool_descendants)
  this_pool_descendants_string = serpent.dump(this_pool_descendants)

  _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.descendant_ids, this_pool_descendants_string)
end


function _module_glue.handleParentPoolReferencesInChildPools(active_pool_id, contained_items_pool_params)
  local this_contained_item_instance_pool_id, this_contained_item_params, this_selected_item_is_superitem

  for this_contained_item_instance_pool_id, this_contained_item_params in pairs(contained_items_pool_params) do
    this_selected_item_is_superitem = not string.find(this_contained_item_instance_pool_id, _constant.noninstance_label)

    if this_selected_item_is_superitem then
      _module_glue.storeParentPoolReferencesInChildPool(this_contained_item_instance_pool_id, active_pool_id)
    end
  end
end


function _module_glue.storeParentPoolReferencesInChildPool(preglue_child_instance_pool_id, active_pool_id)
  local parent_pool_ids_data_key_label, retval, parent_pool_ids_referenced_in_child_pool, this_parent_pool_id, this_parent_pool_id_is_referenced_in_child_pool

  parent_pool_ids_data_key_label = _constant.data.key.prefix.pool .. preglue_child_instance_pool_id .. _constant.data.key.suffix.pool.parent_ids_data
  retval, parent_pool_ids_referenced_in_child_pool = _module_data.storeRetrieveProjectData(parent_pool_ids_data_key_label)

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

    _module_data.storeRetrieveProjectData(parent_pool_ids_data_key_label, parent_pool_ids_referenced_in_child_pool)
  end
end


function _module_glue.deleteUnselectedContainedItems()
  local this_contained_item_outside, this_contained_item_track

  if _state.restored_items.unselected_contained_items then

    for i = 1, #_state.restored_items.unselected_contained_items do
      this_contained_item_outside = _state.restored_items.unselected_contained_items[i]
      this_contained_item_track = reaper.GetMediaItem_Track(this_contained_item_outside)

      reaper.DeleteTrackMediaItem(this_contained_item_track, this_contained_item_outside)
    end
  end

  _state.restored_items.unselected_contained_items = nil
end


function _module_glue.handleReglue(selected_items, restored_items_pool_id)
  local sizing_region_guid, superitem, superitem_params

  sizing_region_guid = _module_common.checkSizingRegionExists(restored_items_pool_id, selected_items)

  if not sizing_region_guid then return false end

  _module_data.cleanUnselectedRestoredItemsFromPool(restored_items_pool_id)

  _state.superitem.params.last_glue.edited_pool = _module_data.storeRetrieveSuperitemParams(restored_items_pool_id, _constant.actionstep.postglue)
  superitem = _module_glue.handleGlue(selected_items, restored_items_pool_id, sizing_region_guid, nil, nil)
  superitem, superitem_params = _module_glue.handleReglueSuperitemParams(superitem, restored_items_pool_id)

  _module_glue.setRegluePositionDeltas(superitem_params)
  _module_glue.adjustPostGlueTakeMarkersAndEnvelopes(superitem, nil, nil, true)
  _module_glue.reglueAncestors(superitem_params.pool_id, superitem)
  reaper.Main_OnCommand(_cmd.deselect_all_items, _api.cmd_flag)
  _module_glue.propagateChangesToSuperitems(superitem, sizing_region_guid)
  reaper.ClearPeakCache()

  return superitem
end


function _module_data.cleanUnselectedRestoredItemsFromPool(pool_id)
  local all_items_count, this_item, this_item_is_selected, this_item_parent_pool_id

  all_items_count = reaper.CountMediaItems(_api.current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api.current_project, i)
    this_item_is_selected = reaper.IsMediaItemSelected(this_item)

    if not this_item_is_selected then

      this_item_parent_pool_id = _module_data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)

      if this_item_parent_pool_id == pool_id then
        _module_common.dePoolRestoredItem(this_item)
      end
    end
  end
end


function _module_common.dePoolRestoredItem(item)
  local item_instance_pool_id, item_is_instance, item_type

  _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.pool.parent_id, "")

  item_instance_pool_id = _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.pool.instance_id)
  item_is_instance = item_instance_pool_id and item_instance_pool_id ~= ""
  item_type = item_is_instance and "superitem" or false

  -- if item_is_instance then
  --   _module_common.addRemoveItemImage(item, "superitem")

  -- else
  --   _module_common.addRemoveItemImage(item, false)
  -- end

  _module_common.addRemoveItemImage(item, item_type)
end


function _module_glue.handleReglueSuperitemParams(superitem, restored_items_pool_id)
  local superitem_params, global_option_toggle_retain_only_last_glue_source_enabled

  superitem_params = _module_data.getSetItemParams(superitem)
  superitem_params.updated_src = _module_common.getSetWipeItemAudioSrc(superitem)
  superitem_params.pool_id = restored_items_pool_id
  superitem = _module_data.restoreSuperitemState(superitem, superitem_params)
  _state.superitem.params.fresh_glue.edited_pool = superitem_params
  _state.superitem.params.preedit.edited_pool = _module_data.storeRetrieveSuperitemParams(_state.superitem.params.fresh_glue.edited_pool.pool_id, _constant.actionstep.preedit)
  global_option_toggle_retain_only_last_glue_source_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.retain_only_last_glue_source)

  if global_option_toggle_retain_only_last_glue_source_enabled == "true" then
    _module_common.getSetWipeItemAudioSrc(superitem, "wipe")
  end

  return superitem, superitem_params
end


function _module_common.checkSizingRegionExists(pool_id, selected_items)
  local retval, all_pool_ids_with_active_sizing_regions, sizing_region_guid, region_idx, this_region_guid

  retval, all_pool_ids_with_active_sizing_regions = _module_data.storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions)
  retval, all_pool_ids_with_active_sizing_regions = serpent.load(all_pool_ids_with_active_sizing_regions)
  sizing_region_guid = all_pool_ids_with_active_sizing_regions[pool_id]

  if sizing_region_guid and sizing_region_guid ~= "" then
    region_idx = 0

    repeat
      retval, this_region_guid = reaper.GetSetProjectInfo_String(_api.current_project, _api.regionmarker.guid_key_prefix .. region_idx, "", false)

      if retval and this_region_guid == sizing_region_guid then
        return this_region_guid
      end

      region_idx = region_idx + 1
    until retval == false

    sizing_region_user_result = _module_common.handleNoSizingRegionExists(selected_items, pool_id)

    return sizing_region_user_result
  end

  return nil
end


function _module_common.handleNoSizingRegionExists(selected_items, pool_id)
  local global_option_time_selection_sets_bounds_enabled, time_selection_start, time_selection_end, no_time_selection_exists, user_response_create_time_selection

  global_option_time_selection_sets_bounds_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.time_selection_sets_bounds_on_glue)
  time_selection_start, time_selection_end = reaper.GetSet_LoopTimeRange(false, false, nil, nil, false)
  no_time_selection_exists = time_selection_end == _constant.position_start_of_project

  if global_option_time_selection_sets_bounds_enabled == "false" then

    return _module_common.handleNoSizer_TimeSelectionBoundsOptionDisabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)

  elseif global_option_time_selection_sets_bounds_enabled == "true" then

    return _module_common.handleNoSizer_TimeSelectionBoundsOptionEnabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)
  end
end


function _module_common.handleNoSizer_TimeSelectionBoundsOptionDisabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)
  local msg_sizing_region__deleted, msg_title_sizing_region__deleted, user_response_reinstate_sizing_region, sizing_region_guid

  msg_sizing_region__deleted = "The sizing region for this Edited Superitem was removed somehow! "
  msg_title_sizing_region__deleted = "Missing sizing region"

  if no_time_selection_exists then
    reaper.ShowMessageBox(msg_sizing_region__deleted .. _brand.name .. " will now create a new sizing region at the bounds of the restored items.", msg_title_sizing_region__deleted, _api.msg.type.ok)
    _module_common.createSizingRegionFromRestoredItems(selected_items, pool_id)

    return false

  else
    user_response_reinstate_sizing_region = reaper.ShowMessageBox(msg_sizing_region__deleted .. " Select Yes to reglue to time selection, or No to create a new sizing region at the bounds of the restored items.", msg_title_sizing_region__deleted, _api.msg.type.yes_no)

    if user_response_reinstate_sizing_region == _api.msg.response.yes then
      sizing_region_guid = _module_common.createSizingRegionFromTimeSelection(pool_id, time_selection_start, time_selection_end)

      return sizing_region_guid

    elseif user_response_reinstate_sizing_region == _api.msg.response.no then
      _module_common.createSizingRegionFromRestoredItems(selected_items, pool_id)

      return false
    end
  end
end


function _module_common.handleNoSizer_TimeSelectionBoundsOptionEnabled(no_time_selection_exists, selected_items, pool_id, time_selection_start, time_selection_end)
  local user_response_create_time_selection, sizing_region_guid

  if no_time_selection_exists then
    user_response_create_time_selection = reaper.ShowMessageBox("There's no time selection to set Superitem bounds to. Select Yes to set time selection to the bounds of the restored items, or No to abort Reglue.", "No time selection", _api.msg.type.yes_no)

    if user_response_create_time_selection == _api.msg.response.yes then
      _module_common.createTimeSelectionFromRestoredItems(selected_items)
      _module_common.createSizingRegionFromRestoredItems(selected_items, pool_id)

      return false

    else

      return false
    end

  else
    sizing_region_guid = _module_common.createSizingRegionFromTimeSelection(pool_id, time_selection_start, time_selection_end)

    return sizing_region_guid
  end
end


function _module_common.createSizingRegionFromRestoredItems(selected_items, pool_id)
  local sizing_region_params = _module_common.getBoundsFromItems(selected_items)

  _module_common.getSetSizingRegion(pool_id, sizing_region_params)
end


function _module_common.createTimeSelectionFromRestoredItems(selected_items)
  local sizing_region_params = _module_common.getBoundsFromItems(selected_items)

  reaper.GetSet_LoopTimeRange(true, false, sizing_region_params.position, sizing_region_params.end_point, false)
end


function _module_common.createSizingRegionFromTimeSelection(pool_id, time_selection_start, time_selection_end)
  local sizing_region_params, sizing_region_guid

  sizing_region_params = {
    position = time_selection_start,
    end_point = time_selection_end
  }
  sizing_region_params.length = time_selection_end - time_selection_start
  sizing_region_guid = _module_common.getSetSizingRegion(pool_id, sizing_region_params)

  return sizing_region_guid
end


function _module_common.getSetWipeItemAudioSrc(item, src_or_wipe)
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
    src = _module_common.getSetWipeItemAudioSrc(item)

    os.remove(src)
    os.remove(src .. _file.name.peak_data_extension)
  end
end


function _module_data.restoreSuperitemState(superitem, superitem_params)
  local superitem_preglue_state_key_label, retval, superitem_last_glue_state, superitem_active_take

  superitem_preglue_state_key_label = _constant.data.key.prefix.pool .. superitem_params.pool_id .. _constant.data.key.suffix.preglue.superitem_state
  retval, superitem_last_glue_state = _module_data.storeRetrieveProjectData(superitem_preglue_state_key_label)
  superitem_active_take = reaper.GetActiveTake(superitem)

  if retval == true and superitem_last_glue_state then
    _module_data.getSetItemStateChunk(superitem, superitem_last_glue_state)
    _module_common.getSetWipeItemAudioSrc(superitem, superitem_params.updated_src)
    _module_data.getSetItemParams(superitem, superitem_params)
    reaper.SetMediaItemTakeInfo_Value(superitem_active_take, _api.take.key.src_offset, superitem_params.source_offset)
  end

  return superitem
end


function _module_glue.setRegluePositionDeltas()
  _state.superitem.params.fresh_glue.edited_pool, _state.superitem.params.preedit.edited_pool, _state.superitem.params.last_glue.edited_pool = _module_util.numberizeAndRoundElements(
    {_state.superitem.params.fresh_glue.edited_pool, _state.superitem.params.preedit.edited_pool, _state.superitem.params.last_glue.edited_pool},
    {"position", "source_offset"}
  )
  _state.superitem.delta.position_during_glue = _state.superitem.params.fresh_glue.edited_pool.position - _state.superitem.params.preedit.edited_pool.position
  _state.superitem.delta.position_during_glue = _module_common.round(_state.superitem.delta.position_during_glue, _api.time_value_decimal_resolution)
  _state.superitem.reglue_position_change_affect_on_length = _state.superitem.params.fresh_glue.edited_pool.length - _state.superitem.params.preedit.edited_pool.length
  _state.superitem.delta.offset_since_last_glue = _state.superitem.params.fresh_glue.edited_pool.source_offset - _state.superitem.params.last_glue.edited_pool.source_offset
  _state.superitem.delta.offset_since_last_glue = _module_common.round(_state.superitem.delta.offset_since_last_glue, _api.time_value_decimal_resolution)

  if _state.superitem.delta.position_during_glue ~= 0 then
    _state.superitem.position_changed_since_last_glue = true
  end

  if _state.superitem.delta.offset_since_last_glue ~= 0 then
    _state.superitem.offset_changed_since_last_glue = true
  end
end


function _module_glue.adjustPostGlueTakeMarkersAndEnvelopes(instance, adjustment_near_project_start, fresh_glue_source_offset, this_is_edited_superitem)
  local instance_position, instance_active_take, instance_current_src_offset, instance_playrate, envelope_point_position_adjustment_delta, take_marker_position_adjustment_delta

  instance_position, instance_active_take, instance_current_src_offset, instance_playrate, fresh_glue_source_offset = _module_glue.getParamsForTakeMarkersAndEnvelopes(instance, instance_active_take, fresh_glue_source_offset)
  envelope_point_position_adjustment_delta, take_marker_position_adjustment_delta = _module_glue.getDeltasForTakeMarkersAndEnvelopes(adjustment_near_project_start, instance_position, instance_current_src_offset, instance_playrate, this_is_edited_superitem)

  _module_glue.adjustTakeEnvelopes(instance_active_take, envelope_point_position_adjustment_delta)
  _module_glue.adjustTakeMarkers(instance_active_take, take_marker_position_adjustment_delta, fresh_glue_source_offset)
  _module_glue.handleTakeStretchMarkers(instance_active_take, take_marker_position_adjustment_delta, fresh_glue_source_offset)
end


function _module_glue.getParamsForTakeMarkersAndEnvelopes(instance, instance_active_take, fresh_glue_source_offset)
  local instance_position, instance_active_take, instance_current_src_offset, instance_playrate

  instance_position = reaper.GetMediaItemInfo_Value(instance, _api.item.key.position)
  instance_active_take = reaper.GetActiveTake(instance)
  instance_current_src_offset = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _api.take.key.src_offset)
  instance_playrate = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _api.take.key.playrate)

  if not fresh_glue_source_offset then
    fresh_glue_source_offset = 0
  end

  return instance_position, instance_active_take, instance_current_src_offset, instance_playrate, fresh_glue_source_offset
end


function _module_glue.getDeltasForTakeMarkersAndEnvelopes(adjustment_near_project_start, instance_position, instance_current_src_offset, instance_playrate, this_is_edited_superitem)
  local envelope_point_position_adjustment_delta, take_marker_position_adjustment_delta

  if this_is_edited_superitem or _state.propagation.user_wants_option.position then
    envelope_point_position_adjustment_delta = -_state.superitem.delta.offset_since_last_glue
    take_marker_position_adjustment_delta = -_state.superitem.delta.offset_since_last_glue

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


function _module_glue.adjustTakeEnvelopes(instance_active_take, position_adjustment_delta)
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


function _module_glue.adjustTakeMarkers(instance_active_take, position_adjustment_delta, fresh_glue_source_offset)
  local take_markers_count, all_take_markers, this_marker_position, this_marker_name, retval, adjusted_marker_position

  take_markers_count = reaper.GetNumTakeMarkers(instance_active_take)

  if take_markers_count > 0 then
    all_take_markers = {}

    for i = 0, take_markers_count-1 do
      this_marker_position, this_marker_name = reaper.GetTakeMarker(instance_active_take, i)

      table.insert(all_take_markers, {
        position = this_marker_position,
        name = this_marker_name
      })
    end

    repeat
      retval = reaper.DeleteTakeMarker(instance_active_take, 0)

    until retval == false

    for i = 1, #all_take_markers do
      adjusted_marker_position = all_take_markers[i].position + position_adjustment_delta + fresh_glue_source_offset

      reaper.SetTakeMarker(instance_active_take, _api.take.new_take_marker_idx, all_take_markers[i].name, adjusted_marker_position)
    end
  end
end


function _module_glue.handleTakeStretchMarkers(instance_active_take, position_adjustment_delta, fresh_glue_source_offset)
  local stretch_markers_count, marker_position_adjustment, marker_source_position_adjustment

  stretch_markers_count = reaper.GetTakeNumStretchMarkers(instance_active_take)

  if stretch_markers_count > 0 then
    _state.propagation.user_wants_option.source_position = _module_common.getUserPropagationChoice("source_position", _constant.data.key.options.defaults.maintain_source_position)

    if _state.propagation.user_wants_option.source_position then
      marker_position_adjustment = position_adjustment_delta
      marker_source_position_adjustment = position_adjustment_delta + fresh_glue_source_offset

    else
      marker_position_adjustment = 0
      marker_source_position_adjustment = 0
    end

    _module_glue.adjustTakeStretchMarkers(instance_active_take, stretch_markers_count, marker_position_adjustment, marker_source_position_adjustment)
  end
end


function _module_glue.adjustTakeStretchMarkers(instance_active_take, stretch_markers_count, marker_position_adjustment, marker_source_position_adjustment)
  local all_stretch_markers, this_marker_position, this_marker_source_position, adjusted_marker_position, adjusted_marker_source_position

  all_stretch_markers = {}

  for i = 0, stretch_markers_count-1 do
    retval, this_marker_position, this_marker_source_position = reaper.GetTakeStretchMarker(instance_active_take, i)

    table.insert(all_stretch_markers, {
      position = this_marker_position,
      source_position = this_marker_source_position
    })
  end

  reaper.DeleteTakeStretchMarkers(instance_active_take, 0, stretch_markers_count)

  for i = 1, #all_stretch_markers do
    adjusted_marker_position = all_stretch_markers[i].position + marker_position_adjustment
    adjusted_marker_source_position = all_stretch_markers[i].source_position + marker_source_position_adjustment

    reaper.SetTakeStretchMarker(instance_active_take, _api.take.new_take_marker_idx, adjusted_marker_position, adjusted_marker_source_position)
  end
end


function _module_glue.reglueAncestors(pool_id, superitem, descendant_nesting_depth_of_active_parent)
  local parent_pool_ids_data_key_label, retval, parent_pool_ids, parent_pool_ids_data_found_for_active_pool, this_parent_pool_id, parent_pool_is_present_in_overglue_pools

  parent_pool_ids_data_key_label = _constant.data.key.prefix.pool .. pool_id .. _constant.data.key.suffix.pool.parent_ids_data
  retval, parent_pool_ids = _module_data.storeRetrieveProjectData(parent_pool_ids_data_key_label)
  parent_pool_ids_data_found_for_active_pool = retval == true

  if not descendant_nesting_depth_of_active_parent then
    descendant_nesting_depth_of_active_parent = 1
  end

  if parent_pool_ids_data_found_for_active_pool then
    retval, parent_pool_ids = serpent.load(parent_pool_ids)

    if #parent_pool_ids > 0 then
      _state.user.time_selection_before_action.position, _state.user.time_selection_before_action.end_point = reaper.GetSet_LoopTimeRange(false, false, nil, nil, false)

      for i = 1, #parent_pool_ids do
        this_parent_pool_id = parent_pool_ids[i]
        parent_pool_is_present_in_overglue_pools = _module_util.isPresentInArray(this_parent_pool_id, _state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor)

        if not parent_pool_is_present_in_overglue_pools then

          if _state.superitem.params.ancestor_pools[this_parent_pool_id] then
            _module_glue.assignParentNestingDepth(this_parent_pool_id, descendant_nesting_depth_of_active_parent)

          else
            _module_glue.traverseAncestorsUsingTempTracks(this_parent_pool_id, superitem, descendant_nesting_depth_of_active_parent)
          end
        end
      end

      reaper.GetSet_LoopTimeRange(true, false, _state.user.time_selection_before_action.position, _state.user.time_selection_before_action.end_point, false)
    end
  end
end


function _module_glue.assignParentNestingDepth(this_parent_pool_id, descendant_nesting_depth_of_active_parent)
  _state.superitem.params.ancestor_pools[this_parent_pool_id].children_nesting_depth = math.max(descendant_nesting_depth_of_active_parent, _state.superitem.params.ancestor_pools[this_parent_pool_id].children_nesting_depth)
end


function _module_glue.traverseAncestorsUsingTempTracks(this_parent_pool_id, superitem, descendant_nesting_depth_of_active_parent)
  local this_parent_is_ancestor_in_project, this_parent_instance_params, this_parent_instance_is_item_in_project

  this_parent_instance_params = _module_glue.getFirstPoolInstanceParams(this_parent_pool_id)
  this_parent_instance_is_item_in_project = this_parent_instance_params

  if not this_parent_instance_is_item_in_project then
    this_parent_is_ancestor_in_project = _module_glue.checkParentPoolIsAncestorInProject(this_parent_pool_id)

    if this_parent_is_ancestor_in_project then
      this_parent_instance_params = {}
    end
  end

  if this_parent_instance_is_item_in_project or this_parent_is_ancestor_in_project then
    _module_glue.setUpAncestorReglues(this_parent_instance_params, this_parent_pool_id, descendant_nesting_depth_of_active_parent, superitem)
  end
end


function _module_glue.getFirstPoolInstanceParams(pool_id)
  local all_items_count, this_item, this_item_instance_pool_id, parent_instance_params

  all_items_count = reaper.CountMediaItems(_api.current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api.current_project, i)
    this_item_instance_pool_id = _module_data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.instance_id)
    this_item_instance_pool_id = tonumber(this_item_instance_pool_id)

    if this_item_instance_pool_id == pool_id then
      parent_instance_params = _module_data.getSetItemParams(this_item)

      return parent_instance_params
    end
  end

  return false
end


function _module_glue.checkParentPoolIsAncestorInProject(this_parent_pool_id)
  local all_pool_ids_in_project, this_pool, this_pool_descendant_pool_ids, retval

  all_pool_ids_in_project = _module_glue.getAllPoolIdsInProject()

  for i = 1, #all_pool_ids_in_project do
    this_pool = all_pool_ids_in_project[i]

    if this_pool == this_parent_pool_id then

      return true
    end

    this_pool_descendant_pool_ids = _module_data.storeRetrievePoolData(this_pool, _constant.data.key.suffix.pool.descendant_ids)
    retval, this_pool_descendant_pool_ids = serpent.load(this_pool_descendant_pool_ids)

    if this_pool_descendant_pool_ids then

      for j = 1, #this_pool_descendant_pool_ids do
        this_pool_descendant_pool_id = tonumber(this_pool_descendant_pool_ids[j])

        if this_pool_descendant_pool_id == this_parent_pool_id then

          return true
        end
      end
    end
  end

  _module_glue.deletePoolDescendantsData(this_parent_pool_id)

  return false
end


function _module_glue.getAllPoolIdsInProject()
  local all_items_count, all_pool_ids_in_project, this_item, this_item_instance_pool_id

  all_items_count = reaper.CountMediaItems(_api.current_project)
  all_pool_ids_in_project = {}

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api.current_project, i)
    this_item_instance_pool_id = _module_data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.instance_id)

    if this_item_instance_pool_id and this_item_instance_pool_id ~= "" then
      table.insert(all_pool_ids_in_project, this_item_instance_pool_id)
    end
  end

  return _module_util.deduplicateTable(all_pool_ids_in_project)
end


function _module_glue.deletePoolDescendantsData(pool_id)
  _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.descendant_ids, "")
end


function _module_glue.setUpAncestorReglues(parent_instance_params, parent_pool_id, descendant_nesting_depth_of_active_parent, superitem)
  local parent_edit_temp_track__name, parent_edit_temp_track, restored_items, next_nesting_depth

  parent_instance_params.pool_id = parent_pool_id
  parent_instance_params.children_nesting_depth = descendant_nesting_depth_of_active_parent
  parent_edit_temp_track__name = "Pool #" .. parent_pool_id .. " temp edit"

  reaper.InsertTrackAtIndex(_api.track.very_1st_track_of_project, _api.track.no_defaults)

  parent_edit_temp_track = reaper.GetTrack(_api.current_project, 0)

  reaper.GetSetMediaTrackInfo_String(parent_edit_temp_track, _api.track.key.name, parent_edit_temp_track__name, _api.set_value)
  reaper.Main_OnCommand(_cmd.deselect_all_items, _api.cmd_flag)

  restored_items = _module_common.restoreStoredItems(parent_pool_id, parent_edit_temp_track, superitem, true, nil)
  parent_instance_params.track = parent_edit_temp_track
  parent_instance_params.restored_items = restored_items
  _state.superitem.params.ancestor_pools[parent_pool_id] = parent_instance_params
  next_nesting_depth = descendant_nesting_depth_of_active_parent + 1

  _module_glue.reglueAncestors(parent_pool_id, superitem, next_nesting_depth)
end


function _module_common.restoreStoredItems(pool_id, active_track, superitem, this_is_ancestor_superitem_update, action, superitemLane)
  local stored_item_states_table, restored_items, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled

  if _constant.support.fixed_lanes then
    _module_lanes.debugLaneInfo("RESTORE START", nil, active_track, pool_id)

    -- Make sure track is in fixed lanes mode for consistent lane calculations
    local currentMode = reaper.GetMediaTrackInfo_Value(active_track, "I_FOLDERCOMPACT")
    if currentMode ~= 2 then
      reaper.SetMediaTrackInfo_Value(active_track, "I_FOLDERCOMPACT", 2)
      reaper.UpdateArrange()
    end
  end

  stored_item_states_table = _module_data.getStoredItemStatesTable(pool_id, action)
  restored_items = {}

  _module_data.defineStoredItemsParams(pool_id)

  -- Create all items first without lane positioning
  for item_guid, stored_item_state in pairs(stored_item_states_table) do
    if stored_item_state then
      _unglued_pool_preunglue_params = _module_data.getSetItemParams(superitem)
      local restored_item = _module_common.handleRestoredItem(superitem, active_track, stored_item_state, {}, this_is_ancestor_superitem_update, action)
      table.insert(restored_items, restored_item)
    end
  end

  -- CRITICAL: Apply lane positioning only AFTER all items are created and ONLY ONCE
  if _constant.support.fixed_lanes and #restored_items > 0 then
    if _test_logging_enabled then
      _module_dev.log("Calling restoreItemLaneOffsets for " .. #restored_items .. " items")
    end

    _module_lanes.restoreItemLaneOffsets(restored_items, false, pool_id)
    _module_lanes.debugLaneInfo("AFTER RESTORE", restored_items, active_track, pool_id)
  end

  return restored_items, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled
end


function _module_data.getStoredItemStatesTable(pool_id, action)
  local this_is_unglue, this_is_depool, retval, stored_item_states_table, stored_item_states

  this_is_unglue = action == "Unglue"
  this_is_depool = action == "DePool"

  if (this_is_unglue or this_is_depool) and _state.restored_items.preglue_restored_item_states then
    retval, stored_item_states_table = serpent.load(_state.restored_items.preglue_restored_item_states)

  else
    stored_item_states = _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.contained_item_states)
    stored_item_states_table = _module_data.retrieveStoredItemStates(stored_item_states)
  end

  return stored_item_states_table
end


function _module_data.retrieveStoredItemStates(item_state_chunks_string)
  local retval, item_state_chunks_table

  retval, item_state_chunks_table = serpent.load(item_state_chunks_string)
  item_state_chunks_table.track = reaper.BR_GetMediaTrackByGUID(_api.current_project, item_state_chunks_table.track_guid)

  return item_state_chunks_table
end


function _module_data.defineStoredItemsParams(pool_id)
  _state.restored_items.first_restored_item_last_glue_delta_to_parent = _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.superitem.first_child_delta_to_superitem_position)
  _state.superitem.this_previously_depooled_superitem_has_not_been_edited = _module_data.storeRetrievePoolData(pool_id, _constant.actionstep.freshly_depooled_superitem_flag)
  _state.superitem.params.post_glue.edited_pool = _module_data.storeRetrieveSuperitemParams(pool_id, _constant.actionstep.postglue)

  if not _state.superitem.params.preedit.edited_pool then
    _state.superitem.params.preedit.edited_pool = _module_data.storeRetrieveSuperitemParams(pool_id, _constant.actionstep.preedit)
  end

  if not _state.restored_items.first_restored_item_last_glue_delta_to_parent or _state.restored_items.first_restored_item_last_glue_delta_to_parent == "" then
    _state.restored_items.first_restored_item_last_glue_delta_to_parent = 0
  end
end


function _module_common.handleRestoredItem(superitem, active_track, stored_item_state, restored_instances_near_project_start, this_is_ancestor_superitem_update, action)
  local restored_item, restored_instance_pool_id, restored_item_negative_position_delta, this_is_first_edit_after_auto_depool, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled

  restored_item = _module_common.restoreItem(active_track, stored_item_state, this_is_ancestor_superitem_update)
  restored_instance_pool_id = _module_data.storeRetrieveItemData(restored_item, _constant.data.key.suffix.pool.instance_id)

  _module_common.handleOfflineTake(restored_item, "restored")
  reaper.SetMediaItemSelected(restored_item, true)
  _module_common.handleRestoredItemImage(restored_item, restored_instance_pool_id, action)

  if not this_is_ancestor_superitem_update then
    restored_item, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled = _module_common.adjustRestoredItem(superitem, restored_item, action)
  end

  if action == "Unglue" or action == "DePool" then
    _module_data.storeRetrieveItemData(restored_item, _constant.data.key.suffix.pool.parent_id, "")
  end

  return restored_item, restored_instances_near_project_start, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled
end


function _module_common.handleRestoredItemImage(restored_item, restored_instance_pool_id, action)
  local this_restored_item_is_instance, image_type

  this_restored_item_is_instance = restored_instance_pool_id and restored_instance_pool_id ~= ""

  if action == "Unglue" then
    image_type = this_restored_item_is_instance and "superitem" or false

    -- if this_restored_item_is_instance then
    --   _module_common.addRemoveItemImage(restored_item, "superitem")

    -- else
    --   _module_common.addRemoveItemImage(restored_item, false)
    -- end

  else
    image_type = this_restored_item_is_instance and "restored_instance" or "restored"

  --   if this_restored_item_is_instance then
  --     _module_common.addRemoveItemImage(restored_item, "restored_instance")

  --   else
  --     _module_common.addRemoveItemImage(restored_item, "restored")
  --   end
  end

  _module_common.addRemoveItemImage(restored_item, image_type)
end


function _module_common.restoreItem(track, state, this_is_ancestor_superitem_update)
  local restored_item = reaper.AddMediaItemToTrack(track)

  if state then
    _module_data.getSetItemStateChunk(restored_item, state)
  end

  if not this_is_ancestor_superitem_update then
    _module_common.restoreOriginalMidiTake(restored_item)
  end

  return restored_item
end


function _module_common.restoreOriginalMidiTake(item)
  local item_takes_count, preglue_active_midi_take_guid, preglue_active_midi_take, rendered_audio_take, rendered_audio_take_num, global_option_toggle_retain_only_last_glue_source_enabled

  item_takes_count = reaper.GetMediaItemNumTakes(item)

  if item_takes_count > 0 then
    preglue_active_midi_take_guid = _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.preglue.active_take_guid)
    preglue_active_midi_take = reaper.SNM_GetMediaItemTakeByGUID(_api.current_project, preglue_active_midi_take_guid)

    if preglue_active_midi_take then
      rendered_audio_take = reaper.GetActiveTake(item)
      rendered_audio_take_num = reaper.GetMediaItemTakeInfo_Value(rendered_audio_take, "IP_TAKENUMBER")
      global_option_toggle_retain_only_last_glue_source_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.retain_only_last_glue_source)

      if global_option_toggle_retain_only_last_glue_source_enabled == "true" then
        _module_common.getSetWipeItemAudioSrc(item, "wipe")
      end

      reaper.NF_DeleteTakeFromItem(item, rendered_audio_take_num)
      reaper.SetActiveTake(preglue_active_midi_take)
      _module_glue.cleanNullTakes(item)
    end
  end
end


function _module_common.adjustRestoredItem(superitem, restored_item, action)
  local restored_item_params, adjusted_restored_item_position_is_before_project_start, restored_item_negative_position

  restored_item_params = _module_data.getSetItemParams(restored_item)
  restored_item_params.position, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled = _module_common.getRestoredItemPositionDeltaSinceLastGlue(superitem, restored_item, restored_item_params, action)
  adjusted_restored_item_position_is_before_project_start = restored_item_params.position < 0

  reaper.SetMediaItemPosition(restored_item, restored_item_params.position, _api.dont_refresh_ui)

  return restored_item, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled
end


function _module_common.getRestoredItemPositionDeltaSinceLastGlue(superitem, restored_item, restored_item_params, action)
  local this_item_position_delta_to_last_glue_superitem_instance, superitem_loop_is_enabled, superitem_active_take, superitem_source, superitem_source_length, superitem_loop_starts_in_later_half, restored_item_altered_position

  looped_source_sets_sizing_region__enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.loop_source_sets_sizing_region_bounds_on_reglue)
  superitem_loop_is_enabled = reaper.GetMediaItemInfo_Value(superitem, _api.item.key.loop_src) == _api.timeline.loop_enabled
  superitem_active_take = reaper.GetActiveTake(superitem)
  superitem_source = reaper.GetMediaItemTake_Source(superitem_active_take)
  superitem_source_length = reaper.GetMediaSourceLength(superitem_source)

  if action == "Edit" or action == "Unglue" or action == "Smart Glue/Edit" or action == "Smart Glue/Unglue" then
    superitem_loop_starts_in_later_half = _unglued_pool_preunglue_params.source_offset > (superitem_source_length / 2)
    this_item_position_delta_to_last_glue_superitem_instance = _unglued_pool_preunglue_params.position - _state.superitem.params.post_glue.edited_pool.position - _unglued_pool_preunglue_params.source_offset

    if _state.superitem.this_previously_depooled_superitem_has_not_been_edited ~= "true" then
      this_item_position_delta_to_last_glue_superitem_instance = this_item_position_delta_to_last_glue_superitem_instance + _state.superitem.params.post_glue.edited_pool.source_offset
    end

    if looped_source_sets_sizing_region__enabled == "true" and superitem_loop_is_enabled and superitem_loop_starts_in_later_half then
      this_item_position_delta_to_last_glue_superitem_instance = this_item_position_delta_to_last_glue_superitem_instance + superitem_source_length
    end

  elseif action == "DePool" then
    this_item_position_delta_to_last_glue_superitem_instance = _unglued_pool_preunglue_params.position - _state.superitem.params.post_glue.edited_pool.position + _state.superitem.params.post_glue.edited_pool.source_offset
  end

  restored_item_altered_position = restored_item_params.position + this_item_position_delta_to_last_glue_superitem_instance

  return restored_item_altered_position, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled
end


function _module_glue.propagateChangesToSuperitems(active_superitem, sizing_region_guid)
  local this_is_ancestor_superitem_update, ancestor_pools_near_project_start, ancestor_pools_params_sorted_by_ascending_nesting_depth, this_ancestor_pool_id, ancestor_pool_is_present_in_overglue_pools

  this_is_ancestor_superitem_update = false
  ancestor_pools_near_project_start = _module_glue.handleSuperitemsChangedByReglue(active_superitem, this_is_ancestor_superitem_update)
  ancestor_pools_params_sorted_by_ascending_nesting_depth = _module_glue.sortAncestorUpdatesByNestingDepth()

  for i = 1, #ancestor_pools_params_sorted_by_ascending_nesting_depth do
    _state.superitem.params.fresh_glue.current_pool = ancestor_pools_params_sorted_by_ascending_nesting_depth[i]
    this_ancestor_pool_id = tostring(_state.superitem.params.fresh_glue.current_pool.pool_id)
    _state.restored_items.delta.position_delta_near_project_start = ancestor_pools_near_project_start[this_ancestor_pool_id]
    _state.superitem.params.preedit.current_pool = _module_data.storeRetrieveSuperitemParams(this_ancestor_pool_id, _constant.actionstep.preedit)
    ancestor_pool_is_present_in_overglue_pools = _module_util.isPresentInArray(this_ancestor_pool_id, _state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor)

    if _state.restored_items.delta.position_delta_near_project_start then
      _module_glue.adjustParentPoolChildrenNearProjectStart(this_ancestor_pool_id, _state.superitem.params.fresh_glue.edited_pool.pool_id)

    else
      _state.restored_items.delta.position_delta_near_project_start = 0
    end

    if not ancestor_pool_is_present_in_overglue_pools then
      _module_glue.reglueAncestor(sizing_region_guid)
    end
  end
end


function _module_glue.handleSuperitemsChangedByReglue(active_superitem, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  local all_items_count, ancestor_pools_near_project_start, this_item, this_active_pool_instance, global_option_toggle_depool_all_siblings_on_reglue

  all_items_count = reaper.CountMediaItems(_api.current_project)
  ancestor_pools_near_project_start = {}

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api.current_project, i)
    this_active_pool_instance = _module_glue.getSuperitemChangedByReglue(this_item, active_superitem, this_is_ancestor_superitem_update)

    if this_active_pool_instance then
      global_option_toggle_depool_all_siblings_on_reglue = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.depool_all_siblings_on_reglue)

      if global_option_toggle_depool_all_siblings_on_reglue == "true" and not this_is_ancestor_superitem_update then
        global_option_toggle_depool_all_siblings_on_reglue = _module_depool.handleDePoolSibling(this_active_pool_instance)

      elseif global_option_toggle_depool_all_siblings_on_reglue == "false" then
        ancestor_pools_near_project_start = _module_glue.updateSuperitemChangedByReglue(this_active_pool_instance, this_item, ancestor_pools_near_project_start, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
      end
    end
  end

  return ancestor_pools_near_project_start
end


function _module_glue.getSuperitemChangedByReglue(item, active_superitem, this_is_ancestor_superitem_update)
  local item_instance_pool_id, item_is_instance, fresh_glue_params, item_is_active_pool_instance, instance_current_src, this_instance_needs_update

  item_instance_pool_id = _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.pool.instance_id)
  item_is_instance = item_instance_pool_id and item_instance_pool_id ~= ""
  fresh_glue_params = this_is_ancestor_superitem_update and _state.superitem.params.fresh_glue.current_pool or _state.superitem.params.fresh_glue.edited_pool

  -- if this_is_ancestor_superitem_update then
  --   fresh_glue_params = _state.superitem.params.fresh_glue.current_pool

  -- else
  --   fresh_glue_params = _state.superitem.params.fresh_glue.edited_pool
  -- end

  if item_is_instance then

    if not fresh_glue_params.instance_pool_id or fresh_glue_params.instance_pool_id == "" then
      fresh_glue_params.instance_pool_id = fresh_glue_params.pool_id
      fresh_glue_params.instance_pool_id = tostring(fresh_glue_params.instance_pool_id)
    end

    item_is_active_pool_instance = item_instance_pool_id == fresh_glue_params.instance_pool_id

    if item_is_active_pool_instance then
      instance_current_src = _module_common.getSetWipeItemAudioSrc(item)
      this_instance_needs_update = instance_current_src ~= fresh_glue_params.updated_src and item ~= active_superitem

      if this_instance_needs_update then

        return item
      end
    end
  end
end


function _module_depool.handleDePoolSibling(active_pool_sibling)
  local global_option_toggle_depool_all_siblings_on_reglue_warning, global_option_toggle_depool_all_siblings_on_reglue

  global_option_toggle_depool_all_siblings_on_reglue_warning = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.depool_all_siblings_on_reglue_warning)

  if global_option_toggle_depool_all_siblings_on_reglue_warning == "true" and _state.user.wants_to_depool_all_siblings == nil then
    _state.user.wants_to_depool_all_siblings = reaper.ShowMessageBox("You have the option to remove all sibling instances from pool enabled. Select yes to continue and remove all of this item's siblings from its pool, or no to disable this option.", "Warning: Remove all siblings?", _api.msg.type.yes_no)

    if _state.user.wants_to_depool_all_siblings == _api.msg.response.no then
      reaper.SetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.depool_all_siblings_on_reglue, "false", _api.extstate.persist_enabled)

      return "false"

    elseif _state.user.wants_to_depool_all_siblings == _api.msg.response.yes then
      reaper.SetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.depool_all_siblings_on_reglue_warning, "false", _api.extstate.persist_enabled)
    end
  end

  _module_depool.processSiblingDePool(active_pool_sibling)

  return global_option_toggle_depool_all_siblings_on_reglue
end


function _module_glue.updateSuperitemChangedByReglue(active_pool_instance, item, ancestor_pools_near_project_start, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  local siblings_are_being_updated, current_pool_updated_src, attempted_negative_instance_position, instance_parent_pool_id, parent_active_take, parent_playrate, parent_current_src_offset, parent_adjusted_src_offset

  siblings_are_being_updated = not this_is_ancestor_superitem_update

  if this_is_ancestor_superitem_update then
    current_pool_updated_src = _state.superitem.params.fresh_glue.current_pool.updated_src

  elseif siblings_are_being_updated then
    current_pool_updated_src = _state.superitem.params.fresh_glue.edited_pool.updated_src
  end

  _module_common.getSetWipeItemAudioSrc(active_pool_instance, current_pool_updated_src)

  attempted_negative_instance_position = _module_glue.adjustSuperitemChangedByReglue(active_pool_instance, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)

  if attempted_negative_instance_position ~= 0 then
    instance_parent_pool_id = _module_data.storeRetrieveItemData(item, _constant.data.key.suffix.pool.parent_id)
    ancestor_pools_near_project_start[instance_parent_pool_id] = attempted_negative_instance_position
  end

  return ancestor_pools_near_project_start
end


function _module_glue.adjustSuperitemChangedByReglue(instance, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  local this_is_sibling_instance_update, this_instance_parent_pool_id, this_instance_is_child, instance_active_take, instance_current_src_offset, instance_playrate, instance_would_get_adjusted_before_project_start

  this_is_sibling_instance_update = not this_is_ancestor_superitem_update
  this_instance_parent_pool_id = _module_data.storeRetrieveItemData(instance, _constant.data.key.suffix.pool.parent_id)
  this_instance_is_child = this_instance_parent_pool_id and this_instance_parent_pool_id ~= ""
  instance_active_take = reaper.GetActiveTake(instance)
  instance_current_src_offset = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _api.take.key.src_offset, "", false)
  instance_playrate = reaper.GetMediaItemTakeInfo_Value(instance_active_take, _api.take.key.playrate)

  _module_glue.getSuperitemPropagationOptionChoices()

  if this_is_sibling_instance_update then
    instance_would_get_adjusted_before_project_start = _module_glue.adjustSuperitemPosition(instance, instance_active_take, instance_current_src_offset, instance_playrate)
    _module_glue.adjustSuperitemLength(instance, instance_playrate, this_instance_is_child)

    -- Propagate lane position to siblings
    if _constant.support.fixed_lanes and _state.propagation.user_wants_option.lane then
      local editedSuperitem = reaper.BR_GetMediaItemByGUID(_api.current_project, _state.superitem.params.fresh_glue.edited_pool.item_guid)
      if editedSuperitem then
        local editedSuperitemLane = reaper.GetMediaItemInfo_Value(editedSuperitem, "I_FIXEDLANE")
        local instanceLane = reaper.GetMediaItemInfo_Value(instance, "I_FIXEDLANE")
        local laneOffset = instanceLane - editedSuperitemLane

        -- Get the edited superitem's new lane
        local freshEditedSuperitemLane = reaper.GetMediaItemInfo_Value(_state.superitem.params.fresh_glue.edited_pool.superitem, "I_FIXEDLANE")
        local targetLane = freshEditedSuperitemLane + laneOffset

        -- Apply lane position
        local laneY = _module_lanes.getLaneYPosition(targetLane)
        reaper.SetMediaItemInfo_Value(instance, "F_FREEMODE_Y", laneY)
      end
    end
  end

  if (this_is_sibling_instance_update or this_is_direct_parent_instance_update) and
    _state.propagation.user_wants_option.source_position and
    not instance_would_get_adjusted_before_project_start then

    _module_glue.adjustSuperitemSourceOffset(instance, instance_active_take, instance_current_src_offset, this_is_direct_parent_instance_update, this_is_sibling_instance_update)
  end
end


function _module_glue.getSuperitemPropagationOptionChoices()
  _state.propagation.user_wants_option.playrate_toggle = _module_common.getUserPropagationChoice("playrate_toggle", _constant.data.key.options.defaults.playrate_affects_propagation)

  if _state.superitem.position_changed_since_last_glue then
    _state.propagation.user_wants_option.position = _module_common.getUserPropagationChoice("position", _constant.data.key.options.defaults.propagate_position)

    -- Lane propagation follows position propagation behavior
    if _constant.support.fixed_lanes then
      _state.propagation.user_wants_option.lane = _state.propagation.user_wants_option.position
    end
  end

  if _state.superitem.offset_changed_since_last_glue then
    _state.propagation.user_wants_option.source_position = _module_common.getUserPropagationChoice("source_position", _constant.data.key.options.defaults.maintain_source_position)
  end
end


function _module_common.getUserPropagationChoice(propagation_option, ext_state_key)
  local option_value, user_choice

  option_value = reaper.GetExtState(_constant.data.key.options.global_section, ext_state_key)

  if not _state.propagation.user_responses[propagation_option] and option_value == "ask" then
    _state.propagation.user_responses[propagation_option] = _module_common.launchPropagateDialog(propagation_option)
  end

  user_choice = option_value == "always" or _state.propagation.user_responses[propagation_option] == _api.msg.response.yes

  return user_choice
end


function _module_common.launchPropagateDialog(param)
  local propagate_dialog_params, global_option_propagate_default, msg_title, msg_content

  propagate_dialog_params = _module_common.getPropagateDialogValues()
  global_option_propagate_default = reaper.GetExtState(_constant.data.key.options.global_section, propagate_dialog_params[param].global_option_param_key)
  msg_title = _brand.name .. ": " .. propagate_dialog_params[param].message_title_string .. " changed"
  msg_content = "The " .. propagate_dialog_params[param].message_title_string .. " of the Superitem you're regluing has changed! Do you want to adjust pool sibling Superitems' " .. propagate_dialog_params[param].message_content_string

  if global_option_propagate_default == "ask" then

    return reaper.ShowMessageBox(msg_content, msg_title, _api.msg.type.yes_no)

  elseif global_option_propagate_default == "always" then

    return _api.msg.response.yes

  elseif global_option_propagate_default == "no" then

    return _api.msg.response.no
  end
end


function _module_common.getPropagateDialogValues()
  local propagate_dialog_data, propagate_dialog_params

  propagate_dialog_data = {
    {"source_position", _constant.data.key.options.defaults.maintain_source_position, "audio source timeline locations so they remain in the same place?", "source position"},
    {"length", _constant.data.key.options.defaults.propagate_length, "lengths to match?", "length"},
    {"position", _constant.data.key.options.defaults.propagate_position, "left edge to adjust as well?", "left edge position"},
    {"absolute_length_propagation", _constant.data.key.options.defaults.length_propagation_type, "length to match the Edited Superitem? (No = alter sibling length relatively by the length change amount)", "length"},
    {"playrate_toggle", _constant.data.key.options.defaults.playrate_affects_propagation, "position and/or length in proportion to their playrates?", "length and/or position"}
  }
  propagate_dialog_params = {}

  for i = 1, #propagate_dialog_data do
    propagate_dialog_params[propagate_dialog_data[i][1]] = {
      global_option_param_key = propagate_dialog_data[i][2],
      message_content_string = propagate_dialog_data[i][3],
      message_title_string = propagate_dialog_data[i][4]
    }
  end

  return propagate_dialog_params
end


function _module_glue.adjustSuperitemPosition(instance, instance_active_take, instance_current_src_offset, instance_playrate)
  local instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start, take_markers_source_offset

  instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start = _module_glue.getPositionPropagationParams(instance, instance_current_src_offset, instance_playrate)

if _state.propagation.user_wants_option.position then
    take_markers_source_offset = _state.superitem.params.fresh_glue.edited_pool.source_offset - _state.superitem.params.preedit.edited_pool.source_offset

    _module_glue.adjustPostGlueTakeMarkersAndEnvelopes(instance, nil, take_markers_source_offset)
    reaper.SetMediaItemPosition(instance, instance_adjusted_position, _api.dont_refresh_ui)

    if _state.propagation.user_wants_option.source_position == nil then
      _state.propagation.user_wants_option.source_position = _module_common.getUserPropagationChoice("source_position", _constant.data.key.options.defaults.maintain_source_position)
    end

    if _state.propagation.user_wants_option.source_position then
      reaper.SetMediaItemTakeInfo_Value(instance_active_take, _api.take.key.src_offset, instance_current_src_offset)
    end

  else
    _module_glue.adjustPostGlueTakeMarkersAndEnvelopes(instance)
  end

  return instance_would_get_adjusted_before_project_start
end


function _module_glue.getPositionPropagationParams(instance, instance_current_src_offset, instance_playrate)
  local instance_current_position, instance_position_adjustment_delta, instance_adjusted_position, instance_would_get_adjusted_before_project_start

  instance_current_position = reaper.GetMediaItemInfo_Value(instance, _api.item.key.position)
  instance_position_adjustment_delta = _state.superitem.delta.position_during_glue

  if _state.propagation.user_wants_option.playrate_toggle then
    instance_position_adjustment_delta = instance_position_adjustment_delta / instance_playrate
  end

  instance_adjusted_position = instance_current_position + instance_position_adjustment_delta
  instance_would_get_adjusted_before_project_start = instance_adjusted_position < _constant.position_start_of_project

  return instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start
end


function _module_glue.adjustSuperitemSourceOffset(instance, instance_active_take, instance_current_src_offset, this_is_direct_parent_instance_update, this_is_sibling_instance_update)
  local instance_adjusted_src_offset, ancestor_position, ancestor_pool_id, active_child_position_delta_to_parent

  if this_is_direct_parent_instance_update then

    if _state.propagation.user_wants_option.position then

      if instance_current_src_offset >= 0 then
        instance_adjusted_src_offset = _state.superitem.params.fresh_glue.current_pool.source_offset

      else
        instance_adjusted_src_offset = instance_current_src_offset - _state.superitem.delta.offset_since_last_glue
      end

    else
      instance_adjusted_src_offset = instance_current_src_offset
    end

  elseif this_is_sibling_instance_update then
    instance_adjusted_src_offset = _state.superitem.params.fresh_glue.edited_pool.source_offset
  end

  reaper.SetMediaItemTakeInfo_Value(instance_active_take, _api.take.key.src_offset, instance_adjusted_src_offset)

  _active_superitem_source_position_adjustment_delta = _state.superitem.params.fresh_glue.edited_pool.source_offset - _state.superitem.params.preedit.edited_pool.source_offset
end


function _module_glue.adjustSuperitemLength(instance, instance_playrate, this_instance_is_child)
  local instance_current_length, instance_length_adjustment_delta, user_wants_relative_length_propagation, instance_adjusted_length

  instance_current_length = reaper.GetMediaItemInfo_Value(instance, _api.item.key.length)
  _state.propagation.user_wants_option.length = _module_common.getUserPropagationChoice("length", _constant.data.key.options.defaults.propagate_length)

  if _state.propagation.user_wants_option.length then
    _state.propagation.user_wants_option.playrate_toggle = _module_common.getUserPropagationChoice("playrate_toggle", _constant.data.key.options.defaults.playrate_affects_propagation)
    _state.propagation.user_wants_option.absolute_length_propagation = _module_common.getUserPropagationChoice("absolute_length_propagation", _constant.data.key.options.defaults.length_propagation_type)
    user_wants_relative_length_propagation = not _state.propagation.user_wants_option.absolute_length_propagation

    if _state.propagation.user_wants_option.absolute_length_propagation then
      instance_adjusted_length = _state.superitem.params.fresh_glue.edited_pool.length

      if _state.propagation.user_wants_option.playrate_toggle then
        instance_adjusted_length = _state.superitem.params.fresh_glue.edited_pool.length / instance_playrate
      end

    elseif user_wants_relative_length_propagation then
      instance_adjusted_length = instance_current_length + _state.superitem.reglue_position_change_affect_on_length

      if _state.propagation.user_wants_option.playrate_toggle then
        instance_adjusted_length = instance_current_length + (_state.superitem.reglue_position_change_affect_on_length / instance_playrate)
      end
    end

    reaper.SetMediaItemLength(instance, instance_adjusted_length, _api.dont_refresh_ui)
  end
end


function _module_glue.sortAncestorUpdatesByNestingDepth()
  local ancestor_pools_params_sorted_by_ascending_nesting_depth

  ancestor_pools_params_sorted_by_ascending_nesting_depth = {}

  for pool_id, this_parent_instance_params in pairs(_state.superitem.params.ancestor_pools) do
    table.insert(ancestor_pools_params_sorted_by_ascending_nesting_depth, this_parent_instance_params)
  end

  table.sort(ancestor_pools_params_sorted_by_ascending_nesting_depth, function(a, b)

    return a.children_nesting_depth < b.children_nesting_depth end
  )

  return ancestor_pools_params_sorted_by_ascending_nesting_depth
end


function _module_glue.reglueAncestor(sizing_region_guid)
  local this_is_ancestor_superitem_update, selected_items, this_is_direct_parent_instance_update, ancestor_instance, ancestor_active_track

  reaper.Main_OnCommand(_cmd.deselect_all_items, _api.cmd_flag)
  _module_depool.refreshCurrentPoolStoredItemsPostDePool()
  _module_common.selectDeselectItems(_state.superitem.params.fresh_glue.current_pool.restored_items, true)

  this_is_ancestor_superitem_update = true
  selected_items = _module_init.getSelectedItems(#_state.superitem.params.fresh_glue.current_pool.restored_items)
  this_is_direct_parent_instance_update = _module_glue.isThisDirectParentInstanceUpdate(selected_items)
  ancestor_instance = _module_glue.handleGlue(selected_items, _state.superitem.params.fresh_glue.current_pool.pool_id, sizing_region_guid, nil, this_is_ancestor_superitem_update)
  ancestor_active_track = _state.superitem.params.fresh_glue.current_pool.track
  _state.superitem.params.fresh_glue.current_pool = _module_data.getSetItemParams(ancestor_instance)
  _state.superitem.params.fresh_glue.current_pool.updated_src = _module_common.getSetWipeItemAudioSrc(ancestor_instance)

  reaper.Main_OnCommand(_cmd.deselect_all_items, _api.cmd_flag)
  _module_glue.handleSuperitemsChangedByReglue(ancestor_instance, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  reaper.DeleteTrack(ancestor_active_track)
end


function _module_depool.refreshCurrentPoolStoredItemsPostDePool()
  local this_restored_item_exists, all_items_count, this_item, this_item_parent_pool_id, this_item_belongs_to_current_pool

  for i = 1, #_state.superitem.params.fresh_glue.current_pool.restored_items do
    this_restored_item_exists = reaper.ValidatePtr(_state.superitem.params.fresh_glue.current_pool.restored_items[i], _api.datatype.mediaitem)

    if not this_restored_item_exists then
      _state.superitem.params.fresh_glue.current_pool.restored_items = {}
      all_items_count = reaper.CountMediaItems(_api.current_project)

      for j = 0, all_items_count-1 do
        this_item = reaper.GetMediaItem(_api.current_project, j)
        this_item_parent_pool_id = _module_data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)
        this_item_parent_pool_id = tonumber(this_item_parent_pool_id)
        this_item_belongs_to_current_pool = this_item_parent_pool_id == _state.superitem.params.fresh_glue.current_pool.pool_id

        if this_item_belongs_to_current_pool then
          table.insert(_state.superitem.params.fresh_glue.current_pool.restored_items, this_item)
        end
      end

      break
    end
  end
end


function _module_glue.isThisDirectParentInstanceUpdate(selected_items)
  local this_selected_item, this_selected_item_params, this_selected_instance_pool_id, this_is_direct_parent_instance_update

  for i = 1, #selected_items do
    this_selected_item = selected_items[i]
    this_selected_item_params = _module_data.getSetItemParams(this_selected_item)
    this_selected_instance_pool_id = this_selected_item_params.instance_pool_id

    if this_selected_instance_pool_id == _state.superitem.params.fresh_glue.edited_pool.pool_id then
      this_is_direct_parent_instance_update = true

      break
    end
  end

  return this_is_direct_parent_instance_update
end


function _module_single.handleOtherInstanceBeingEdited(instance_being_edited, instance_being_edited_pool_id, action)
  instance_being_edited_pool_id = tostring(instance_being_edited_pool_id)

  reaper.ShowMessageBox(_brand.name .. " can only " .. action .. " one superitem pool instance at a time. Reglue the other open instance from Pool " .. instance_being_edited_pool_id .. " before trying to " .. action .. " this superitem. It will be selected and scrolled to now.", "Pool already being edited", _api.msg.type.ok)
  reaper.Main_OnCommand(_cmd.deselect_all_items, _api.cmd_flag)
  reaper.SetMediaItemSelected(instance_being_edited, true)
  reaper.Main_OnCommand(_cmd.scroll_to_selected_item, _api.cmd_flag)
end


function _module_single.superitemHasMultipleTakes(superitem)
  local superitem_takes_count

  superitem_takes_count = reaper.GetMediaItemNumTakes(superitem)

  if superitem_takes_count > 1 then

    return true, superitem_takes_count
  end
end


function _module_single.handleMultitakeSuperitem(superitem_takes_count)
  local user_wants_to_explode_superitem_takes, user_response_explode_in_order

  user_wants_to_explode_superitem_takes = reaper.ShowMessageBox("The Superitem selected has " .. superitem_takes_count .. " takes in it. " .. _brand.name .. " does not support multiple takes on Superitems. Do you want to explode your Superitem takes before Editing?", "Superitem has multiple takes", _api.msg.type.ok_cancel)

  if user_wants_to_explode_superitem_takes == _api.msg.response.ok then
    user_response_explode_in_order = reaper.ShowMessageBox("Choose Yes to explode in order or No to explode in place.", "Do you want to explode in order?", _api.msg.type.yes_no)

    superitem, superitem_active_take = _module_single.checkSuperitemTakesAreValid()

    if not superitem_active_take then

      return "cancel"
    end

    _module_single.explodeSuperitem(superitem, superitem_active_take, user_response_explode_in_order)

  elseif user_wants_to_explode_superitem_takes == _api.msg.response.cancel then

    return "cancel"
  end
end


function _module_single.checkSuperitemTakesAreValid()
  local superitem, superitem_active_take

  superitem = _module_init.getFirstSelectedItem()
  superitem_active_take = reaper.GetActiveTake(superitem)

  if not superitem_active_take then
    _module_init.throwOfflineTakeWarning()

    return false
  end

  return superitem, superitem_active_take
end


function _module_single.explodeSuperitem(superitem, superitem_active_take, user_response_explode_in_order)
  local user_wants_to_explode_in_order, superitem_takes_count, superitem_params, duplicated_item_target_take_num, item_data_values, i, offline_takes_msg__shown

  superitem_takes_count, superitem_params, duplicated_item_target_take_num, item_data_values = _module_single.explodeSuperitem(superitem)

  if user_response_explode_in_order == _api.msg.response.yes then
    user_wants_to_explode_in_order = true
  end

  for i = 0, superitem_takes_count-2 do
    duplicated_item_target_take_num, offline_takes_msg__shown = _module_single.explodeSuperitemTakes(i, superitem, user_wants_to_explode_in_order, superitem_params, duplicated_item_target_take_num, item_data_values, offline_takes_msg__shown)
  end

  reaper.Main_OnCommand(_cmd.deselect_all_items, _api.cmd_flag)
  reaper.SetMediaItemSelected(superitem, true)
  reaper.Main_OnCommand(_cmd.crop_selected_items_to_active_takes, _api.cmd_flag)
end


function _module_single.explodeSuperitem(superitem)
  local superitem_takes_count, superitem_params, duplicated_item_target_take_num, item_data_values, superitem_superglue_active_take_key, this_superitem_take, retval, this_superitem_take_active_flag

  superitem_takes_count = reaper.GetMediaItemNumTakes(superitem)
  superitem_params = _module_data.getSetItemParams(superitem)
  duplicated_item_target_take_num = 0
  item_data_values = {_constant.data.key.suffix.pool.instance_id, _constant.data.key.suffix.pool.parent_id, _constant.data.key.suffix.superitem.first_child_delta_to_superitem_position, _constant.data.key.suffix.preglue.active_take_guid}
  superitem_superglue_active_take_key = _api.data_key .. _brand.prefix.global .. _constant.data.key.prefix.pool .. superitem_params.instance_pool_id .. _constant.data.key.suffix.superitem.superglue_active_take
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


function _module_single.explodeSuperitemTakes(i, superitem, user_wants_to_explode_in_order, superitem_params, duplicated_item_target_take_num, item_data_values, offline_takes_msg__shown)
  local this_duplicated_item, this_duplicated_item_new_position, this_duplicated_item_new_active_take

  reaper.Main_OnCommand(_cmd.duplicate_selected_items, _api.cmd_flag)

  this_duplicated_item = _module_init.getFirstSelectedItem()
  this_duplicated_item_new_position = superitem_params.position

  if user_wants_to_explode_in_order then
    this_duplicated_item_new_position = this_duplicated_item_new_position + (superitem_params.length * (i + 1))
  end

  reaper.SetMediaItemPosition(this_duplicated_item, this_duplicated_item_new_position, _api.dont_refresh_ui)

  for j = 1, #item_data_values do
    _module_data.storeRetrieveItemData(this_duplicated_item, item_data_values[j], "")
  end

  duplicated_item_target_take_num, this_duplicated_item_new_active_take, offline_takes_msg__shown = _module_single.handleDuplicatedItemTargetTake(i, this_duplicated_item, duplicated_item_target_take_num, superitem_params, offline_takes_msg__shown)

  _module_single.handleDuplicatedItemTargetTake(this_duplicated_item)
  _module_common.addRemoveItemImage(this_duplicated_item, false)
  reaper.Main_OnCommand(_cmd.deselect_all_items, _api.cmd_flag)
  reaper.SetMediaItemSelected(superitem, true)

  return duplicated_item_target_take_num, offline_takes_msg__shown
end


function _module_single.handleDuplicatedItemTargetTake(i, this_duplicated_item, duplicated_item_target_take_num, superitem_params, offline_takes_msg__shown)
  local this_duplicated_item_new_active_take, targeted_take_is_offline

  duplicated_item_target_take_num = duplicated_item_target_take_num + i

  if duplicated_item_target_take_num == superitem_params.superglue_active_take_num then
    duplicated_item_target_take_num = duplicated_item_target_take_num + 1
  end

  this_duplicated_item_new_active_take = reaper.GetTake(this_duplicated_item, duplicated_item_target_take_num)
  targeted_take_is_offline = not this_duplicated_item_new_active_take

  if not targeted_take_is_offline then
    reaper.SetActiveTake(this_duplicated_item_new_active_take)
    reaper.Main_OnCommand(_cmd.crop_selected_items_to_active_takes, _api.cmd_flag)

  elseif not offline_takes_msg__shown then
    _module_init.throwOfflineTakeWarning(true)

    offline_takes_msg__shown = true
  end

  return duplicated_item_target_take_num, this_duplicated_item_new_active_take, offline_takes_msg__shown
end


function _module_single.handleDuplicatedItemTargetTake(item)
  local active_take_name, superglue_name_prefix, new_take_name

  active_take_name = _module_common.getSetItemName(item)
  superglue_name_prefix = string.match(active_take_name, _brand.prefix.superitem_name_default)

  if superglue_name_prefix then
    new_take_name = string.gsub(active_take_name, _brand.prefix.superitem_name_default, "")

    _module_common.getSetItemName(item, new_take_name)
  end
end


function _module_edit.handleEditOrUnglue(superitem, pool_id, action)

  if not _module_edit.validateRestoredItemPositions(superitem, pool_id, action) then

    return false
  end

  if action == "Edit" or action == "Smart Glue/Edit" then
    _module_edit.processEdit(superitem, pool_id, action)

  elseif action == "Unglue" or action == "Smart Glue/Unglue" then
    _module_edit.processUnglue(superitem, pool_id, action)
  end
end


function _module_edit.processEdit(superitem, pool_id, action)
  local superitem_preedit_params = _module_data.getSetItemParams(superitem)
  local active_track = reaper.BR_GetMediaTrackByGUID(_api.current_project, superitem_preedit_params.track_guid)
  local superitem_state = _module_data.getSetItemStateChunk(superitem)

  if _constant.support.fixed_lanes then
    -- Get superitem's current Y position
    local superitemY = reaper.GetMediaItemInfo_Value(superitem, "F_FREEMODE_Y")
    _module_data.storeRetrievePoolData(pool_id, "edit_superitem_y", tostring(superitemY))

    local currentLaneCount = reaper.GetMediaTrackInfo_Value(active_track, "I_NUMFIXEDLANES")
    -- Use rounding instead of flooring for more accurate lane calculation
    local currentLane = math.floor(superitemY * currentLaneCount + 0.5)
    _module_data.storeRetrievePoolData(pool_id, "edit_superitem_lane", tostring(currentLane))

    if _test_logging_enabled then
      _module_dev.log("EDIT: Stored superitem Y=" .. superitemY .. ", lane=" .. currentLane .. ", laneCount=" .. currentLaneCount)
    end
  end

  _module_data.storeRetrieveSuperitemParams(pool_id, _constant.actionstep.preedit, superitem)
  _module_data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.preglue.superitem_state, superitem_state)

  local restored_items = _module_common.restoreStoredItems(pool_id, active_track, superitem, nil, action, nil)

  local sizing_region_guid = _module_edit.createSizingRegionFromSuperitem(superitem, pool_id)
  _state.action.edit_or_unglue.restored_items = restored_items

  reaper.DeleteTrackMediaItem(active_track, superitem)
  _module_edit.updateRestoredItemsData(restored_items, pool_id)
end


function _module_edit.processUnglue(superitem, pool_id, action)
  local superitem_preedit_params = _module_data.getSetItemParams(superitem)
  local active_track = reaper.BR_GetMediaTrackByGUID(_api.current_project, superitem_preedit_params.track_guid)

  if _constant.support.fixed_lanes then
    -- Store superitem's current Y position and lane (like in processEdit)
    local superitemY = reaper.GetMediaItemInfo_Value(superitem, "F_FREEMODE_Y")
    _module_data.storeRetrievePoolData(pool_id, "edit_superitem_y", tostring(superitemY))

    local currentLaneCount = reaper.GetMediaTrackInfo_Value(active_track, "I_NUMFIXEDLANES")
    -- Use rounding instead of flooring for more accurate lane calculation
    local currentLane = math.floor(superitemY * currentLaneCount + 0.5)
    _module_data.storeRetrievePoolData(pool_id, "edit_superitem_lane", tostring(currentLane))

    if _test_logging_enabled then
      _module_dev.log("UNGLUE: Stored superitem Y=" .. superitemY .. ", lane=" .. currentLane .. ", laneCount=" .. currentLaneCount)
    end

    -- Get the original lane count
    local originalLaneCountStr = _module_data.storeRetrievePoolData(pool_id, "original_lane_count")
    local originalLaneCount = tonumber(originalLaneCountStr) or currentLaneCount -- Default to current count if not stored

    -- Force track to fixed lanes mode
    reaper.SetMediaTrackInfo_Value(active_track, "I_FOLDERCOMPACT", 2)
    reaper.SetMediaTrackInfo_Value(active_track, "I_NUMFIXEDLANES", originalLaneCount)
    reaper.UpdateArrange()
  end

  local restored_items = _module_common.restoreStoredItems(pool_id, active_track, superitem, nil, action)
  _state.action.edit_or_unglue.restored_items = restored_items

  reaper.DeleteTrackMediaItem(active_track, superitem)
  return pool_id, restored_items
end


function _module_edit.validateRestoredItemPositions(superitem, pool_id, action)
  local stored_item_states = _module_data.getStoredItemStatesTable(pool_id, action)
  local superitem_params = _module_data.getSetItemParams(superitem)
  local post_glue_params = _module_data.storeRetrieveSuperitemParams(pool_id, _constant.actionstep.postglue)

  if not post_glue_params then return true end

  local position_delta = superitem_params.position - post_glue_params.position

  for item_guid, stored_item_state in pairs(stored_item_states) do
    if stored_item_state then
      local temp_track = reaper.GetTrack(0, 0)
      local temp_item = reaper.AddMediaItemToTrack(temp_track)
      _module_data.getSetItemStateChunk(temp_item, stored_item_state)
      local stored_position = reaper.GetMediaItemInfo_Value(temp_item, _api.item.key.position)
      reaper.DeleteTrackMediaItem(temp_track, temp_item)

      local adjusted_position = stored_position + position_delta

      if adjusted_position < 0 then
        reaper.ShowMessageBox("This operation cannot be completed because one or more items would be placed before the start of the project.", "Cannot Edit/Unglue", _api.msg.type.ok)
        return false
      end
    end
  end

  return true
end


function _module_edit.createSizingRegionFromSuperitem(superitem, pool_id, looped_source_sets_sizing_region__enabled, superitem_loop_is_enabled)
  local superitem_params, sizing_region_guid

  superitem_params = _module_data.getSetItemParams(superitem)

  if looped_source_sets_sizing_region__enabled == "true" and superitem_loop_is_enabled then
    superitem_params.length, superitem_params.end_point = _module_edit.getSuperitemLoopLength(superitem, superitem_params)
  end

  sizing_region_guid = _module_common.getSetSizingRegion(pool_id, superitem_params)

  return sizing_region_guid
end


function _module_edit.getSuperitemLoopLength(superitem, superitem_params)
  local superitem_active_take, superitem_active_take_source, superitem_length, superitem_end_point

  superitem_active_take = reaper.GetActiveTake(superitem)
  superitem_active_take_source = reaper.GetMediaItemTake_Source(superitem_active_take)
  superitem_length = reaper.GetMediaSourceLength(superitem_active_take_source)
  superitem_end_point = superitem_length - superitem_params.position

  return superitem_length, superitem_end_point
end


function _module_edit.updateRestoredItemsData(restored_items, pool_id)
  local this_restored_item

  for i = 1, #restored_items do
    this_restored_item = restored_items[i]

    _module_data.storeRetrieveItemData(this_restored_item, _constant.data.key.suffix.pool.parent_id, pool_id)
  end
end


function _module_init.getSmartAction(user_selected_items_on_this_track)
  local global_option_toggle_multiitem_editing_enabled, smart_action, user_response_disable_multiitem_option

  global_option_toggle_multiitem_editing_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.multiitem_editing)

  if global_option_toggle_multiitem_editing_enabled == "true" then
    user_response_disable_multiitem_option = reaper.ShowMessageBox('Smart Action cannot run when the option "Enable multi-item Edit, Unglue, or DePool in single action" is enabled. Would you like to disable this option and run the Smart Action?', "Smart Action not allowed", _api.msg.type.ok_cancel)

    if user_response_disable_multiitem_option == _api.msg.response.ok then
      initOptionToggle("multiitem_editing")

    else

      return false
    end
  end

  smart_action = _module_init.calculateSmartAction(user_selected_items_on_this_track)

  return smart_action
end


function _module_init.calculateSmartAction(user_selected_items_on_this_track)
  local selected_item_groups, parent_instances_count, no_parent_instances_are_selected, single_parent_instance_is_selected, parent_instances_are_selected, multiple_parent_instances_are_selected, nonsuperitems_count, no_nonsuperitems_are_selected, nonsuperitems_are_selected, child_instances_count, no_child_instances_are_selected, user_wants_to_edit_or_unglue, user_must_glue_or_abort, user_wants_to_glue

  selected_item_groups = _module_common.getSuperglueItemTypes(user_selected_items_on_this_track, {"nonsuperitem", "child_instance", "parent_instance"})
  parent_instances_count = #selected_item_groups.parent_instance.items
  no_parent_instances_are_selected = parent_instances_count == 0
  single_parent_instance_is_selected = parent_instances_count == 1
  parent_instances_are_selected = parent_instances_count > 0
  multiple_parent_instances_are_selected = parent_instances_count > 1
  nonsuperitems_count = #selected_item_groups.nonsuperitem.items
  no_nonsuperitems_are_selected = nonsuperitems_count == 0
  nonsuperitems_are_selected = nonsuperitems_count > 0
  child_instances_count = #selected_item_groups.child_instance.items
  no_child_instances_are_selected = child_instances_count == 0
  single_child_instance_is_selected = child_instances_count == 1
  user_wants_to_edit_or_unglue = single_parent_instance_is_selected and no_nonsuperitems_are_selected and no_child_instances_are_selected
  user_must_glue_or_abort = parent_instances_are_selected and single_child_instance_is_selected
  user_wants_to_glue = (multiple_parent_instances_are_selected and no_nonsuperitems_are_selected and no_child_instances_are_selected) or
    (nonsuperitems_are_selected and no_child_instances_are_selected) or
    (no_parent_instances_are_selected and single_child_instance_is_selected)

  if user_wants_to_edit_or_unglue then

    return "edit_or_unglue"

  elseif user_must_glue_or_abort then

    return "glue/abort"

  elseif user_wants_to_glue then

    return "glue"
  end
end


function _module_depool.processSiblingDePool(sibling)
  local action, sibling_params, sibling_state, sibling_instance_pool_id, restored_items, contained_item_states, superitem, new_pool_id

  action = "DePool"
  sibling_params, sibling_state, sibling_instance_pool_id = _module_depool.setUpDePool(sibling)
  _state.action.glue.current_track = reaper.BR_GetMediaTrackByGUID(_api.current_project, sibling_params.track_guid)
  pool_id, restored_items = _module_edit.processUnglue(sibling, sibling_params.pool_id, action)
  contained_item_states = _module_data.prepareAndGetItemStates(restored_items, sibling_params.pool_id)
  superitem = _module_glue.handleGlue(restored_items, nil, nil, sibling_params, false)
  new_pool_id = _module_depool.handleDePoolPostGlue(superitem, sibling_state, sibling_params)

  _module_data.storeItemStates(new_pool_id, contained_item_states)
end


function _module_depool.setUpDePool(target_item)
    local target_item_params, target_item_state, target_item_instance_pool_id

    target_item_params = _module_data.getSetItemParams(target_item)
    target_item_params.pool_id = _module_data.storeRetrieveItemData(target_item, _constant.data.key.suffix.pool.instance_id)

    -- Get original pool's position
    local original_pool_position = _module_data.storeRetrievePoolData(target_item_params.pool_id, _constant.data.key.suffix.pool.parent_position)
    original_pool_position = tonumber(original_pool_position)

    -- Store movement direction relative to original
    local movement_direction = target_item_params.position < original_pool_position and "earlier" or "later"
    _module_data.storeRetrievePoolData(target_item_params.pool_id, "depool_movement_direction", movement_direction)

    target_item_state = _module_data.getSetItemStateChunk(target_item)
    target_item_instance_pool_id = target_item_params.pool_id
    _state.restored_items.first_restored_item_last_glue_delta_to_parent = _module_data.storeRetrievePoolData(target_item_instance_pool_id, _constant.data.key.suffix.superitem.first_child_delta_to_superitem_position)

    return target_item_params, target_item_state, target_item_instance_pool_id
end


function _module_depool.handleDePoolPostGlue(superitem, target_item_state, target_item_params)
  local superitem_active_take, active_take_name, updated_src, new_pool_id

  superitem_active_take = reaper.GetActiveTake(superitem)
  active_take_name = _module_common.getSetItemName(superitem)
  updated_src = _module_common.getSetWipeItemAudioSrc(superitem)
  new_pool_id = _module_data.storeRetrieveItemData(superitem, _constant.data.key.suffix.pool.instance_id)

  _module_data.storeRetrievePoolData(new_pool_id, _constant.data.key.suffix.superitem.first_child_delta_to_superitem_position, _state.restored_items.first_restored_item_last_glue_delta_to_parent)
  _module_data.storeRetrievePoolData(new_pool_id, _constant.actionstep.freshly_depooled_superitem_flag, "true")
  _module_data.getSetItemStateChunk(superitem, target_item_state)
  _module_common.getSetItemName(superitem, active_take_name)
  _module_data.storeRetrieveItemData(superitem, _constant.data.key.suffix.pool.instance_id, new_pool_id)
  _module_common.refreshActiveTakeFlag(superitem, superitem_active_take, new_pool_id)
  reaper.SetMediaItemSelected(superitem, true)
  _module_common.setSuperitemColor()

  return new_pool_id
end


function _module_common.setAllSuperitemsColor(action)
  local current_window, retval, color, all_items_count, this_item, this_item_instance_pool_id

  current_window = reaper.GetMainHwnd()
  retval, color = reaper.GR_SelectColor(current_window)
  pool_ids = {}

  if retval ~= 0 then
    _module_init.prepareAction("color")

    all_items_count = reaper.CountMediaItems(_api.current_project)

    for i = 0, all_items_count-1 do
      this_item = reaper.GetMediaItem(_api.current_project, i)
      this_item_instance_pool_id = _module_data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.instance_id)

      if this_item_instance_pool_id and this_item_instance_pool_id ~= "" then
        reaper.SetMediaItemInfo_Value(this_item, _api.item.key.color, color|0x1000000)
        table.insert(pool_ids, this_item_instance_pool_id)
      end
    end

    _module_init.cleanUpAction(action, pool_ids)
  end
end


function Superglue.logSuperglueProjectData()
  local master_track, retval, master_track_chunk

  master_track = reaper.GetMasterTrack(_api.current_project)
  retval, master_track_chunk = reaper.GetTrackStateChunk(master_track, "", false)

  log(master_track_chunk)
end



--- UTILITY FUNCTIONS ---

function _module_util.copyFile(old_path, new_path)
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

function _module_util.initEmptyTables(...)
  for i = 1, select('#', ...) do
    local tbl = select(i, ...)
    if tbl == nil then
      select(i, ...)[i] = {}
    else
      tbl = {}
    end
  end
end

function _module_util.deduplicateTable(t)
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

function _module_util.getTableSize(t)
    local count = 0
    for _, __ in pairs(t) do
        count = count + 1
    end
    return count
end

function _module_util.fileExists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function _module_util.getFileNameFromPath(file)
    return file:match("^.+[/\\](.+)$")
end

function _module_util.numberizeAndRoundElements(tables, elems)
  local this_table
  for i = 1, #tables do
    this_table = tables[i]
    for j = 1, #elems do
      this_table[elems[j]] = _module_common.round(tonumber(this_table[elems[j]]),_api.time_value_decimal_resolution)
    end
  end
  return table.unpack(tables)
end

function _module_common.round(num, precision)
   return math.floor(num*(10^precision)+0.5) / 10^precision
end

function _module_util.stringifyArray(t)
  local s = ""
  local this_array_entry
  for i = 1, #t do
    this_array_entry = tostring(t[i])
    s = s .. this_array_entry
    if i ~= #t then
       s = s .. ", "
    end
  end
  if not s or s == "" then
    s = "none"
  end
  return s
end

function _module_util.concatenateArrays(array_of_arrays)
  local result = {}
  for _, arr in ipairs(array_of_arrays) do
    for _, value in ipairs(arr) do
        table.insert(result, value)
    end
  end
  return result
end

function _module_util.isPresentInArray(value, tbl)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

function _module_util.escapeRegexSpecialCharacters(s)
  local patternSpecials = "().%+-*?[^$"
  return (s:gsub("["..patternSpecials.."]", "%%%1"))
end



if _test_logging_enabled then

  local logging_config = {
    _test_logging_enabled = _test_logging_enabled,
    _log_function_entry = _log_function_entry,
    _log_function_exit = _log_function_exit,
  }

  -- List of all modules to wrap
  local modules_to_wrap = {
    Superglue = Superglue,                 -- Main module

    _module_common = _module_common,       -- Common utilities and methods
    _module_single = _module_single,       -- Single-operation-specific methods
    _module_util = _module_util,           -- Utility functions
    _module_edit = _module_edit,           -- Editing-related functions
    _module_depool = _module_depool,       -- De-pooling operations
    _module_init = _module_init,           -- Initialization logic
    _module_data = _module_data,           -- Data handling and storage
    _module_glue = _module_glue,           -- Glue-related methods
    _module_actions = _module_actions,     -- Action-handling functions
    _module_state = _module_state,         -- State management and updates
    _module_brand = _module_brand,         -- Branding and namespace functions
    _module_api = _module_api,             -- API integration and commands
    _module_config = _module_config,       -- Configuration management
  }


  -- Apply logging wrapper to all modules
  for name, module_table in pairs(modules_to_wrap) do
    _module_dev.wrapWithLogging(module_table, name, logging_config)
  end
end


-- send script namespace to external files
return Superglue
