# MonkeyBars Reaper Scripts

The URL to import in ReaPack is https://github.com/MonkeyBars3k/ReaScripts/raw/master/index.xml.


## Glue (Reversible)

There are two main ways to consolidate selected items on a track in Reaper: **Glue** and **Groups**. Both have disadvantages. 

**Glue** is permanent: once you glue items together, you cannot make edits later without cutting again. This has disadvantages, as you may wish to extend the length of one of the enclosed items (such as make the sound of a kick drum's tail longer, etc.). You cannot do this using Glue.

The other option is to Group items. This works well if you simply want to  move items around or select multiple items by clicking one item; however, you cannot use the other benefits of Reaper items, such as quickly looping, take envelopes, etc. Grouping can become confusing because Groups are highlighted in green around the items, but *not* around the boundary of the group itself. Groups can be unwieldy to work with in many musical contexts, such as a four-bar repetition. Groups tend to create visual clutter.

Glue (Reversible) aims to address the shortcomings of both Glue and Groups, as well as restore the convenient functionality already present in items (looping, timestretching, and much more), by placing selected items in a new container item. 

**To use Glue (Reversible)**, simply select items or make a time selection with items inside and trigger the Glue (Reversible) script.

To edit your glued items, **Unglue (Reversible)** opens the created container item; the items inside are automatically grouped for you. You can see the container item created with Glue (Reversible), but the items inside are now visible and directly editable. Continue working with them as grouped items and/or reglue them again with Glue (Reversible). 

You can  Glue (Reversible) existing container items, nondestructively **nesting** container items. There is no limit in the code as to how many times you can nest.

### Notes
- Copied Glue (Reversible) container items are effectively pooled; editing and regluing one container item **updates all instances** – you may need to zoom in/out to refresh.
- When you **Unglue (Reversible)**, a new empty item "grc" is inserted under the original items. This item has the data to recall which group these items came from – don't delete it unless you want to glue the items and make a new group that doesnt update other instances.
- If you **add new items** to a Glue (Reversible) container item, select them AND at least one of the original items to make sure they get added to the existing container item. If you only tweak the existing items, you can select any item and reglue, and the script will remember which container item it belongs to.
- You can use the **empty container** "grc" to create silence at the start and end of the glued wav.
- Uses item notes/names to keep track of which container item items belong in. If you see "gr1:" or "grc1:", **don't delete it from the item's name**, as the code depends on that name to find it! You can add text to notes/names AFTER – e.g. "gr1: My extra text"
- Even creates **MIDI container items**. Uses "Apply track FX as new take" on each item to get the wav. When you Unglue (Reversible), the wav take is removed and just the original MIDI take is restored to active.
- Glue (Reversible) container items **CAN be nested inside other container items**. When you update the nested container item, the script checks the parent item too and updates that. Tested with 20 levels of nesting.
- Requires **SWS Plugin Extension** of course!

### History

matthewjumpsoffbuildings created the powerful, excellent "Glue Groups" scripts: https://bitbucket.org/matthewjumpsoffbuildings/reaper-scripts/src/master/

MonkeyBars continues the effort with some different nomenclature (in the interest of onboarding new users and making it easy to find in the Actions Window) and additional features.


#### Planned improvements
- Autoname container items by first selected item - COMPLETE
- Add **Rename Glue (Reversible) container items** script to rename all pooled instances of container item.
- Add **Reglue (Reversible) container item** script to make a container item independent from its pool, but retain all other settings.
- Add **Explode Glue (Reversible) container items** script to completely remove container items and ungroup contained items back to their original state.
- Add **Toggle Glue (Reversible) Pooled by default** global option.
- Add **Toggle Glue/Unglue (Reversible)** script

#### *Changelog*:
- 1.06 Change nomenclature to Glue (Reversible), gr/grc item labels
