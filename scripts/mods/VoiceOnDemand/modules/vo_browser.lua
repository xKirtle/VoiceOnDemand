local mod = get_mod("VoiceOnDemand")

if mod._vo_browser_module then return mod._vo_browser_module end

local DialogueSettings = require("scripts/settings/dialogue/dialogue_settings")
local Vo = require("scripts/utilities/vo")

local function build_file_list()
	local files, seen = {}, {}
	local function add(name)
		if not seen[name] then seen[name] = true; files[#files + 1] = name end
	end
	for _, name in ipairs(DialogueSettings.auto_load_files) do add(name) end
	for _, level_files in pairs(DialogueSettings.level_specific_load_files) do
		for _, name in ipairs(level_files) do add(name) end
	end
	table.sort(files)
	return files
end

local ALL_FILES = build_file_list()

local _file  = nil
local _rules = {}

local function get_player_unit()
	local player = Managers.player and Managers.player:local_player_safe(1)
	return player and player.player_unit
end

local function get_dialogue_ext(unit)
	return unit and ScriptUnit.has_extension(unit, "dialogue_system")
end

local function get_dialogue_system()
	local ext = Managers.state.extension
	return ext and ext:system_by_extension("DialogueExtension")
end

local function ensure_loaded(file, rule, diag_ext)
	if not diag_ext._vo_choice[rule] then
		local ds = get_dialogue_system()
		if ds and ds._vo_sources_cache then
			ds._vo_sources_cache:add_rule_file(file)
		end
	end
	return diag_ext._vo_choice[rule] ~= nil
end

local function play_rule(file, rule, line)
	local unit = get_player_unit()
	local ext = get_dialogue_ext(unit)
	if not ext then mod:echo("Must be in a mission"); return false end
	if not ensure_loaded(file, rule, ext) then
		mod:echo(string.format("No audio for '%s' (profile: %s)", rule, ext._vo_profile_name))
		return false
	end
	-- The engine refuses a new line while one is still playing; interrupt it so
	-- rapid back-to-back triggers actually fire.
	if ext.is_currently_playing_dialogue and ext:is_currently_playing_dialogue() then
		ext:stop_currently_playing_vo()
	end
	if line then
		ext:play_local_vo_event(rule, 0, nil, nil, nil, nil, nil, line)
	else
		Vo.play_local_vo_event(unit, rule, 0)
	end
	return true
end

-- number of audio variants in a rule (0 if unknown / not in a mission)
local function variant_count(file, rule)
	local ext = get_dialogue_ext(get_player_unit())
	if not ext then return 0 end
	ensure_loaded(file, rule, ext)
	local choice = ext._vo_choice and ext._vo_choice[rule]
	return choice and choice.sound_events_n or 0
end

local function load_file(filename, filter)
	local unit = get_player_unit()
	local ext = get_dialogue_ext(unit)
	if not ext then mod:echo("Must be in a mission"); return false end

	local voice_profile = ext._vo_profile_name
	local path = DialogueSettings.default_voSources_path .. filename .. "_" .. voice_profile

	if not Application.can_get_resource("lua", path) then
		mod:echo(string.format("No VO data for '%s' (profile: %s)", filename, voice_profile))
		return false
	end

	local source_data = require(path)
	local lfilter = filter and string.lower(filter)
	local rules = {}
	for rule_name in pairs(source_data) do
		if not lfilter or string.find(string.lower(rule_name), lfilter, 1, true) then
			rules[#rules + 1] = rule_name
		end
	end
	table.sort(rules)

	_file  = filename
	_rules = rules

	return true
end

local function get_state()
	return { file = _file, rules = _rules, all_files = ALL_FILES }
end

local _avail = { profile = nil, list = nil }

-- Files that actually contain VO lines for the local player's voice profile.
local function available_files()
	local ext = get_dialogue_ext(get_player_unit())
	if not ext then return ALL_FILES end
	local profile = ext._vo_profile_name
	if _avail.profile == profile and _avail.list then return _avail.list end

	local list = {}
	for _, f in ipairs(ALL_FILES) do
		local path = DialogueSettings.default_voSources_path .. f .. "_" .. profile
		if Application.can_get_resource("lua", path) and next(require(path)) then
			list[#list + 1] = f
		end
	end
	_avail.profile = profile
	_avail.list = list
	return list
end

local api = {
	play_rule       = play_rule,
	variant_count   = variant_count,
	load_file       = load_file,
	get_state       = get_state,
	all_files       = ALL_FILES,
	available_files = available_files,
}

mod._vo_browser_module = api
return api
