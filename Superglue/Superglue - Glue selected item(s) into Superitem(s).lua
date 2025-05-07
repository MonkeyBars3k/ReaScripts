-- @description MB_Superglue: Reversible, nondestructive glue and nesting pooled audio for Reaper
-- @author MonkeyBars
-- @version 1.900
-- @changelog Enable Glue/Edit/Unglue on multiple tracks at once (https://github.com/MonkeyBars3k/ReaScripts/issues/11); Enable Editing/Ungluing multiple Superitems at once (https://github.com/MonkeyBars3k/ReaScripts/issues/15); Add script: Pool - Remove restored items from Pool (https://github.com/MonkeyBars3k/ReaScripts/issues/283); Add Option: Enable multi-item Edit/Unglue/Remove from Pool (https://github.com/MonkeyBars3k/ReaScripts/issues/343); Add option: Retain only the latest Superglue source media (undo history offline) (https://github.com/MonkeyBars3k/ReaScripts/issues/344); Reglue with Sibling DePool enabled throws error (https://github.com/MonkeyBars3k/ReaScripts/issues/345); Display item info: Support multiitem (https://github.com/MonkeyBars3k/ReaScripts/issues/348); Reglued child relative position to parent superitem position can't go negative (stuck at 0) (https://github.com/MonkeyBars3k/ReaScripts/issues/349); Replace simple condition assignments with short-circuit evaluations; Restored items placement wrong after DePool then Edit or Unglue (https://github.com/MonkeyBars3k/ReaScripts/issues/361); Display item info: Support multiitem (https://github.com/MonkeyBars3k/ReaScripts/issues/348); Remove Near Project Start submodule (https://github.com/MonkeyBars3k/ReaScripts/issues/376); Trying to Edit non-instance restored items throws Too many siblings error (https://github.com/MonkeyBars3k/ReaScripts/issues/375); New module system (https://github.com/MonkeyBars3k/ReaScripts/issues/379); Fixed Lanes support (https://github.com/MonkeyBars3k/ReaScripts/issues/364); Split up Remove script into 2 (https://github.com/MonkeyBars3k/ReaScripts/issues/377)
-- @provides [main] .
--   [main] Superglue - Change Option - Absolute or relative length propagation to Siblings on Reglue (Absolute-Ask-Relative).lua
--   [main] Superglue - Change Option - Add background image on new Superitems and contained items (On-Off).lua
--   [main] Superglue - Change Option - Auto-increase Superitem channel count from take FX on Glue (On-Off).lua
--   [main] Superglue - Change Option - Color newly created Superitems randomly (On-Off).lua
--   [main] Superglue - Change Option - Disable Superitem Pooling, generating new Pool for every Sibling on every Reglue (On-Off).lua
--   [main] Superglue - Change Option - Maintain loop length of Superitems on Reglue (On-Off).lua
--   [main] Superglue - Change Option - Maintain Siblings' source offset on Reglue (Enable-Ask-Disable).lua
--   [main] Superglue - Change Option - Multi-item Edit, Unglue, or DePool in single action (On-Off).lua
--   [main] Superglue - Change Option - Propagate Edited Superitems' left edge changes to Siblings on Reglue (Enable-Ask-Disable).lua
--   [main] Superglue - Change Option - Propagate Edited Superitems' length changes to Siblings on Reglue (Enable-Ask-Disable).lua
--   [main] Superglue - Change Option - Retain only the latest Superglue source media (On-Off).lua
--   [main] Superglue - Change Option - Siblings' playrate affects their length & position propagation values on Reglue (Enable-Ask-Disable).lua
--   [main] Superglue - Change Option - Time selection determines Superitem bounds on initial Glue (On-Off).lua
--   [main] Superglue - Edit selected Superitem(s).lua
--   [main] Superglue - Generate new Pool for each selected Superitem.lua
--   [main] Superglue - Open Options window.lua
--   [main] Superglue - Remove selected restored item(s) from Pool(s).lua
--   [main] Superglue - Smart Glue or Edit selected item(s) by context.lua
--   [main] Superglue - Smart Glue or Unglue selected item(s) by context.lua
--   [main] Superglue - Unglue selected Superitem(s).lua
--   [main] Superglue - Utility - Set all Superitems in project to one custom color.lua
--   [main] Superglue - Utility - View selected Superglue items' data.lua
--   [nomain] Superglue - Utility - Dump Superglue project data to log.lua
--   [nomain] Superglue.lua
--   [nomain] module-utils.lua
--   [nomain] lib/serpent.lua
--   [nomain] lib/rtk.lua
--   [nomain] modules/ancestor.lua
--   [nomain] modules/common.lua
--   [nomain] modules/constant.lua
--   [nomain] modules/data.lua
--   [nomain] modules/depool.lua
--   [nomain] modules/dev.lua
--   [nomain] modules/edit.lua
--   [nomain] modules/glue.lua
--   [nomain] modules/init.lua
--   [nomain] modules/iteminfo.lua
--   [nomain] modules/lanes.lua
--   [nomain] modules/multi.lua
--   [nomain] modules/options.lua
--   [nomain] modules/overglue.lua
--   [nomain] modules/reglue.lua
--   [nomain] modules/sibling.lua
--   [nomain] modules/single.lua
--   [nomain] modules/sizing.lua
--   [nomain] modules/state.lua
--   [nomain] modules/util.lua
--   [nomain] modules/vi.lua
--   assets/sg-bg-restored.png
--   assets/sg-bg-restoredinstance.png
--   assets/sg-bg-superitem.png
--   assets/sg-logo-nobg-sm.png
--   gnu_license_v3.txt
-- @link Superglue forum thread https://forum.cockos.com/showthread.php?p=2540818
-- @about Main Glue script & package metadata for MB_Superglue


-- === SCRIPT REQUIREMENTS ===
-- Reaper v6.43+
-- Reaper SWS plug-in extension v2.13.1.0+ (https://www.sws-extension.org/download/pre-release)
-- js_ReaScript_API plug-in extension (https://github.com/ReaTeam/Extensions/raw/master/index.xml)


-- Copyright (C) MonkeyBars 2025
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.


local _, script_file = reaper.get_action_context()
local script_dir = script_file:match("^(.*[/\\])")

package.path = package.path .. ";" .. script_dir .. "?.lua"

require("Superglue").init("main.Glue")
