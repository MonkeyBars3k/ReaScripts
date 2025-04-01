-- @noindex

local Overglue = {}


local loadDependencies, serpent, _common, _constant, _data, _single, _state


loadDependencies = (function()
  serpent = require("lib.serpent")
  _common = require("modules.common")
  _constant = require("modules.constant")
  _data = require("modules.data")
  _single = require("modules.single")
  _state = require("modules.state")
end)()



function Overglue.doOverglue(user_selected_items_on_this_track, pool_ids_by_depth)
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
        local this_item_parent_pool_id = _data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)
        if not this_item_parent_pool_id or this_item_parent_pool_id == "" then
            table.insert(all_nonrestored_items, this_item)
        end
    end

    -- Calculate distances to determine outermost pool processing order
    local pool_distances = {}
    for _, pool_id in ipairs(outermost_pools) do
        local _, sizing_regions = _data.storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions)
        retval, sizing_regions = serpent.load(sizing_regions)
        local sizing_region_guid = sizing_regions[pool_id]
        local pool_params = _common.getSetDeleteSizingRegion(sizing_region_guid)

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
        local restored_items = Overglue.getRestoredItems(user_selected_items_on_this_track, pool_id)
        local nonrestored_items__with_params = is_outermost
            and Overglue.getNonRestoredItemsWithParams(all_nonrestored_items)
            or Overglue.getNonRestoredItemsWithParams({})

        local outermost_pools = is_outermost and {pool_id} or {}
        local outermost_ancestor_pools__with_params = Overglue.getOutermostAncestorPoolsWithParams(outermost_pools)
        local pool_item_distances, nearest_nonrestored_items = Overglue.populateNonRestoredItemsDurationsData(outermost_ancestor_pools__with_params, nonrestored_items__with_params)
        local all_items_to_glue = Overglue.getItemsToOverglue(nearest_nonrestored_items, restored_items)

        local superitem = _single.triggerSingleTrackSinglePoolGlue(all_items_to_glue, pool_id)

        if superitem then
            _state.action.glue.overglued_superitems[pool_id] = {
                superitem = superitem,
                descendant_pool_ids = _data.storeRetrievePoolData(pool_id, _constant.data.key.suffix.pool.descendant_ids),
                processed = true
            }

            selected_items_on_this_track__post_glue = Overglue.getSelectedItems_PostGlue(
                selected_items_on_this_track__post_glue,
                user_selected_items_on_this_track,
                superitem
            )
        end
    end

    return selected_items_on_this_track__post_glue
end


function Overglue.getRestoredItems(user_selected_items_on_this_track, requested_parent_pool_id)
    local restored_items = {}

    -- First get directly restored items
    for j = 1, #user_selected_items_on_this_track do
        local this_item = user_selected_items_on_this_track[j]
        if reaper.ValidatePtr(this_item, "MediaItem*") then
            local this_item_parent_pool_id = _data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.parent_id)
            if this_item_parent_pool_id == requested_parent_pool_id then
                table.insert(restored_items, this_item)
            end
        end
    end

    -- Check if we have any descendant info before trying to parse it
    local descendant_data = _data.storeRetrievePoolData(requested_parent_pool_id, _constant.data.key.suffix.pool.descendant_ids)

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


-- function Overglue.getOutermostAncestorPools(pool_ids_by_depth)
--   local outermost_ancestor_pools = {}

--   for this_pool_id, depth in pairs(pool_ids_by_depth) do

--     if depth == 0 then
--       table.insert(outermost_ancestor_pools, this_pool_id)
--     end
--   end

--   return outermost_ancestor_pools
-- end


function Overglue.getNonRestoredItemsWithParams(nonrestored_items)
    local nonrestored_items__with_params = {}

    for i = 1, #nonrestored_items do
        local this_item = nonrestored_items[i]

        if reaper.ValidatePtr(this_item, "MediaItem*") then
            nonrestored_items__with_params[this_item] = _data.getSetItemParams(this_item)
        end
    end

    return nonrestored_items__with_params
end


