-- @noindex

local Init = {}

local loadDependencies, loadCircularDependencies, _constant, _data,  _options, _state, _util, _module_utils, _common, _midi, _multi

local _dev = require("modules.dev")

loadDependencies = (function()
  _constant = require("modules.constant")
  _data = require("modules.data")
  _options = require("modules.options")
  _state = require("modules.state")
  _util = require("modules.util")

  _module_utils = require("module-utils")
end)()


loadCircularDependencies = (function()
  _common = function() return _module_utils.lazyRequire("common") end
  _midi = function() return _module_utils.lazyRequire("midi") end
  _multi = function() return _module_utils.lazyRequire("multi") end
end)()



function Init.setUpAction(action)
  local selected_item_count

  selected_item_count = Init.doPreSuperglueChecks(action)

  if selected_item_count == false then return end

  Init.prepareAction(action)

  selected_item_count = reaper.CountSelectedMediaItems(_constant.api.current_project)

  if Init.itemsAreSelected(selected_item_count) == false then return false end

  return selected_item_count
end


function Init.doPreSuperglueChecks(action)
  local selected_item_count

  if Init.renderPathIsValid() == false then return false end

  selected_item_count = reaper.CountSelectedMediaItems(_constant.api.current_project)

  if not selected_item_count or selected_item_count == 0 then return false end

  if not Init.itemsAreSelected(selected_item_count) then return false end

  if Init.requiredLibsAreInstalled() == false then return false end

  Init.checkFixedLanesSupport()

  return selected_item_count
end


function Init.renderPathIsValid()
  local platform, win_platform_regex, is_win, win_absolute_path_regex, is_win_absolute_path, is_win_local_path, nix_absolute_path_regex, is_nix_absolute_path, is_other_local_path

  platform = reaper.GetOS()
  win_platform_regex = "^Win"
  is_win = string.match(platform, win_platform_regex)
  win_absolute_path_regex = "^%u%:\\"
  is_win_absolute_path = string.match(_constant.file.path.proj_render, win_absolute_path_regex)
  is_win_local_path = is_win and not is_win_absolute_path
  nix_absolute_path_regex = "^/"
  is_nix_absolute_path = string.match(_constant.file.path.proj_render, nix_absolute_path_regex)
  is_other_local_path = not is_win and not is_nix_absolute_path

  if is_win_local_path or is_other_local_path then
    reaper.ShowMessageBox(_constant.brand.name .. " needs a valid file render path. Set an absolute path in Project Settings > Media > Path or save your new project and try again.", "No file render path", _constant.api.msg.type.ok)

    return false

  else

    return true
  end
end


function Init.itemsAreSelected(selected_item_count)
  local no_items_are_selected = selected_item_count < 1

  if not selected_item_count or no_items_are_selected then

    return false

  else

    return true
  end
end


function Init.requiredLibsAreInstalled()
  local sws_version = reaper.CF_GetSWSVersion()

  if not sws_version then
    reaper.ShowMessageBox(_constant.brand.name .. " requires the SWS plugin extension to work. Please install SWS from https://standingwaterstudios.com/ and try again.", "SWS not installed", _constant.api.msg.type.ok)

    return false
  end
end


function Init.checkFixedLanesSupport()
  local version = reaper.GetAppVersion()
  local major = tonumber(version:match("^(%d+)"))

  if major >= _constant.reaper.version.fixed_lanes then
    _constant.support.fixed_lanes = true
  end
end


function Init.copySuperglueItemImagesToProject()
  local project_images_paths, script_image_paths

  project_images_paths = {
    superitem_bg = _constant.file.path.superitem_bg_img,
    restored_item_bg = _constant.file.path.restored_item_bg_img,
    restored_instance_bg = _constant.file.path.restored_instance_bg_img
  }

  script_image_paths = {
    superitem_bg = _constant.file.path.script .. _constant.file.name.superitem_bg_img,
    restored_item_bg = _constant.file.path.script .. _constant.file.name.restored_item_bg_img,
    restored_instance_bg = _constant.file.path.script .. _constant.file.name.restored_instance_bg_img
  }

  for image_name, image_path in pairs(project_images_paths) do

    if not _util.fileExists(image_path) then
      _util.copyFile(script_image_paths[image_name], project_images_paths[image_name])
    end
  end
