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

To change the contents of your Superitem, the **Edit** script "opens" the created Superitem, restoring the contained items once again. To Reglue, just use one of the Glue or Smart Action scripts again. The **Unglue** scripts restore the contained items to their state from before that pool's last Superglue (i.e., irreversibly restored the contained items in the Superitem).

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
- **Using just the pooled audio item feature:** Feel free to Superglue a _single audio item_ and make copies of that! Since every Superitem you copy is a pooled audio item, all you need to ensure all the copies stay updated is to Edit any one of the pooled Superitems and Reglue.
- **Using just the container feature:** The most basic application of Superglue is probably just treating your Superitem as a container item that can be edited easily later, i.e. a more convenient way to group items.
- Check out **all the scripts** that get installed when you sync the ReaPack repo. There are some very useful utilities.
- Make sure to examine the **options window** which enables numerous configurations for various use cases.
- While Superglue does add a default Pool indicator prefix to Superitem take names, you may end up changing the name. In this and other cases, it's useful to open up the **Superglue item info window** to see its Parent Pool ID and other relevant Superglue data.

### Requirements
- Requires **Reaper v6.43** or newer
- Requires **SWS Plugin Extension** and **js_ReaScript_API Plugin Extension**

### Warnings
#### Audio sources
- Be _very_ careful if you want to **Clean current project directory** after Supergluing – you could lose contained items' audio, since at that point those "items" aren't included in the project proper – they only exist as data (state chunks).
- Stay aware of the state of your Superitems whenever editing audio externally. If you're destructively editing audio in a contained item, or for example editing a subproject which is present as a contained item in a Superitem, such items' direct parent must be in Edit mode ("open") during your external audio source edits, or their ancestors (parent, grandparent, etc. Superitems) won't be updated.
#### MIDI
- Currently only **MIDI on virtual instrument tracks** is supported.
- To create **MIDI Superitems**, the script uses "Apply track FX as new take" on each item to get an audio take. When you Edit, the audio take is removed and just the original MIDI take is made active.
#### Editing Superitems
- When you Edit a Superitem, a **special white region** is automatically created so you can expand the size of the Superitem past its contained items once it is reglued. Superglue displays a warning message should you delete this "sizing region". (This message can be disabled in the options, in which case when you delete the sizing region, the items will revert to their presuperglued state as if you had Unglued.) **Be careful undoing** sizing region deletion, as the defer loop (constantly checking for sizing region deletion by the user) often gets confused.
- Be careful Editing a parent Superitem **near project start**. If a child Superitem would extend before project start, its source offset will adjust automatically so its audio is in the right place, but regluing could affect its sibling pooled Superitems.
- Remember that **restored items can extend beyond the size of your Superitem** on Edit. Stay aware of content in tracks (such as items, track envelopes, etc.) nearby.
- Reaper throws warnings that scripts are "running again" in various situations with Superglue (since it runs defer scripts), such as when you **Edit more than one Superitem** at the same time, and other cases. In Reaper's dialog, just select that you want to allow the Superglue script in question to run (always, if you don't like getting prompted). ReaScript devs can't get around this message until [this FR](https://forum.cockos.com/showthread.php?t=202416) is implemented.
#### Superitem configuration
- Multiple takes on Superitems are not supported. If you try to Edit a Superitem with multiple takes, you'll be prompted to explode them or cancel.
- Set the **item mix behavior** on your items (and tracks) very carefully, as that affects how your items glue. Unfortunately, [the ReaScript API does not allow setting this mode directly](https://forum.cockos.com/showthread.php?p=2525910) yet.
- When using copies of Superitems, you can't Superglue a copy of itself inside itself, as that would cause an **infinite recursion** and implode the universe in a Big Crunch type event. (This actually happened during dev a few times but I was safe inside my pocket microverse and just undid reality.)
- Superglue uses item notes to set background images for easy recognition of Superitems and contained items. Careful: **The background image will overwrite any item notes you already have on your glued items.** Just disable this feature in the script options window or with the included script if you don't like it for any reason.
#### Potential project conflicts
- Superglue uses **item selection set slot 10** and **SWS time selection set slot 5**.

### Glossary
- **Ancestor**: A Superitem in which another Superitem or other Superitems are nested – parents, grandparents, etc. are ancestors.
- **Child**: A Superitem which is nested (superglued) inside another Superitem (its parent)
- **Contained items**: Items whose data ("state chunks" in ReaScript parlance) are referenced in a Superitem's data
- **Descendant**: A Superitem nested one or more levels inside another Superitem – children, grandchildren, etc. are descendants.
- **Edit**: Restore a Superitem into its "contained" items reversibly/nondestructively, maintaining the ability to reglue them and retain Superitem properties and update its pool siblings
- **Instance**: Any Superitem from a given Pool
- **Nest**: Superglue a Superitem into or inside another Superitem
- **Parent**: The Superitem in which another Superitem is directly nested
- **Pool**: A group of siblings that update each other if Edited
- **Reglue**: Run a Superglue Glue script on items restored from an instance (in Edit mode)
- **Restored items**: Contained items which reappear after running an Edit or Unglue script on a Superitem
- **Sibling**: Pooled copy of a Superitem – Edit any sibling, and all its sibling and ancestor Superitems get updated as well.
- **Smart Action**: Superglue script that tries to guess the user's intention from the item selection – sometimes you'll be prompted for an action choice or warned that none can be determined automagically.
- **Superitem**: The resulting "container item" after Supergluing – really it's just a normal Reaper item, but Superglue stores all the data about the items that were glued into it, etc.
- **Unglue**: Restore a Superitem into its contained items irreversibly/destructively, deleting any connection to their pool and any of the former Superitem's properties
 
### History

matthewjumpsoffbuildings created the powerful, excellent "Glue Groups" scripts: https://bitbucket.org/matthewjumpsoffbuildings/reaper-scripts/src/master/

MonkeyBars continues the effort with some different nomenclature (in the interest of onboarding new users and making it easy to find in the Actions Window), bugfixes, and additional features.


### Planned improvements
See [enhancement Issues](https://github.com/MonkeyBars3k/ReaScripts/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement).

### Report a Bug
Add a bug Issue [here](https://github.com/MonkeyBars3k/ReaScripts/issues/new).
