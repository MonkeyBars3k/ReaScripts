-- @noindex

local Depool = {}

local loadDependencies, loadCircularDependencies, _common, _constant, _data, _edit, _state, _module_utils, _glue, _single


loadDependencies = (function()
  _common = require("modules.common")
  _constant = require("modules.constant")
  _data = require("modules.data")
  _edit = require("modules.edit")
  _state = require("modules.state")

  _module_utils = require("module-utils")
end)()


loadCircularDependencies = (function()
  _glue = function() return _module_utils.lazyRequire("glue") end
  _single = function() return _module_utils.lazyRequire("single") end
end)()



function Depool.dePoolSuperitems(user_selected_items_on_this_track, this_user_selected_items_track, action)
  local superitems, this_superitem, this_superitem_params, this_superitem_state, this_superitem_instance_pool_id, superitem, new_pool_id

  superitems = _single().setUpSingleTrackEditOrUnglueOrDePool(user_selected_items_on_this_track)
  _state.action.glue.current_track = this_user_selected_items_track

  for i = 1, #superitems do
    this_superitem = superitems[i]
    this_superitem_params, this_superitem_state, this_superitem_instance_pool_id = Depool.setUpDePool(this_superitem)
    this_superitem_params.pool_id = _edit.processUnglue(this_superitem, this_superitem_instance_pool_id, action)
    superitem = _glue().handleGlue(_state.action.edit_or_unglue.restored_items, nil, nil, this_superitem_params, false)
    new_pool_id = Depool.handleDePoolPostGlue(superitem, this_superitem_state, this_superitem_params)

    table.insert(_state.action.glue.all_glued_superitems, superitem)
    table.insert(_state.action.depool.new_pool_ids, new_pool_id)
  end
end


function Depool.dePoolRestoredItems(user_selected_items_on_this_track, this_user_selected_items_track)
  local selected_item_groups, restored_items

  selected_item_groups = _common.getSuperglueItemTypes(user_selected_items_on_this_track, {"restored"})
  restored_items = selected_item_groups.restored.items
  _state.action.glue.current_track = this_user_selected_items_track

  for i = 1, #restored_items do
    _common.dePoolRestoredItem(restored_items[i])
  end
end


function Depool.handleDePoolSibling(active_pool_sibling)
  local global_option_toggle_depool_all_siblings_on_reglue_warning, global_option_toggle_depool_all_siblings_on_reglue

  global_option_toggle_depool_all_siblings_on_reglue_warning = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.depool_all_siblings_on_reglue_warning)

  if global_option_toggle_depool_all_siblings_on_reglue_warning == "true" and _state.user.wants_to_depool_all_siblings == nil then
    _state.user.wants_to_depool_all_siblings = reaper.ShowMessageBox("You have the option to remove all sibling instances from pool enabled. Select yes to continue and remove all of this item's siblings from its pool, or no to disable this option.", "Warning: Remove all siblings?", _constant.api.msg.type.yes_no)

    if _state.user.wants_to_depool_all_siblings == _constant.api.msg.response.no then
      reaper.SetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.depool_all_siblings_on_reglue, "false", _constant.api.extstate.persist_enabled)

      return "false"

    elseif _state.user.wants_to_depool_all_siblings == _constant.api.msg.response.yes then
      reaper.SetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.depool_all_siblings_on_reglue_warning, "false", _constant.api.extstate.persist_enabled)
    end
  end

  Depool.processSiblingDePool(active_pool_sibling)

  return global_option_toggle_depool_all_siblings_on_reglue
end


function Depool.refreshCurrentPoolStoredItemsPostDePool()
  local this_restored_item_exists, all_items_count, this_item, this_item_parent_pool_id, this_item_belongs_to_current_pool

  for i = 1, #_state.superitem.params.fresh_glue.current_pool.restored_items do
  this_restored_item_exists = reaper.ValidatePtr(_state.superitem.params.fresh_glue.current_pool.restored_items[i], _constant.api.datatype.mediaitem)

  if not this_restored_item_exists then
    _state.superitem.params.fresh_glue.current_pool.restored_items = {}
    all_items_count = reaper.CountMediaItems(_constant.api.current_project)

    for j = 0, all_items_count-1 do
      this_item = reaper.GetMediaItem(_constant.api.current_project, j)
      this_item_parent_pool_id = _data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)
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


function Depool.processSiblingDePool(sibling)
  local action, sibling_params, sibling_state, sibling_instance_pool_id, pool_id, restored_items, contained_item_states, superitem, new_pool_id

  action = "DePool"
  sibling_params, sibling_state, sibling_instance_pool_id = Depool.setUpDePool(sibling)
  _state.action.glue.current_track = reaper.BR_GetMediaTrackByGUID(_constant.api.current_project, sibling_params.track_guid)
  pool_id, restored_items = _edit.processUnglue(sibling, sibling_params.pool_id, action)
  contained_item_states = _data.prepareAndGetItemStates(restored_items, sibling_params.pool_id)
  superitem = _glue().handleGlue(restored_items, nil, nil, sibling_params, false)
  new_pool_id = Depool.handleDePoolPostGlue(superitem, sibling_state, sibling_params)

  _data.storeItemStates(new_pool_id, contained_item_states)
end


function Depool.setUpDePool(target_item)
  local target_item_params, target_item_state, target_item_instance_pool_id

  target_item_params = _data.getSetItemParams(target_item)
  target_item_params.pool_id = _data.storeRetrieveItemData(target_item, _constant.data.key.suffix.pool.instance_id)

  -- Get original pool's position
  local original_pool_position = _data.storeRetrievePoolData(target_item_params.pool_id, _constant.data.key.suffix.pool.parent_position)
  original_pool_position = tonumber(original_pool_position)

  -- Store movement direction relative to original
  local movement_direction = target_item_params.position < original_pool_position and "earlier" or "later"
  _data.storeRetrievePoolData(target_item_params.pool_id, "depool_movement_direction", movement_direction)

  target_item_state = _data.getSetItemStateChunk(target_item)
  target_item_instance_pool_id = target_item_params.pool_id
  _state.restored_items.first_restored_item_last_glue_delta_to_parent = _data.storeRetrievePoolData(target_item_instance_pool_id, _constant.data.key.suffix.superitem.first_child_delta_to_superitem_position)

  return target_item_params, target_item_state, target_item_instance_pool_id
end


function Depool.handleDePoolPostGlue(superitem, target_item_state, target_item_params)
  local superitem_active_take, active_take_name, updated_src, new_pool_id

  superitem_active_take = reaper.GetActiveTake(superitem)
  active_take_name = _common.getSetItemName(superitem)
  updated_src = _common.getSetWipeItemAudioSrc(superitem)
  new_pool_id = _data.storeRetrieveItemData(superitem, _constant.data.key.suffix.pool.instance_id)

  _data.storeRetrievePoolData(new_pool_id, _constant.data.key.suffix.superitem.first_child_delta_to_superitem_position, _state.restored_items.first_restored_item_last_glue_delta_to_parent)
  _data.storeRetrievePoolData(new_pool_id, _constant.actionstep.freshly_depooled_superitem_flag, "true")
  _data.getSetItemStateChunk(superitem, target_item_state)
  _common.getSetItemName(superitem, active_take_name)
  _data.storeRetrieveItemData(superitem, _constant.data.key.suffix.pool.instance_id, new_pool_id)
  _common.refreshActiveTakeFlag(superitem, superitem_active_take, new_pool_id)
  reaper.SetMediaItemSelected(superitem, true)
  _common.setSuperitemColor()

  return new_pool_id
end



return Depool
