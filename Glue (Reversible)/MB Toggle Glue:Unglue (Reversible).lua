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
  local num_selected_items, item, selected_items, item_glue_group

  num_selected_items = num_items = reaper.CountSelectedMediaItems(0)
  selected_items = {}
  i = 0
  while i < num_selected_items do
    selected_items[i] = reaper.GetSelectedMediaItem(0, i)
    selected_items[i][item_glue_group] = getGlueGroupFromItem(selected_items[i], true)
  end
  
  if num_selected_items and num_selected_items < 2 then
    -- single selected item
    

      if item_glue_group then

    
    -- not container?
      -- glue
      reaper.NamedCommandLookup("_RS91d1a5598d120c7828ce83c5bac4c716b0fac39d")
    -- is container?
    if selected_items[i][item_glue_group] 
      -- unglue
      reaper.NamedCommandLookup("_RS84af5ced344b56a3bd4b866f51852a5dc98b6d35")
    end

  else
    -- multiple selected items
    -- selected items are part of 2+ unglued containers OR selected items contain multiple containers OR items both inside & outside unglued container(s)?
      -- warning & break
    -- selected items contain 1 container and 1+ noncontainers?
      -- glue/unglue dialog
    -- selected items inside same unglued container?
      -- (single) selected item nested container?
        -- glue/unglue dialog
      -- glue
  end
end


toggleGlueUnglue()