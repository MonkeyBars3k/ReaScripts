-- @noindex

local Multi = {}


local loadDependencies, loadCircularDependencies, serpent, _common, _constant, _data, _overglue, _state, _util, _module_utils, _init, _single

-- local _dev = require("modules.dev")

loadDependencies = (function()
  serpent = require("lib.serpent")
  _common = require("modules.common")
  _constant = require("modules.constant")
  _data = require("modules.data")
  _overglue = require("modules.overglue")
  _state = require("modules.state")
  _util = require("modules.util")

  _module_utils = require("module-utils")
end)()


loadCircularDependencies = (function()
  _init = function() return _module_utils.lazyRequire("init") end
  _single = function() return _module_utils.lazyRequire("single") end
end)()



function Multi.setUpMultiTrackActions(selected_items, action)
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

  all_tracks_with_user_selected_items = Multi.handleMultiitemCases(all_tracks_with_user_selected_items, action)

  if not all_tracks_with_user_selected_items then return false end

  if not Multi.iterateTracksWithSelectedItems(all_tracks_with_user_selected_items, action) then return false end

  return true
end


function Multi.handleMultiitemCases(all_tracks_with_user_selected_items, action)
  local global_option_toggle_multiitem_editing_enabled, multiitem_result, user_wants_to_affect_1st_superitem, user_selected_items_on_this_track

  if action == "Edit" or action == "Unglue" or action == "DePool" then

    for i = 1, #all_tracks_with_user_selected_items do

      if #all_tracks_with_user_selected_items[i].items > 1 then
        global_option_toggle_multiitem_editing_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.multiitem_editing)

        if global_option_toggle_multiitem_editing_enabled ~= "true" then
          multiitem_result = reaper.ShowMessageBox('The option "Multi-item Edit, Unglue, or DePool in single action" is disabled, but more than one item is selected on one or more tracks. Would you like to ' .. action .. ' the first selected superitem on each track only?', "Multiple items selected", _constant.api.msg.type.ok_cancel)
          user_wants_to_affect_1st_superitem = multiitem_result == _constant.api.msg.response.ok

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


function Multi.iterateTracksWithSelectedItems(all_tracks_with_user_selected_items, action)
  local this_user_selected_items_track, user_selected_items_on_this_track

  for i = 1, #all_tracks_with_user_selected_items do
    this_user_selected_items_track = all_tracks_with_user_selected_items[i].track
    user_selected_items_on_this_track = all_tracks_with_user_selected_items[i].items

    if action == "Glue" then
      Multi.doSingleTrackGlue(user_selected_items_on_this_track, this_user_selected_items_track)

    elseif action == "Edit" or action == "Unglue" then
      _single().doSingleTrackEditOrUnglue(user_selected_items_on_this_track, action)

    elseif action == "DePool" then
      _single().doSingleTrackDePool(user_selected_items_on_this_track, this_user_selected_items_track, action)

    elseif action == "Smart Glue/Edit" or action == "Smart Glue/Unglue" then

      if not _single().doSingleTrackSmartAction(user_selected_items_on_this_track, this_user_selected_items_track, action) then return false end
    end
  end

  return true
end


-- removed a call at end to select glued items because such is already getting called in _init().completeGlueOrDePool()
function Multi.doSingleTrackGlue(user_selected_items_on_this_track, this_user_selected_items_track)
  local global_option_toggle_multiitem_editing_enabled, restored_items_pool_id

  _state.action.glue.current_track = this_user_selected_items_track
  global_option_toggle_multiitem_editing_enabled = reaper.GetExtState(_constant.data.key.options.global_section, _constant.data.key.options.toggle.multiitem_editing)

  _init().copySuperglueItemImagesToProject()

  if global_option_toggle_multiitem_editing_enabled == "true" then
    Multi.doSingleTrackMultiitemGlue(user_selected_items_on_this_track)

  else
    restored_items_pool_id = _init().getFirstParentPoolIdFromSelectedItems(user_selected_items_on_this_track)

    _single().triggerSingleTrackSinglePoolGlue(user_selected_items_on_this_track, restored_items_pool_id)
  end
end


function Multi.doSingleTrackMultiitemGlue(user_selected_items_on_this_track)
  local pool_ids_by_depth

  _state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor, pool_ids_by_depth = Multi.getPoolIdsFromItems(user_selected_items_on_this_track, "parent", "descendant to ancestor")

  if not _state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor then
    _single().triggerSingleTrackSinglePoolGlue(user_selected_items_on_this_track)

  else
    Multi.handleSingleTrackMultiPoolGlue(user_selected_items_on_this_track, pool_ids_by_depth)
  end
end


function Multi.getPoolIdsFromItems(items, type, sort_order)
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
      this_item_pool_id = _data.storeRetrieveItemData(this_item, type_key_suffix)
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
      this_item_pool_id = _data.storeRetrieveItemData(this_item, type_key_suffix)

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
      pool_ids_from_items = _util.deduplicateTable(pool_ids_from_items)
      pool_ids_by_depth = Multi.getPoolIdNestedDepths(pool_ids_from_items)
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


function Multi.getPoolIdNestedDepths(pool_ids)
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
      this_pool_id__descendant_pool_ids = _data.storeRetrievePoolData(this_pool_id, _constant.data.key.suffix.pool.descendant_ids)
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


function Multi.handleSingleTrackMultiPoolGlue(user_selected_items_on_this_track, pool_ids_by_depth)
  local this_is_single_reglue, this_is_overglue, superitem, selected_items_on_this_track__post_glue

  this_is_single_reglue = #_state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor == 1
  this_is_overglue = #_state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor > 1

  if this_is_single_reglue then
    superitem = _single().triggerSingleTrackSinglePoolGlue(user_selected_items_on_this_track, _state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor[1])
    selected_items_on_this_track__post_glue = {superitem}

  elseif this_is_overglue then
    selected_items_on_this_track__post_glue = _overglue.doOverglue(user_selected_items_on_this_track, pool_ids_by_depth)
  end

  reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)
  _common.selectDeselectItems(selected_items_on_this_track__post_glue, true)
end






return Multi
