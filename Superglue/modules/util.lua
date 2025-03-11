-- @noindex

local Util = {}


local _constant = require("modules.constant")



function Util.copyFile(old_path, new_path)
  local old_file = io.open(old_path, "rb")
  local new_file = io.open(new_path, "wb")
  local old_file_sz, new_file_sz = 0, 0
  if not old_file or not new_file then
    return false
  end
  while true do
    local block = old_file:read(2^13)
    if not block then
      old_file_sz = old_file:seek( "end" )
      break
    end
    new_file:write(block)
  end
  old_file:close()
  new_file_sz = new_file:seek( "end" )
  new_file:close()
  return new_file_sz == old_file_sz
end

function Util.initEmptyTables(...)
  for i = 1, select('#', ...) do
    local tbl = select(i, ...)
    if tbl == nil then
      select(i, ...)[i] = {}
    else
      tbl = {}
    end
  end
end

function Util.deduplicateTable(t)
  local hash = {}
  local res = {}
  for _, v in ipairs(t) do
    if (not hash[v]) then
      res[#res+1] = v
      hash[v] = true
    end
  end
  return res
end

function Util.getTableSize(t)
    local count = 0
    for _, __ in pairs(t) do
        count = count + 1
    end
    return count
end

function Util.fileExists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function Util.getFileNameFromPath(file)
    return file:match("^.+[/\\](.+)$")
end

function Util.numberizeAndRoundElements(tables, elems)
  local this_table
  for i = 1, #tables do
    this_table = tables[i]
    for j = 1, #elems do
      this_table[elems[j]] = Util.round(tonumber(this_table[elems[j]]),_constant.api.time_value_decimal_resolution)
    end
  end
  return table.unpack(tables)
end

function Util.round(num, precision)
   return math.floor(num*(10^precision)+0.5) / 10^precision
end

function Util.stringifyArray(t)
  local s = ""
  local this_array_entry
  for i = 1, #t do
    this_array_entry = tostring(t[i])
    s = s .. this_array_entry
    if i ~= #t then
       s = s .. ", "
    end
  end
  if not s or s == "" then
    s = "none"
  end
  return s
end

function Util.concatenateArrays(array_of_arrays)
  local result = {}
  for _, arr in ipairs(array_of_arrays) do
    for _, value in ipairs(arr) do
        table.insert(result, value)
    end
  end
  return result
end

function Util.isPresentInArray(value, tbl)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

function Util.escapeRegexSpecialCharacters(s)
  local patternSpecials = "().%+-*?[^$"
  return (s:gsub("["..patternSpecials.."]", "%%%1"))
end



return Util