function Overglue.getOutermostAncestorPoolsWithParams(outermost_ancestor_pools--[[ , restored_items_with_this_parent_pool_id ]])
    local outermost_ancestor_pools__with_params = {}

    for _, this_outermost_ancestor_pool_id in ipairs(outermost_ancestor_pools) do
        local _, all_pool_ids_with_active_sizing_regions = _data.storeRetrieveProjectData(_constant.data.key.all_pool_ids_with_active_sizing_regions)
        _, all_pool_ids_with_active_sizing_regions = serpent.load(all_pool_ids_with_active_sizing_regions)
        local sizing_region_guid = all_pool_ids_with_active_sizing_regions[this_outermost_ancestor_pool_id]

        if sizing_region_guid then
            local sizing_params = _common.getSetDeleteSizingRegion(sizing_region_guid)
            if sizing_params then
                outermost_ancestor_pools__with_params[this_outermost_ancestor_pool_id] = sizing_params
            end
        end
    end

    return outermost_ancestor_pools__with_params
end


function Overglue.populateNonRestoredItemsDurationsData(outermost_ancestor_pools__with_params, nonrestored_items__with_params)
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


function Overglue.getRelation_NonRestoredItemsBounds_OutermostAncestorBounds(this_outermost_ancestor_pool_id, this_outermost_ancestor_pool_id__sizing_params, nonrestored_items__with_params)
  local this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap, nonrestored_items_with_partial_overlap, nonrestored_items_to_add_to_glue, nonrestored_items_non_overlapping

  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds = {}
  nonrestored_items_with_both_sides_overlap = {}
  nonrestored_items_with_partial_overlap = {}
  nonrestored_items_to_add_to_glue = {}
  nonrestored_items_non_overlapping = {}

  for this_nonrestored_item, this_nonrestored_item__params in pairs(nonrestored_items__with_params) do
    Overglue.processNonRestoredItemBounds(this_nonrestored_item, this_nonrestored_item__params, this_outermost_ancestor_pool_id__sizing_params, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap, nonrestored_items_with_partial_overlap, nonrestored_items_to_add_to_glue, nonrestored_items_non_overlapping)
  end

  Overglue.addCategorizedNonRestoredItemsToMainTable(this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap, nonrestored_items_with_partial_overlap, nonrestored_items_to_add_to_glue, nonrestored_items_non_overlapping)

  return this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds
end


function Overglue.processNonRestoredItemBounds(this_nonrestored_item, this_nonrestored_item__params, this_outermost_ancestor_pool_id__sizing_params, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap, nonrestored_items_with_partial_overlap, nonrestored_items_to_add_to_glue, nonrestored_items_non_overlapping)
  local item_position, item_end_point, pool_position, pool_end_point

  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds[this_nonrestored_item] = this_nonrestored_item__params
  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds[this_nonrestored_item].overlaps = {}
  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds[this_nonrestored_item].deltas = {}
  item_position = this_nonrestored_item__params.position
  item_end_point = this_nonrestored_item__params.end_point
  pool_position = this_outermost_ancestor_pool_id__sizing_params.position
  pool_end_point = this_outermost_ancestor_pool_id__sizing_params.end_point

  Overglue.checkNonRestoredItemOverlapConditions(this_nonrestored_item, item_position, item_end_point, pool_position, pool_end_point, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap, nonrestored_items_with_partial_overlap, nonrestored_items_to_add_to_glue, nonrestored_items_non_overlapping)
  Overglue.calculateNonRestoredItemPoolDeltas(this_nonrestored_item, item_position, item_end_point, pool_position, pool_end_point, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds)
end


function Overglue.processNonRestoredItemOverlapCondition(overlap_type, nonrestored_item, outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, target_table, overlap_duration)
    -- Handle the overlap data storage
    outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds[nonrestored_item].overlaps[overlap_type] = overlap_duration or true

    -- Store the actual MediaItem, not just a reference
    table.insert(target_table, nonrestored_item)
end


function Overglue.calculateNonRestoredItemPoolDeltas(this_nonrestored_item, item_position, item_end_point, pool_position, pool_end_point, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds)
  local deltas = {
    item_position_to_pool_position = pool_position - item_position,
    item_position_to_pool_end = pool_end_point - item_position,
    item_end_to_pool_position = pool_position - item_end_point,
    item_end_to_pool_end = pool_end_point - item_end_point
  }

  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds[this_nonrestored_item].deltas = deltas
end


function Overglue.addCategorizedNonRestoredItemsToMainTable(this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap, nonrestored_items_with_partial_overlap, nonrestored_items_to_add_to_glue, nonrestored_items_non_overlapping)
  local dummy_local

  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds.nonrestored_items_with_both_sides_overlap = nonrestored_items_with_both_sides_overlap
  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds.nonrestored_items_with_partial_overlap = nonrestored_items_with_partial_overlap
  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds.nonrestored_items_to_add_to_glue = nonrestored_items_to_add_to_glue
  this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds.nonrestored_items_non_overlapping = nonrestored_items_non_overlapping
