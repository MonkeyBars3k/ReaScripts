-- @noindex
-- @description This script can be used e.g. with a virtual instrument to create a pair of breakout tracks, 1 to send MIDI and 1 to receive audio, shows them only in the TCP and mixer respectively, and groups some of their controls (defined in groupNewTracks()).


local _api__current_project, _api__command_flag, _api__message_type_ok, _api__routing_type__send, _api__routing__src_channels, _api__routing__dest_channels, _api__routing__dest_track, _api__track__num, _api__track__want_defaults, _api__track__name, _api__info__set_new_val, _api__routing__midi__flags, _api__routing__midi__all_all, _api__routing__midi__none, _api__routing__audio__stereo_base, _api__routing__audio__none, _api__track_group__get_mask, _api__track_group__get_value, _api__track__show_in_mixer, _api__track__show_in_tcp, _api__track__channel_count, _command_id__deselect_all_tracks, _regex__chars_between_commas, _max_track_groups_count

_api__current_project = 0
_api__command_flag = 0
_api__message_type_ok = 0
_api__routing_type__send = 0
_api__routing__src_channels = "I_SRCCHAN"
_api__routing__dest_channels = "I_DSTCHAN"
_api__routing__dest_track = "P_DESTTRACK"
_api__track__num = "IP_TRACKNUMBER"
_api__track__want_defaults = true
_api__track__name = "P_NAME"
_api__info__set_new_val = 1
_api__routing__midi__flags = "I_MIDIFLAGS"
_api__routing__midi__all_all = 0
_api__routing__midi__none = -1
_api__routing__audio__stereo_base = 0
_api__routing__audio__none = -1
_api__track_group__get_mask = 0
_api__track_group__get_value = 0
_api__track__show_in_mixer = "B_SHOWINMIXER"
_api__track__show_in_tcp = "B_SHOWINTCP"
_api__track__channel_count = "I_NCHAN"
_command_id__deselect_all_tracks = 40297
_regex__chars_between_commas = "[^,]*"
_max_track_groups_count = 64 


-- for dev
-- package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
-- require("mb-dev-functions")



reaper.Undo_BeginBlock()


function getUserSelectedTrack()
	local user_selected_tracks_count, user_selected_track

	user_selected_tracks_count = reaper.CountSelectedTracks(_api__current_project)

	if user_selected_tracks_count == 0 then

		return false
	
	elseif user_selected_tracks_count > 1 then
		reaper.ShowMessageBox("This script is meant to add breakout tracks with routing to & from only one track. Select only one track (with your virutal instrument e.g.) and try again.", "Too many track selected", _api__message_type_ok)

		return false

	elseif user_selected_tracks_count == 1 then
		user_selected_track = reaper.GetSelectedTrack(_api__current_project, 0)

		return user_selected_track

	end
end


function getUserTrackNames()
	local user_input_title, inputs_count, caption_string_base, captions_csv, defaultvals_csv, retval, user_track_names, user_track_names_table

	user_input_title = "Choose a name for each new track pair you wish to add. Unused track groups will bse used in order from low to high."
	inputs_count = 16
	caption_string_base = "Track name "
	captions_csv = ""
	defaultvals_csv = ""
	user_track_names_table = {}

	for i = 1, inputs_count do
		captions_csv = captions_csv .. caption_string_base .. i .. ","
	end

	retval, user_track_names = reaper.GetUserInputs(user_input_title, inputs_count, captions_csv, defaultvals_csv)

	for track_name in string.gmatch(user_track_names, _regex__chars_between_commas) do
		
		if track_name ~= "" then
			table.insert(user_track_names_table, track_name)
		end
	end

	return user_track_names_table
end


