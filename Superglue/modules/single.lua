-- @noindex

local Single = {}


local _module_utils = require("module-utils")

local _common = require("modules.common")
local _constant = require("modules.constant")
local _data = require("modules.data")
local _depool = require("modules.depool")
local _edit = require("modules.edit")
local _glue = require("modules.glue")
local _init = require("modules.init")
-- local _multi = require("modules.multi")
local _state = require("modules.state")

local function _multi() return _module_utils.lazyRequire("multi") end



function Single.triggerSingleTrackSinglePoolGlue(items_to_glue, restored_items_pool_id)
  local this_is_reglue, superitem

  this_is_reglue = restored_items_pool_id

  if this_is_reglue then
    superitem = _glue.handleReglue(items_to_glue, restored_items_pool_id)

  else
    superitem = _glue.handleGlue(items_to_glue, nil, nil, nil, nil)
  end

  if superitem then
    table.insert(_state.action.glue.all_glued_superitems, superitem)
    table.insert(_state.action.glue.changed_pool_ids, _state.pool.active_glue_pool_id)
  end

  return superitem
end


function Single.doSingleTrackEditOrUnglue(user_selected_items_on_this_track, action)
  local superitems = Single.setUpSingleTrackEditOrUnglueOrDePool(user_selected_items_on_this_track)

  for i = 1, #superitems do
    local this_superitem = superitems[i]
    local this_pool_id = _data.storeRetrieveItemData(this_superitem, _constant.data.key.suffix.pool.instance_id)

    local other_instance_being_edited = Single.otherInstanceIsOpen(this_pool_id)
    if other_instance_being_edited then
      Single.handleOtherInstanceBeingEdited(other_instance_being_edited, this_pool_id, action)
      return
    end

    local superitem_is_multitake, superitem_takes_count = Single.superitemHasMultipleTakes(this_superitem)
    if superitem_is_multitake then
      local multitake_msg__user_response = Single.handleMultitakeSuperitem(superitem_takes_count)
      if multitake_msg__user_response == "cancel" then return end
    end

    if _edit.handleEditOrUnglue(this_superitem, this_pool_id, action) ~= false then
      table.insert(_state.action.edit.changed_pool_ids, this_pool_id)
    end
  end
end


function Single.otherInstanceIsOpen(edit_pool_id)
  local all_items_count, this_item, restored_item_pool_id

  all_items_count = reaper.CountMediaItems(_constant.api.current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_constant.api.current_project, i)
    restored_item_pool_id = _data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)

    if restored_item_pool_id == edit_pool_id then

      return this_item
    end
  end
end


function Single.doSingleTrackDePool(user_selected_items_on_this_track, this_user_selected_items_track, action)
  local superitems, selected_item_groups, restored_items, this_superitem, this_superitem_params, this_superitem_state, this_superitem_instance_pool_id, superitem, new_pool_id

  superitems = Single.setUpSingleTrackEditOrUnglueOrDePool(user_selected_items_on_this_track)
  selected_item_groups = _common.getSuperglueItemTypes(user_selected_items_on_this_track, {"restored"})
  restored_items = selected_item_groups.restored.items
  _state.action.glue.current_track = this_user_selected_items_track

  for i = 1, #superitems do
    this_superitem = superitems[i]
    this_superitem_params, this_superitem_state, this_superitem_instance_pool_id = _depool.setUpDePool(this_superitem)
    this_superitem_params.pool_id = _edit.processUnglue(this_superitem, this_superitem_instance_pool_id, action)
    superitem = _glue.handleGlue(_state.action.edit_or_unglue.restored_items, nil, nil, this_superitem_params, false)
    new_pool_id = _depool.handleDePoolPostGlue(superitem, this_superitem_state, this_superitem_params)

    table.insert(_state.action.glue.all_glued_superitems, superitem)
    table.insert(_state.action.depool.new_pool_ids, new_pool_id)
  end

  for i = 1, #restored_items do
    _common.dePoolRestoredItem(restored_items[i])
  end
end


function Single.setUpSingleTrackEditOrUnglueOrDePool(user_selected_items_on_this_track)
  local superglue_item_types, selected_item_groups, superitems

  superglue_item_types = {"superitem"}
  selected_item_groups = _common.getSuperglueItemTypes(user_selected_items_on_this_track, superglue_item_types)
  superitems = selected_item_groups.superitem.items

  return superitems
end