end


function Init.prepareAction(action)
  local api_undo_flag_track_configurations = 1

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(api_undo_flag_track_configurations)

  if action == "Glue" or string.find(action, "Smart") then
    Init.setResetUsersItemSelection("set")
  end

  if _constant.support.fixed_lanes then
    Init.saveRecallUsersTrackSelection("save")
  end
end


function Init.doGlueAction(selected_item_count, action)
  local selected_items

  selected_items = _common().getSelectedItems(selected_item_count)
  _state.action.glue.all_glued_superitems = {}
  _state.action.glue.changed_pool_ids = {}

  if Init.selectedItemsAreInvalid(selected_items, action) then return end

  if Init.checkItemsOffscreen(selected_items, "selected") == true then return end

  Init.completeGlueOrDePool(selected_items, action)
end


function Init.completeGlueOrDePool(selected_items, action)
  local pool_ids_changed

  if not _multi().setUpMultiTrackActions(selected_items, action) then
    _state.user.item_selection = Init.removeItemsAbsentFromProjectFromArray(_state.user.item_selection)

    Init.setResetUsersItemSelection("reset")

    return
  end

  if action == "Glue" then
    pool_ids_changed = _state.action.glue.changed_pool_ids

  elseif string.find(action, "DePool") then
    pool_ids_changed = _state.action.depool.new_pool_ids
  end

  _state.action.glue.all_glued_superitems = Init.removeItemsAbsentFromProjectFromArray(_state.action.glue.all_glued_superitems)

  _common().selectDeselectItems(_state.action.glue.all_glued_superitems, true)
  Init.cleanUpAction(action, pool_ids_changed)
end


-- CAN THIS BE USED ELSEWHERE TOO?
function Init.removeItemsAbsentFromProjectFromArray(array)
  local presentItems = {}

  for _, item in ipairs(array) do

    if reaper.ValidatePtr2(_constant.api.current_project, item, _constant.api.datatype.mediaitem) then
      table.insert(presentItems, item)
    end
  end

  return presentItems
end


function Init.doEditOrUnglueAction(selected_item_count, action)

  if selected_item_count == 0 then return end

  local selected_items = _common().getSelectedItems(selected_item_count)
  local selected_item_groups = _common().getSuperglueItemTypes(selected_items, {"superitem"})
  local superitems = selected_item_groups.superitem.items

  if #superitems == 0 then
    reaper.ShowMessageBox("The " .. action .. " action only works on Superitems. Select a Superitem and try again.", _constant.brand.name .. " " .. action, _constant.api.msg.type.ok)
    return
  end

  _state.action.edit.changed_pool_ids = {}

  if Init.checkItemsOffscreen(selected_items, "selected") == true then return end

  local selected_siblings = Init.getSelectedSiblings(selected_items, action)
  selected_items = Init.handleSelectedSiblings(selected_items, selected_siblings, action)

  if not selected_items then return end

  if not _multi().setUpMultiTrackActions(selected_items, action) then return end

  if Init.checkItemsOffscreen(_state.action.edit_or_unglue.restored_items, "restored") == true then return end

  Init.cleanUpAction(action, _state.action.edit.changed_pool_ids)
end


function Init.doDePoolAction(selected_item_count, action)
  local selected_items

  selected_items = _common().getSelectedItems(selected_item_count)
  _state.action.glue.all_glued_superitems = {}
  _state.action.depool.new_pool_ids = {}

  Init.completeGlueOrDePool(selected_items, action)
end


