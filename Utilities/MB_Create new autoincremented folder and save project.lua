-- @noindex


-- TESTING FUNCTIONS

-- function logV(name, val)
--   val = val or ""
--   reaper.ShowConsoleMsg(name.." = "..val.."\n")
-- end

-- function logStr(val)
--   reaper.ShowConsoleMsg(tostring(val)..", \n")
-- end


-- function logTable(t, name)
--   if name then
--     log("Iterate through table " .. name .. ":")
--   end
--   for k,v in pairs(t) do
--     logV(k,tostring(v))
--   end
-- end


-- function log(...)
--   local arg = {...}
--   local msg = "", i, v
--   for i,v in ipairs(arg) do
--     msg = msg..v..", "
--   end
--   msg = msg.."\n"
--   reaper.ShowConsoleMsg(msg)
-- end



-- CHANGE THESE 2 VALUES TO MATCH YOUR SYSTEM'S PATHS

local main_projects_folder = "/Users/gabriel/Projects/proj_save_test"
local project_template_path = "/Users/gabriel/Library/Application Support/REAPER/ProjectTemplates/StreamBasic-template_test.RPP"




function listFolders(container_folder)
  local p, contained_folders

  p = io.popen('find "'..container_folder..'" -type d -mindepth 1 -maxdepth 1')
  contained_folders = {}

  for folder in p:lines() do
    table.insert(contained_folders, folder)
  end

  return contained_folders
end


function make3Digits(num)
  local digits_count, leading_zeroes

  digits_count = string.len(num)
  leading_zeroes = ""

  if digits_count == 2 then
    leading_zeroes = "0"

  elseif digits_count == 1 then
    leading_zeroes = "00"
  end

  return leading_zeroes .. tostring(num)
end


local all_month_folders, last_month_folder, all_project_folders, last_project_folder, last_project_number, new_project_number, new_project_folder, new_project_name, retval, current_project_path, temp_reaproject, temp_project_path, new_project_path, rename_succeeded


reaper.Undo_BeginBlock()

all_month_folders = listFolders(main_projects_folder)

table.sort(all_month_folders)

last_month_folder = all_month_folders[#all_month_folders]

all_project_folders = listFolders(last_month_folder)

table.sort(all_project_folders)

last_project_folder = all_project_folders[#all_project_folders]
last_project_number = string.match(last_project_folder, "%[%d%d%d%]")
last_project_number = string.match(last_project_number, "%d%d%d")
last_project_number = tonumber(last_project_number)
new_project_number = make3Digits(last_project_number+1)
new_project_folder = "[" .. new_project_number .. "]"
new_project_folder = string.gsub(new_project_folder, "%s", " ")
new_project_name = "[" .. new_project_number .. "].RPP"

reaper.Main_openProject(project_template_path)
reaper.Main_OnCommand(41895, 0) -- save new version of project

retval, current_project_path = reaper.EnumProjects(-1)

os.remove(current_project_path .. "-UNDO")
os.execute("mkdir " .. "'" .. last_month_folder .. "/" .. new_project_folder .. "'")

temp_reaproject, temp_project_path = reaper.EnumProjects(-1)
new_project_path = last_month_folder .. "/" .. new_project_folder .. "/" .. new_project_name
rename_succeeded = os.rename(temp_project_path, new_project_path)

reaper.Main_openProject(new_project_path)
reaper.Undo_EndBlock("MB_Create new autoincremented folder and save project", -1)