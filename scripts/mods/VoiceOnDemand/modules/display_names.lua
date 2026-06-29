local mod = get_mod("VoiceOnDemand")

if mod._display_names_module then return mod._display_names_module end

-- Optional friendly-name overrides. Anything not listed falls back to an
-- auto-prettified version of the raw id (underscores -> spaces, title case),
-- so this stays low-maintenance: only add entries you actually want renamed.
local FILE_OVERRIDES = {
	-- Non-class VO category files
	asset_vo        = "Assets",
	enemy_vo        = "Enemy Callouts",
	gameplay_vo     = "Gameplay",
	guidance_vo     = "Guidance",
	mission_giver_vo= "Mission Giver",
	on_demand_vo    = "On Demand",
	class_rework    = "Class Rework",
}

-- Class voice files (adamant, cryptic, broker, ...) map to archetypes, which
-- carry real localized class names — pull those in so e.g. "cryptic" shows
-- the proper class name instead of a codename.
pcall(function()
	local archetypes = require("scripts/settings/archetype/archetypes")
	for name, archetype in pairs(archetypes) do
		if not FILE_OVERRIDES[name] and archetype.archetype_name then
			FILE_OVERRIDES[name] = Localize(archetype.archetype_name)
		end
	end
end)

local RULE_OVERRIDES = {
	-- ["vo_combat_taunt"] = "Taunt",
}

local _cache = {}

local function prettify(id)
	local s = _cache[id]
	if s then return s end
	s = tostring(id):gsub("_", " ")
	s = s:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end)
	_cache[id] = s
	return s
end

local function file_name(id)
	return FILE_OVERRIDES[id] or prettify(id)
end

local function rule_name(id)
	return RULE_OVERRIDES[id] or prettify(id)
end

local api = {
	file_name = file_name,
	rule_name = rule_name,
}

mod._display_names_module = api
return api
