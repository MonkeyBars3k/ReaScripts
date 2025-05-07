-- @noindex

local Sibling = {}


local _dev = require("modules.dev")

local loadDependencies, _common, _constant, _data, _state


loadDependencies = (function()
  _common = require("modules.common")
  _constant = require("modules.constant")
  _data = require("modules.data")
  _state = require("modules.state")
end)()




function Sibling.validateSiblingPositionsBeforeReglue(pool_id)



  _dev.dbg("DELTA_PRE_SIB_VALIDATE", "pos=%s  offset=%s",
      tostring(_state.superitem.delta.position_during_glue),
      tostring(_state.superitem.delta.offset_since_last_glue))




  local cache = {}; _state.propagation.sibling_cache[pool_id] = cache
  local NEG = _constant.position_start_of_project

  Sibling.loadSuperitemPropagationOptionChoices()

  for i = 0, reaper.CountMediaItems(0)-1 do
    local it   = reaper.GetMediaItem(0, i)
    local raw = _data.storeRetrieveItemData(it, _constant.data.key.suffix.pool.instance_id)
    local inst_key = _constant.data.key.suffix.pool.instance_id
    local inst_id  = _data.storeRetrieveItemData(it, inst_key)

    if inst_id ~= "" and inst_id == pool_id then
      local curP  = reaper.GetMediaItemInfo_Value(it, _constant.api.item.key.position)
      local tk    = reaper.GetActiveTake(it)


      _dev.dbg("CACHE_WRITE_TEST",
        "GUID=%s  wants_src=%s  actual_src=%s",
        reaper.BR_GetMediaItemGUID(it),
        tostring(_state.propagation.user_wants_option.source_position),
        tostring(reaper.GetMediaItemTakeInfo_Value(tk, _constant.api.take.key.src_offset)))

          _dev.dbg("SIB_CACHE_BUILD", "GUID=%s  src_offset=%s", reaper.BR_GetMediaItemGUID(it),
                   tostring(reaper.GetMediaItemTakeInfo_Value(tk, _constant.api.take.key.src_offset)))




      local rate  = reaper.GetMediaItemTakeInfo_Value(tk, _constant.api.take.key.playrate)
      local delta = _state.superitem.delta.position_during_glue_preview
      local delta_adjusted = delta
      if _state.propagation.user_wants_option.playrate_toggle then
        delta_adjusted = delta_adjusted / (rate == 0 and 1 or rate)
      end

      local newP = curP + delta_adjusted

      if newP < _constant.position_start_of_project then
        reaper.ShowMessageBox(
          "Propagating the left-edge shift would push a sibling before project start.\nOperation aborted.",
          "Invalid sibling position", _constant.api.msg.type.ok)



        _dev.dbg("SOURCE_POS_OPTION", "source_position=%s", tostring(_state.propagation.user_wants_option.source_position))



        return false
      end

      cache[reaper.BR_GetMediaItemGUID(it)] = {
        new_pos = newP,
        new_len = Sibling.calcNewLength(it, rate),
        new_src = _state.propagation.user_wants_option.source_position
                  and reaper.GetMediaItemTakeInfo_Value(tk, _constant.api.take.key.src_offset)
                  or nil
      }
    end
  end

  return true
end


function Sibling.calcNewLength(instance, playrate)

  if not _state.propagation.user_wants_option.length then
    return reaper.GetMediaItemInfo_Value(instance, _constant.api.item.key.length)
  end

  local abs = _state.propagation.user_wants_option.absolute_length_propagation
  local L0  = reaper.GetMediaItemInfo_Value(instance, _constant.api.item.key.length)

  if abs then
    local fg = _state.superitem.params.fresh_glue
            and _state.superitem.params.fresh_glue.edited_pool
    local pre = _state.superitem.params.pre_edit

    local target = fg and fg.length or pre and pre.length or L0

    local computed_value = _state.propagation.user_wants_option.playrate_toggle
           and target / playrate or target

    return computed_value
  else
    local delta = _state.superitem.reglue_position_change_affect_on_length
               or _state.superitem.params.pre_edit
                  and _state.superitem.params.fresh_glue
                  and _state.superitem.params.fresh_glue.edited_pool.length
                      - _state.superitem.params.pre_edit.length
               or 0

    if _state.propagation.user_wants_option.playrate_toggle then
      delta = delta / playrate
    end

    local computed_value = L0 + delta

    return computed_value
  end
end


-- function Sibling.predictSiblingLength(instance, instance_playrate)
--     if not _state.propagation.user_wants_option then return reaper.GetMediaItemInfo_Value(instance, _constant.api.item.key.length) end
--     local wants_len = _state.propagation.user_wants_option.length
--     if not wants_len then return reaper.GetMediaItemInfo_Value(instance, _constant.api.item.key.length) end

--     local abs = _state.propagation.user_wants_option.absolute_length_propagation
--     local rel = not abs
--     local play = _state.propagation.user_wants_option.playrate_toggle
--     local curr = reaper.GetMediaItemInfo_Value(instance, _constant.api.item.key.length)

--     if abs then
--         local L = _state.superitem.params.fresh_glue.edited_pool.length
--         if play then L = L / instance_playrate end
--         return L
--     else -- relative
--         local delta = _state.superitem.reglue_position_change_affect_on_length
--         if play then delta = delta / instance_playrate end
--         return curr + delta
--     end
-- end


function Sibling.loadSuperitemPropagationOptionChoices()
  _state.propagation.user_wants_option.playrate_toggle = _common.getUserPropagationChoice("playrate_toggle",
      _constant.data.key.options.switch.playrate_affects_propagation)

  if _state.superitem.position_changed_since_last_glue then
    _state.propagation.user_wants_option.position = _common.getUserPropagationChoice("position", _constant.data.key.options.switch.propagate_position)

    -- Lane propagation follows position propagation behavior
    if _constant.support.fixed_lanes then
      _state.propagation.user_wants_option.lane = _state.propagation.user_wants_option.position
    end
  end

  _state.propagation.user_wants_option.source_position = _common.getUserPropagationChoice("source_position", _constant.data.key.options.switch.maintain_source_position)

  if _state.superitem.reglue_position_change_affect_on_length ~= 0 then
    _state.propagation.user_wants_option.length =
    _common.getUserPropagationChoice("length",
      _constant.data.key.options.switch.propagate_length)

    if _state.propagation.user_wants_option.length then
      _state.propagation.user_wants_option.absolute_length_propagation =
      _common.getUserPropagationChoice("absolute_length_propagation",
        _constant.data.key.options.switch.length_propagation_type)
    end
  end
end


function Sibling.getPositionPropagationParams(instance, instance_current_src_offset, instance_playrate)
  local instance_current_position, instance_position_adjustment_delta, instance_adjusted_position, instance_would_get_adjusted_before_project_start

  instance_current_position = reaper.GetMediaItemInfo_Value(instance, _constant.api.item.key.position)
  instance_position_adjustment_delta = _state.superitem.delta.position_during_glue

  if _state.propagation.user_wants_option.playrate_toggle then
    instance_position_adjustment_delta = instance_position_adjustment_delta / instance_playrate
  end

  instance_adjusted_position = instance_current_position + instance_position_adjustment_delta
  instance_would_get_adjusted_before_project_start = instance_adjusted_position < _constant.position_start_of_project

  return instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start
end


return Sibling