function Single.doSingleTrackSmartAction(user_selected_items_on_this_track, this_user_selected_items_track, action)
  local smart_action, glue_abort_dialog

  smart_action = _init.getSmartAction(user_selected_items_on_this_track)

  if smart_action == "glue" then
    _multi.doSingleTrackGlue(user_selected_items_on_this_track, this_user_selected_items_track, action)

  elseif smart_action == "edit_or_unglue" then
    Single.doSingleTrackEditOrUnglue(user_selected_items_on_this_track, action)

  elseif smart_action == "glue/abort" then
    glue_abort_dialog = reaper.ShowMessageBox("You have selected both Superitem(s) and restored item(s) from an edited Superitem. Are you sure you want to Superglue them?", "Mixed " .. _constant.brand.name .. "items selected", _constant.api.msg.type.ok_cancel)

    if glue_abort_dialog == _constant.api.msg.response.cancel then
      _init.setResetUsersItemSelection(false)

      return false

    else
      _multi.doSingleTrackGlue(user_selected_items_on_this_track, this_user_selected_items_track, action)
      _common.selectDeselectItems(_state.action.glue.all_glued_superitems, true)
    end

  else

    return false
  end

  return true
end


function Single.handleOtherInstanceBeingEdited(instance_being_edited, instance_being_edited_pool_id, action)
  instance_being_edited_pool_id = tostring(instance_being_edited_pool_id)

  reaper.ShowMessageBox(_constant.brand.name .. " can only " .. action .. " one superitem pool instance at a time. Reglue the other open instance from Pool " .. instance_being_edited_pool_id .. " before trying to " .. action .. " this superitem. It will be selected and scrolled to now.", "Pool already being edited", _constant.api.msg.type.ok)
  reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)
  reaper.SetMediaItemSelected(instance_being_edited, true)
  reaper.Main_OnCommand(_constant.cmd.scroll_to_selected_item, _constant.api.cmd_flag)
end


function Single.superitemHasMultipleTakes(superitem)
  local superitem_takes_count

  superitem_takes_count = reaper.GetMediaItemNumTakes(superitem)

  if superitem_takes_count > 1 then

    return true, superitem_takes_count
  end
end


function Single.handleMultitakeSuperitem(superitem_takes_count)
  local user_wants_to_explode_superitem_takes, user_response_explode_in_order, superitem, superitem_active_take

  user_wants_to_explode_superitem_takes = reaper.ShowMessageBox("The Superitem selected has " .. superitem_takes_count .. " takes in it. " .. _constant.brand.name .. " does not support multiple takes on Superitems. Do you want to explode your Superitem takes before Editing?", "Superitem has multiple takes", _constant.api.msg.type.ok_cancel)

  if user_wants_to_explode_superitem_takes == _constant.api.msg.response.ok then
    user_response_explode_in_order = reaper.ShowMessageBox("Choose Yes to explode in order or No to explode in place.", "Do you want to explode in order?", _constant.api.msg.type.yes_no)

    superitem, superitem_active_take = Single.checkSuperitemTakesAreValid()

    if not superitem_active_take then

      return "cancel"
    end

    Single.explodeSuperitem(superitem--[[, superitem_active_take, user_response_explode_in_order]])

  elseif user_wants_to_explode_superitem_takes == _constant.api.msg.response.cancel then

    return "cancel"
  end
end


function Single.checkSuperitemTakesAreValid()
  local superitem, superitem_active_take

  superitem = _init.getFirstSelectedItem()
  superitem_active_take = reaper.GetActiveTake(superitem)

  if not superitem_active_take then
    _init.throwOfflineTakeWarning()

    return false
  end

  return superitem, superitem_active_take
end


-- function Single.explodeSuperitem(superitem, superitem_active_take, user_response_explode_in_order)
--   local user_wants_to_explode_in_order, superitem_takes_count, superitem_params, duplicated_item_target_take_num, item_data_values, i, offline_takes_msg__shown

--   superitem_takes_count, superitem_params, duplicated_item_target_take_num, item_data_values = Single.explodeSuperitem(superitem)

--   if user_response_explode_in_order == _constant.api.msg.response.yes then
--     user_wants_to_explode_in_order = true
--   end

--   for i = 0, superitem_takes_count-2 do
--     duplicated_item_target_take_num, offline_takes_msg__shown = Single.explodeSuperitemTakes(i, superitem, user_wants_to_explode_in_order, superitem_params, duplicated_item_target_take_num, item_data_values, offline_takes_msg__shown)
--   end

