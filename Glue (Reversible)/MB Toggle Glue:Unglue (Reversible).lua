-- @description MB Toggle Glue/Unglue (Reversible)
-- @author MonkeyBars
-- @version 1.0
-- @changelog initial commit
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
-- require("MB Glue (Reversible) Utils")


function toggleGlueUnglue()
  local num_selected_items, selected_items, selection_has_container, selected_item_is_part_of_group, prev_item_group, selected_item_is_noncontainer, are_inside_multiple_containers, item_group, multiple_containers_are_selected

  num_selected_items = reaper.CountSelectedMediaItems(0)
  
  selected_items = {}
  i = 0
  while i < num_selected_items do
    selected_items[i] = reaper.GetSelectedMediaItem(0, i)
  end

  -- single selected item
  if num_selected_items and num_selected_items < 2 then

    selection_has_container = checkSelectionForContainer(num_selected_items)
    -- is container?
    if selection_has_container then
      -- unglue
      reaper.NamedCommandLookup("_RS84af5ced344b56a3bd4b866f51852a5dc98b6d35")
      
    -- not container?
    else
      -- glue
      reaper.NamedCommandLookup("_RS91d1a5598d120c7828ce83c5bac4c716b0fac39d")
    end

  -- multiple selected items
  else
    
    i = 0
    while i < num_selected_items do
      selected_item_is_part_of_group = checkItemForGlueGroup(selected_items[i])

      if selected_item_is_part_of_group then
        -- selected items are part of 2+ unglued containers?
        if selected_item_is_part_of_group == prev_item_group then
          reaper.ShowMessageBox("Change the items selected and try again.", "Toggle Glue/Unglue (Reversible) error: Selected items can't be inside multiple unglued containers.", 0)
          return false
        end
      else 
        selected_item_is_noncontainer = true      
      end
      prev_item_group = selected_item_is_part_of_group
    end

    -- items both inside & outside unglued container(s)?
    if selected_item_is_part_of_group and selected_item_is_noncontainer then
      reaper.ShowMessageBox("Change the items selected and try again.", "Toggle Glue/Unglue (Reversible) error: Selected items can't be both inside and outside unglued containers.", 0)
          return false
    end

    -- selected items contain multiple containers?
    selection_has_container = checkSelectionForContainer(num_selected_items)
    if selection_has_container then
      
      local selected_containers = {}
      
      i = 0
      while i < num_selected_items do
        item_group = getGlueGroupFromItem(selected_items[i])
        if item_group then
          selected_containers[item_group] = item_group
        end
      end

      if #selected_containers > 1 then
        reaper.ShowMessageBox("Change the items selected and try again.", "Toggle Glue/Unglue (Reversible) error: Selected items can't contain multiple containers.", 0)
          return false
      end
    end

    -- selected items contain 1 container and 1+ noncontainers?
      -- glue/unglue dialog

    -- selected items inside same unglued container?
      -- (single) selected item nested container?
        -- glue/unglue dialog
      -- glue

    -- selected items contain only noncontainers?
      -- glue
  end
end


toggleGlueUnglue()