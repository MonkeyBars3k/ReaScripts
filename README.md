# MonkeyBars Reaper Scripts

The URL to import in ReaPack is https://github.com/MonkeyBars3k/ReaScripts/raw/master/index.xml.


## Glue (Reversible)

### Background

There are two main ways to consolidate selected items on a track in Reaper: **Glue** and **Groups**. Both have disadvantages. 

**Glue** is permanent: once you glue items together, you cannot make edits later without cutting again. This has disadvantages, as you may wish to extend the length of one of the enclosed items (such as make the sound of a kick drum's tail longer, etc.). You cannot do this using Glue.

The other option is to **Group** items. This works well if you simply want to  move items around or select multiple items by clicking one item; however, you cannot use the other benefits of Reaper items, such as quickly looping, take envelopes, etc. Grouping can become confusing because Groups are highlighted in green around the items, but *not* around the boundary of the group itself. Groups can be unwieldy to work with in many musical contexts, such as a four-bar repetition. Groups tend to create visual clutter.

**Glue (Reversible)** aims to address the shortcomings of both Glue and Groups, as well as restore the convenient functionality already present in items (looping, timestretching, and much more), by placing selected items in a new container item.

### How to use

**To use Glue (Reversible)**, simply select items or make a time selection with items inside and trigger the Glue (Reversible) script.

To edit your glued items, **Unglue (Reversible)** opens the created container item; the items inside are automatically grouped for you. You can see the container item created with Glue (Reversible), but the items inside are now visible and directly editable. Continue working with them as grouped items and/or reglue them again with Glue (Reversible). 

You can  Glue (Reversible) existing container items, nondestructively **nesting** container items. There is no limit in the code as to how many times you can nest.

### Features
- Fills in the missing **nondestructive/reversible Glue function** in Reaper!
- - A.k.a.: Glue Groups, Item Containers, Container Items, Pooled Item Boxes
- Currently, Glue (Reversible) container item copies are **pooled by default**. Editing and regluing one container item **updates all instances**. 
- - Considering Reaper is missing native Pooled Audio Items, this is great! However, we do plan to allow this to be toggled off and back on with a global script. 
- Supports **nesting Glue (Reversible) container items** inside other container items! When you update the nested container item, the script checks the parent item and updates that as well. Tested with 20 levels of nesting.

### Notes
- Requires **SWS Plugin Extension**, of course!
- After copying a Glue (Reversible) container item, you may need to zoom in/out to refresh. _Note_: this is Matthew's original comment; the codebase does include a zoom in/out on every Glue (perhaps to update the GUI?), which probably means you don't have to.
- When you **Unglue (Reversible)**, a new empty item "grc" is inserted under the original items. This item has the data to recall which group these items came from – don't delete it unless you want to glue the items and make a new group that doesnt update other instances.
- If you **add new items** to a Glue (Reversible) container item, select them AND at least one of the original items to make sure they get added to the existing container item. If you only tweak the existing items, you can select any item and reglue, and the script will remember which container item it belongs to.
- You can use the **empty container** "grc" to create silence at the start and end of the glued wav.
- Uses item notes/names to keep track of which container item items belong in. If you see "gr:1" or "grc:1", **don't delete it from the item's name**, as the code depends on that name to find it! You can add text to notes/names AFTER – e.g. "gr:1 - My extra text"
- To create **MIDI container items**, the script uses "Apply track FX as new take" on each item to get a (silent) wav audio take. When you Unglue (Reversible), the wav take is removed and just the original MIDI take is restored to active. Currently only MIDI on virtual instrument tracks is supported.
- When using copies of Glue (Reversible) container items, you can't make a copy of itself inside itself, as that would cause an infinite recursion.
- Uses selection set slot 10 at times to save and recall selected items. 

### History

matthewjumpsoffbuildings created the powerful, excellent "Glue Groups" scripts: https://bitbucket.org/matthewjumpsoffbuildings/reaper-scripts/src/master/

MonkeyBars continues the effort with some different nomenclature (in the interest of onboarding new users and making it easy to find in the Actions Window), bugfixes, and additional features.


### Planned improvements
See [Issues labeled "enhancement"](https://github.com/MonkeyBars3k/ReaScripts/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement).
