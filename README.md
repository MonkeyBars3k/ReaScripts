# MonkeyBars Reaper Scripts

The URL to import in ReaPack is https://github.com/MonkeyBars3k/ReaScripts/raw/master/index.xml.


## Superglue

### Background

There are two main ways to consolidate selected items on a track natively in Reaper: **Glue** and **Groups**. Both have disadvantages. 

**Glue** is permanent: once you glue items together, you cannot make edits later without cutting again. This can be problematic as you may wish make any number of changes to enclosed items (such as make the sound of a kick drum's tail longer, etc.). You cannot do this using Glue.

The other option is to **Group** items. This works well if you simply want to  move items around or select multiple items by clicking one item; however, you cannot use the other benefits of Reaper items, such as quickly looping, take envelopes, etc. Grouping can become confusing because Groups are highlighted in green around the items, but *not* around the boundary of the group itself. Groups can be unwieldy to work with in many musical contexts, such as a four-bar repetition, and they tend to create visual clutter.

**Superglue** aims to address the shortcomings of both Glue and Groups, restore the convenient functionality already present in items (looping, timestretching, and much more) by placing selected items in a new container item – _and_ provide users the convenience of audio item pooling.

### How to use

**To Superglue items**, simply select items and trigger one of the Superglue Glue, Unglue, Explode, or Smart Action scripts (obey time selection enabled/disabled).

To edit your superglued item container, the **Unglue** script opens the created container item, revealing the contained items once again. To Reglue, just use one of the Glue or Smart Action scripts again. The **Explode** scripts open the superglued container item and returns the contained items to their state from before that pool's last superglue.

**Smart Action** (with time selection enabled/disabled) will intelligently determine which action is required based on your item selection.

### Features
- Provides the missing **nondestructive/reversible Glue feature** in Reaper!
  - A.k.a.: Glue Groups, Item Containers, Container Items, Pooled Item Boxes, Pooled Audio Items
- Currently, Superglued container item copies are **pooled by default**. Editing and regluing one container item **updates all instances**. (Yes! We have scripted the missing native **pooled audio items** feature in Reaper along with everything else!)
  - If you want to separate a container from its pool, Explode it then Superglue anew.
- Supports **nesting Superglued container items** inside _other_ superglued container items! When you update the nested container item, Superglue checks the parent item and updates that as well. There is no limit in the code as to how many times you can nest – tested with 20 levels of nesting.

### Tips
- **Using just the pooled audio item feature:** Feel free to superglue a single audio item and make copies of that! Since every superglued container item you copy is a pooled audio item, all you need to ensure all the copies stay updated is Unglue any one of the pooled glue containers and reglue after.
- When superglue items are Unglued, an automatically created region can be used to increase the size of your glued container item. Otherwise, the size will be determined by the items selected as with native Reaper glue or by time selection if you run one of those scripts.

### Notes
- Requires **Reaper v6.43** or newer
- Requires **SWS Plugin Extension**!
- Be _very_ careful if you want to **Clean current project directory** after supergluing – you could lose your superglued items, since at that point, those "items" aren't included in the project proper – they only exist as data (state chunks).
- Be very careful ungluing and editing a parent container item **near project start**. If a child container item would extend before project start, its source offset will adjust automatically so its audio is in the right place, but regluing could affect its pooled sibling container items.
- Superglue uses item notes to set background image for easy recognition of superglued container and contained items. Careful: **The background image will overwrite any item notes you already have on your glued items.** We plan to allow disabling of this feature in Superglue script options soon.
- To create **MIDI superglued container items**, the script uses "Apply track FX as new take" on each item to get an audio take. When you Unglue, the audio take is removed and just the original MIDI take is restored to active. _Currently only MIDI on virtual instrument tracks is supported._
- When using copies of superglued container items, you can't make a copy of itself inside itself, as that would cause an **infinite recursion**.
- Superglue uses **item selection set slot 10** and **SWS time selection set slot 5**.
 
### History

matthewjumpsoffbuildings created the powerful, excellent "Glue Groups" scripts: https://bitbucket.org/matthewjumpsoffbuildings/reaper-scripts/src/master/

MonkeyBars continues the effort with some different nomenclature (in the interest of onboarding new users and making it easy to find in the Actions Window), bugfixes, and additional features.


### Planned improvements
See [enhancement Issues](https://github.com/MonkeyBars3k/ReaScripts/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement).

### Report a Bug
Add a bug Issue [here](https://github.com/MonkeyBars3k/ReaScripts/issues/new).
