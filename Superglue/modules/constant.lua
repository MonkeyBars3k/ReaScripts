-- @noindex

local Constant = {
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

  regex = {
    nested_item_default_name = '%[".+%]',
    file_extension = "%.([^%.]+)$",
    string_start = "^",
    superitem_name_iterator = "%:%d+"
  },

  unicode = {
    double_quotation_mark = "\u{0022}",
    no_break_space = "\u{00a0}"
  },

  api = {
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
        name = "P_NAME",
        num_fixed_lanes = "I_NUMFIXEDLANES"
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
  },

  cmd = {
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
    add_lane_to_track = 42647,
    deselect_all_tracks = 40297,
    scroll_to_selected_item = reaper.NamedCommandLookup("_S&M_SCROLL_ITEM")
  },

  brand = {
    name = "MB_Superglue",
    separator = ":",

    prefix = {
      global = "SG_",
      item_name = "sg"
    }
  }
}

Constant.brand.prefix.superitem_name = Constant.brand.prefix.item_name .. Constant.brand.separator
Constant.brand.prefix.superitem_name_default = Constant.regex.string_start .. Constant.brand.prefix.item_name .. Constant.regex.superitem_name_iterator

Constant.data = {
  storage_track = reaper.GetMasterTrack(Constant.api.current_project),

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
        descendant_ids = ":descendant-pool-ids"
      },

      item = {
          lane_delta = ":item-lane-delta"
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

Constant.file = {

  os = {
    separator = package.config:sub(1,1)
  },

  path = {
    script = string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$"),
    proj_render = reaper.GetProjectPath(Constant.api.current_project)
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

Constant.file.path.splitter = "([^%" .. Constant.file.os.separator .. "]+)"
Constant.file.path.superitem_bg_img = Constant.file.path.proj_render .. Constant.file.os.separator .. Constant.file.name.superitem_bg_img
Constant.file.path.restored_item_bg_img = Constant.file.path.proj_render .. Constant.file.os.separator .. Constant.file.name.restored_item_bg_img
Constant.file.path.restored_instance_bg_img = Constant.file.path.proj_render .. Constant.file.os.separator .. Constant.file.name.restored_instance_bg_img


Constant.global_options = {

  {
    name = "time_selection_sets_superitem_bounds_on_initial_glue",
    type = "checkbox",
    ext_state_key = Constant.data.key.options.toggle.time_selection_sets_bounds_on_glue,
    option_script_filename = "MB_Superglue - Options - Glue - Time selection determines Superitem bounds on initial glue (On-Off).lua",
    user_readable_text = "Glue: Time selection determines Superitem bounds on initial Superitem creation",
    default_value = "false"
  },

  {
    name = "auto_increase_channel_count_with_take_fx",
    type = "checkbox",
    ext_state_key = Constant.data.key.options.toggle.auto_increase_channel_count,
    option_script_filename = "MB_Superglue - Options - Glue - Auto-increase channel count with take FX (On-Off).lua",
    user_readable_text = "Glue: Auto-increase channel count with take FX",
    default_value = "false"
  },

  {
    name = "loop_source_sets_sizing_region_bounds_on_reglue",
    type = "checkbox",
    ext_state_key = Constant.data.key.options.toggle.loop_source_sets_sizing_region_bounds_on_reglue,
    option_script_filename = "MB_Superglue - Options - Reglue - Looped source of Superitem determines Sizing Region bounds (On-Off).lua",
    user_readable_text = "Reglue: Looped source of Superitem determines Sizing Region bounds",
    default_value = "true"
  },

  {
    name = "depool_all_siblings_on_reglue",
    type = "checkbox",
    ext_state_key = Constant.data.key.options.toggle.depool_all_siblings_on_reglue,
    option_script_filename = "MB_Superglue - Options - Reglue - Remove Siblings from Edited Superitem's Pool, giving every Sibling its own new Pool (On-Off).lua",
    user_readable_text = "Reglue: Remove all sibling instances from pool (disable & undo pooling)",
    default_value = "false"
  },

  {
    name = "multiitem_editing",
    type = "checkbox",
    ext_state_key = Constant.data.key.options.toggle.multiitem_editing,
    option_script_filename = "MB_Superglue - Options - Edit-Unglue-DePool - Enable multi-item Edit, Unglue, or DePool in single action (On-Off).lua",
    user_readable_text = "Edit/Unglue/DePool: Enable multi-item Edit, Unglue, and DePool in single action (Disable for v1.x Smart Action)",
    default_value = "true"
  },

  {
    name = "item_images",
    type = "checkbox",
    ext_state_key = Constant.data.key.options.toggle.item_images,
    option_script_filename = "MB_Superglue - Options - Display - Background images on new Superglue items - Superitems diagonal, contained items horizontal stripes (On-Off).lua",
    user_readable_text = "Display: Insert item background images on Superglue and Edit, overwriting item notes",
    default_value = "true"
  },

  {
    name = "new_superglue_random_color",
    type = "checkbox",
    ext_state_key = Constant.data.key.options.toggle.new_superglue_random_color,
    option_script_filename = "MB_Superglue - Options - Display - Randomly color newly Superglued Superitem (On-Off).lua",
    user_readable_text = "Display: Set newly glued Superitems to random color",
    default_value = "true"
  },

  {
    name = "retain_only_last_glue_source",
    type = "checkbox",
    ext_state_key = Constant.data.key.options.toggle.retain_only_last_glue_source,
    option_script_filename = "MB_Superglue - Options - Files - Retain only the latest Superglue source media, leaving undo history offline (On-Off).lua",
    user_readable_text = "Files: Retain only the latest Superglue source media (leaving undo history offline)",
    default_value = "false"
  },

  {
    name = "maintain_source_position",
    type = "dropdown",
    ext_state_key = Constant.data.key.options.switch.maintain_source_position,
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
    ext_state_key = Constant.data.key.options.switch.propagate_position,
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
    ext_state_key = Constant.data.key.options.switch.propagate_length,
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
    ext_state_key = Constant.data.key.options.switch.length_propagation_type,
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
    ext_state_key = Constant.data.key.options.switch.playrate_affects_propagation,
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



return Constant
