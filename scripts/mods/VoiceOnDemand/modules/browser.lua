local mod = get_mod("VoiceOnDemand")

if mod._browser_module then return mod._browser_module end

local favorites  = mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/favorites")
local vo_browser = mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/vo_browser")
local display    = mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/display_names")
local icons      = mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/icons")
local ui         = mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/ui")
local broadcast_tags = mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/broadcast_tags")

local UIRenderer = require("scripts/managers/ui/ui_renderer")

local C        = ui.colors
local LAYER    = ui.LAYER
local draw_rect    = ui.rect
local point_in     = ui.point_in
local scrollbar    = ui.scrollbar
local clamp_scroll = ui.clamp_scroll

-- ── Layout (base values; scaled per frame) ───────────────────────────────────

local BASE = {
	PANEL_W = 1480, PANEL_H = 830, PADDING = 28, ROW_H = 44,
	HEADER_H = 56, FOOTER_H = 42, COL_GAP = 24, FILE_COL_W = 360, ICON_COL_W = 300,
}
local PANEL_W, PANEL_H, PADDING, ROW_H = BASE.PANEL_W, BASE.PANEL_H, BASE.PADDING, BASE.ROW_H
local HEADER_H, FOOTER_H, COL_GAP, FILE_COL_W = BASE.HEADER_H, BASE.FOOTER_H, BASE.COL_GAP, BASE.FILE_COL_W
local ICON_COL_W = BASE.ICON_COL_W

local function refresh_scale()
	local s = ui.scale()
	PANEL_W    = BASE.PANEL_W * s
	PANEL_H    = BASE.PANEL_H * s
	PADDING    = BASE.PADDING * s
	ROW_H      = BASE.ROW_H * s
	HEADER_H   = BASE.HEADER_H * s
	FOOTER_H   = BASE.FOOTER_H * s
	COL_GAP    = BASE.COL_GAP * s
	FILE_COL_W = BASE.FILE_COL_W * s
	ICON_COL_W = BASE.ICON_COL_W * s
end

-- ── State ────────────────────────────────────────────────────────────────────

local _file_scroll  = 0
local _rule_scroll  = 0
local _show_favs    = false
local _kb_sel       = 0       -- selected row in the middle column
local _focus        = "file"  -- "file" | "rule" | "variant"
local _file_sel     = 1       -- 1 = Favourites, 2.. = files
local _icon_scroll  = 0
local _open_rule    = nil
local _var_sel      = 0
local _opened       = false   -- remember selection across opens

