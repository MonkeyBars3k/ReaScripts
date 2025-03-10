-- @noindex

local Setup = {}


function Setup.bootstrap()
  local script_dir = Setup.getScriptPath()

  Setup.setPackageVals(script_dir)

  return script_dir
end


function Setup.getScriptPath()
  local _, script_file = reaper.get_action_context()
  local script_dir = Setup.extractDirectoryPath(script_file)

  return script_dir
end


function Setup.extractDirectoryPath(filePath)
  local directory = filePath:match("^(.*[/\\])")

  return directory
end


function Setup.setPackageVals(script_dir)
  local libPath = script_dir .. "lib/?.lua"
  local modulesPath = script_dir .. "modules/?.lua"

  package.path = package.path .. ";" .. libPath  .. ";" .. modulesPath
  package.preload["sg_paths"] = Setup.returnPaths(script_dir)
end


function Setup.returnPaths(script_dir)

  return {
    script_dir = script_dir,

    join = function(...)
      local parts = {...}

      return table.concat(parts, "/")
    end
  }
end


-- place these outside for later usage in other functions for dev purposes if needed
local internal_modules = {
  "common",
  "constant",
  "data",
  "depool",
  "dev",
  "edit",
  "glue",
  "init",
  "iteminfo",
  "lanes",
  "multi",
  "options",
  "reglue",
  "single",
  "state",
  "util",
  "vi"
}

local external_libs = {
  rtk = "lib.rtk",
  serpent = "lib.serpent"
}

local modules = {}
local module_names = {}


function Setup.load(module_string)
  Setup.parseModuleNames(module_string)
  Setup.loadModules()
  Setup.injectDependencies()

  return Setup.orderModules()
end


function Setup.parseModuleNames(module_string)
  local module_name_pattern = "([^,%s]+)"

  for name in string.gmatch(module_string, module_name_pattern) do
    table.insert(module_names, name)
  end
end


function Setup.loadModules()

  for _, name in ipairs(module_names) do

    if external_libs[name] then
      modules[name] = require(external_libs[name])

    else
      local is_valid = false

      for _, mod_name in ipairs(internal_modules) do

        if name == mod_name then
          is_valid = true

          break
        end
      end

      if is_valid then
        modules[name] = require("modules." .. name)

      else
        error("Unknown module: " .. name)
      end
    end
  end
end


function Setup.injectDependencies()

  for _, module in pairs(modules) do

    if type(module.injectDependencies) == "function" then
      module.injectDependencies(modules)
    end
  end
end


function Setup.orderModules()
  local ordered_modules = {}

  for i, name in ipairs(module_names) do
    ordered_modules[i] = modules[name]
  end

  return table.unpack(ordered_modules)
end


-- can't self-execute at this point; explore other architecture
-- local wrapFunctionsInTestLogs = (function()
--   local _dev = modules.dev

--   if not _dev or not _dev.config.test_logging_enabled then return end

--   for _, name in ipairs(module_names) do
--     modules[name] = _dev.wrapWithLogging(modules[name], name)
--   end
-- end)()


return Setup
