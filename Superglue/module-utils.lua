-- @noindex

local ModuleUtils = {}


local cache = {}

function ModuleUtils.lazyRequire(module_name)

  if not cache[module_name] then
      cache[module_name] = require("modules." .. module_name)
  end

  return cache[module_name]
end



return ModuleUtils