function getTrackGroupMemberships()
	local all_tracks_count, all_tracks__group_memberships, all_tracks__group_memberships_33up, this_track

	all_tracks_count = reaper.CountTracks(_api__current_project)
	all_tracks__group_memberships = {}
	all_tracks__group_memberships_33up = {}

	for i = 0, all_tracks_count-1 do
		this_track = reaper.GetTrack(_api__current_project, i)
		all_tracks__group_memberships, all_tracks__group_memberships_33up = gatherGroupLeadFollowMembershipData(this_track, all_tracks__group_memberships, all_tracks__group_memberships_33up)
		all_tracks__group_memberships, all_tracks__group_memberships_33up = gatherGroupLeadNonFollowMembershipData(this_track, all_tracks__group_memberships, all_tracks__group_memberships_33up)
	end

	return all_tracks__group_memberships, all_tracks__group_memberships_33up
end


function gatherGroupLeadFollowMembershipData(track, all_tracks__group_memberships, all_tracks__group_memberships_33up)
	local all_lead_follow_track_group_params, this_group_param_lead, this_group_param_follow

	all_lead_follow_track_group_params = {"MEDIA_EDIT", "VOLUME", "VOLUME_VCA", "PAN", "WIDTH", "MUTE", "SOLO", "RECARM", "POLARITY", "AUTOMODE"}

	for j = 1, #all_lead_follow_track_group_params do
		this_group_param_lead = all_lead_follow_track_group_params[j] .. "_LEAD"
		this_group_param_follow = all_lead_follow_track_group_params[j] .. "_FOLLOW"

		table.insert(all_tracks__group_memberships, reaper.GetSetTrackGroupMembership(track, this_group_param_lead, _api__track_group__get_mask, _api__track_group__get_value))
		table.insert(all_tracks__group_memberships, reaper.GetSetTrackGroupMembership(track, this_group_param_follow, _api__track_group__get_mask, _api__track_group__get_value))
		table.insert(all_tracks__group_memberships_33up, reaper.GetSetTrackGroupMembershipHigh(track, this_group_param_lead, _api__track_group__get_mask, _api__track_group__get_value))
		table.insert(all_tracks__group_memberships_33up, reaper.GetSetTrackGroupMembershipHigh(track, this_group_param_follow, _api__track_group__get_mask, _api__track_group__get_value))
	end

	return all_tracks__group_memberships, all_tracks__group_memberships_33up
end



function gatherGroupLeadNonFollowMembershipData(track, all_tracks__group_memberships, all_tracks__group_memberships_33up)
	local non_lead_follow_track_group_params, this_group_param

	non_lead_follow_track_group_params = {"VOLUME_REVERSE", "PAN_REVERSE", "WIDTH_REVERSE", "NO_LEAD_WHEN_FOLLOW", "VOLUME_VCA_FOLLOW_ISPREFX"}

	for j = 1, #non_lead_follow_track_group_params do
		this_group_param = non_lead_follow_track_group_params[j]

		table.insert(all_tracks__group_memberships, reaper.GetSetTrackGroupMembership(track, this_group_param, _api__track_group__get_mask, _api__track_group__get_value))
		table.insert(all_tracks__group_memberships_33up, reaper.GetSetTrackGroupMembershipHigh(track, this_group_param, _api__track_group__get_mask, _api__track_group__get_value))
	end

	return all_tracks__group_memberships, all_tracks__group_memberships_33up
end


function getUnusedTrackGroups(all_tracks__group_memberships, all_tracks__group_memberships_33up)
	local all_group_memberships, used_track_groups_bitwise, unused_track_groups

	all_group_memberships = {all_tracks__group_memberships, all_tracks__group_memberships_33up}
	used_track_groups_bitwise = getUsedTrackGroupsBitwiseVals(all_group_memberships)
	used_track_groups_nums = getUsedTrackGroupNums(used_track_groups_bitwise)

	if #used_track_groups_nums == 0 then
		unused_track_groups = getTrackGroupsNums_IfAllUnused()

	else
		unused_track_groups = getTrackGroupsNums()
	end
	
	return unused_track_groups
end


