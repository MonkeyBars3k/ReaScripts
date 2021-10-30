# MonkeyBars Reaper Scripts

The URL to import in ReaPack is https://github.com/MonkeyBars3k/ReaScripts/raw/master/index.xml.


## Glue-Reversible

### Background

There are two main ways to consolidate selected items on a track natively in Reaper: **Glue** and **Groups**. Both have disadvantages. 

**Glue** is permanent: once you glue items together, you cannot make edits later without cutting again. This can be problematic as you may wish to extend the length of one of the enclosed items (such as make the sound of a kick drum's tail longer, etc.). You cannot do this using Glue.

The other option is to **Group** items. This works well if you simply want to  move items around or select multiple items by clicking one item; however, you cannot use the other benefits of Reaper items, such as quickly looping, take envelopes, etc. Grouping can become confusing because Groups are highlighted in green around the items, but *not* around the boundary of the group itself. Groups can be unwieldy to work with in many musical contexts, such as a four-bar repetition. Groups tend to create visual clutter.

**Glue-Reversible** aims to address the shortcomings of both Glue and Groups, as well as restore the convenient functionality already present in items (looping, timestretching, and much more), by placing selected items in a new container item.

### How to use

**To use Glue-Reversible**, simply select items or make a time selection with items inside and trigger either of the Glue-Reversible scripts (time selection enabled/disabled).

To edit your glued items, the **Edit** script opens the created container item; the items inside are automatically grouped for you. You can see the container item created with Glue-Reversible, but the items inside are now visible and directly editable. Continue working with them as grouped items and/or reglue them again with Glue-Reversible. 

**Smart Glue/Edit** (with time selection enabled/disabled) will intelligently determine which action is required based on your item selections.

### Features
- Fills in the missing **nondestructive/reversible Glue function** in Reaper!
- - A.k.a.: Glue Groups, Item Containers, Container Items, Pooled Item Boxes, Pooled Audio Items
- Currently, Glue-Reversible container item copies are **pooled by default**. Editing and regluing one container item **updates all instances**. (Yes! We have scripted the missing native **pooled audio items** feature in Reaper along with everything else!)
- Supports **nesting Glue-Reversible container items** inside other container items! When you update the nested container item, the script checks the parent item and updates that as well. There is no limit in the code as to how many times you can nest – tested with 20 levels of nesting.

### Tips
- If you want to **move items** while Editing a container, you'll need to ungroup them temporarily. When you regroup them, ensure that you select ALL the items in the group so the script can keep track of the container and update all the pooled instances after reglue.
- If you want to **add new items** to a Glue-Reversible container item, select them AND at least one of the original items to make sure they get added to the existing container item. If you only tweak the existing items, you can select any item and reglue, and the script will remember which container item it belongs to.
- You can expand the **empty container** "grc" to create silence at the start and end of the glued wav, or just expand the time selection before reglue.
- **Using just the pooled audio item feature:** Feel free to glue a single audio item and make copies of that! Since every glued container item you copy is a pooled audio item, all you need to ensure all the copies stay updated is Edit any one of the pooled glue containers and reglue after.

### Notes
- Requires **SWS Plugin Extension**, of course!
- Don't **Clean current project directory** after gluing, or you'll lose your original items!
- When you **
-Reversible**, a new empty item "grc" is inserted under the original items. This item has the data to recall which group these items came from – don't delete it unless you want to glue the items and make a new, unpooled group that doesnt update other instances.
- Uses item notes/names to keep track of which container item items belong in. **Never delete "gr:1" or "grc:1" from items' names**, as the code depends on that label to find it! You can add text to notes/names AFTER – e.g. "gr:1 - My extra text"
- To create **MIDI container items**, the script uses "Apply track FX as new take" on each item to get a (silent) wav audio take. When you Edit, the wav take is removed and just the original MIDI take is restored to active. Currently only MIDI on virtual instrument tracks is supported.
- When using copies of Glue-Reversible container items, you can't make a copy of itself inside itself, as that would cause an **infinite recursion**.
- Uses **item selection set slot 10** at times to save and recall selected items. 
- Some **undo bugs** may still be lurking in this script, so you should prefer ungluing and regluing to undoing. But please create an Issue [here](https://github.com/MonkeyBars3k/ReaScripts/issues/new) if you notice any bugs.
 
### History

matthewjumpsoffbuildings created the powerful, excellent "Glue Groups" scripts: https://bitbucket.org/matthewjumpsoffbuildings/reaper-scripts/src/master/

MonkeyBars continues the effort with some different nomenclature (in the interest of onboarding new users and making it easy to find in the Actions Window), bugfixes, and additional features.


### Planned improvements
See [enhancement Issues](https://github.com/MonkeyBars3k/ReaScripts/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement).

### Report a Bug
Add a bug Issue [here](https://github.com/MonkeyBars3k/ReaScripts/issues/new).
