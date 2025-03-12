-- @noindex

local Data = {}

local loadDependencies, loadCircularDependencies, serpent, _constant, _state, _module_utils, _common, _glue


loadDependencies = (function()
  serpent = require("lib.serpent")
  _constant = require("modules.constant")
  _state = require("modules.state")
  -- local _dev = require("modules.dev")

  _module_utils = require("module-utils")
end)()


loadCircularDependencies = (function()
  _common = function() return _module_utils.lazyRequire("common") end
  _glue = function() return _module_utils.lazyRequire("glue") end
end)()



function Data.storeRetrieveProjectData(key, val)
  local retrieve, store, store_or_retrieve_state_data, data_param_key, retval, state_data_val

  retrieve = not val
  store = val

  if retrieve then
    val = ""
    store_or_retrieve_state_data = false

  elseif store then
    store_or_retrieve_state_data = true
  end

  data_param_key = _constant.api.data_key .. _constant.brand.prefix.global .. key
  retval, state_data_val = reaper.GetSetMediaTrackInfo_String(_constant.data.storage_track, data_param_key, val, store_or_retrieve_state_data)

  return retval, state_data_val
end


function Data.storeRetrievePoolData(pool_id, key_suffix, new_value)
  local is_store, is_retrieve, key, retval, stored_value

  is_store = new_value
  is_retrieve = not new_value
  key = _constant.data.key.prefix.pool .. pool_id .. key_suffix

  if is_store then
    Data.storeRetrieveProjectData(key, new_value)

  elseif is_retrieve then
    retval, stored_value = Data.storeRetrieveProjectData(key)
  end

  return stored_value
end


function Data.storeRetrieveItemData(item, key_suffix, val)
  local retrieve, store, data_param_key, retval

  retrieve = not val
  store = val
  data_param_key = _constant.api.data_key .. _constant.brand.prefix.global .. key_suffix

  if retrieve then
    retval, val = reaper.GetSetMediaItemInfo_String(item, data_param_key, "", false)

    return val

  elseif store then
    reaper.GetSetMediaItemInfo_String(item, data_param_key, val, _constant.api.set_value)
  end
end


function Data.prepareAndGetItemStates(items, active_pool_id)
  local selected_item_states, selected_items_pool_params, item, this_item, this_item_instance_pool_id, this_item_parent_pool_id, this_item_guid, this_item_state

  selected_item_states = {}
  selected_items_pool_params = {}

  for i, item in ipairs(items) do
    this_item = items[i]
    this_item_instance_pool_id = Data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.instance_id)
    this_item_parent_pool_id = Data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)

    if not this_item_instance_pool_id or this_item_instance_pool_id == "" then
      this_item_instance_pool_id = _constant.noninstance_label .. i
    end

    _glue().convertMidiItemToAudio(this_item)

    this_item_guid = reaper.BR_GetMediaItemGUID(item)
    this_item_state = Data.getSetItemStateChunk(this_item)
    selected_item_states[this_item_guid] = this_item_state
    selected_items_pool_params[this_item_instance_pool_id] = {
      parent_pool_id = this_item_parent_pool_id,
      position = reaper.GetMediaItemInfo_Value(this_item, _constant.api.item.key.position)
    }
  end

  return selected_item_states, selected_items_pool_params, this_item_instance_pool_id
end


function Data.getSetItemStateChunk(item, state)
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


function Data.storeItemStates(pool_id, item_states_table)
  item_states_table = serpent.dump(item_states_table)

  Data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.contained_item_states, item_states_table)
end


function Data.getSetItemParams(item, params)
  local get, set, track, retval, track_guid, active_take, active_take_num, item_params

  get = not params
  set = params

  if get then
    track = reaper.GetMediaItemTrack(item)
    retval, track_guid = reaper.GetSetMediaTrackInfo_String(track, _constant.api.take.key.guid, "", _constant.api.get_value)
    active_take = reaper.GetActiveTake(item)

    if active_take then
      active_take_num = reaper.GetMediaItemTakeInfo_Value(active_take, _constant.api.take.key.number)
    end

    item_params = {
      item_guid = reaper.BR_GetMediaItemGUID(item),
      state = Data.getSetItemStateChunk(item),
      track_guid = track_guid,
      active_take_num = active_take_num,
      position = reaper.GetMediaItemInfo_Value(item, _constant.api.item.key.position),
      length = reaper.GetMediaItemInfo_Value(item, _constant.api.item.key.length),
      instance_pool_id = Data.storeRetrieveItemData(item, _constant.data.key.suffix.pool.instance_id),
      parent_pool_id = Data.storeRetrieveItemData(item, _constant.data.key.suffix.pool.parent_id)
    }
    item_params.end_point = item_params.position + item_params.length

    if active_take then
      item_params.source_offset = reaper.GetMediaItemTakeInfo_Value(active_take, _constant.api.take.key.src_offset)
    end

    return item_params

  elseif set then
    reaper.SetMediaItemInfo_Value(item, _constant.api.item.key.position, params.position)
    reaper.SetMediaItemInfo_Value(item, _constant.api.item.key.length, params.length)
  end