function getUsedTrackGroupsBitwiseVals(all_group_memberships)
	local used_track_groups_bitwise, used_track_groups_nums, unused_track_groups, this_track_group_val, track_group_block_33up_idx, track_groups_in_block_count, this_track_group_block_is_33up

	used_track_groups_bitwise = {}

	for track_group_block = 1, #all_group_memberships do

		for i = 1, #all_group_memberships[track_group_block] do
			this_track_group_val = all_group_memberships[track_group_block][i]
			track_group_block_33up_idx = 2
			track_groups_in_block_count = 32

			if this_track_group_val ~= 0 then
				this_track_group_block_is_33up = track_group_block == track_group_block_33up_idx

				if this_track_group_block_is_33up then
					this_track_group_val = this_track_group_val << track_groups_in_block_count
				end

				table.insert(used_track_groups_bitwise, this_track_group_val)
			end
		end
	end

	used_track_groups_bitwise = deduplicateTable(used_track_groups_bitwise)

	return used_track_groups_bitwise
end


function getUsedTrackGroupNums(used_track_groups_bitwise)
	local used_track_groups_nums, these_used_track_group_nums

	used_track_groups_nums = {}

	for i = 1, #used_track_groups_bitwise do
		these_used_track_group_nums = getActiveBits(used_track_groups_bitwise[i])

		for j = 1, #these_used_track_group_nums do
			table.insert(used_track_groups_nums, these_used_track_group_nums[j])
		end
	end

	return used_track_groups_nums
end


function getTrackGroupsNums_IfAllUnused()
	local unused_track_groups = {}

	for i = 1, _max_track_groups_count do
		table.insert(unused_track_groups, i)
	end

	return unused_track_groups
end


function getTrackGroupsNums()
	local unused_track_groups, track_group_is_unused

	unused_track_groups = {}

	for i = 1, _max_track_groups_count do
		track_group_is_unused = false

		for j = 1, #used_track_groups_nums do

			if used_track_groups_nums[j] == i then
				track_group_is_unused = false

				break
			end

			track_group_is_unused = true
		end

		if track_group_is_unused then
			table.insert(unused_track_groups, i)
		end
	end

	return unused_track_groups
end


function iterateOverUserTrackNames(user_selected_track, user_track_names, unused_track_groups)
	local user_selected_track_highest_send_channels_dest_track_num, highest_channel_value__send_value, new_tracks, new_track_group

	
	user_selected_track_highest_send_channels_dest_track_num, highest_channel_value__send_value = getHighestSendChannelDestTrackNum(user_selected_track)

	for i = 1, #user_track_names do
		new_tracks = createAndNameTracks(i, user_track_names, user_selected_track_highest_send_channels_dest_track_num)
		new_track_group = unused_track_groups[i]

		showAndHideNewTracks(new_tracks)
		createRouting(new_tracks, user_selected_track, i, highest_channel_value__send_value)
		groupNewTracks(new_tracks, new_track_group)
		selectNewTracks(new_tracks)
	end
end


function getHighestSendChannelDestTrackNum(user_selected_track)
	local user_selected_track_highest_send_channels_dest_track_num, highest_channel_value__send_idx, highest_channel_value__send_value, highest_channel_value__dest_track

	highest_channel_value__send_idx, highest_channel_value__send_value = getHighestChannelVals(user_selected_track)
	highest_channel_value__dest_track = reaper.GetTrackSendInfo_Value(user_selected_track, _api__routing_type__send, highest_channel_value__send_idx-1, _api__routing__dest_track)

	if highest_channel_value__dest_track and highest_channel_value__dest_track ~= 0 then
		user_selected_track_highest_send_channels_dest_track_num = reaper.GetMediaTrackInfo_Value(highest_channel_value__dest_track, _api__track__num)

	else
		user_selected_track_highest_send_channels_dest_track_num = reaper.GetMediaTrackInfo_Value(user_selected_track, _api__track__num)
	end

	return user_selected_track_highest_send_channels_dest_track_num, highest_channel_value__send_value
end


