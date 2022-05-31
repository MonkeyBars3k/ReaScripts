-- @description MB_Superglue: Reversible, nondestructive glue and nesting pooled audio for Reaper
-- @author MonkeyBars
-- @version 2.00
-- @changelog Enable Glue/Edit/Unglue on multiple tracks at once (https://github.com/MonkeyBars3k/ReaScripts/issues/11); Enable Editing/Ungluing multiple Superitems at once (https://github.com/MonkeyBars3k/ReaScripts/issues/15)
-- @provides [main] .
--   [main] MB_Superglue - Edit - Reveal contained item(s) from selected Superitem previously glued by Superglue, retaining ability to Glue back to same Pool.lua
--   [main] MB_Superglue - Options - Display - Background images on new Superglue items - Superitems diagonal, contained items horizontal stripes (On-Off).lua
--   [main] MB_Superglue - Options - Display - Randomly color newly Superglued Superitem (On-Off).lua
--   [main] MB_Superglue - Options - Global - Open script options window.lua
--   [main] MB_Superglue - Options - Glue - Auto-increase channel count with take FX (On-Off).lua
--   [main] MB_Superglue - Options - Glue - Time selection (not sizing region) determines Superitem bounds (On-Off).lua
--   [main] MB_Superglue - Options - Reglue - Absolute or relative propagation length change on Siblings (still altered by playrate) (Absolute-Ask-Relative).lua
--   [main] MB_Superglue - Options - Reglue - Audio source position of Siblings is maintained (Enable-Ask-Disable).lua
--   [main] MB_Superglue - Options - Reglue - Length change of Edited Superitem propagates to Siblings (Enable-Ask-Disable).lua
--   [main] MB_Superglue - Options - Reglue - Looped source of Superitem determines Sizing Region bounds (On-Off).lua
--   [main] MB_Superglue - Options - Reglue - Playrate of Siblings affects their length & position propagation values (Enable-Ask-Disable).lua
--   [main] MB_Superglue - Options - Reglue - Position change of Edited Superitem's left edge propagates to Siblings (Enable-Ask-Disable).lua
--   [main] MB_Superglue - Options - Reglue - Remove Siblings from Edited Superitem's Pool, giving every Sibling its own new Pool (On-Off).lua
--   [main] MB_Superglue - Pool - Remove selected Superitem from current Pool & create new Pool for it.lua
--   [main] MB_Superglue - Smart Action - Glue or Edit selected item(s) by context.lua
--   [main] MB_Superglue - Smart Action - Glue or Unglue selected item(s) by context.lua
--   [main] MB_Superglue - Unglue - Reveal contained item(s) from selected Superitem & detach from Pool (won't propagate changes to siblings on Reglue).lua
--   [main] MB_Superglue - Utility - Display selected Superglue item info - Pool no., No. of contained items, Parent Pool, etc.lua
--   [main] MB_Superglue - Utility - Set all Superitems in project to one custom color.lua
--   [nomain] MB_Superglue - Utility - Dump Superglue project data to log.lua
--   [nomain] MB_Superglue-Utils.lua
--   [nomain] serpent.lua
--   [nomain] rtk.lua
--   [nomain] sg-dev-functions.lua
--   sg-bg-restored.png
--   sg-bg-superitem.png
--   sg-bg-restoredinstance.png
--   gnu_license_v3.txt
-- @link Superglue forum thread https://forum.cockos.com/showthread.php?p=2540818
-- @about Main Glue script & package metadata for MB_Superglue


-- Copyright (C) MonkeyBars 2022
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

initSuperglue(false)