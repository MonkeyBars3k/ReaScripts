-- @description MB_Fold source media into imploded takes at item length - if multiple takes, explode active take to new track
-- @author MonkeyBars
-- @version 1.1.3
-- @changelog Fix globals
-- @provides [main] .
--   [nomain] mb-dev-functions.lua
--   gnu_license_v3.txt
-- @link https://forum.cockos.com/showthread.php?p=2597213
-- @about Fold Source main script


-- Copyright (C) MonkeyBars 2024
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

-- N.B.:
-- This script requires SWS (https://www.sws-extension.org/download/pre-release/) 
-- and the ReaTeam script "amagalma_Explode selected item active take to new track (remove take from original item).lua" (https://github.com/ReaTeam/ReaScripts/raw/master/index.xml).



-- for dev only
-- package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
-- require("mb-dev-functions")



reaper.Undo_BeginBlock()


local _cmd = {
  deselect_all_items = 40289,
  set_item_bounds_to_source = 42228,
  delete_active_take = 40129,
  duplicate_active_take = 40639,
  explode_active_takes_to_new_tracks = reaper.NamedCommandLookup("_RS57edce15d7afa714deecb2ac0541e8cdd3af72cb")
}

local _api = {
  command_flag = 0,
  take_src_offset_key = "D_STARTOFFS",
  item_length_key = "D_LENGTH",
  item_position_key = "D_POSITION",
  takenumber_key = "IP_TAKENUMBER",
  take_name_key = "P_NAME",
  msg_type_ok = 0,
  all_take_info_values = {"D_STARTOFFS", "D_VOL", "D_PAN", "D_PANLAW", "D_PLAYRATE", "D_PITCH", "B_PPITCH", "I_CHANMODE", "I_PITCHMODE"}
}



function initFoldSource()

  if requiredLibsAreInstalled() == false then return end

  _selected_items = getSetSelectedItems()
  
  cleanItemSelection()
  extractSelectedTakes()
  foldSelectedItems()
  getSetSelectedItems(_selected_items)
end


function requiredLibsAreInstalled()
  local can_get_sws_version, sws_version

  can_get_sws_version = reaper.CF_GetSWSVersion ~= nil

  if can_get_sws_version then
    sws_version = reaper.CF_GetSWSVersion()
  end

  if not can_get_sws_version or not sws_version then
    reaper.ShowMessageBox("Please install SWS from https://standingwaterstudios.com/ and try again.", "MB_Fold source media requires the SWS plugin extension to work.", _api.msg_type_ok)
    
    return false

  elseif not _cmd.explode_active_takes_to_new_tracks then
    reaper.ShowMessageBox("Please install the ReaTeam scripts from https://github.com/ReaTeam/ReaScripts/raw/master/index.xml and try again.", "MB_Fold source media requires an Amalgama script to work.", _api.msg_type_ok)
    
    return false
  end 
end


function getSetSelectedItems(new_selected_items)
  local get_set

  if new_selected_items then
    get_set = "set"

  else
    get_set = "get"
  end

  if get_set == "get" then

    return getSelectedItems()

  elseif get_set == "set" then
    reaper.Main_OnCommand(_cmd.deselect_all_items, _api.command_flag)

    for i = 1, #new_selected_items do
      reaper.SetMediaItemSelected(new_selected_items[i], true)
    end

    return new_selected_items
  end
end


function getSelectedItems()
  local selected_item_count, selected_items, this_item

  selected_item_count = reaper.CountSelectedMediaItems(0)
  selected_items = {}

  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(0, i)

    table.insert(selected_items, this_item)
  end

  return selected_items
end


function cleanItemSelection()
  local new_selected_items, this_selected_item, multiple_takes_are_present, newly_extracted_item

  new_selected_items = copySimpleArray(_selected_items)

  for i = 1, #_selected_items do
    this_selected_item = _selected_items[i]

    getItemAndTakeValues(this_selected_item)

    if _active_take_source_length <= _original_item_length then
      new_selected_items = removeItemFromSelection(new_selected_items, this_selected_item)
    end
  end

  _selected_items = getSetSelectedItems(new_selected_items)
end


function extractSelectedTakes()
  local this_selected_item, multiple_takes_are_present, newly_extracted_item, new_selected_items

  new_selected_items = copySimpleArray(_selected_items)

  for i = 1, #_selected_items do
    this_selected_item = _selected_items[i]

    getItemAndTakeValues(this_selected_item)
    
    multiple_takes_are_present = extractActiveTake(this_selected_item)

    if multiple_takes_are_present then
      newly_extracted_item = reaper.GetSelectedMediaItem(0, 0)
      new_selected_items = removeItemFromSelection(new_selected_items, this_selected_item)
      new_selected_items = addItemToSelection(new_selected_items, newly_extracted_item)
    end
  end

  _selected_items = getSetSelectedItems(new_selected_items)
end


function copySimpleArray(arr)
  local new_array = {}

  for i = 1, #arr do
    table.insert(new_array, arr[i])
  end

  return new_array
end


function foldSelectedItems()
  local this_selected_item

  for i = 1, #_selected_items do
    this_selected_item = _selected_items[i]

    reaper.Main_OnCommand(_cmd.deselect_all_items, _api.command_flag)
    reaper.SetMediaItemSelected(this_selected_item, true)
    getItemAndTakeValues(this_selected_item)
    foldItem(this_selected_item)
  end
end


function getItemAndTakeValues(item)
  _original_item_length = reaper.GetMediaItemInfo_Value(item, _api.item_length_key)
  _item_takes_count = reaper.GetMediaItemNumTakes(item)
  _item_all_takes = {}

  for i = 0, _item_takes_count-1 do
    _item_all_takes[i] = reaper.GetTake(item, i)
  end

  _active_take = reaper.GetActiveTake(item)
  _active_take_source = reaper.GetMediaItemTake_Source(_active_take)
  _active_take_source_type = reaper.GetMediaSourceType(_active_take_source)

  if _active_take_source_type == "MIDI" or _active_take_source_type == "MIDIPOOL" then
    getMidiTakeValues(item)

  else
    getAudioTakeValues()
  end
end


function getMidiTakeValues(item)
  local original_item_position, original_active_take_offset

  original_item_position = reaper.GetMediaItemInfo_Value(item, _api.item_position_key)
  original_active_take_offset = reaper.GetMediaItemTakeInfo_Value(_active_take, _api.take_src_offset_key)

  reaper.Main_OnCommand(_cmd.set_item_bounds_to_source, _api.command_flag)

  _active_take_source_length = reaper.GetMediaItemInfo_Value(item, _api.item_length_key)

  reaper.SetMediaItemPosition(item, original_item_position, false)
  reaper.SetMediaItemLength(item, _original_item_length, false)
  reaper.SetMediaItemTakeInfo_Value(_active_take, _api.take_src_offset_key, original_active_take_offset)
end


function getAudioTakeValues()
  _active_take_source_length = reaper.GetMediaSourceLength(_active_take_source)
    
  if _active_take_source_type == "SECTION" then
    _active_take_source = reaper.GetMediaSourceParent(_active_take_source)
  end

  _active_take_source_filename = reaper.GetMediaSourceFileName(_active_take_source)
end


function extractActiveTake(item)

  if _item_takes_count > 1 then
    reaper.Main_OnCommand(_cmd.explode_active_takes_to_new_tracks, _api.command_flag)

    return true
  end
end


function removeItemFromSelection(items, item_to_deselect)
  local new_selected_items, this_selected_item

  new_selected_items = {}

  for i = 1, #items do
    this_selected_item = items[i]

    if this_selected_item ~= item_to_deselect then
      table.insert(new_selected_items, this_selected_item)
    end
  end

  return new_selected_items
end


function addItemToSelection(items, item_to_select)
  local new_selected_items, this_selected_item

  new_selected_items = {}

  for i = 1, #items do
    this_selected_item = items[i]

    table.insert(new_selected_items, this_selected_item)
  end

  table.insert(new_selected_items, item_to_select)

  return new_selected_items
end


function foldItem(item)
  defineTakeSetup()
  addFoldedTakesBeforeActive(item)
  handleActiveTake(item)
  addFoldedTakesAfterActive(item)
  renameNewTakes(item)
  cleanUpFoldSource()
end


function defineTakeSetup()
  _active_take_num = reaper.GetMediaItemTakeInfo_Value(_active_take, _api.takenumber_key)
  _active_take_params = getSetTakeParams(_active_take, "get")
  _new_takes_before_active_count = math.ceil(_active_take_params.D_STARTOFFS / _original_item_length)
  _source_length_after_active_take = _active_take_source_length - _original_item_length - _active_take_params.D_STARTOFFS
  _new_takes_after_active_count = math.ceil(_source_length_after_active_take / _original_item_length)
end


function getSetTakeParams(take, get_set, new_params)
  local this_take_params, this_take_param_name, this_take_param_value, retval

  if get_set == "get" then
    this_take_params = {}

    for i = 1, #_api.all_take_info_values do
      this_take_param_name = _api.all_take_info_values[i]
      this_take_param_value = reaper.GetMediaItemTakeInfo_Value(take, this_take_param_name)

      this_take_params[this_take_param_name] = this_take_param_value
    end

    retval, this_take_params["name"] = reaper.GetSetMediaItemTakeInfo_String(take, _api.take_name_key, "", false)

    return this_take_params

  elseif get_set == "set" then

    for i = 1, #_api.all_take_info_values do
      this_take_param_name = _api.all_take_info_values[i]

      reaper.SetMediaItemTakeInfo_Value(take, this_take_param_name, new_params[this_take_param_name])
    end
  end
end


function addFoldedTakesBeforeActive(item)

  if _new_takes_before_active_count > 0 then
    addNewTake(item, 0, "before_active_take")

    if _new_takes_before_active_count > 1 then

      for i = 1, _new_takes_before_active_count-1 do
        addNewTake(item, i, "before_active_take")
      end
    end
  end
end


function addNewTake(item, new_take_idx, new_take_location)
  local new_take_offset, new_take

  if new_take_location == "before_active_take" then
    new_take_offset = _active_take_params.D_STARTOFFS - round( (_original_item_length * (_new_takes_before_active_count - new_take_idx) ), 12)

  elseif new_take_location == "after_active_take" then
    new_take_offset = _active_take_params.D_STARTOFFS + round( (_original_item_length * new_take_idx ), 12)
  end

  reaper.Main_OnCommand(_cmd.duplicate_active_take, _api.command_flag)

  new_take = reaper.GetActiveTake(item)
  
  reaper.SetActiveTake(new_take)
  reaper.SetMediaItemTakeInfo_Value(new_take, _api.take_src_offset_key, new_take_offset)
end


function handleActiveTake(item)
  local new_take

  reaper.Main_OnCommand(_cmd.duplicate_active_take, _api.command_flag)

  new_take = reaper.GetActiveTake(item)
  _new_active_take = new_take

  reaper.SetMediaItemTakeInfo_Value(_new_active_take, _api.take_src_offset_key, _active_take_params.D_STARTOFFS)
end


function addFoldedTakesAfterActive(item)

  if _new_takes_after_active_count > 0 then

    for i = 1, _new_takes_after_active_count do
      addNewTake(item, i, "after_active_take")
    end
  end
end


function renameNewTakes(item)
  local all_takes_count

  all_takes_count = reaper.CountTakes(item)

  for i = 0, all_takes_count-1 do

    if i ~= _active_take_num then
      renameTake(item, i, all_takes_count)
    end
  end
end


function renameTake(item, idx, all_takes_count)
  local this_take, this_take_source_end_point, this_take_indicator, this_is_last_take, new_take_name

  this_take = reaper.GetTake(item, idx)
  this_take_offset = round(reaper.GetMediaItemTakeInfo_Value(this_take, _api.take_src_offset_key), 3)
  this_take_source_end_point = round(this_take_offset + _original_item_length, 3)
  this_is_last_take = idx == all_takes_count-1

  if this_is_last_take then
    this_take_indicator = "<"

  else
    this_take_indicator = ">>"
  end

  new_take_name = _active_take_params.name .. " " .. idx .. " of " .. all_takes_count .. " [" .. this_take_offset .. "s to " .. this_take_source_end_point .. "s] " .. this_take_indicator

  reaper.GetSetMediaItemTakeInfo_String(this_take, _api.take_name_key, new_take_name, true)
end


function cleanUpFoldSource()
  reaper.SetActiveTake(_active_take)
  reaper.Main_OnCommand(_cmd.delete_active_take, _api.command_flag)
  reaper.SetActiveTake(_new_active_take)
end


function round(num, precision)
   return math.floor(num*(10^precision)+0.5) / 10^precision
end


initFoldSource()

reaper.Undo_EndBlock("MB_Fold source media into imploded takes at item length – if multiple takes, explode active take to new track", -1)