end


function Data.storeRetrieveSuperitemParams(pool_id, action_step, superitem)
  local retrieve, store, superitem_params_key_label, retval, superitem_params

  retrieve = not superitem
  store = superitem
  superitem_params_key_label = _constant.data.key.prefix.pool .. pool_id .. _constant.brand.separator .. action_step .. _constant.data.key.suffix.superitem.params

  if retrieve then
    retval, superitem_params = Data.storeRetrieveProjectData(superitem_params_key_label)
    retval, superitem_params = serpent.load(superitem_params)

    if superitem_params then
      superitem_params.track = reaper.BR_GetMediaTrackByGUID(_constant.api.current_project, superitem_params.track_guid)
    end

    return superitem_params

  elseif store then
    superitem_params = Data.getSetItemParams(superitem)
    superitem_params = serpent.dump(superitem_params)

    Data.storeRetrieveProjectData(superitem_params_key_label, superitem_params)
  end
end


function Data.cleanUnselectedRestoredItemsFromPool(pool_id)
  local all_items_count, this_item, this_item_is_selected, this_item_parent_pool_id

  all_items_count = reaper.CountMediaItems(_constant.api.current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_constant.api.current_project, i)
    this_item_is_selected = reaper.IsMediaItemSelected(this_item)

    if not this_item_is_selected then

      this_item_parent_pool_id = Data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)

      if this_item_parent_pool_id == pool_id then
        _common().dePoolRestoredItem(this_item)
      end
    end
  end
end


function Data.restoreSuperitemState(superitem, superitem_params)
  local superitem_preglue_state_key_label, retval, superitem_last_glue_state, superitem_active_take

  superitem_preglue_state_key_label = _constant.data.key.prefix.pool .. superitem_params.pool_id .. _constant.data.key.suffix.preglue.superitem_state
  retval, superitem_last_glue_state = Data.storeRetrieveProjectData(superitem_preglue_state_key_label)
  superitem_active_take = reaper.GetActiveTake(superitem)

  if retval == true and superitem_last_glue_state then
    Data.getSetItemStateChunk(superitem, superitem_last_glue_state)
    _common().getSetWipeItemAudioSrc(superitem, superitem_params.updated_src)
    Data.getSetItemParams(superitem, superitem_params)
    reaper.SetMediaItemTakeInfo_Value(superitem_active_take, _constant.api.take.key.src_offset, superitem_params.source_offset)
  end

  return superitem
end


function Data.getStoredItemStatesTable(pool_id, action)
  local this_is_unglue, this_is_depool, retval, stored_item_states_table, stored_item_states

  this_is_unglue = action == "Unglue"
  this_is_depool = action == "DePool"

  if (this_is_unglue or this_is_depool) and _state.restored_items.preglue_restored_item_states then
    retval, stored_item_states_table = serpent.load(_state.restored_items.preglue_restored_item_states)

  else
    stored_item_states = Data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.contained_item_states)
    stored_item_states_table = Data.retrieveStoredItemStates(stored_item_states)
  end

  return stored_item_states_table
end


function Data.retrieveStoredItemStates(item_state_chunks_string)
  local retval, item_state_chunks_table

  retval, item_state_chunks_table = serpent.load(item_state_chunks_string)
  item_state_chunks_table.track = reaper.BR_GetMediaTrackByGUID(_constant.api.current_project, item_state_chunks_table.track_guid)

  return item_state_chunks_table
end


function Data.defineStoredItemsParams(pool_id)
  _state.restored_items.first_restored_item_last_glue_delta_to_parent = Data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.superitem.first_child_delta_to_superitem_position)
  _state.superitem.this_previously_depooled_superitem_has_not_been_edited = Data.storeRetrievePoolData(pool_id, _constant.actionstep.freshly_depooled_superitem_flag)
  _state.superitem.params.post_glue.edited_pool = Data.storeRetrieveSuperitemParams(pool_id, _constant.actionstep.postglue)

  if not _state.superitem.params.preedit.edited_pool then
    _state.superitem.params.preedit.edited_pool = Data.storeRetrieveSuperitemParams(pool_id, _constant.actionstep.preedit)
  end

  if not _state.restored_items.first_restored_item_last_glue_delta_to_parent or _state.restored_items.first_restored_item_last_glue_delta_to_parent == "" then
    _state.restored_items.first_restored_item_last_glue_delta_to_parent = 0
  end
end



return Data
