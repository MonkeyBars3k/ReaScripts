-- @noindex

local Options = {}


local loadDependencies, rtk, _constant



local _dev = require("modules.dev")

loadDependencies = (function()
  rtk = require("lib.rtk")
  _constant = require("modules.constant")
end)()



function Options.populateOptionsDefaults()

  for _, option in ipairs(_constant.global_options) do
    _constant.data.key.options.defaults[option.name] = option.default_value
  end
end


function Options.updateOptionValue(option, val)
  local option_toggle_script_filepath, option_toggle_script_command_id, option_is_boolean, integer_val

  option_toggle_script_filepath = _constant.file.path.script .. option.option_script_filename
  option_toggle_script_command_id = reaper.AddRemoveReaScript(true, _constant.api.command_section.main, option_toggle_script_filepath, false)
  option_is_boolean = not option.values

  if option_is_boolean then
    integer_val = val == "true" and 1 or 0

    reaper.SetToggleCommandState(_constant.api.command_section.main, option_toggle_script_command_id, integer_val)
    reaper.RefreshToolbar2(_constant.api.command_section.main, option_toggle_script_command_id)
  end

  reaper.SetExtState(_constant.data.key.options.global_section, option.ext_state_key, val, _constant.api.extstate.persist_enabled)
end


function Options.setDefaultOptionValues()
  local this_option_ext_state_key, this_option_exists_in_extstate, this_option_is_not_set_in_extstate

  for i = 1, #_constant.global_options do
    this_option_ext_state_key = _constant.global_options[i].ext_state_key
    this_option_exists_in_extstate = reaper.HasExtState(_constant.data.key.options.global_section, this_option_ext_state_key)
    this_option_is_not_set_in_extstate = not this_option_exists_in_extstate or this_option_exists_in_extstate == "nil"

    if this_option_is_not_set_in_extstate then
      Options.updateOptionValue(_constant.global_options[i], _constant.global_options[i].default_value)
    end
  end
end


function Options.getActiveOption(option_name)
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


function Options.debug_log_dimensions(stage, option_window_widgets)
  local calc = option_window_widgets.options_window.calc
  local viewport_calc = option_window_widgets.options_viewport.calc
  local content_calc = option_window_widgets.options_window_content.calc

  -- Count total height of content children
  local total_height = 0

  for i, child in ipairs(option_window_widgets.options_window_content.children) do

    local widget = child[1]

    if widget.calc and widget.calc.h then
      total_height = total_height + widget.calc.h
    end
  end
end


function Options.openOptionsWindow()
    local option_window_widgets, all_option_controls
    local _, _, screen_w, screen_h = reaper.my_getViewport(0, 0, 0, 0, 0, 0, 0, 0, 1)

    option_window_widgets = Options.createOptionsWidgets()
    option_window_widgets.options_window:attr('h', 400) -- Temporary initial height
    option_window_widgets.options_viewport:attr('flexh', true)
    option_window_widgets.options_viewport:attr('vscrollbar', rtk.Viewport.SCROLLBAR_AUTO)

    Options.populateOptionsWidgets(option_window_widgets)
    all_option_controls = Options.populateOptionControls(option_window_widgets)
    Options.populateOptionsEventHandlers(option_window_widgets, all_option_controls)
    Options.populateOptionsWindow(option_window_widgets)

    option_window_widgets.options_window:open{align = "center"}

    reaper.defer(function()
      -- Multiple reflows can help stabilize calculations
      option_window_widgets.options_window:reflow()
      option_window_widgets.options_window:reflow()

      -- Add nil checks for defensive programming
      local content_height = option_window_widgets.options_window_content.calc and option_window_widgets.options_window_content.calc.h or 0
      local footer_height = option_window_widgets.option_footer and option_window_widgets.option_footer.calc and option_window_widgets.option_footer.calc.h or 0
      local buffer = 50 * rtk.scale.value

      -- Rest of calculation remains same
      local window_height = math.min(
          content_height + footer_height + buffer,
          screen_h * 0.85
      )
      window_height = math.max(window_height, 150)

      option_window_widgets.options_window:attr('h', window_height)

      local window_y = math.max(0, (screen_h - window_height) / 2)
      option_window_widgets.options_window:attr('y', window_y)
    end)
end


