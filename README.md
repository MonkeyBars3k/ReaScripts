# MonkeyBars Reaper Scripts

The URL to import in ReaPack is https://github.com/MonkeyBars3k/ReaScripts/raw/master/index.xml.


## Item Containers

matthewjumpsoffbuildings created the "Glue Groups" actions to create a sort of item container that is a basically a combination of item gluing and grouping. https://bitbucket.org/matthewjumpsoffbuildings/reaper-scripts/src/master/

MonkeyBars continues the effort under a more generic, clear name: **Item Containers**.

- Currently item containers only work on a **single track**.
- Item Container recreation updates all instances – you may need to zoom in/out to refresh.
- Upon opening Item Container, a new empty item "icc" is inserted under the original items. This item has the data to recall which group these items came from – don't delete it unless you want to glue the items and make a new group that doesnt update other instances.
- If you add new items to the Item Container, select them AND at least one of the original items to make sure they get added to the existing Item Container. If you just tweak the existing items, you can select any one and recreate, and it will remember which Item Container it belongs to.
- You can use the empty container "icc" to create silence at the start and end of the glued wav.
- Uses item notes/names to keep track of which Item Container items belong in. If you see "ic:1:" or "icc:1:", don't delete it from the item's name, as the code depends on that name to find it! You can add text to notes/names AFTER ":1:" – e.g. "ic:1 My extra text"
- Even creates MIDI Item Containers. Uses "Apply track FX as new take" on each item to get the wav. When you Open Item Container, the wav take is removed and just the original MIDI take is restored to active.
- Item Containers CAN be nested inside other Item Containers. When you update the nested Item Container, the script checks the parent item too, and updates that. Tested with 20 levels of nesting.
- Requires SWS

Future improvements include:
- Adding **explode** action to completely remove item container and revert items to original state