function Init.doSmartAction(selected_item_count, action)
  local selected_items, pool_id

  selected_items = _common().getSelectedItems(selected_item_count)
  _state.action.glue.all_glued_superitems = {}
  _state.action.glue.changed_pool_ids = {}
  _state.action.edit.changed_pool_ids = {}

  if Init.superitemSelectionIsInvalid(selected_items, action) then return end

  if not _multi().setUpMultiTrackActions(selected_items, action) then return end

  for i = 1, #_state.action.glue.changed_pool_ids do
    table.insert(_state.action.edit.changed_pool_ids, _state.action.glue.changed_pool_ids[i])
  end

  Init.cleanUpAction(action, _state.action.edit.changed_pool_ids)
end


function Init.getSelectedSiblings(selected_items)
  local unique_instance_ids, selected_siblings, this_selected_item_instance_pool_id, this_selected_item_instance_pool_id_is_unique, this_unique_instance_pool_id, this_sibling_instance_id

  unique_instance_ids = {}
  selected_siblings = {}

  for i = 1, #selected_items do
    this_selected_item_instance_pool_id = _data.storeRetrieveItemData(selected_items[i], _constant.data.key.suffix.pool.instance_id)
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
          this_sibling_instance_id = _data.storeRetrieveItemData(selected_items[j], _constant.data.key.suffix.pool.instance_id)

          if this_sibling_instance_id == this_selected_item_instance_pool_id then
            table.insert(selected_siblings, selected_items[j])
          end
        end
      end
    end
  end

  return selected_siblings
end


function Init.handleSelectedSiblings(selected_items, selected_siblings, action)
  local siblings_are_selected, selected_items_without_siblings, user_response_sibling_deselect, selected_item_is_sibling

  siblings_are_selected = #selected_siblings > 0
  selected_items_without_siblings = {}

  if siblings_are_selected then
    user_response_sibling_deselect = reaper.ShowMessageBox(_constant.brand.name .. " can only " .. action .. " one pool instance at a time. Press OK to deselect any Sibling superitems and " .. action .. ", or Cancel.", "Too many siblings selected", _constant.api.msg.type.ok_cancel)

    if user_response_sibling_deselect == _constant.api.msg.response.ok then

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

      _common().selectDeselectItems(selected_siblings, false)

      return selected_items_without_siblings

    else

      return false
    end

  elseif not siblings_are_selected then

    return selected_items
  end
end


function Init.checkItemsOffscreen(items, item_type)
  local this_item, this_selected_item_is_before_arrange_view, this_selected_item_is_after_arrange_view, offscreen_msg__text_start, offscreen_msg__text_end, offscreen_msg__text, items_offscreen_response

  if items then

    for i = 1, #items do
      this_item = items[i]
      this_selected_item_is_before_arrange_view, this_selected_item_is_after_arrange_view, offscreen_msg__text_start, offscreen_msg__text_end = Init.getOffscreenItemParams(this_item)

      if this_selected_item_is_before_arrange_view or this_selected_item_is_after_arrange_view then

        if item_type == "selected" then
          offscreen_msg__text = _constant.brand.name .. ": " .. offscreen_msg__text_start .. item_type .. offscreen_msg__text_end
          items_offscreen_response = reaper.ShowMessageBox(offscreen_msg__text .. " Select OK to continue with the items selected or Cancel to abort.", "Items selected offscreen", _constant.api.msg.type.ok_cancel)

          if items_offscreen_response == _constant.api.msg.response.ok then

            return false

          else

            return true
          end

        elseif item_type == "restored" then
          offscreen_msg__text = offscreen_msg__text_start .. item_type .. offscreen_msg__text_end

          reaper.ShowMessageBox(offscreen_msg__text, "Warning: Offscreen items", _constant.api.msg.type.ok)

          break
        end
      end
    end
  end
end