function Options.createOptionsWidgets()
  local option_window_widgets

  option_window_widgets = {
    options_window = rtk.Window{w = 0.5, maxh = 0.85, title = _constant.brand.name .. " Global Options"},
    options_window_inner = rtk.VBox(),
    options_window_top = rtk.Container{valign = "center"},
    options_window_constant_branding = rtk.VBox{halign = "center", padding = "3 5", border = "1px #878787", bg = "#505050"},
    options_window_script_name = rtk.Text{_constant.brand.name, halign = "center", fontscale = 0.8},
    options_window_logo = rtk.ImageBox{rtk.Image():load(_constant.file.name.script_logo, 2), tmargin = 4},
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


function Options.populateOptionsWidgets(option_window_widgets)
  option_window_widgets.option_form_buttons:add(option_window_widgets.option_form_save)
  option_window_widgets.option_form_buttons:add(option_window_widgets.option_form_cancel)
  option_window_widgets.option_footer:add(option_window_widgets.option_repo_text)
  option_window_widgets.options_window_constant_branding:add(option_window_widgets.options_window_script_name)
  option_window_widgets.options_window_constant_branding:add(option_window_widgets.options_window_logo)
  option_window_widgets.options_window_top:add(option_window_widgets.options_window_constant_branding)
  option_window_widgets.options_window_top:add(option_window_widgets.options_window_title)
end


function Options.populateOptionControls(option_window_widgets)
  local all_option_controls, this_option, this_option_name

  all_option_controls = {}

  for i = 1, #_constant.global_options do
    this_option = _constant.global_options[i]
    this_option_name = this_option.name

    if this_option.type == "checkbox" then
      all_option_controls[this_option_name] = Options.getOptionCheckbox(this_option, option_window_widgets.option_form_save)

    elseif this_option.type == "dropdown" then
      all_option_controls[this_option_name] = Options.getOptionDropdown(this_option, option_window_widgets.option_form_save)
    end

    option_window_widgets.options_window_content:add(all_option_controls[this_option_name])
  end

  return all_option_controls
end


function Options.populateOptionsEventHandlers(option_window_widgets, all_option_controls)
  option_window_widgets.option_form_cancel.onclick = function()
    option_window_widgets.options_window:close()
  end

  option_window_widgets.option_repo_text.onclick = function()
    reaper.CF_SetClipboard(option_window_widgets.options_repo_url)

    option_window_widgets.option_repo_text:animate{"color", dst = "#FFFFFF", duration = 0.15}
      :done(function()
          option_window_widgets.option_repo_text:animate{"color", dst = "#FFFFFE", duration = 0.67}
            :done(function()
              option_window_widgets.option_repo_text:animate{"color", dst = "#989898", duration = 0.15}
            end)
      end)
  end

  option_window_widgets.option_form_save.onclick = function()
    Options.submitOptionChanges(all_option_controls, option_window_widgets.options_window)
  end
end


function Options.populateOptionsWindow(option_window_widgets)
  -- Add buttons and footer to content BEFORE setting viewport child
  option_window_widgets.options_window_content:add(option_window_widgets.option_form_buttons)
  option_window_widgets.options_window_content:add(option_window_widgets.option_footer)

  -- Now set viewport child after content is fully populated
  option_window_widgets.options_viewport:attr("child", option_window_widgets.options_window_content)

  -- Rest of function remains same
  option_window_widgets.options_window_inner:add(option_window_widgets.options_window_top)
  option_window_widgets.options_window_inner:add(option_window_widgets.options_viewport)
  option_window_widgets.options_window:add(option_window_widgets.options_window_inner)
end


function Options.getOptionCheckbox(option, option_form_save)
  local option_saved_value, checkbox_value, option_checkbox

  option_saved_value = reaper.GetExtState(_constant.data.key.options.global_section, option.ext_state_key)
  checkbox_value = option_saved_value == "true" and true or false
  option_checkbox = rtk.CheckBox{option.user_readable_text, value = checkbox_value, margin = "10 0"}
  option_checkbox.onchange = function()
    Options.activateOptionsubmitButton(option_form_save)
  end

  return option_checkbox
end


function Options.activateOptionsubmitButton(submit_button)
  submit_button:attr("disabled", false)
end


function Options.getOptionDropdown(option, option_form_save)
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
    Options.activateOptionsubmitButton(option_form_save)
  end

  option_dropdown_box:add(dropdown_control)
  option_dropdown_box:add(dropdown_label)

  return option_dropdown_box
end


function Options.submitOptionChanges(all_option_controls, options_window)
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
      Options.updateOptionValue(this_option, this_option_form_value)
      Options.resetDePoolAllSiblingsWarning(this_option.ext_state_key)
    end
  end

  options_window:close()
end


function Options.resetDePoolAllSiblingsWarning(ext_state_key)

  if ext_state_key == _constant.data.key.options.toggle.depool_all_siblings_on_reglue then
    reaper.SetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.depool_all_siblings_on_reglue_warning, "true", _constant.api.extstate.persist_enabled)
  end
end



return Options
