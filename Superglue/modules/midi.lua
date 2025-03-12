-- @noindex

local Midi = {}


local loadDependencies, loadCircularDependencies, _vi, _module_utils, _init

-- local _dev = require("modules.dev")

loadDependencies = (function()
  _vi = require("modules.vi")

  _module_utils = require("module-utils")
end)()


loadCircularDependencies = (function()
  _init = function() return _module_utils.lazyRequire("init") end
end)()



function Midi.pureMidiItemIsSelected(selected_items)
  local this_item, this_item_take, midi_item_is_selected

  for i = 1, #selected_items do
    this_item = selected_items[i]
    this_item_take = reaper.GetActiveTake(this_item)
    midi_item_is_selected = Midi.midiItemIsSelected(this_item)

    if midi_item_is_selected then

      break
    end
  end

  if midi_item_is_selected == true then

    return _vi.virtualInstrumentIsInactive(this_item, this_item_take)

  elseif midi_item_is_selected == "abort" then

    return true
  end
end


function Midi.midiItemIsSelected(item)
  local active_take, active_take_is_midi

  active_take = reaper.GetActiveTake(item)

  if not active_take then
    _init.throwOfflineTakeWarning(false, true)

    return "abort"
  end

  active_take_is_midi = reaper.TakeIsMIDI(active_take)

  if active_take and active_take_is_midi then

    return true

  else

    return false
  end
end



return Midi
