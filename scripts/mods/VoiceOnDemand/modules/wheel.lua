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
local DOT_RING = "content/ui/materials/backgrounds/scanner/scanner_drill_circle_empty"
local DOT_FILL = "content/ui/materials/backgrounds/scanner/scanner_drill_circle_filled"
local FONT    = "proxima_nova_bold"
local CENTERED = { text_horizontal_alignment = "center", text_vertical_alignment = "center" }

local CENTERED_WRAP = {
	word_wrap = true,
	horizontal_alignment = Gui.HorizontalAlignCenter,
	vertical_alignment = Gui.VerticalAlignCenter,
	text_horizontal_alignment = "center",
	text_vertical_alignment = "center",
}

-- ── Geometry painters (asset-free, crisp at any size) ────────────────────────
-- draw_triangle multiplies coordinates by the renderer scale (unlike the bitmap
-- path used elsewhere, which is already in real pixels), so we pre-divide by it
-- to keep the wheel positioned at the same real-pixel coordinates.
local _tri_style = { color = nil, triangle_corners = { { 0, 0 }, { 0, 0 }, { 0, 0 } } }
local function tri(ui_renderer, cx, cy, x1, y1, x2, y2, x3, y3, layer, color)
	local k = 1 / (ui_renderer.scale or 1)
	local c = _tri_style.triangle_corners
	c[1][1], c[1][2] = x1 * k, y1 * k
	c[2][1], c[2][2] = x2 * k, y2 * k
	c[3][1], c[3][2] = x3 * k, y3 * k
	_tri_style.color = color
	UIRenderer.draw_triangle(ui_renderer, Vector3(cx * k, cy * k, layer), nil, _tri_style)
end

-- Paint a ring (annulus) from triangle segments. r_in = 0 yields a filled disc.
local function ring(ui_renderer, cx, cy, r_out, r_in, layer, color, segs)
	-- 48 segments is sub-pixel-accurate at the wheel's radius; more just burns
	-- draw_triangle calls every frame.
	segs = segs or 48
	if r_in <= 0 then
		-- Filled disc: a triangle fan (one tri per segment) rather than the
		-- two-per-segment annulus path (which would emit degenerate triangles).
		local px, py = r_out, 0
		for i = 1, segs do
			local a = (i / segs) * 2 * math.pi
			local nx, ny = math.cos(a) * r_out, math.sin(a) * r_out
			tri(ui_renderer, cx, cy, 0, 0, px, py, nx, ny, layer, color)
			px, py = nx, ny
		end
		return
	end
	for i = 0, segs - 1 do
		local a0 = (i / segs) * 2 * math.pi
		local a1 = ((i + 1) / segs) * 2 * math.pi
		local c0, s0 = math.cos(a0), math.sin(a0)
		local c1, s1 = math.cos(a1), math.sin(a1)
		tri(ui_renderer, cx, cy, c0 * r_out, s0 * r_out, c1 * r_out, s1 * r_out, c0 * r_in, s0 * r_in, layer, color)
		tri(ui_renderer, cx, cy, c0 * r_in, s0 * r_in, c1 * r_out, s1 * r_out, c1 * r_in, s1 * r_in, layer, color)
	end
end

-- Paint an annular sector (wedge) between r_in and r_out over an angular range.
local function wedge(ui_renderer, cx, cy, r_out, r_in, a0, a1, layer, color, segs)
	-- Scale segments to the arc width (~48 per full circle, matching ring()),
	-- so a wide slice (e.g. 2 options = half circle) stays smooth.
	segs = segs or math.max(4, math.ceil(math.abs(a1 - a0) * 48 / (2 * math.pi)))
	for i = 0, segs - 1 do
		local t0 = a0 + (a1 - a0) * (i / segs)
		local t1 = a0 + (a1 - a0) * ((i + 1) / segs)
		local c0, s0 = math.cos(t0), math.sin(t0)
		local c1, s1 = math.cos(t1), math.sin(t1)
		tri(ui_renderer, cx, cy, c0 * r_out, s0 * r_out, c1 * r_out, s1 * r_out, c0 * r_in, s0 * r_in, layer, color)
		tri(ui_renderer, cx, cy, c0 * r_in, s0 * r_in, c1 * r_out, s1 * r_out, c1 * r_in, s1 * r_in, layer, color)
	end
end

-- Paint a radial divider line from r_in to r_out at angle a, given thickness.
local function spoke(ui_renderer, cx, cy, r_in, r_out, a, thick, layer, color)
	local ca, sa = math.cos(a), math.sin(a)
	local px, py = -sa * thick / 2, ca * thick / 2
	local ix, iy = ca * r_in, sa * r_in
	local ox, oy = ca * r_out, sa * r_out
	tri(ui_renderer, cx, cy, ix + px, iy + py, ox + px, oy + py, ix - px, iy - py, layer, color)
	tri(ui_renderer, cx, cy, ix - px, iy - py, ox + px, oy + py, ox - px, oy - py, layer, color)
