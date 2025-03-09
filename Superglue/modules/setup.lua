-- @noindex

local Setup = {}


function Setup.bootstrap()
  local _, script_file = reaper.get_action_context()
  local script_dir = reaper.JS_ReaScript_GetPathToFolder(script_file)

  package.path = package.path .. ";" .. script_dir .. "?.lua" .. ";" .. script_dir .. "modules/?.lua"

  package.preload["sg_paths"] = function()
    return {
      script_dir = script_dir,
      join = function(...)
        local parts = {...}
        return table.concat(parts, "/")
      end
    }
  end

  return script_dir
end


local internal_modules = {
  "constant",
  "state",
  "util",
  "common",
  "data",
  "options",
  "init",
  "dev",
  "glue",
  "edit",
  "unglue",
  "depool",
  "lanes",
  "single",
  "multi",
  "iteminfo",
  "vi"
}

-- List of external libraries with their paths
local external_libs = {
  rtk = "lib.rtk",
  serpent = "lib.serpent"
}

local modules = {}
local module_names = {}

function Setup.load(module_string)

  -- Parse comma-separated module string
  for name in string.gmatch(module_string, "([^,%s]+)") do
    table.insert(module_names, name)
  end

  -- Load each requested module
  for _, name in ipairs(module_names) do
    if external_libs[name] then
      -- Load external library
      modules[name] = require(external_libs[name])
    else
      -- Check if it's a valid internal module
      local is_valid = false
      for _, mod_name in ipairs(internal_modules) do
        if name == mod_name then
          is_valid = true
          break
        end
      end

      if is_valid then
        -- Load internal module
        modules[name] = require("modules." .. name)
      else
        error("Unknown module: " .. name)
      end
    end
  end

  -- Inject dependencies for modules that support it
  for _, module in pairs(modules) do
    if type(module.injectDependencies) == "function" then
      module.injectDependencies(modules)
    end
  end

  -- Return the modules in the order requested
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
