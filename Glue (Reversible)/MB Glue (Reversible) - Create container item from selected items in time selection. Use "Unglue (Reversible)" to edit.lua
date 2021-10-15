-- @description Create container item from selected items in time selection
-- @author MonkeyBars
-- @version 1.07
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Adapted from matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB Glue (Reversible) Utils")


function glueGroup()
  local num_items, source_item, source_track, glue_group, glued_item, container

  num_items = reaper.CountSelectedMediaItems(0)
  if not num_items or num_items < 1 then return end

  -- select whole group if its in one
  reaper.Main_OnCommand(40034, 0)

  -- get num_items again in case its changed
  num_items = reaper.CountSelectedMediaItems(0)
  if not num_items or num_items < 2 then return end


  -- undo block
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)


  -- Group Items regardless
  reaper.Main_OnCommand(40032, 0)

  -- store a reference to the original item
  source_item = reaper.GetSelectedMediaItem(0, 0)

  -- store a pointer to the original track
  source_track = reaper.GetMediaItemTrack(source_item)

  -- is this a reglueing of a previously glued item?
  glue_group, container = checkSelectionForContainer(num_items)

  if glue_group then
    glued_item = reGlue(source_track, source_item, glue_group, container)
  else
    glued_item = doGlue(source_track, source_item)
  end

  if glued_item then
    -- deselect all
    deselect()
    -- select glued item
    reaper.SetMediaItemSelected(glued_item, true)
  end

  -- clean up
  reaper.PreventUIRefresh(-1)
  reaper.UpdateTimeline()
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(true)
  -- zoom in then out
  reaper.Main_OnCommand(1011, 0)
  reaper.Main_OnCommand(1012, 0)
  --
  reaper.Undo_EndBlock("Glue (Reversible)", -1)

 end


