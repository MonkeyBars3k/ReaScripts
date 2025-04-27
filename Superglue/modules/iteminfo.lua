-- @noindex

local Iteminfo = {}


local _dev = require("modules.dev")

local loadDependencies, rtk, serpent, _constant, _common, _data, _init, _util


loadDependencies = (function()
  rtk = require("lib.rtk")
  serpent = require("lib.serpent")
  _constant = require("modules.constant")
  _common = require("modules.common")
  _data = require("modules.data")
  _init = require("modules.init")
  _util = require("modules.util")
end)()



function Iteminfo.openItemInfoWindow()
  local selected_item_count, selected_items, no_superglue_items_are_selected, all_selected_items_window_data

  selected_item_count = reaper.CountSelectedMediaItems(_constant.api.current_project)

  if selected_item_count == false then return end

  selected_items = _common.getSelectedItems(selected_item_count)
  no_superglue_items_are_selected, all_selected_items_window_data = Iteminfo.getAllSelectedItemsInfo(selected_items)

  if no_superglue_items_are_selected then
    reaper.ShowMessageBox("The selected items aren't associated with " .. _constant.brand.name .. ". Select Superitems or restored items and try again.", "No " .. _constant.brand.name .. " items selected", _constant.api.msg.type.ok)

    return
  end

  if all_selected_items_window_data then
    Iteminfo.populateItemInfoWindow(all_selected_items_window_data)
  end
end


function Iteminfo.getAllSelectedItemsInfo(selected_items)
  local no_superglue_items_are_selected, all_selected_items_window_data, this_selected_item, this_selected_superitem_instance_pool_id, this_is_superitem, this_selected_item_parent_pool_id, this_is_child_item, this_selected_item_info_name, this_selected_item_info

  no_superglue_items_are_selected = true
  all_selected_items_window_data = {}

  for i = 1, #selected_items do
    this_selected_item = selected_items[i]
    this_selected_superitem_instance_pool_id = _data.storeRetrieveItemData(this_selected_item, _constant.data.key.suffix.pool.instance_id)
    this_is_superitem = this_selected_superitem_instance_pool_id and this_selected_superitem_instance_pool_id ~= ""
    this_selected_item_parent_pool_id = _data.storeRetrieveItemData(this_selected_item, _constant.data.key.suffix.pool.parent_id)
    this_is_child_item = this_selected_item_parent_pool_id and this_selected_item_parent_pool_id ~= ""

    if this_is_superitem or this_is_child_item then
      no_superglue_items_are_selected = false
      this_selected_item_info_name, this_selected_item_info = Iteminfo.getSelectedItemInfo(this_selected_item, this_selected_superitem_instance_pool_id, this_selected_item_parent_pool_id, this_is_superitem, this_is_child_item)

      all_selected_items_window_data[i] = {
        name = this_selected_item_info_name,
        info = this_selected_item_info
      }
    end
  end

  return no_superglue_items_are_selected, all_selected_items_window_data
end


function Iteminfo.getSelectedItemInfo(selected_item, selected_superitem_instance_pool_id, selected_item_parent_pool_id, this_is_superitem, this_is_child_item)
  local selected_item_info_name, selected_item_info, selected_item_params

  selected_item_info_name = _common.getSetItemName(selected_item)
  selected_item_info = ""

  if this_is_superitem then
    selected_item_params = Iteminfo.prepareItemInfo(selected_superitem_instance_pool_id, selected_item_parent_pool_id)

  elseif this_is_child_item then
    selected_item_params = {
      {
        "Parent Pool ID: ",
        selected_item_parent_pool_id
      }
    }
  end

  for i = 1, #selected_item_params do

    if not selected_item_params[i][2] or selected_item_params[i][2] == "" then
      selected_item_params[i][2] = "none"
    end

    selected_item_info = selected_item_info .. selected_item_params[i][1] .. "\n" .. selected_item_params[i][2] .. "\n\n"
  end

  return selected_item_info_name, selected_item_info
end


function Iteminfo.prepareItemInfo(selected_superitem_instance_pool_id, selected_item_parent_pool_id)
  local selected_superitem_descendant_pool_ids, retval, stored_item_state_chunks, selected_superitem_descendant_pool_ids_list, selected_superitem_contained_items_count, sibling_positions, selected_item_params

  selected_superitem_descendant_pool_ids = _data.storeRetrievePoolData(selected_superitem_instance_pool_id, _constant.data.key.suffix.pool.descendant_ids)
  retval, selected_superitem_descendant_pool_ids = serpent.load(selected_superitem_descendant_pool_ids)
  stored_item_state_chunks = _data.storeRetrievePoolData(selected_superitem_instance_pool_id, _constant.data.key.suffix.pool.contained_item_states)
  retval, stored_item_state_chunks = serpent.load(stored_item_state_chunks)
  selected_superitem_descendant_pool_ids_list = _util.stringifyArray(selected_superitem_descendant_pool_ids)
  selected_superitem_contained_items_count = _util.getTableSize(stored_item_state_chunks)
  sibling_positions = Iteminfo.getSiblingPositions(selected_superitem_instance_pool_id)
  selected_item_params = {
    {
      "Pool ID: ",
      selected_superitem_instance_pool_id
    },
    {
      "Parent Pool ID: ",
      selected_item_parent_pool_id
    },
    {
      "Descendant (recursively contained instances) Pool IDs: ",
      selected_superitem_descendant_pool_ids_list
    },
    {
      "No. of directly contained items: ",
      selected_superitem_contained_items_count
    },
    {
      "Pool #" .. selected_superitem_instance_pool_id .. " All Instance positions: ",
      sibling_positions
    }
  }

  return selected_item_params
