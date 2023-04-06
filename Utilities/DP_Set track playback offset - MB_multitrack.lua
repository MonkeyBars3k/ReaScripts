-- @noindex
--
-- Requires Lokasenna_GUI v2
--
-- Quickly alter playback time offset on selected track(s) without having to keep opening the track routing options.
--
-- ~For dev~
-- package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
-- require("mb-dev-functions")


local _lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")

if not _lib_path or _lib_path == "" then
 reaper.MB("Couldn't load the Lokasenna_GUI library. Please run 'Script: Set Lokasenna_GUI v2 library path.lua' in your Action List.", "Whoops!", 0)

 return
end

local _track_count = reaper.CountSelectedTracks()

if _track_count < 1 then
	reaper.MB("No track selected. Select a track first", "Whoops!", 0)

	return
end


loadfile(_lib_path .. "Core.lua")()
GUI.req("Classes/Class - Menubox.lua")()
GUI.req("Classes/Class - Knob.lua")()
GUI.req("Classes/Class - Slider.lua")()
GUI.req("Classes/Class - Button.lua")()
GUI.req("Classes/Class - Textbox.lua")()
GUI.req("Classes/Class - Label.lua")()


local _api_playback_offset_flag, _api_playback_offset_flag_bypassed, _api_play_offset, _api_time_resolution_divisor, _api_undo_states_flag_track_routing, _api_current_project, _slider_range, _first_selected_track, _current_delay

_api_playback_offset_flag = "I_PLAY_OFFSET_FLAG"
_api_playback_offset_flag_bypassed = 1
_api_play_offset = "D_PLAY_OFFSET"
_api_time_resolution_divisor = 1000
_api_undo_states_flag_track_routing = 1
_api_current_project = 0
_slider_range = 100
_first_selected_track = reaper.GetSelectedTrack(0, 0)
_current_delay = reaper.GetMediaTrackInfo_Value(_first_selected_track, _api_play_offset) * _api_time_resolution_divisor



function setUpGUI()
	GUI.name, GUI.x, GUI.y, GUI.w, GUI.h = "Set Playback Offset", 200, 200, 500, 210
	GUI.fonts[5] = {"Helvetica Neue", 15, "i"}

	GUI.New("coming_soon", "Label", 1, 148, 15, "Unit and range controls coming soon!", false, 5)
	-- GUI.New("unit", "Menubox", 1, 40, 10, 55, 25, "Unit", "ms,samples", 3, true)
	-- GUI.New("range", "Knob", 1, 420, 5, 30, "Slider range: " .. _slider_range .. "ms", 5, 1000, _slider_range, 5, false)
	GUI.New("delay_slider", "Slider", 10, 20, 90, 450, "Playback Offset (ms)", -_slider_range, _slider_range, _slider_range)
	GUI.New("textbox", "Textbox", 50, 340, 141, 45, 24, "")
	GUI.New("set_button", "Button", 1, 390, 140, 64, 24, "Set offset", set_track_current_delay)
	GUI.New("btn_plus_1", "Button", 1, 60, 130, 34, 24, "+1", track_current_delay_1)
	GUI.New("btn_minus_1", "Button", 1, 20, 130, 34, 24, "-1", track_current_delay_m1)
	GUI.New("btn_plus_10", "Button", 1, 60, 160, 34, 24, "+10", track_current_delay_10)
	GUI.New("btn_minus_10", "Button", 1, 20, 160, 34, 24, "-10", track_current_delay_m10)
end

setUpGUI()



function setTracksPlaybackDelay(slider_value, refresh_track_list, declare_undo_block, bypass_playback_offset)
	local playback_offset_enabled, this_track

	if refresh_track_list then
		_track_count = reaper.CountSelectedTracks()

		if _track_count < 1 then return end
	end

	if declare_undo_block then
		reaper.Undo_BeginBlock()
	end

	playback_offset_enabled = reaper.GetMediaTrackInfo_Value(_first_selected_track, _api_playback_offset_flag)
	
	for i = 0, _track_count-1 do
		this_track = reaper.GetSelectedTrack(_api_current_project, i)

		if bypass_playback_offset then
			reaper.SetMediaTrackInfo_Value(this_track, _api_playback_offset_flag, _api_playback_offset_flag_bypassed)
		end
	
		if playback_offset_enabled&1 ~= 0 then
		  reaper.SetMediaTrackInfo_Value(this_track, _api_playback_offset_flag, playback_offset_enabled&(~1))
		end

		reaper.SetMediaTrackInfo_Value(this_track, _api_play_offset, slider_value / _api_time_resolution_divisor)
	end

	if declare_undo_block then
		reaper.Undo_EndBlock("Set track playback offset", _api_undo_states_flag_track_routing)
	end
end


function adjustTracksPlaybackDelay(adjustment_amount)
	_current_delay = _current_delay + adjustment_amount
	local slider_value = _current_delay + _slider_range

	GUI.Val("delay_slider", slider_value)
	setTracksPlaybackDelay(_current_delay, true, true)
end


-- function GUI.elms.range:onmouseup()
-- 	GUI.Knob.onmouseup(self)

-- 	_slider_range = GUI.Val("range")
-- 	GUI.elms.delay_slider.min = -_slider_range
-- 	GUI.elms.delay_slider.max = _slider_range

-- 	GUI.elms.delay_slider:redraw()
-- end


function GUI.elms.delay_slider:onmousedown()
	GUI.Slider.onmousedown(self)

	_track_count = reaper.CountSelectedTracks()
end


function GUI.elms.delay_slider:ondrag()
	local slider_value = GUI.Val("delay_slider")

 	GUI.Slider.ondrag(self)
	setTracksPlaybackDelay(slider_value, false, false, false)

	_current_delay = slider_value
end


function GUI.elms.delay_slider:onmouseup()
	local slider_value = GUI.Val("delay_slider")

 	reaper.Undo_BeginBlock()
	GUI.Slider.onmouseup(self)
	setTracksPlaybackDelay(slider_value, false, false, false)

	_current_delay = slider_value

	reaper.Undo_EndBlock("Set track playback offset", _api_undo_states_flag_track_routing)
end


function GUI.elms.delay_slider:ondoubleclick()
	reaper.Undo_BeginBlock()
	GUI.Slider.ondoubleclick(self)
	setTracksPlaybackDelay(0, true, true, true)

	_current_delay = _slider_range

	reaper.Undo_EndBlock("Set track playback offset", _api_undo_states_flag_track_routing)
end


function GUI.elms.btn_minus_1:onmouseup()
	adjustTracksPlaybackDelay(-1)
end


function GUI.elms.btn_plus_1:onmouseup()
	adjustTracksPlaybackDelay(1)
end


function GUI.elms.btn_minus_10:onmouseup()
	adjustTracksPlaybackDelay(-10)
end


function GUI.elms.btn_plus_10:onmouseup()
	adjustTracksPlaybackDelay(10)
end


function GUI.elms.set_button:onmouseup()	
	local textbox_value = GUI.Val("textbox")
	_current_delay = tonumber(textbox_value)

	setTracksPlaybackDelay(_current_delay, true, true, false)
end


GUI.Init()
GUI.Main()