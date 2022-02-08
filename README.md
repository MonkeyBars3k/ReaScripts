# MonkeyBars Reaper Scripts

The URL to import in ReaPack is https://github.com/MonkeyBars3k/ReaScripts/raw/master/index.xml.


## Superglue

### Background

There are two main ways to consolidate selected items on a track natively in Reaper: **Glue** and **Groups**. Both have disadvantages. 

**Glue** is permanent: once you glue items together, you cannot make edits later without cutting again. This can be problematic as you may wish make any number of changes to enclosed items (such as make the sound of a kick drum's tail longer, etc.). You cannot do this using Glue, a "destructive" edit.

The other option is to **Group** items. This works well if you simply want to move items around or select multiple items by clicking one item; however, you cannot use many other benefits of a single Reaper item, such as quickly looping, take envelopes etc. Grouping can also become confusing because Groups are highlighted in green around the items, but *not* around the boundary of the group itself. Groups can be unwieldy to work with in many musical contexts, such as a four-bar repetition, and they tend to create visual clutter.

**Superglue** aims to address the shortcomings of both Glue and Groups, restore the convenient functionality already present in items (looping, timestretching, and much more) by placing selected items in a new container item called a **Superitem** – _and_ provide users the convenience of **audio item pooling**.

### How to use

**To Superglue items**, simply select items and trigger one of the MB_Superglue Glue or Smart Action scripts.

To edit your Superitem, the **Edit** script opens the created Superitem, restoring the contained items once again. To Reglue, just use one of the Glue or Smart Action scripts again. The **Unglue** scripts restore the contained items to their state from before that pool's last Superglue (i.e., irreversibly removes the Superitem).

**Smart Action** scripts intelligently determine which action is required based on your item selection!

### Features
- Provides the missing **nondestructive/reversible Glue** feature in Reaper!
  - A.k.a.: Glue Groups, Item Containers, Container Items, Pooled Item Boxes, Pooled Audio Items
- Provides the missing **pooled audio items** feature in Reaper!
  - Superitem copies are **pooled by default**. Editing and regluing one Superitem **updates all instances**.
  - Run the script to Remove Superitem from current Pool to place a Superitem on its own new Pool.
  - Disable Superitem pooling by enabling the option to Remove Superitem siblings from Pool on Glue. Careful: this removes formerly copied Superitems from their pools. If you want a mix of pooled and unpooled Superitems, it's recommended to run the script to Remove Superitem from Pool manually as needed.
- Supports **nesting Superitems** inside _other_ Superitems! When you update the nested Superitem, Superglue checks the parent item and updates that Superitem as well. There is no limit in the code as to how many times you can nest Superitems – tested with 20 levels of nesting.
- Superglue has its own script options that can be selected by the user. Just run the script to open the options window and try them out. Scripts are supplied to toggle Boolean (on/off) options.
  - You can toggle expansion to time selection in the options window.

### Tips
- **Using just the pooled audio item feature:** Feel free to superglue a single audio item and make copies of that! Since every superglued container item you copy is a pooled audio item, all you need to ensure all the copies stay updated is Unglue any one of the pooled glue containers and reglue after.
- When superglue items are Unglued, an automatically created region can be used to increase the size of your glued container item. Otherwise, the size will be determined by the items selected as with native Reaper glue or by time selection, if you run one of those scripts.

### Notes
- Requires **Reaper v6.43** or newer
- Requires **SWS Plugin Extension**
- Stay aware of the state of your Superitems whenever editing audio externally. If you're destructively editing audio in a contained item, or for example editing a subproject which is present as a contained item in a Superitem, such items' direct parent must be in Edit mode ("open") during your external audio source edits, or their ancestors (parent, grandparent, etc. Superitems) won't be updated.
- When you Edit a Superitem, a "sizing region" is automatically created so you can expand the size of the Superitem past its contained items once it is reglued. Superglue displays a warning message should you delete this region. (This message can be disabled in the options, in which case when you delete the sizing region, the items will revert to their presuperglued state as if you had Unglued.) **Be careful undoing** sizing region deletion, as the defer loop (constantly checking for sizing region deletion by the user) can get a bit confused.
- Be _very_ careful if you want to **Clean current project directory** after Supergluing – you could lose contained items, since at that point, those "items" aren't included in the project proper – they only exist as data (state chunks).
- Be careful Editing a parent Superitem **near project start**. If a child Superitem would extend before project start, its source offset will adjust automatically so its audio is in the right place, but regluing could affect its sibling pooled Superitems.
- Superglue uses item notes to set background images for easy recognition of Superitems and contained items. Careful: **The background image will overwrite any item notes you already have on your glued items.** Just disable this feature in the script options window or with the included script if you don't like it for any reason.
- Reaper throws warnings that scripts are "running again" in various situations with Superglue (since it runs defer scripts), such as when you **Edit more than one Superitem** at the same time, and other cases. In Reaper's dialog, just select that you want to allow the Superglue script in question to run (always, if you don't like getting prompted). ReaScript devs can't get around this message until [this FR](https://forum.cockos.com/showthread.php?t=202416) is implemented. 
- To create **MIDI Superitems**, the script uses "Apply track FX as new take" on each item to get an audio take. When you Edit, the audio take is removed and just the original MIDI take is restored to active. _Currently only MIDI on virtual instrument tracks is supported._
- When using copies of Superitems, you can't Superglue a copy of itself inside itself, as that would cause an **infinite recursion** and probably implode the universe in a Big Crunch type event.
- Superglue uses **item selection set slot 10** and **SWS time selection set slot 5**.
 
### History

matthewjumpsoffbuildings created the powerful, excellent "Glue Groups" scripts: https://bitbucket.org/matthewjumpsoffbuildings/reaper-scripts/src/master/

MonkeyBars continues the effort with some different nomenclature (in the interest of onboarding new users and making it easy to find in the Actions Window), bugfixes, and additional features.


### Planned improvements
See [enhancement Issues](https://github.com/MonkeyBars3k/ReaScripts/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement).

### Report a Bug
Add a bug Issue [here](https://github.com/MonkeyBars3k/ReaScripts/issues/new).
