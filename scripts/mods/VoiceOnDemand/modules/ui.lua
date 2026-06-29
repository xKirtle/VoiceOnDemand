local mod = get_mod("VoiceOnDemand")

if mod._ui_module then return mod._ui_module end

local UIRenderer = require("scripts/managers/ui/ui_renderer")

local BG_MAT = "content/ui/materials/backgrounds/default_square"
local FONT   = "proxima_nova_bold"
local LAYER  = 500

-- ── Theme: colour arrays {alpha, r, g, b} 0-255 ──────────────────────────────

local colors = {
	panel     = { 245, 18, 18, 24 },
	header    = { 255, 220, 170, 80 },
	item      = { 255, 200, 200, 200 },
	hover     = { 255, 255, 230, 100 },
	hover_bg  = { 90, 255, 230, 100 },
	loaded    = { 255, 130, 220, 130 },
	loaded_bg = { 70, 130, 220, 130 },
	fav       = { 255, 255, 215, 80 },
	dim       = { 170, 140, 140, 140 },
	divider   = { 80, 220, 170, 80 },
	scroll_track = { 60, 120, 120, 120 },
	scroll_thumb = { 220, 220, 170, 80 },
}

-- ── Scale (set once per frame) ───────────────────────────────────────────────

local _scale = 1
local function set_scale(s) _scale = s or 1 end
local function scale() return _scale end

-- ── Drawing primitives ───────────────────────────────────────────────────────

local _text_opts = {}

local function rect(ui_renderer, x, y, w, h, color)
	UIRenderer.script_draw_bitmap(ui_renderer, BG_MAT, Vector3(x, y, LAYER), Vector2(w, h), color)
end

-- text: size is a base value scaled by the current UI scale; opts is an
-- optional UIRenderer options table (e.g. alignment). z is layered above rects.
local function text(ui_renderer, str, x, y, color, size, w, opts)
	UIRenderer.script_draw_text(ui_renderer, str, (size or 16) * _scale, FONT,
		Vector3(x, y, LAYER + 2), Vector2(w or 9999, (size or 16) * _scale * 2.4),
		color or colors.item, opts or _text_opts)
end

local function bitmap(ui_renderer, material, x, y, w, h, color)
	UIRenderer.script_draw_bitmap(ui_renderer, material, Vector3(x, y, LAYER + 1), Vector2(w, h), color)
end

local function point_in(px, py, x, y, w, h)
	return px >= x and px <= x + w and py >= y and py <= y + h
end

-- thin scrollbar; total/visible/scroll measured in row units. Auto-hides when
-- everything fits.
local function scrollbar(ui_renderer, x, y, h, total, visible, scroll)
	if total <= visible then return end
	local w = 5 * _scale
	rect(ui_renderer, x, y, w, h, colors.scroll_track)
	local th = math.max(20 * _scale, h * visible / total)
	local ty = y + (h - th) * (scroll / (total - visible))
	rect(ui_renderer, x, ty, w, th, colors.scroll_thumb)
end

local function clamp_scroll(scroll, count, visible)
	local max = math.max(0, count - visible)
	if scroll < 0 then return 0 end
	if scroll > max then return max end
	return scroll
end

-- ── Cursor / input service ───────────────────────────────────────────────────

local function push_cursor(name)
	if not Managers.input then return end
	Managers.input:push_cursor(name)
	Managers.input:set_cursor_position(name, Vector3(0.5, 0.5, 0))
end

local function pop_cursor(name)
	if Managers.input then Managers.input:pop_cursor(name) end
end

local function view_service()
	return Managers.input and Managers.input:get_input_service("View")
end

local function get_cursor()
	local svc = view_service()
	local c = svc and svc:get("cursor")
	if not c then return nil end
	return c[1], c[2]
end

local api = {
	colors      = colors,
	LAYER       = LAYER,
	set_scale   = set_scale,
	scale       = scale,
	rect        = rect,
	text        = text,
	bitmap      = bitmap,
	point_in    = point_in,
	scrollbar   = scrollbar,
	clamp_scroll= clamp_scroll,
	push_cursor = push_cursor,
	pop_cursor  = pop_cursor,
	view_service= view_service,
	get_cursor  = get_cursor,
}

mod._ui_module = api
return api