function Init.getOffscreenItemParams(item)
  local item_position, item_length, item_end_point,  arrange_start_time, arrange_end_time, item_is_before_arrange_view, item_is_after_arrange_view, offscreen_msg__text_start, offscreen_msg__text_end

  item_position = reaper.GetMediaItemInfo_Value(item, _constant.api.item.key.position)
  item_length = reaper.GetMediaItemInfo_Value(item, _constant.api.item.key.length)
  item_end_point = item_position + item_length
  arrange_start_time, arrange_end_time = reaper.GetSet_ArrangeView2(_constant.api.current_project, false, 0, 0)
  item_is_before_arrange_view = item_position < arrange_start_time
  item_is_after_arrange_view = item_end_point > arrange_end_time
  offscreen_msg__text_start = "One or more "
  offscreen_msg__text_end = " items extend(s) beyond the current visible Arrange window view."

  return item_is_before_arrange_view, item_is_after_arrange_view, offscreen_msg__text_start, offscreen_msg__text_end
end


function Init.setResetUsersItemSelection(set_reset)
  local set, reset, selected_items_count, this_selected_item

  set = set_reset == "set"
  reset = set_reset == "reset"

  if set then
    _state.user.item_selection = {}
    selected_items_count = reaper.CountSelectedMediaItems(_constant.api.current_project)

    for i = 0, selected_items_count-1 do
      this_selected_item = reaper.GetSelectedMediaItem(_constant.api.current_project, i)

      table.insert(_state.user.item_selection, this_selected_item)
    end

  elseif reset then
    reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)

    for i = 1, #_state.user.item_selection do
      reaper.SetMediaItemSelected(_state.user.item_selection[i], true)
    end

    reaper.UpdateArrange()
  end
end


function Init.saveRecallUsersTrackSelection(save_recall)
  local save, recall, selected_tracks_count, this_selected_track

  save = save_recall == "save"
  recall = save_recall == "recall"

  if save then
    _state.user.track_selection = {}
    selected_tracks_count = reaper.CountSelectedTracks(_constant.api.current_project)

    for i = 0, selected_tracks_count-1 do
      this_selected_track = reaper.GetSelectedTrack(_constant.api.current_project, i)
      table.insert(_state.user.track_selection, this_selected_track)
    end

  elseif recall then
    reaper.Main_OnCommand(_constant.cmd.deselect_all_tracks, _constant.api.cmd_flag)

    for i = 1, #_state.user.track_selection do
      reaper.SetTrackSelected(_state.user.track_selection[i], true)
    end
  end
end


function Init.getFirstParentPoolIdFromSelectedItems(user_selected_items_on_this_track)
  local this_item, this_item_parent_pool_id, this_item_has_stored_parent_pool_id

  for i = 1, #user_selected_items_on_this_track do
    this_item = user_selected_items_on_this_track[i]
    this_item_parent_pool_id = _data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)
    this_item_has_stored_parent_pool_id = this_item_parent_pool_id and this_item_parent_pool_id ~= ""

    if this_item_has_stored_parent_pool_id then

      return this_item_parent_pool_id
    end
  end

  return false
end


function Init.selectedItemsAreInvalid(selected_items, action_text)

  if Init.superitemSelectionIsInvalid(selected_items, action_text) or
  _midi().pureMidiItemIsSelected(selected_items) then

      return true
  end
end


function Init.superitemSelectionIsInvalid(selected_items, action)
  local selected_item_groups, superitems, restored_items, siblings_are_selected, recursive_superitem_is_being_glued

  selected_item_groups = _common().getSuperglueItemTypes(selected_items, {"superitem", "restored"})
  superitems = selected_item_groups.superitem.items
  restored_items = selected_item_groups.restored.items
  recursive_superitem_is_being_glued = Init.recursiveSuperitemIsBeingGlued(superitems, restored_items) == true

  if recursive_superitem_is_being_glued then return true end
end


function Init.getFirstSelectedItem()

  return reaper.GetSelectedMediaItem(_constant.api.current_project, 0)
end


