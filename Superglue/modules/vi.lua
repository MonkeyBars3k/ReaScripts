-- @noindex

local Vi = {}


local loadDependencies, _constant


loadDependencies = (function()
  _constant = require("modules.constant")
end)()



function Vi.virtualInstrumentIsInactive(item, item_take)
  local current_track, track_virtual_instrument_idx, track_has_virtual_instrument, track_virtual_instrument_is_enabled, track_virtual_instrument_is_muted, take_first_virtual_instrument_idx, take_virtual_instrument_is_enabled, take_virtual_instrument_is_muted, user_response_ignore_muted_virtual_instrument

  current_track = reaper.GetMediaItemTrack(item)
  track_virtual_instrument_idx = reaper.TrackFX_GetInstrument(current_track)
  track_has_virtual_instrument = track_virtual_instrument_idx ~= -1
  track_virtual_instrument_is_enabled = reaper.TrackFX_GetEnabled(current_track, track_virtual_instrument_idx)
  track_virtual_instrument_is_muted = track_has_virtual_instrument and not track_virtual_instrument_is_enabled
  take_first_virtual_instrument_idx, take_virtual_instrument_is_enabled = Vi.takeVirtualInstrumentIsActive(item_take)
  take_virtual_instrument_is_muted = take_first_virtual_instrument_idx and not take_virtual_instrument_is_enabled

  if track_virtual_instrument_is_muted or take_virtual_instrument_is_muted then
    user_response_ignore_muted_virtual_instrument = reaper.ShowMessageBox("The first virtual instrument in the FX chain is bypassed. Are you sure you want to Superglue the item(s)?", "Warning: Bypassed VI", _constant.api.msg.type.yes_no)

    if user_response_ignore_muted_virtual_instrument == _constant.api.msg.response.no then

      return true
    end

  elseif not track_has_virtual_instrument and not take_virtual_instrument_is_enabled then
    reaper.ShowMessageBox(_constant.brand.name .. " can't glue pure MIDI without a virtual instrument. Add/enable a virtual instrument to render audio into the superitem or try a different item selection.", "Pure MIDI selected", _constant.api.msg.type.ok)

    return true
  end
end


function Vi.takeVirtualInstrumentIsActive(item_take)
  local take_fx_count, retval, take_fx_type, take_fx_is_virtual_instrument, take_first_virtual_instrument_idx, take_first_virtual_instrument_is_enabled

  take_fx_count = reaper.TakeFX_GetCount(item_take)

  for i = 0, take_fx_count-1 do
    retval, take_fx_type = reaper.TakeFX_GetNamedConfigParm(item_take, i, "fx_type")
    take_fx_is_virtual_instrument = string.match(take_fx_type, "i$")

    if take_fx_is_virtual_instrument then
      take_first_virtual_instrument_idx = i

      break
    end
  end

  if take_first_virtual_instrument_idx then
    take_first_virtual_instrument_is_enabled = reaper.TakeFX_GetEnabled(item_take, take_first_virtual_instrument_idx)

    return take_first_virtual_instrument_idx, take_first_virtual_instrument_is_enabled
  end
end



return Vi