function doGlue(source_track, source_item, glue_group, existing_container, ignore_depends)

  local num_items, original_items, item, item_states, container, glue_container, i, r, container_length, container_position, item_position, new_length
  local glued_item, item_glue_group, nested_glue_groups, key, dependencies_table, dependencies, dependency, dependents, dependent, original_state_key, container_name

  -- make a new glue_group id from the group id if this is a new group, and name glue_track accordingly
  if not glue_group then
    r, last_glue_group = reaper.GetProjExtState(0, "GLUE_GROUPS", "last", '')
    if r > 0 and last_glue_group then
      last_glue_group = tonumber( last_glue_group )
      glue_group = math.floor(last_glue_group + 1)
    else
      glue_group = 1
    end
  end

  -- store this glue group id so the next group can increment up
  reaper.SetProjExtState(0, "GLUE_GROUPS", "last", glue_group)

  -- count items to be added
  num_items = reaper.CountSelectedMediaItems(0)

  -- keep track of originally selected items
  original_items = {}
  i = 0
  while i < num_items do
    original_items[i] = reaper.GetSelectedMediaItem(0, i)
    i = i + 1
  end

  deselect()

  -- convert to audio takes and store state, and check for dependencies
  item_states = ''
  dependencies_table = {}
  has_non_container_items = false
  i = 0
  while i < num_items do
    item = original_items[i]
    if item ~= existing_container then

      has_non_container_items = true

      setToAudioTake( item )
      
      item_states = item_states..getSetObjectState(item)
      item_states = item_states.."|||"

      item_glue_group = getGlueGroupFromItem(item, true)
      if item_glue_group then
        -- are we attempting to nest an instance of the current glue group in itself?
        if item_glue_group == glue_group then 
          reaper.ShowConsoleMsg("Glue (Reversible): Error: You can't put an instance of "..glue_group.." inside itself")
          return false
        end
        -- else keep track of this items glue group to set up dependencies later
        dependencies_table[item_glue_group] = item_glue_group
      end
    end
    i = i + 1
  end

  -- if we are attemptign to glue a bunch of containers and nothing else
  if not has_non_container_items then return end

  -- if we are passing in an existing container (eg a reglue of an unglued group)
  if existing_container then
    -- the existing container will be used for state storage/resizing later
    container = existing_container
    -- store reference to a new empty container for glueing purposes only
    glue_container = reaper.AddMediaItemToTrack(source_track)
    -- select the glue_container too, it will be absorbed in the glue
    reaper.SetMediaItemSelected(glue_container, true)
    -- resize and reposition the new glue_container to match the existing container
    container_length = reaper.GetMediaItemInfo_Value(container, "D_LENGTH")
    container_position = reaper.GetMediaItemInfo_Value(container, "D_POSITION")
    reaper.SetMediaItemInfo_Value(glue_container, "D_LENGTH", container_length)
    reaper.SetMediaItemInfo_Value(glue_container, "D_POSITION", container_position)
    -- does this container have a reference to an original state of the item that was unglued?
    container_name = getSetItemName(container)
    original_state_key = string.match(container_name, "original_state:%d+:%d+")
    -- get rid of the original state key from the container, not needed anymore
    getSetItemName(container, "%s+original_state:%d+:%d+", -1)
  else
    -- otherwise this is a new glue, create the container that will be resized and stored after the glue is done
    container = reaper.AddMediaItemToTrack(source_track)
    -- set the containers name to point to this glue group
    setItemGlueGroup(container, glue_group)
  end

  -- reselect
  i = 0
  while i < num_items do
    reaper.SetMediaItemSelected(original_items[i], true)
    i = i + 1
  end

  -- deselect the original container
  reaper.SetMediaItemSelected(container, false)

  -- glue selected items
  reaper.Main_OnCommand(41588, 0)
  -- store ref to new glued item
  glued_item = reaper.GetSelectedMediaItem(0, 0)
  -- store a reference to this glue group in the glued item
  setItemGlueGroup(glued_item, glue_group, true)

  -- make sure the container is big enough
  new_length = reaper.GetMediaItemInfo_Value(glued_item, "D_LENGTH")
  reaper.SetMediaItemInfo_Value(container, "D_LENGTH", new_length)

  -- make sure container is aligned with the start of the items
  item_position = reaper.GetMediaItemInfo_Value(glued_item, "D_POSITION")
  reaper.SetMediaItemInfo_Value(container, "D_POSITION", item_position)

  -- add the container to the stored states
  item_states = item_states..getSetObjectState(container)

  -- insert the stored states into the ProjExtState
  reaper.SetProjExtState(0, "GLUE_GROUPS", glue_group, item_states)

  -- if this is being called from an 'updateSources' nested call, the dependencies havent been changed so dont bother with this part
  if not ignore_depends then

    r, old_dependencies = reaper.GetProjExtState(0, "GLUE_GROUPS", glue_group..":dependencies", '')
    if r < 1 then old_dependencies = "" end

    dependencies = ""
    dependent = "|"..glue_group.."|"

    -- store a reference to this glue group for all of the nested glue groups so if any of them get updated they can check and update this group
    for item_glue_group, r in pairs(dependencies_table) do
      
      -- make a key for the nested glue group to keep track of which groups are dependent on it
      key = item_glue_group..":dependents"
      -- see if the nested glue group already has a list of dependents
      r, dependents = reaper.GetProjExtState(0, "GLUE_GROUPS", key, '')
      if r == 0 then dependents = "" end
      -- if this glue group isnt already in the list, add it
      if not string.find(dependents, dependent) then
        dependents = dependents..dependent
        reaper.SetProjExtState(0, "GLUE_GROUPS", key, dependents)
      end

      -- now keep track of this glue groups dependencies
      dependency = "|"..item_glue_group.."|"
      dependencies = dependencies..dependency
      -- remove this dependency from the old_dependencies string
      old_dependencies = string.gsub(old_dependencies, dependency, "")
    end

    -- store this glue groups dependencies list
    reaper.SetProjExtState(0, "GLUE_GROUPS", glue_group..":dependencies", dependencies)

    -- have the dependencies changed?
    if string.len(old_dependencies) > 0 then
      -- loop thru all the no longer needed dependencies
      for dependency in string.gmatch(old_dependencies, "%d+") do 
        -- remove this glue group from the other glue groups dependents list
        key = dependency..":dependents"
        r, dependents = reaper.GetProjExtState(0, "GLUE_GROUPS", key, '')
        if r > 0 and string.find(dependents, dependent) then
          dependents = string.gsub(dependents, dependent, "")
          reaper.SetProjExtState(0, "GLUE_GROUPS", key, dependents)
        end

      end
    end
  end

  reaper.DeleteTrackMediaItem(source_track, container)

  return glued_item, original_state_key, item_position
end


function reGlue(source_track, source_item, glue_group, container)

  local glued_item, new_src, original_state, pos, take, r, original_state_key, container_name
  -- get the original state that the unglued item was in
  -- TODO - use ExtState to store it and key it to a particular container that was inserted on unglue


  -- run doGlue, but this time with a glue_group and container
  glued_item, original_state_key, pos = doGlue(source_track, source_item, glue_group, container)

  -- store updated src
  new_src = getItemWavSrc(glued_item)

  -- if there is a key in the containers name, find it in the ProjExtState and delete it from the item
  if original_state_key then
    r, original_state = reaper.GetProjExtState(0, "GLUE_GROUPS", original_state_key, '')

    if r > 0 and original_state then
      -- reapply the original state to the glued item
      getSetObjectState(glued_item, original_state)
      -- reapply the new src cause the original state would have the old one
      take = reaper.GetActiveTake(glued_item)
      reaper.BR_SetTakeSourceFromFile2(take, new_src, false, true)
      -- move to the new position, in case the newly glued version sits further left
      reaper.SetMediaItemInfo_Value(glued_item, "D_POSITION", pos)
      -- remove the original state data, not needed anymore
      reaper.SetProjExtState(0, "GLUE_GROUPS", original_state_key, '')
    end
  end

  -- calculate dependents, create an update_table with a nicely ordered sequence and re-insert the items of each glue group into temp tracks so they can be updated
  calculateUpdates(glue_group)
  -- sort the dependents update_table by how nested they are
  sortUpdates()
  -- do the actual updates now
  updateDependents(glue_group, new_src)

  return glued_item