function Init.recursiveSuperitemIsBeingGlued(superitems, restored_items)
  local this_superitem, this_superitem_instance_pool_id, this_restored_item, this_restored_item_parent_pool_id, this_restored_item_is_from_same_pool_as_selected_superitem

  for i = 1, #superitems do
    this_superitem = superitems[i]
    this_superitem_instance_pool_id = _data.storeRetrieveItemData(this_superitem, _constant.data.key.suffix.pool.instance_id)

    for j = 1, #restored_items do
      this_restored_item = restored_items[j]
      this_restored_item_parent_pool_id = _data.storeRetrieveItemData(this_restored_item, _constant.data.key.suffix.pool.parent_id)
      this_restored_item_is_from_same_pool_as_selected_superitem = this_superitem_instance_pool_id == this_restored_item_parent_pool_id

      if this_restored_item_is_from_same_pool_as_selected_superitem then
        reaper.ShowMessageBox(_constant.brand.name .. " can't glue a Superitem to an instance from the same pool being Edited – that could destroy the universe! Change the items selected and try again.", "Recursive Superitem warning", _constant.api.msg.type.ok)
        Init.setResetUsersItemSelection("reset")

        return true
      end
    end
  end
end


function Init.throwOfflineTakeWarning(recommend_undo, is_restored_item)
  local msg, item_string

  msg = _constant.brand.name .. ": Your " .. item_string .. "'s inactive takes are empty, offline or have some other weird setting going on. "
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

  reaper.ShowMessageBox(msg, "Warning: Offline takes", _constant.api.msg.type.ok)
end


function Init.cleanUpAction(action, pool_ids)
  local undo_block_string, pool_ids_string

  undo_block_string = _constant.brand.name .. " " .. action
  pool_ids_string = Init.getPoolIdsforUndoString(pool_ids)

  if pool_ids_string then
    undo_block_string = undo_block_string .. " - Pool #" .. pool_ids_string
  end

  if _constant.support.fixed_lanes then
    Init.saveRecallUsersTrackSelection("recall")
  end

  Init.refreshUI()
  reaper.Undo_EndBlock(undo_block_string, _constant.api.include_all_undo_states)
end


function Init.getPoolIdsforUndoString(pool_ids_changed)
  local pool_ids_for_string

  pool_ids_for_string = {}

  for i = 1, #pool_ids_changed do

    if pool_ids_changed[i] then
      table.insert(pool_ids_for_string, pool_ids_changed[i])
    end
  end

  pool_ids_for_string = _util.stringifyArray(pool_ids_for_string)

  return pool_ids_for_string
end


function Init.refreshUI()
  reaper.PreventUIRefresh(-1)
  reaper.UpdateTimeline()
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(true)
end


function Init.getSmartAction(user_selected_items_on_this_track)
  local global_option_toggle_multiitem_editing_enabled, smart_action, user_response_disable_multiitem_option

  global_option_toggle_multiitem_editing_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.multiitem_editing)

  if global_option_toggle_multiitem_editing_enabled == "true" then
    user_response_disable_multiitem_option = reaper.ShowMessageBox('Smart Action cannot run when the option "Enable multi-item Edit, Unglue, or DePool in single action" is enabled. Would you like to disable this option and run the Smart Action?', "Smart Action not allowed", _constant.api.msg.type.ok_cancel)

    if user_response_disable_multiitem_option == _constant.api.msg.response.ok then
      _options.updateOptionValue("multiitem_editing", false)

    else

      return false
    end
  end

  smart_action = Init.calculateSmartAction(user_selected_items_on_this_track)

  return smart_action
end


function Init.calculateSmartAction(user_selected_items_on_this_track)
  local selected_item_groups, parent_instances_count, no_parent_instances_are_selected, single_parent_instance_is_selected, parent_instances_are_selected, multiple_parent_instances_are_selected, nonsuperitems_count, no_nonsuperitems_are_selected, nonsuperitems_are_selected, child_instances_count, no_child_instances_are_selected, single_child_instance_is_selected, user_wants_to_edit_or_unglue, user_must_glue_or_abort, user_wants_to_glue

  selected_item_groups = _common().getSuperglueItemTypes(user_selected_items_on_this_track, {"nonsuperitem", "child_instance", "parent_instance"})
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



return Init