--   reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)
--   reaper.SetMediaItemSelected(superitem, true)
--   reaper.Main_OnCommand(_constant.cmd.crop_selected_items_to_active_takes, _constant.api.cmd_flag)
-- end


function Single.explodeSuperitem(superitem)
  local superitem_takes_count, superitem_params, duplicated_item_target_take_num, item_data_values, superitem_superglue_active_take_key, this_superitem_take, retval, this_superitem_take_active_flag

  superitem_takes_count = reaper.GetMediaItemNumTakes(superitem)
  superitem_params = _data.getSetItemParams(superitem)
  duplicated_item_target_take_num = 0
  item_data_values = {_constant.data.key.suffix.pool.instance_id, _constant.data.key.suffix.pool.parent_id, _constant.data.key.suffix.superitem.first_child_delta_to_superitem_position, _constant.data.key.suffix.preglue.active_take_guid}
  superitem_superglue_active_take_key = _constant.api.data_key .. _constant.brand.prefix.global .. _constant.data.key.prefix.pool .. superitem_params.instance_pool_id .. _constant.data.key.suffix.superitem.superglue_active_take
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


function Single.explodeSuperitemTakes(i, superitem, user_wants_to_explode_in_order, superitem_params, duplicated_item_target_take_num, item_data_values, offline_takes_msg__shown)
  local this_duplicated_item, this_duplicated_item_new_position, this_duplicated_item_new_active_take

  reaper.Main_OnCommand(_constant.cmd.duplicate_selected_items, _constant.api.cmd_flag)

  this_duplicated_item = _init.getFirstSelectedItem()
  this_duplicated_item_new_position = superitem_params.position

  if user_wants_to_explode_in_order then
    this_duplicated_item_new_position = this_duplicated_item_new_position + (superitem_params.length * (i + 1))
  end

  reaper.SetMediaItemPosition(this_duplicated_item, this_duplicated_item_new_position, _constant.api.dont_refresh_ui)

  for j = 1, #item_data_values do
    _data.storeRetrieveItemData(this_duplicated_item, item_data_values[j], "")
  end

  duplicated_item_target_take_num, this_duplicated_item_new_active_take, offline_takes_msg__shown = Single.handleDuplicatedItemTargetTake(i, this_duplicated_item, duplicated_item_target_take_num, superitem_params, offline_takes_msg__shown)

  Single.handleDuplicatedItemTargetTake(this_duplicated_item)
  _common.addRemoveItemImage(this_duplicated_item, false)
  reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)
  reaper.SetMediaItemSelected(superitem, true)

  return duplicated_item_target_take_num, offline_takes_msg__shown
end


-- function Single.handleDuplicatedItemTargetTake(i, this_duplicated_item, duplicated_item_target_take_num, superitem_params, offline_takes_msg__shown)
--   local this_duplicated_item_new_active_take, targeted_take_is_offline

--   duplicated_item_target_take_num = duplicated_item_target_take_num + i

--   if duplicated_item_target_take_num == superitem_params.superglue_active_take_num then
--     duplicated_item_target_take_num = duplicated_item_target_take_num + 1
--   end

--   this_duplicated_item_new_active_take = reaper.GetTake(this_duplicated_item, duplicated_item_target_take_num)
--   targeted_take_is_offline = not this_duplicated_item_new_active_take

--   if not targeted_take_is_offline then
--     reaper.SetActiveTake(this_duplicated_item_new_active_take)
--     reaper.Main_OnCommand(_constant.cmd.crop_selected_items_to_active_takes, _constant.api.cmd_flag)

--   elseif not offline_takes_msg__shown then
--     _init.throwOfflineTakeWarning(true)

--     offline_takes_msg__shown = true
--   end

--   return duplicated_item_target_take_num, this_duplicated_item_new_active_take, offline_takes_msg__shown
-- end


function Single.handleDuplicatedItemTargetTake(item)
  local active_take_name, superglue_name_prefix, new_take_name

  active_take_name = _common.getSetItemName(item)
  superglue_name_prefix = string.match(active_take_name, _constant.brand.prefix.superitem_name_default)

  if superglue_name_prefix then
    new_take_name = string.gsub(active_take_name, _constant.brand.prefix.superitem_name_default, "")

    _common.getSetItemName(item, new_take_name)
  end
end



return Single
