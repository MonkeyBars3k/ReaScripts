-- @noindex

local Ancestor = {}


local _dev = require("modules.dev")

local loadDependencies, loadCircularDependencies, serpent, _common, _constant, _data, _depool, _state, _util, _module_utils, _glue, _reglue


loadDependencies = (function()
  serpent = require("lib.serpent")
  _common = require("modules.common")
  _constant = require("modules.constant")
  _data = require("modules.data")
  _depool = require("modules.depool")
  _state = require("modules.state")
  _util = require("modules.util")

  _module_utils = require("module-utils")
end)()


loadCircularDependencies = (function()
  _glue = function() return _module_utils.lazyRequire("glue") end
  _reglue = function() return _module_utils.lazyRequire("reglue") end
end)()




function Ancestor.handleDescendantPoolReferences(pool_id, contained_items_pool_params)
  local this_pool_descendants, this_contained_item_instance_pool_id, this_contained_item_params, this_selected_item_is_superitem, this_child_pool_descendant_pool_ids, this_pool_descendants_string

  this_pool_descendants = {}

  for this_contained_item_instance_pool_id, this_contained_item_params in pairs(contained_items_pool_params) do
    this_selected_item_is_superitem = not string.find(this_contained_item_instance_pool_id, _constant.noninstance_label)

    if this_selected_item_is_superitem then
      this_child_pool_descendant_pool_ids = _data.storeRetrievePoolData(this_contained_item_instance_pool_id, _constant.data.key.suffix.pool.descendant_ids)

      table.insert(this_pool_descendants, this_contained_item_instance_pool_id)

      for j = 1, #this_child_pool_descendant_pool_ids do
        table.insert(this_pool_descendants, this_child_pool_descendant_pool_ids[j])
      end
    end
  end

  this_pool_descendants = _util.deduplicateTable(this_pool_descendants)
  this_pool_descendants_string = serpent.dump(this_pool_descendants)

  _data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.descendant_ids, this_pool_descendants_string)
end


function Ancestor.handleParentPoolReferencesInChildPools(active_pool_id, contained_items_pool_params)
  local this_contained_item_instance_pool_id, this_contained_item_params, this_selected_item_is_superitem

  for this_contained_item_instance_pool_id, this_contained_item_params in pairs(contained_items_pool_params) do
    this_selected_item_is_superitem = not string.find(this_contained_item_instance_pool_id, _constant.noninstance_label)

    if this_selected_item_is_superitem then
      Ancestor.storeParentPoolReferencesInChildPool(this_contained_item_instance_pool_id, active_pool_id)
    end
  end
end


function Ancestor.storeParentPoolReferencesInChildPool(preglue_child_instance_pool_id, active_pool_id)
  local parent_pool_ids_data_key_label, retval, parent_pool_ids_referenced_in_child_pool, this_parent_pool_id, this_parent_pool_id_is_referenced_in_child_pool

  parent_pool_ids_data_key_label = _constant.data.key.prefix.pool .. preglue_child_instance_pool_id .. _constant.data.key.suffix.pool.parent_ids_data
  retval, parent_pool_ids_referenced_in_child_pool = _data.storeRetrieveProjectData(parent_pool_ids_data_key_label)

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

    _data.storeRetrieveProjectData(parent_pool_ids_data_key_label, parent_pool_ids_referenced_in_child_pool)
  end
end


function Ancestor.reglueAncestors(pool_id, superitem, descendant_nesting_depth_of_active_parent)
  local parent_pool_ids_data_key_label, retval, parent_pool_ids, parent_pool_ids_data_found_for_active_pool, this_parent_pool_id, parent_pool_is_present_in_overglue_pools

  parent_pool_ids_data_key_label = _constant.data.key.prefix.pool .. pool_id .. _constant.data.key.suffix.pool.parent_ids_data
  retval, parent_pool_ids = _data.storeRetrieveProjectData(parent_pool_ids_data_key_label)
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
        parent_pool_is_present_in_overglue_pools = _util.isPresentInArray(this_parent_pool_id, _state.pool.parent_pool_ids_on_this_track.descendant_to_ancestor)

        if not parent_pool_is_present_in_overglue_pools then

          if _state.superitem.params.ancestor_pools[this_parent_pool_id] then
            Ancestor.assignParentNestingDepth(this_parent_pool_id, descendant_nesting_depth_of_active_parent)

          else
            Ancestor.traverseAncestorsUsingTempTracks(this_parent_pool_id, superitem, descendant_nesting_depth_of_active_parent)
          end
        end
      end

      reaper.GetSet_LoopTimeRange(true, false, _state.user.time_selection_before_action.position, _state.user.time_selection_before_action.end_point, false)
    end
  end
end


function Ancestor.assignParentNestingDepth(this_parent_pool_id, descendant_nesting_depth_of_active_parent)
  _state.superitem.params.ancestor_pools[this_parent_pool_id].children_nesting_depth = math.max(descendant_nesting_depth_of_active_parent, _state.superitem.params.ancestor_pools[this_parent_pool_id].children_nesting_depth)
end