end

local MAX_PER_PAGE = 10

local _selection = 0
-- Persisted across openings so the wheel reopens on the last viewed page.
local _page = 0

local function selection() return _selection end
-- Keep _page so the next open shows the same page; only clear the hover.
local function reset() _selection = 0 end

local function page_count()
	local total = #favorites.all()
	return math.max(1, math.ceil(total / MAX_PER_PAGE))
end

local function clamp_page()
	local last = page_count() - 1
	if _page > last then _page = last end
	if _page < 0 then _page = 0 end
end

-- Move the wheel by whole pages (e.g. mouse-wheel notches). Clamped, no wrap.
local function scroll(delta)
	_page = _page + delta
	clamp_page()
end

-- Direction-based radial of favourites. Cursor angle picks a wedge; inside the
-- dead zone selects nothing (cancel). Returns nothing; query selection().
local function draw(ui_renderer, mx, my)
	local s = ui.scale()
	local favs = favorites.all()
	if #favs == 0 then _selection = 0; return end

	clamp_page()
	local pages   = page_count()
	local start_i = _page * MAX_PER_PAGE
	local n       = math.min(MAX_PER_PAGE, #favs - start_i)

	local sw, sh = RESOLUTION_LOOKUP.width, RESOLUTION_LOOKUP.height
	local cx, cy = sw / 2, sh / 2
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

	local r_out = R + ic
	local r_in  = 188 * s
	local hub   = r_in * 2
	-- Inner circle (hub): more transparent. Options band: a bit more opaque.
	-- The hub's edge is hidden under the inner ring + separators, so a coarse
	-- fan (24) is plenty; the visible band keeps the default smoothness.
	ring(ui_renderer, cx, cy, r_in, 0, LAYER, { 110, 6, 6, 10 }, 24)
	ring(ui_renderer, cx, cy, r_out, r_in, LAYER, { 195, 6, 6, 10 })
	-- Highlight the selected item's wedge (equal slice radiating from centre).
	if _selection > 0 then
		local slot = (_selection - 1) / n * 2 * math.pi - math.pi / 2
		local half = math.pi / n
		wedge(ui_renderer, cx, cy, r_out, r_in, slot - half, slot + half, LAYER + 1, C.hover_bg)
	end
	-- Radial separators dividing the band into equal item slices.
	for i = 1, n do
		local b = (i - 1) / n * 2 * math.pi - math.pi / 2 - math.pi / n
		spoke(ui_renderer, cx, cy, r_in, r_out, b, 2 * s, LAYER + 1, C.divider)
	end
	-- Inner ring closing the separators, in the same divider style.
	ring(ui_renderer, cx, cy, r_in + s, r_in - s, LAYER + 1, C.divider)

	for i = 1, n do
		local fav  = favs[start_i + i]
		local slot = (i - 1) / n * 2 * math.pi - math.pi / 2
		local sel  = (i == _selection)
		local size = ic
		local px   = cx + math.cos(slot) * R - size / 2
		local py   = cy + math.sin(slot) * R - size / 2
		local mat = icons.material(fav.icon)
		if mat then
			UIRenderer.script_draw_bitmap(ui_renderer, mat, Vector3(px, py, LAYER + 2), Vector2(size, size), sel and C.hover or C.item)
		else
			UIRenderer.script_draw_text(ui_renderer, tostring(i), 26 * s, FONT,
				Vector3(px, py, LAYER + 2), Vector2(size, size), sel and C.hover or C.item, CENTERED)
		end
	end

	local label = _selection > 0 and display.rule_name(favs[start_i + _selection].rule) or mod:localize("cancel")
	local box_w = hub * 0.78
	local box_h = 120 * s
	UIRenderer.script_draw_text(ui_renderer, label, 32 * s, FONT,
		Vector3(cx - box_w / 2, cy - box_h / 2, LAYER + 2), Vector2(box_w, box_h),
		_selection > 0 and { 255, 255, 255, 255 } or C.dim, CENTERED_WRAP)

	if pages > 1 then
		-- Pager dots: hollow white ring per page, solid white for the current one.
		local WHITE = { 255, 255, 255, 255 }
		local d   = 18 * s
		local gap = 14 * s
		local row = pages * d + (pages - 1) * gap
		local dx0 = cx - row / 2
		local dy  = cy + 92 * s
		for p = 1, pages do
			local active = (p - 1 == _page)
			local x = dx0 + (p - 1) * (d + gap)
			UIRenderer.script_draw_bitmap(ui_renderer, active and DOT_FILL or DOT_RING,
				Vector3(x, dy, LAYER + 2), Vector2(d, d), WHITE)
		end
	end
end

-- Play the favourite currently pointed at (if any). Returns true if it played.
local function play_selected()
	if _selection <= 0 then return false end
	local fav = favorites.get(_page * MAX_PER_PAGE + _selection)
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
	scroll        = scroll,
	play_selected = play_selected,
}

mod._wheel_module = api
return api