end


function Overglue.getOutermostAncestorPools(pool_ids_by_depth)
    local outermost_ancestor_pools = {}

    for this_pool_id, depth in pairs(pool_ids_by_depth) do
        if depth == 0 then
            table.insert(outermost_ancestor_pools, this_pool_id)
        end
    end

    return outermost_ancestor_pools
end


function Overglue.assignNonRestoredItemsToPoolsBasedOnMaxOverlap(item_pool_assignments)
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


function Overglue.calculateAllNonRestoredItemPoolOverlaps(relation__nonrestored_items_bounds__outermost_ancestor_bounds)
  local item_pool_assignments = {}

  for this_outermost_ancestor_pool_id, this_outermost_ancestor_pool__params in pairs(relation__nonrestored_items_bounds__outermost_ancestor_bounds) do

    for this_nonrestored_item, this_nonrestored_item__params in pairs(this_outermost_ancestor_pool__params) do

      if type(this_nonrestored_item__params) ~= "table" then goto continue end

      item_pool_assignments[this_nonrestored_item] = item_pool_assignments[this_nonrestored_item] or {}
      item_pool_assignments[this_nonrestored_item][this_outermost_ancestor_pool_id] = Overglue.calculateNonRestoredItemPoolOverlap(this_nonrestored_item__params)

      ::continue::
    end
  end

  return item_pool_assignments
end


function Overglue.calculateNonRestoredItemPoolOverlap(nonrestored_item__params)
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

function Overglue.checkNonRestoredItemOverlapConditions(this_nonrestored_item, item_position, item_end_point, pool_position, pool_end_point, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap, nonrestored_items_with_partial_overlap, nonrestored_items_to_add_to_glue, nonrestored_items_non_overlapping)
  local item_center = item_position + ((item_end_point - item_position) / 2)
  local pool_center = pool_position + ((pool_end_point - pool_position) / 2)
  local distance_to_pool_center = math.abs(pool_center - item_center)

  local item_is_within_pool = item_position >= pool_position and item_end_point <= pool_end_point
  local item_overlaps_both_sides = item_position <= pool_position and item_end_point >= pool_end_point
  local item_overlaps_pool_position = item_position <= pool_position and item_end_point > pool_position and item_end_point <= pool_end_point
  local item_overlaps_pool_end_point = item_position >= pool_position and item_position < pool_end_point and item_end_point >= pool_end_point

  if item_is_within_pool then
    Overglue.processNonRestoredItemOverlapCondition("is_within", this_nonrestored_item, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_to_add_to_glue)
  elseif item_overlaps_both_sides then
    Overglue.processNonRestoredItemOverlapCondition("overlaps_both_sides", this_nonrestored_item, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_both_sides_overlap)
  elseif item_overlaps_pool_position then
    local overlap = item_end_point - pool_position
    Overglue.processNonRestoredItemOverlapCondition("overlaps_pool_position", this_nonrestored_item, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_partial_overlap, overlap)
  elseif item_overlaps_pool_end_point then
    local overlap = pool_end_point - item_position
    Overglue.processNonRestoredItemOverlapCondition("overlaps_pool_end_point", this_nonrestored_item, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_with_partial_overlap, overlap)
  else
    -- Store the negative distance (so closer items get higher values when compared)
    Overglue.processNonRestoredItemOverlapCondition("non_overlapping", this_nonrestored_item, this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds, nonrestored_items_non_overlapping)
    this_outermost_ancestor_pool_id__relation__nonrestored_items_bounds__outermost_ancestor_bounds[this_nonrestored_item].distance_to_pool_center = -distance_to_pool_center
  end
end


function Overglue.getItemsToOverglue(outermost_ancestor_pools__nearest_nonrestored_items, restored_items_with_this_parent_pool_id)
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


function Overglue.getSelectedItems_PostGlue(selected_items_on_this_track__post_glue, user_selected_items_on_this_track, superitem)
  local selected_items_on_this_track__post_glue, this_item, this_item_still_exists_in_project

  -- SHOULD THIS BE HERE, OR SHOULD THE VALUE COME FROM THE ARGUMENT??
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



return Overglue