end


function Iteminfo.getSiblingPositions(pool_id)
  local sibling_locations_text, all_items_count, this_sibling_num, this_item, this_instance_pool_id, this_active_take, retval, this_active_take_name, this_instance_position_time, measures, beats_since_new_bar

  sibling_locations_text = ""
  all_items_count = reaper.CountMediaItems(_constant.api.current_project)
  this_sibling_num = 1

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_constant.api.current_project, i)
    this_instance_pool_id = _data.storeRetrieveItemData(this_item, _constant.data.key.suffix.pool.instance_id)

    if this_instance_pool_id and this_instance_pool_id ~= "" and this_instance_pool_id == pool_id then
      this_active_take = reaper.GetActiveTake(this_item)
      retval, this_active_take_name = reaper.GetSetMediaItemTakeInfo_String(this_active_take, _constant.api.take.key.name, "", false)
      this_instance_position_time = reaper.GetMediaItemInfo_Value(this_item, _constant.api.item.key.position)
      measures, beats_since_new_bar = Iteminfo.convertSecondsToMusicTime(this_instance_position_time)
      sibling_locations_text = sibling_locations_text .. _constant.unicode.no_break_space.._constant.unicode.no_break_space .. this_sibling_num .. ":  " .. this_active_take_name .. " – " .. measures .. "." .. beats_since_new_bar .. " / " .. _util.round(this_instance_position_time, 3) .. "s" .. "\r\n"
      this_sibling_num = this_sibling_num + 1
    end
  end

  if sibling_locations_text == "" then
    sibling_locations_text = "none"
  end

  return sibling_locations_text
end


function Iteminfo.convertSecondsToMusicTime(duration_in_seconds)
  local retval, measures, cml, fullbeats, beats_since_new_bar

  retval, measures, cml, fullbeats = reaper.TimeMap2_timeToBeats(_constant.api.current_project, duration_in_seconds)
  beats_since_new_bar = fullbeats % measures

  return measures, _util.round(beats_since_new_bar, 3)
end


function Iteminfo.populateItemInfoWindow(all_selected_items_window_data)
    local item_info_window, item_info_viewport, item_info_content, item_info_title, item_info_name, item_info_text

    -- Get the actual screen dimensions
    local _, _, screen_w, screen_h = reaper.my_getViewport(0, 0, 0, 0, 0, 0, 0, 0, 1)

    -- Create window with width set but use temporary height initially
    local window_width = screen_w * 0.3
    item_info_window = rtk.Window{
        w = window_width,
        h = 400,  -- Temporary default height
        title = _constant.brand.name .. " Item Info"
    }

    item_info_viewport = rtk.Viewport{
        halign = "center",
        padding = "0 38",
        flexh = true,  -- Enable height flexibility for proper content height calculation
        vscrollbar = rtk.Viewport.SCROLLBAR_AUTO
    }

    item_info_content = rtk.VBox{padding = "27 0 7", w = 1}
    item_info_title = rtk.Heading{_constant.brand.name .. " Item Info", w = 1, bmargin = 35, halign = "center"}

    item_info_content:add(item_info_title)

    for i = 1, #all_selected_items_window_data do
        item_info_name = rtk.Text{all_selected_items_window_data[i].name, w = 1, bmargin = 8, tpadding = 12, tborder = "1px #666666", halign = "center", textalign = "center", fontscale = 1.2, wrap = "normal", color = "#599D8E"}
        item_info_text = rtk.Text{all_selected_items_window_data[i].info, w = 1, textalign = "left", wrap = "normal"}

        item_info_content:add(item_info_name)
        item_info_content:add(item_info_text)
    end

    item_info_viewport:attr("child", item_info_content)
    item_info_window:add(item_info_viewport)

    -- Open window first with default size
    item_info_window:open{align = "center"}

    -- Calculate proper size after window has rendered
    reaper.defer(function()
        -- Multiple reflows can help stabilize calculations
        item_info_window:reflow()
        item_info_window:reflow()

        local content_height = item_info_content.calc and item_info_content.calc.h or 0

        -- Add buffer for window chrome and padding
        local window_height = math.min(content_height, screen_h * 0.85)

        -- Set the final window height
        item_info_window:attr('h', window_height)

        -- Recenter the window vertically
        local window_y = math.max(0, (screen_h - window_height) / 2)
        item_info_window:attr('y', window_y)
    end)
end



return Iteminfo
