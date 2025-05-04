-- @noindex

local Sibling = {}


local _dev = require("modules.dev")

local loadDependencies, loadCircularDependencies, serpent, _common, _constant, _data, _depool, _init, _sizing, _state, _util, _module_utils, _glue, _reglue


loadDependencies = (function()
  serpent = require("lib.serpent")
  _common = require("modules.common")
  _constant = require("modules.constant")
  _data = require("modules.data")
  _depool = require("modules.depool")
  _init = require("modules.init")
  _sizing = require("modules.sizing")
  _state = require("modules.state")
  _util = require("modules.util")

  _module_utils = require("module-utils")
end)()


loadCircularDependencies = (function()
  _glue = function() return _module_utils.lazyRequire("glue") end
  _reglue = function() return _module_utils.lazyRequire("reglue") end
end)()




function Sibling.validateSiblingPositionsBeforeReglue(pool_id)
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
    return reaper.GetMediaItemInfo_Value(instance,_constant.api.item.key.length)
  end
  local abs = _state.propagation.user_wants_option.absolute_length_propagation
  local delta = _state.superitem.reglue_position_change_affect_on_length
  if abs then
    local L = _state.superitem.params.fresh_glue.edited_pool.length
    return _state.propagation.user_wants_option.playrate_toggle and L/playrate or L
  else
    return reaper.GetMediaItemInfo_Value(instance,_constant.api.item.key.length) +
           (_state.propagation.user_wants_option.playrate_toggle and delta/playrate or delta)
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

  if _state.superitem.offset_changed_since_last_glue then
    _state.propagation.user_wants_option.source_position = _common.getUserPropagationChoice("source_position", _constant.data.key.options.switch.maintain_source_position)
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