function getHighestChannelVals(user_selected_track)
	local user_selected_track_sends_count, all_sends__src_channels

	user_selected_track_sends_count = reaper.GetTrackNumSends(user_selected_track, _api__routing_type__send)
	all_sends__src_channels = {}

	if user_selected_track_sends_count > 0 then
	
		for i = 0, user_selected_track_sends_count-1 do
			all_sends__src_channels[i+1] = reaper.GetTrackSendInfo_Value(user_selected_track, _api__routing_type__send, i, _api__routing__src_channels)
		end

	else
		all_sends__src_channels[1] = -1
	end

	highest_channel_value__send_idx, highest_channel_value__send_value = max(all_sends__src_channels)

	return highest_channel_value__send_idx, highest_channel_value__send_value
end


function createAndNameTracks(user_track_name_idx, user_track_names, user_selected_track_highest_send_channels_dest_track_num)
	local new_tracks, new_tracks_count, this_user_track_name, new_track_idx_iterator

	new_tracks = {}
	new_tracks_count = 2
	this_user_track_name = user_track_names[user_track_name_idx]

	for i = 1, new_tracks_count do
		new_tracks[i] = {}
		new_track_idx_iterator = (user_track_name_idx * 2) + i - 3
		new_tracks[i].idx = user_selected_track_highest_send_channels_dest_track_num + new_track_idx_iterator

		reaper.InsertTrackAtIndex(new_tracks[i].idx, _api__track__want_defaults)

		new_tracks[i].track = reaper.GetTrack(_api__current_project, new_tracks[i].idx)

		reaper.GetSetMediaTrackInfo_String(new_tracks[i].track, _api__track__name, this_user_track_name, _api__info__set_new_val)
	end

	return new_tracks
end


function showAndHideNewTracks(new_tracks)
	reaper.SetMediaTrackInfo_Value(new_tracks[1].track, _api__track__show_in_tcp, 1)
	reaper.SetMediaTrackInfo_Value(new_tracks[1].track, _api__track__show_in_mixer, 0)
	reaper.SetMediaTrackInfo_Value(new_tracks[2].track, _api__track__show_in_tcp, 0)
	reaper.SetMediaTrackInfo_Value(new_tracks[2].track, _api__track__show_in_mixer, 1)
end


function createRouting(new_tracks, user_selected_track, track_name_idx, highest_channel_value__send_value)
	local user_selected_track_new_rcv, user_selected_track__new_channel_count

	new_tracks[1].send_idx = reaper.CreateTrackSend(new_tracks[1].track, user_selected_track)
	user_selected_track_new_rcv = reaper.CreateTrackSend(user_selected_track, new_tracks[2].track)
	new_tracks[2].send_channels_value = getAudioSendChannelsValue(highest_channel_value__send_value, track_name_idx)

	addChannelsToUserSelectedTrack(user_selected_track, new_tracks[2].send_channels_value)
	configureNewTracksRouting(new_tracks, user_selected_track, user_selected_track_new_rcv)
end


function getAudioSendChannelsValue(highest_channel_value__send_value, track_name_idx)
	local user_selected_track_has_no_routing, send_channels_value

	user_selected_track_has_no_routing = highest_channel_value__send_value == -1

	if user_selected_track_has_no_routing then

		if track_name_idx == 1 then
			send_channels_value = 0

		else
			send_channels_value = highest_channel_value__send_value + (track_name_idx * 2) - 1
		end

	else
		send_channels_value = highest_channel_value__send_value + (track_name_idx * 2)
	end

	return send_channels_value
end


function addChannelsToUserSelectedTrack(user_selected_track, send_channels_value)
	local user_selected_track__new_channel_count = send_channels_value + 2

	reaper.SetMediaTrackInfo_Value(user_selected_track, _api__track__channel_count, user_selected_track__new_channel_count)
end


