local mod = get_mod("VoiceOnDemand")

if mod._favorites_module then return mod._favorites_module end

local SETTINGS_KEY = "favorites"
local _favorites = mod:get(SETTINGS_KEY) or {}

local function all()
	return _favorites
end

local function save()
	mod:set(SETTINGS_KEY, _favorites, true)
end

local function get(index)
	return all()[index]
end

local function find(file, rule, line)
	for i, fav in ipairs(all()) do
		if fav.file == file and fav.rule == rule and fav.line == line then
			return i
		end
	end
end

local function add(file, rule, label, icon, line)
	if find(file, rule, line) then return false end
	_favorites[#_favorites + 1] = { file = file, rule = rule, label = label or rule, icon = icon, line = line }
	save()
	return true
end

local function remove(index)
	if not _favorites[index] then return false end
	table.remove(_favorites, index)
	save()
	return true
end

local function remove_by_rule(file, rule)
	local index = find(file, rule)
	return index and remove(index) or false
end

local function set_icon(index, icon_id)
	if not _favorites[index] then return false end
	_favorites[index].icon = icon_id
	save()
	return true
end

local api = {
	all            = all,
	get            = get,
	find           = find,
	add            = add,
	remove         = remove,
	remove_by_rule = remove_by_rule,
	set_icon       = set_icon,
}

mod._favorites_module = api
return api
