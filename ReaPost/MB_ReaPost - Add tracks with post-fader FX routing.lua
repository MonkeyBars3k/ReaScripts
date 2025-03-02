-- for dev only
package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("mb-dev-functions")



dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")



local selected_tracks_count, this_selected_track

selected_tracks_count = reaper.CountSelectedTracks(0)


function initReaPost()
	for i = 0, selected_tracks_count-1 do
		this_selected_track = reaper.GetSelectedTrack(0, i)

		-- outputReaLearnParams(this_selected_track)
		outputParamMods(this_selected_track)
	end
end


function outputParamMods(selected_track)
	local retval, track_chunk, track_fx_chunk, track_fx_param_mods_count, this_param_table

	retval, track_chunk = reaper.GetTrackStateChunk(selected_track, "", false)
	track_fx_chunk = ultraschall.GetFXStateChunk(track_chunk)
	-- track_fx_param_mods_count = ultraschall.CountParmModFromFXStateChunk(track_fx_chunk, 1)

	for i = 7, 8 do
		this_param_table = ultraschall.GetParmModTable_FXStateChunk(track_fx_chunk, 1, i)

		logTable(this_param_table)
	end
end


function outputReaLearnParams(selected_track)
	local realearn_fx_idx, params_count, realearn_allparams, retval, this_param_name, this_param_value

	realearn_fx_idx = 2
	params_count = reaper.TrackFX_GetNumParams(selected_track, realearn_fx_idx)
	realearn_allparams = {}

	for i = 0, params_count do
		retval, this_param_name = reaper.TrackFX_GetParamName(selected_track, realearn_fx_idx, i)
		retval, this_param_value = reaper.TrackFX_GetParamNormalized(selected_track, realearn_fx_idx, i)
		realearn_allparams[this_param_name] = this_param_value

		logStr(this_param_name)
		logStr(this_param_value)
	end

	-- logTable(realearn_allparams)
end



initReaPost()