local _hit = {}
local function add_hit(x, y, w, h, kind, payload)
	_hit[#_hit + 1] = { x = x, y = y, w = w, h = h, kind = kind, payload = payload }
end

-- Scrollbar grab regions (rebuilt each frame) and the active drag target.
local _scrollbars = {}
local _drag = nil

local function set_scroll(kind, v)
	if kind == "file" then _file_scroll = v
	elseif kind == "rule" then _rule_scroll = v
	elseif kind == "icon" then _icon_scroll = v end
end

-- Map the cursor's y to a scroll offset for the dragged scrollbar.
local function update_drag(my)
	local sb = _drag
	if not sb then return end
	local th    = math.max(20 * ui.scale(), sb.h * sb.visible / sb.total)
	local denom = sb.h - th
	local maxs  = math.max(0, sb.total - sb.visible)
	local frac  = denom > 0 and (my - sb.y - th / 2) / denom or 0
	local v     = math.floor(frac * maxs + 0.5)
	if v < 0 then v = 0 elseif v > maxs then v = maxs end
	set_scroll(sb.kind, v)
end

-- Draw a scrollbar and, when scrollable, register a widened grab region.
local function draw_scrollbar(ui_renderer, x, y, h, total, visible, scroll, kind)
	scrollbar(ui_renderer, x, y, h, total, visible, scroll)
	if total > visible then
		_scrollbars[#_scrollbars + 1] = { kind = kind, x = x, y = y, h = h, total = total, visible = visible, hx = x - 6, hw = 16 }
	end
end

local function draw_text(ui_renderer, text, x, y, color, size, w)
	ui.text(ui_renderer, text, x, y, color, size, w or PANEL_W)
end

local function hover_or_kb(mx, my, x, y, w, idx)
	return point_in(mx, my, x, y, w, ROW_H) or idx == _kb_sel
end

-- Marks lines that can be broadcast to other players (in broadcast_tags).
-- x_right is the right edge where the marker ends; sized to the current row.
local BROADCAST_MAT = "content/ui/materials/icons/portraits/status_party"
local function broadcast_marker(ui_renderer, rule, x_right, y)
	if not broadcast_tags[rule] then return end
	local sz = ROW_H * 0.7
	UIRenderer.script_draw_bitmap(ui_renderer, BROADCAST_MAT,
		Vector3(x_right - sz, y + (ROW_H - sz) / 2, LAYER + 2), Vector2(sz, sz), C.loaded)
end

local function panel_origin()
	local sw, sh = RESOLUTION_LOOKUP.width, RESOLUTION_LOOKUP.height
	return (sw - PANEL_W) / 2, (sh - PANEL_H) / 2
end

local function visible_rows()
	return math.floor((PANEL_H - HEADER_H - FOOTER_H - PADDING) / ROW_H)
end

-- ── Draw ─────────────────────────────────────────────────────────────────────

local function draw(ui_renderer, mx, my)
	refresh_scale()
	_hit = {}
	_scrollbars = {}

	local px, py  = panel_origin()
	local state   = vo_browser.get_state()
	local files   = vo_browser.available_files()
	local rows    = visible_rows()
	local file_w  = FILE_COL_W
	local icon_w  = ICON_COL_W
	local rule_w  = PANEL_W - PADDING * 2 - COL_GAP * 2 - file_w - icon_w
	local fx      = px + PADDING
	local rx      = fx + file_w + COL_GAP
	local cxw     = rx + rule_w + COL_GAP
	local hdr     = py + HEADER_H
	local top     = hdr + 30 * ui.scale()
	rows          = rows - 1
	local col_h   = PANEL_H - HEADER_H - FOOTER_H - 30 * ui.scale()

	draw_rect(ui_renderer, px, py, PANEL_W, PANEL_H, C.panel)
	draw_text(ui_renderer, mod:localize("browser_title", #files), fx, py + 14, C.header, 28, PANEL_W)
	draw_text(ui_renderer, mod:localize("col_voice_files"), fx + 10, hdr, C.dim, 16, file_w)
	draw_text(ui_renderer, mod:localize("col_voice_lines"), rx + 10, hdr, C.dim, 16, rule_w)
	draw_text(ui_renderer, _show_favs and mod:localize("col_icons") or mod:localize("col_variants"), cxw + 10, hdr, C.dim, 16, icon_w)
	draw_rect(ui_renderer, rx - COL_GAP / 2, top, 1, col_h, C.divider)
	draw_rect(ui_renderer, cxw - COL_GAP / 2, top, 1, col_h, C.divider)

	-- file column (row 1 = pinned Favourites)
	_file_scroll = clamp_scroll(_file_scroll, #files, rows - 1)
	for r = 1, rows do
		if r == 1 then
			local y = top
			local sel = point_in(mx, my, fx, y, file_w, ROW_H) or (_focus == "file" and _file_sel == 1)
			if sel then draw_rect(ui_renderer, fx, y, file_w, ROW_H, C.hover_bg)
			elseif _show_favs then draw_rect(ui_renderer, fx, y, file_w, ROW_H, C.loaded_bg) end
			draw_text(ui_renderer, "* " .. mod:localize("favourites"), fx + 10, y + 11,
				sel and C.hover or (_show_favs and C.loaded or C.fav), 22, file_w)
			add_hit(fx, y, file_w, ROW_H, "favfile")
		else
			local fname = files[_file_scroll + r - 1]
			if not fname then break end
			local y = top + (r - 1) * ROW_H
			local sel    = point_in(mx, my, fx, y, file_w, ROW_H) or (_focus == "file" and _file_sel == _file_scroll + r)
			local loaded = (not _show_favs and fname == state.file)
			if loaded then draw_rect(ui_renderer, fx, y, file_w, ROW_H, C.loaded_bg)
			elseif sel then draw_rect(ui_renderer, fx, y, file_w, ROW_H, C.hover_bg) end
			draw_text(ui_renderer, display.file_name(fname), fx + 10, y + 11,
				loaded and C.loaded or (sel and C.hover or C.item), 22, file_w)
			add_hit(fx, y, file_w, ROW_H, "file", fname)
		end
	end

	-- middle column: favourites or the file's voice lines
	if _show_favs then
		local favs = favorites.all()
		_rule_scroll = clamp_scroll(_rule_scroll, #favs, rows)
		if #favs == 0 then draw_text(ui_renderer, mod:localize("no_favourites"), rx + 10, top + 6, C.dim, 20, rule_w) end
		for r = 1, rows do
			local fav = favs[_rule_scroll + r]
			if not fav then break end
			local y = top + (r - 1) * ROW_H
			local sel = hover_or_kb(mx, my, rx, y, rule_w, _rule_scroll + r)
			if sel then draw_rect(ui_renderer, rx, y, rule_w, ROW_H, C.hover_bg) end
			local mat = icons.material(fav.icon)
			if mat then
				UIRenderer.script_draw_bitmap(ui_renderer, mat, Vector3(rx + 6, y + 4, LAYER + 1), Vector2(ROW_H - 8, ROW_H - 8), C.item)
			end
			draw_text(ui_renderer, display.rule_name(fav.rule), rx + ROW_H, y + 11, sel and C.hover or C.fav, 22, rule_w - ROW_H - 160)
			draw_text(ui_renderer, fav.line and ("#" .. fav.line) or mod:localize("cycle"), rx + rule_w - 150, y + 11, C.dim, 18, 90)
			broadcast_marker(ui_renderer, fav.rule, rx + rule_w - 6, y)
			add_hit(rx, y, rule_w, ROW_H, "favrule", _rule_scroll + r)
		end
	else
		local rules = state.rules
		_rule_scroll = clamp_scroll(_rule_scroll, #rules, rows)
		if #rules == 0 then draw_text(ui_renderer, mod:localize("click_file_hint"), rx + 10, top + 6, C.dim, 20, rule_w) end
		for r = 1, rows do
			local rule = rules[_rule_scroll + r]
			if not rule then break end
			local y = top + (r - 1) * ROW_H
			local hover  = hover_or_kb(mx, my, rx, y, rule_w, _rule_scroll + r)
			local opened = rule == _open_rule
			local is_fav = favorites.find(state.file, rule)
			if opened then draw_rect(ui_renderer, rx, y, rule_w, ROW_H, C.loaded_bg)
			elseif hover then draw_rect(ui_renderer, rx, y, rule_w, ROW_H, C.hover_bg) end
			draw_text(ui_renderer, (is_fav and "* " or "  ") .. display.rule_name(rule), rx + 10, y + 11,
				opened and C.loaded or (hover and C.hover or (is_fav and C.fav or C.item)), 22, rule_w - 44)
			broadcast_marker(ui_renderer, rule, rx + rule_w - 6, y)
			add_hit(rx, y, rule_w, ROW_H, "rule", rule)
		end
	end

	-- right column: icon picker (favourites) or variants of selected line
	if _show_favs then
		local picked = _kb_sel > 0 and favorites.get(_kb_sel)
		local cell = 64 * ui.scale()
		local gap  = 14 * ui.scale()
		local cols = math.max(1, math.floor((icon_w + gap) / (cell + gap)))
		local vis_rows = math.max(1, math.floor(col_h / (cell + gap)))
		local total_rows = math.ceil(#icons.list / cols)
		_icon_scroll = math.max(0, math.min(_icon_scroll, math.max(0, total_rows - vis_rows)))
		local first = _icon_scroll * cols
		for vi = 1, cols * vis_rows do
			local ic = icons.list[first + vi]
			if not ic then break end
			local ix = cxw + ((vi - 1) % cols) * (cell + gap)
			local iy = top + math.floor((vi - 1) / cols) * (cell + gap)
			local on = picked and (picked.icon == ic.id or picked.icon == ic.id:match("[^/]+$"))
			draw_rect(ui_renderer, ix, iy, cell, cell, on and C.hover_bg or C.panel)
			UIRenderer.script_draw_bitmap(ui_renderer, ic.material, Vector3(ix + 4, iy + 4, LAYER + 1), Vector2(cell - 8, cell - 8), C.item)
			add_hit(ix, iy, cell, cell, "seticon", ic.id)
		end
		draw_scrollbar(ui_renderer, cxw + icon_w + 5, top, col_h, total_rows, vis_rows, _icon_scroll, "icon")
	elseif _open_rule then
		local nv = vo_browser.variant_count(state.file, _open_rule)
		local entries = { { label = mod:localize("variant_default"), line = nil } }
		for v = 1, nv do entries[#entries + 1] = { label = mod:localize("variant_n", v), line = v } end
		for r = 1, rows do
			local e = entries[r]
			if not e then break end
			local y = top + (r - 1) * ROW_H
			local cur = (_focus == "variant" and _var_sel == r)
			local hov = point_in(mx, my, cxw, y, icon_w, ROW_H)
			local is_fav = favorites.find(state.file, _open_rule, e.line)
			if cur then draw_rect(ui_renderer, cxw, y, icon_w, ROW_H, C.loaded_bg)
			elseif hov then draw_rect(ui_renderer, cxw, y, icon_w, ROW_H, C.hover_bg) end
			draw_text(ui_renderer, (is_fav and "* " or "  ") .. e.label, cxw + 10, y + 11,
				cur and C.loaded or (hov and C.hover or (is_fav and C.fav or C.item)), 20, icon_w)
			add_hit(cxw, y, icon_w, ROW_H, "variant", e.line or 0)
		end
	end

	draw_scrollbar(ui_renderer, fx + file_w + 5, top, col_h, #files, rows - 1, _file_scroll, "file")
	draw_scrollbar(ui_renderer, rx + rule_w + 5, top, col_h, _show_favs and #favorites.all() or #state.rules, rows, _rule_scroll, "rule")

	local s   = ui.scale()
	local fy  = py + PANEL_H - FOOTER_H + 4 * s
	-- Legend: the broadcast marker icon next to its meaning, at the footer's right.
	local isz = 26 * s
	-- local lx  = fx + PANEL_W - 220 * s -> bottom righ corner
	local lx  = fx + 360 * s
	draw_text(ui_renderer, mod:localize("footer_help"), fx, fy, C.dim, 18, lx - fx - 10 * s)
	UIRenderer.script_draw_bitmap(ui_renderer, BROADCAST_MAT, Vector3(lx, fy - 4 * s, LAYER + 2), Vector2(isz, isz), C.loaded)
	draw_text(ui_renderer, mod:localize("broadcast_legend"), lx + isz + 1 * s, fy, C.dim, 18, 240 * s)
end

-- ── Input ────────────────────────────────────────────────────────────────────

local function handle_keys(svc)
	local rows = visible_rows() - 1
	if _focus == "file" then
		local files = vo_browser.available_files()
		local n = #files + 1
		local moved = false
		if svc:get("navigate_down_pressed") then _file_sel = (_file_sel < n) and _file_sel + 1 or 1; moved = true
		elseif svc:get("navigate_up_pressed") then _file_sel = (_file_sel > 1) and _file_sel - 1 or n; moved = true end
		if moved and _file_sel > 1 then
			if _file_sel <= _file_scroll + 1 then _file_scroll = _file_sel - 2
			elseif _file_sel > _file_scroll + rows then _file_scroll = _file_sel - rows end
		end
		if svc:get("navigate_right_pressed") then
			if _file_sel == 1 then _show_favs = true
			else _show_favs = false; vo_browser.load_file(files[_file_sel - 1]) end
			_rule_scroll = 0; _kb_sel = 1; _focus = "rule"
		end
	elseif _focus == "variant" then
		local s = vo_browser.get_state()
		local count = vo_browser.variant_count(s.file, _open_rule) + 1
		if svc:get("navigate_left_pressed") then
			_focus = "rule"
		else
			if svc:get("navigate_down_pressed") then _var_sel = (_var_sel < count) and _var_sel + 1 or 1
			elseif svc:get("navigate_up_pressed") then _var_sel = (_var_sel > 1) and _var_sel - 1 or count end
			if svc:get("navigate_right_pressed") then
				vo_browser.play_rule(s.file, _open_rule, _var_sel > 1 and (_var_sel - 1) or nil)
			end
		end
	else
		local count = _show_favs and #favorites.all() or #vo_browser.get_state().rules
		if svc:get("navigate_left_pressed") then
			_focus = "file"; _kb_sel = 0
		elseif count > 0 then
			local moved = false
			if svc:get("navigate_down_pressed") then _kb_sel = (_kb_sel < count) and _kb_sel + 1 or 1; moved = true
			elseif svc:get("navigate_up_pressed") then _kb_sel = (_kb_sel > 1) and _kb_sel - 1 or count; moved = true end
			if moved then
				if _kb_sel <= _rule_scroll then _rule_scroll = _kb_sel - 1
				elseif _kb_sel > _rule_scroll + rows then _rule_scroll = _kb_sel - rows end
			end
			if svc:get("navigate_right_pressed") then
				if _show_favs then
					local fav = favorites.get(_kb_sel)
					if fav then vo_browser.play_rule(fav.file, fav.rule, fav.line) end
				else
					_open_rule = vo_browser.get_state().rules[_kb_sel]; _var_sel = 1; _focus = "variant"
				end
			end
		end
	end
end

local function handle_click(h, left, right)
	if h.kind == "favfile" and left then
		_show_favs = true; _open_rule = nil; _rule_scroll = 0; _kb_sel = 1; _focus = "file"; _file_sel = 1
	elseif h.kind == "file" and left then
		_show_favs = false; _open_rule = nil; _focus = "file"; _kb_sel = 1
		for i, f in ipairs(vo_browser.available_files()) do if f == h.payload then _file_sel = i + 1; break end end
		vo_browser.load_file(h.payload); _rule_scroll = 0
	elseif h.kind == "rule" and left then
		_open_rule = h.payload; _var_sel = 1; _focus = "rule"
		for i, r in ipairs(vo_browser.get_state().rules) do if r == h.payload then _kb_sel = i; break end end
	elseif h.kind == "rule" and right then
		local s = vo_browser.get_state()
		if favorites.find(s.file, h.payload) then favorites.remove_by_rule(s.file, h.payload)
		else favorites.add(s.file, h.payload, nil, icons.list[1] and icons.list[1].id) end
	elseif h.kind == "variant" and left then
		local s = vo_browser.get_state()
		_focus = "variant"; _var_sel = h.payload + 1
		vo_browser.play_rule(s.file, _open_rule, h.payload > 0 and h.payload or nil)
	elseif h.kind == "variant" and right then
		local s = vo_browser.get_state()
		local line = h.payload > 0 and h.payload or nil
		local existing = favorites.find(s.file, _open_rule, line)
		if existing then favorites.remove(existing)
		else
			local lbl = display.rule_name(_open_rule) .. (line and (" #" .. line) or "")
			favorites.add(s.file, _open_rule, lbl, icons.list[1] and icons.list[1].id, line)
		end
	elseif h.kind == "favrule" and left then
		_kb_sel = h.payload; _focus = "rule"
		local fav = favorites.get(h.payload)
		if fav then vo_browser.play_rule(fav.file, fav.rule, fav.line) end
	elseif h.kind == "favrule" and right then
		favorites.remove(h.payload)
	elseif h.kind == "seticon" and left then
		if _kb_sel > 0 then favorites.set_icon(_kb_sel, h.payload) end
	end
end

local function handle_input(mx, my, svc)
	if not svc then return end

	-- Scrollbar dragging takes priority while the button is held.
	if _drag then
		if svc:get("left_hold") then update_drag(my); return end
		_drag = nil
	end

	local scroll = svc:get("scroll_axis")
	if scroll and scroll[2] and scroll[2] ~= 0 then
		local px = panel_origin()
		local step = scroll[2] > 0 and -1 or 1
		local icon_x = px + PANEL_W - PADDING - ICON_COL_W
		if mx >= icon_x then _icon_scroll = _icon_scroll + step
		elseif mx < px + PADDING + FILE_COL_W + COL_GAP / 2 then _file_scroll = _file_scroll + step
		else _rule_scroll = _rule_scroll + step end
	end

	handle_keys(svc)

	local left  = svc:get("left_pressed")
	local right = svc:get("right_pressed")

	-- Begin dragging if the press landed on a scrollbar grab region.
	if left then
		for _, sb in ipairs(_scrollbars) do
			if point_in(mx, my, sb.hx, sb.y, sb.hw, sb.h) then
				_drag = sb; update_drag(my); return
			end
		end
	end

	if not left and not right then return end
	for _, h in ipairs(_hit) do
		if point_in(mx, my, h.x, h.y, h.w, h.h) then
			handle_click(h, left, right)
			break
		end
	end
end

-- Initialise selection on first open; keep it on later opens.
local function open()
	icons.refresh()  -- pick up materials that weren't loaded at game boot
	if _opened then return end
	_opened = true
	_focus = "file"; _kb_sel = 0
	local state = vo_browser.get_state()
	if state.file then
		for i, f in ipairs(vo_browser.available_files()) do
			if f == state.file then _file_sel = i + 1; _file_scroll = math.max(0, i - 2); break end
		end
	else
		_show_favs = true; _file_sel = 1
	end
end

local api = {
	draw         = draw,
	handle_input = handle_input,
	open         = open,
}

mod._browser_module = api
return api