end


function  updateSource( item, glue_group_string, new_src)
  local take_name, current_src, take

  -- get take name and see if it matches the currently updated glue group
  take_name, take = getSetItemName(item)

  if take_name and string.find(take_name, glue_group_string) then
    
    current_src = getItemWavSrc(item)

    if current_src ~= new_src then

      -- update the src
      reaper.BR_SetTakeSourceFromFile2(take, new_src, false, true)
      
      -- peakRebuildNeeded = true

      return current_src

    end
  end
end


function updateSources(new_src, glue_group)

  deselect()

  local num_items, glue_group_string, i, old_src, old_srcs

  glue_group_string = "glue_group:"..glue_group

  old_srcs = {}

  -- count all items
  num_items = reaper.CountMediaItems(0)

  -- loop through and update wav srcs
  i = 0
  while i < num_items do

    old_src = updateSource(reaper.GetMediaItem(0, i), glue_group_string, new_src)

    if old_src then old_srcs[old_src] = true end

    i = i + 1
  end

  -- delete old srcs, dont need em
  for old_src, i in pairs(old_srcs) do
    os.remove(old_src)
    os.remove(old_src..'.reapeaks')
  end

end


-- keys
update_table = {}
-- numeric version
iupdate_table = {}
--

function calculateUpdates(glue_group, nesting_level)

  if not update_table then update_table = {} end
  if not nesting_level then nesting_level = 1 end

  local r, dependents = reaper.GetProjExtState(0, "GLUE_GROUPS", glue_group..":dependents", '')

  if r > 0 and string.len(dependents) > 0 then

    local track, dependent_group, restored_items, item, container, glued_item, new_src, i, v, update_item, current_entry

    for dependent_group in string.gmatch(dependents, "%d+") do 

      dependent_group = math.floor(tonumber(dependent_group))

      -- check if an entry for this group already exists
      if update_table[dependent_group] then
        -- keep track of how deeply nested this item is
        update_table[dependent_group].nesting_level = math.max(nesting_level, update_table[dependent_group].nesting_level)

      else 
      -- this is the first time this group has come up, set up for the update loop
        current_entry = {}
        current_entry.glue_group = dependent_group
        current_entry.nesting_level = nesting_level

        -- make a track for this items updates
        reaper.InsertTrackAtIndex(0, false)
        track = reaper.GetTrack(0, 0)

        -- restore the items into the newly made empty track
        item, container, restored_items = restoreItems(dependent_group, track, 0, true, true)

        -- store references to the temp track and items
        current_entry.track = track
        current_entry.item = item
        current_entry.container = container
        current_entry.restored_items = restored_items

        -- store this item in the update_table
        update_table[dependent_group] = current_entry

        -- check if this group also has dependents
        calculateUpdates(dependent_group, nesting_level + 1)
      end
    end
  end
end


-- convert update_table to a numeric array then sort by the nesting value
function sortUpdates()
  
  local i, v

  for i,v in pairs(update_table) do
    table.insert(iupdate_table, v)
  end
  
  table.sort( iupdate_table, function(a, b) return a.nesting_level < b.nesting_level end)
end


-- do the actual updates of the dependent groups
function updateDependents( glue_group, src )

  -- update the items with just one level of nesting now that they are exposed
  updateSources(src, glue_group)

  local glued_item, i, dependent, new_src

  -- loop thru the dependents and update them in order
  for i, dependent in ipairs(iupdate_table) do

    deselect()

    reselect(dependent.restored_items)

    
    glued_item = doGlue(dependent.track, dependent.item, dependent.glue_group, dependent.container, true)

    -- update all instances of this group, including any in the other more deeply nested dependent groups which are exposed and waiting to be updated
    new_src = getItemWavSrc(glued_item)
    updateSources(new_src, dependent.glue_group)

    -- delete the glue track
    reaper.DeleteTrack(dependent.track)
    
  end
end


-- do the actual glue
glueGroup()