function Ancestor.traverseAncestorsUsingTempTracks(this_parent_pool_id, superitem, descendant_nesting_depth_of_active_parent)
  local this_parent_is_ancestor_in_project, this_parent_instance_params, this_parent_instance_is_item_in_project

  this_parent_instance_params = _reglue().getFirstPoolInstanceParams(this_parent_pool_id)
  this_parent_instance_is_item_in_project = this_parent_instance_params

  if not this_parent_instance_is_item_in_project then
    this_parent_is_ancestor_in_project = Ancestor.checkParentPoolIsAncestorInProject(this_parent_pool_id)

    if this_parent_is_ancestor_in_project then
      this_parent_instance_params = {}
    end
  end

  if this_parent_instance_is_item_in_project or this_parent_is_ancestor_in_project then
    Ancestor.setUpAncestorReglues(this_parent_instance_params, this_parent_pool_id, descendant_nesting_depth_of_active_parent, superitem)
  end
end


function Ancestor.checkParentPoolIsAncestorInProject(this_parent_pool_id)
  local all_pool_ids_in_project, this_pool, this_pool_descendant_pool_ids, this_pool_descendant_pool_id

  all_pool_ids_in_project = _reglue().getAllPoolIdsInProject()

  for i = 1, #all_pool_ids_in_project do
    this_pool = all_pool_ids_in_project[i]

    if this_pool == this_parent_pool_id then

      return true
    end

    this_pool_descendant_pool_ids = _data.storeRetrievePoolData(this_pool, _constant.data.key.suffix.pool.descendant_ids)
    _, this_pool_descendant_pool_ids = serpent.load(this_pool_descendant_pool_ids)

    if this_pool_descendant_pool_ids then

      for j = 1, #this_pool_descendant_pool_ids do
        this_pool_descendant_pool_id = tonumber(this_pool_descendant_pool_ids[j])

        if this_pool_descendant_pool_id == this_parent_pool_id then

          return true
        end
      end
    end
  end

  Ancestor.deletePoolDescendantsData(this_parent_pool_id)

  return false
end


function Ancestor.deletePoolDescendantsData(pool_id)
  _data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.descendant_ids, "")
end


function Ancestor.setUpAncestorReglues(parent_instance_params, parent_pool_id, descendant_nesting_depth_of_active_parent, superitem)
  local parent_edit_temp_track__name, parent_edit_temp_track, restored_items, next_nesting_depth

  parent_instance_params.pool_id = parent_pool_id
  parent_instance_params.children_nesting_depth = descendant_nesting_depth_of_active_parent
  parent_edit_temp_track__name = "Pool #" .. parent_pool_id .. " temp edit"

  reaper.InsertTrackAtIndex(_constant.api.track.very_1st_track_of_project, _constant.api.track.no_defaults)

  parent_edit_temp_track = reaper.GetTrack(_constant.api.current_project, 0)

  reaper.GetSetMediaTrackInfo_String(parent_edit_temp_track, _constant.api.track.key.name, parent_edit_temp_track__name, _constant.api.set_value)
  reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)

  restored_items = _common.restoreStoredItems(parent_pool_id, parent_edit_temp_track, superitem, true, nil)
  parent_instance_params.track = parent_edit_temp_track
  parent_instance_params.restored_items = restored_items
  _state.superitem.params.ancestor_pools[parent_pool_id] = parent_instance_params
  next_nesting_depth = descendant_nesting_depth_of_active_parent + 1

  Ancestor.reglueAncestors(parent_pool_id, superitem, next_nesting_depth)
end


function Ancestor.sortAncestorUpdatesByNestingDepth()
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


function Ancestor.reglueAncestor(sizing_region_guid)
  local this_is_ancestor_superitem_update, selected_items, this_is_direct_parent_instance_update, ancestor_instance, ancestor_active_track

  reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)
  _depool.refreshCurrentPoolStoredItemsPostDePool()
  _common.selectDeselectItems(_state.superitem.params.fresh_glue.current_pool.restored_items, true)

  this_is_ancestor_superitem_update = true
  selected_items = _common.getSelectedItems(#_state.superitem.params.fresh_glue.current_pool.restored_items)
  this_is_direct_parent_instance_update = Ancestor.isThisDirectParentInstanceUpdate(selected_items)
  ancestor_instance = _glue().handleGlue(selected_items, _state.superitem.params.fresh_glue.current_pool.pool_id, sizing_region_guid, nil, this_is_ancestor_superitem_update)
  ancestor_active_track = _state.superitem.params.fresh_glue.current_pool.track
  _state.superitem.params.fresh_glue.current_pool = _data.getSetItemParams(ancestor_instance)
  _state.superitem.params.fresh_glue.current_pool.updated_src = _common.getSetWipeItemAudioSrc(ancestor_instance)

  reaper.Main_OnCommand(_constant.cmd.deselect_all_items, _constant.api.cmd_flag)
  _reglue().handleSuperitemsChangedByReglue(ancestor_instance, this_is_ancestor_superitem_update, this_is_direct_parent_instance_update)
  reaper.DeleteTrack(ancestor_active_track)
end


function Ancestor.isThisDirectParentInstanceUpdate(selected_items)
  local this_selected_item, this_selected_item_params, this_selected_instance_pool_id, this_is_direct_parent_instance_update

  for i = 1, #selected_items do
    this_selected_item = selected_items[i]
    this_selected_item_params = _data.getSetItemParams(this_selected_item)
    this_selected_instance_pool_id = this_selected_item_params.instance_pool_id

    if this_selected_instance_pool_id == _state.superitem.params.fresh_glue.edited_pool.pool_id then
      this_is_direct_parent_instance_update = true

      break
    end
  end

  return this_is_direct_parent_instance_update
end


return Ancestor