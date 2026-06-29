local mod = get_mod("VoiceOnDemand")

if mod._wheel_module then return mod._wheel_module end

local favorites = mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/favorites")
local vo_browser = mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/vo_browser")
local display   = mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/display_names")
local icons     = mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/icons")
local ui        = mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/ui")

local UIRenderer = require("scripts/managers/ui/ui_renderer")

local C       = ui.colors
local LAYER   = ui.LAYER
local CIRCLE  = "content/ui/materials/hud/communication_wheel/middle_circle"
local FONT    = "proxima_nova_bold"
local CENTERED = { text_horizontal_alignment = "center", text_vertical_alignment = "center" }

local _selection = 0

local function selection() return _selection end
local function reset() _selection = 0 end

-- Direction-based radial of favourites. Cursor angle picks a wedge; inside the
-- dead zone selects nothing (cancel). Returns nothing; query selection().
local function draw(ui_renderer, mx, my)
	local s = ui.scale()
	local favs = favorites.all()
	if #favs == 0 then _selection = 0; return end

	local sw, sh = RESOLUTION_LOOKUP.width, RESOLUTION_LOOKUP.height
	local cx, cy = sw / 2, sh / 2
	local n      = #favs
	local R      = 270 * s
	local dead   = 210 * s
	local ic     = 84 * s

	local dx, dy = mx - cx, my - cy
	_selection = 0
	if math.sqrt(dx * dx + dy * dy) > dead then
		local ang = math.atan2(dy, dx)
		local best, bestd
		for i = 1, n do
			local slot = (i - 1) / n * 2 * math.pi - math.pi / 2
			local diff = math.abs((ang - slot + math.pi) % (2 * math.pi) - math.pi)
			if not bestd or diff < bestd then bestd, best = diff, i end
		end
		_selection = best
	end

	local disc = (R + ic) * 2
	UIRenderer.script_draw_bitmap(ui_renderer, CIRCLE, Vector3(cx - disc / 2, cy - disc / 2, LAYER), Vector2(disc, disc), { 150, 10, 10, 14 })
	local hub = dead * 2
	UIRenderer.script_draw_bitmap(ui_renderer, CIRCLE, Vector3(cx - hub / 2, cy - hub / 2, LAYER + 1), Vector2(hub, hub), { 230, 18, 18, 24 })

	for i, fav in ipairs(favs) do
		local slot = (i - 1) / n * 2 * math.pi - math.pi / 2
		local sel  = (i == _selection)
		local size = sel and ic * 1.3 or ic
		local px   = cx + math.cos(slot) * R - size / 2
		local py   = cy + math.sin(slot) * R - size / 2
		if sel then
			local hl = size + 22 * s
			UIRenderer.script_draw_bitmap(ui_renderer, CIRCLE, Vector3(cx + math.cos(slot) * R - hl / 2, cy + math.sin(slot) * R - hl / 2, LAYER + 1), Vector2(hl, hl), C.hover_bg)
		end
		local mat = icons.material(fav.icon)
		if mat then
			UIRenderer.script_draw_bitmap(ui_renderer, mat, Vector3(px, py, LAYER + 2), Vector2(size, size), sel and C.hover or C.item)
		else
			UIRenderer.script_draw_text(ui_renderer, tostring(i), 26 * s, FONT,
				Vector3(px, py, LAYER + 2), Vector2(size, size), sel and C.hover or C.item, CENTERED)
		end
	end

	local label = _selection > 0 and display.rule_name(favs[_selection].rule) or "cancel"
	UIRenderer.script_draw_text(ui_renderer, label, 24 * s, FONT,
		Vector3(cx - hub / 2, cy - 14 * s, LAYER + 2), Vector2(hub, 40 * s),
		_selection > 0 and C.hover or C.dim, CENTERED)
end

-- Play the favourite currently pointed at (if any). Returns true if it played.
local function play_selected()
	local fav = _selection > 0 and favorites.get(_selection)
	if fav then
		vo_browser.play_rule(fav.file, fav.rule, fav.line)
		return true
	end
	return false
end

local api = {
	draw          = draw,
	selection     = selection,
	reset         = reset,
	play_selected = play_selected,
}

mod._wheel_module = api
return api