function configureNewTracksRouting(new_tracks, user_selected_track, user_selected_track_new_rcv)
	reaper.SetTrackSendInfo_Value(new_tracks[1].track, _api__routing_type__send, new_tracks[1].send_idx, _api__routing__src_channels, _api__routing__audio__none)
	reaper.SetTrackSendInfo_Value(new_tracks[1].track, _api__routing_type__send, new_tracks[1].send_idx, _api__routing__dest_channels, _api__routing__audio__none)
	reaper.SetTrackSendInfo_Value(new_tracks[1].track, _api__routing_type__send, new_tracks[1].send_idx, _api__routing__midi__flags, _api__routing__midi__all_all)
	reaper.SetTrackSendInfo_Value(user_selected_track, _api__routing_type__send, user_selected_track_new_rcv, _api__routing__src_channels, new_tracks[2].send_channels_value)
	reaper.SetTrackSendInfo_Value(user_selected_track, _api__routing_type__send, user_selected_track_new_rcv, _api__routing__dest_channels, _api__routing__audio__stereo_base)
	reaper.SetTrackSendInfo_Value(user_selected_track, _api__routing_type__send, user_selected_track_new_rcv, _api__routing__midi__flags, _api__routing__midi__none)
end


function groupNewTracks(new_tracks, new_track_group)
	local desired_track_group_params, apiTrackGroupFunction, new_track_group_bitwise

	desired_track_group_params = {"VOLUME", "PAN", "WIDTH", "MUTE", "SOLO", "POLARITY"}

	if new_track_group > 32 then
		new_track_group = new_track_group - 32
		apiTrackGroupFunction = reaper.GetSetTrackGroupMembershipHigh

	else
		apiTrackGroupFunction = reaper.GetSetTrackGroupMembership
	end

	new_track_group_bitwise = bitPositionToDecimal(new_track_group)

	for i = 1, #new_tracks do

		for j = 1, #desired_track_group_params do
			this_group_param_lead = desired_track_group_params[j] .. "_LEAD"
			this_group_param_follow = desired_track_group_params[j] .. "_FOLLOW"

			apiTrackGroupFunction(new_tracks[i].track, this_group_param_lead, new_track_group_bitwise, new_track_group_bitwise)
			apiTrackGroupFunction(new_tracks[i].track, this_group_param_follow, new_track_group_bitwise, new_track_group_bitwise)
		end
	end
end


function selectNewTracks(new_tracks)

	for i = 1, #new_tracks do
		reaper.SetTrackSelected(new_tracks[i].track, true)
	end
end




-- UTILITY FUNCTIONS --

function max(t)
    if #t == 0 then return nil, nil end
    local key, value = 1, t[1], fn
    fn = function(a,b) return a < b end
    for i = 2, #t do
      if fn(value, t[i]) then
         key, value = i, t[i]
      end
    end
    return key, value
end


function getActiveBits(n)
  local i, t = 1, {}
  while n ~= 0 do
    if n & 1 ~= 0 then t[#t + 1] = i end
    i, n = i + 1, n >> 1
  end
  return t
end


function bitPositionToDecimal(n)
   return (2^n)/2
end


function deduplicateTable(t)
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




function initBreakoutTrackCreation()
	local user_selected_track, user_track_names, all_tracks__group_memberships, all_tracks__group_memberships_33up, unused_track_groups

	user_selected_track = getUserSelectedTrack()

	if not user_selected_track then return end
	
	user_track_names = getUserTrackNames()

	if not user_track_names then return end

	all_tracks__group_memberships, all_tracks__group_memberships_33up = getTrackGroupMemberships()
	unused_track_groups = getUnusedTrackGroups(all_tracks__group_memberships, all_tracks__group_memberships_33up)

	if #unused_track_groups < #user_track_names then
		reaper.ShowMessageBox("There aren't enough free track groups to apply to the newly created track pairs. Either free up some more track groups by removing tracks from them, or try this script again creating less track pairs.", "Too few free track groups", _api__message_type_ok)

		return
	end

	reaper.Main_OnCommand(_command_id__deselect_all_tracks, _api__command_flag)
	iterateOverUserTrackNames(user_selected_track, user_track_names, unused_track_groups)
end

initBreakoutTrackCreation()


reaper.Undo_EndBlock("MB_Create new pair of grouped tracks with MIDI & stereo audio routing to & from selected (virtual instrument) tracks", -1)