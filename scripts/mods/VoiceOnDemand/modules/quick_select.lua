local mod = get_mod("VoiceOnDemand")

if mod._quick_select_module then return mod._quick_select_module end

local favorites  = mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/favorites")
local ui         = mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/ui")
local browser    = mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/browser")
local wheel      = mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/wheel")

local UIRenderer = require("scripts/managers/ui/ui_renderer")

local MODE_CLOSED, MODE_BROWSE, MODE_QUICK_SELECT = 0, 1, 2
local CURSOR_NAME = "VoiceOnDemand_overlay"

local _mode = MODE_CLOSED
local _cursor_pushed = false

-- ── Cursor ───────────────────────────────────────────────────────────────────

local function push_cursor()
	if _cursor_pushed then return end
	ui.push_cursor(CURSOR_NAME)
	_cursor_pushed = true
end

local function pop_cursor()
	if not _cursor_pushed then return end
	ui.pop_cursor(CURSOR_NAME)
	_cursor_pushed = false
end

local function close_overlay()
	_mode = MODE_CLOSED
	pop_cursor()
end

-- ── HUD render hook ──────────────────────────────────────────────────────────

-- Reporting input usage makes Managers.ui:using_input() block gameplay look/move.
mod:hook_safe("HudElementSmartTagging", "init", function(self)
	self.using_input = function() return _mode ~= MODE_CLOSED end
end)

mod:hook_safe("HudElementSmartTagging", "update",
	function(self, dt, t, ui_renderer, render_settings, input_service)
		if not self.using_input then
			self.using_input = function() return _mode ~= MODE_CLOSED end
		end
		if _mode == MODE_CLOSED then pop_cursor(); return end
		if not ui_renderer then return end
		if not (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.width) then return end
		ui.set_scale(mod:get("setting_ui_scale") or 1)
		push_cursor()

		local mx, my = ui.get_cursor()

		UIRenderer.begin_pass(ui_renderer, self._ui_scenegraph, input_service, dt, render_settings)
		pcall(function()
			if _mode == MODE_BROWSE then
				browser.draw(ui_renderer, mx or -1, my or -1)
			elseif _mode == MODE_QUICK_SELECT then
				wheel.draw(ui_renderer, mx or -1, my or -1)
			end
		end)
		UIRenderer.end_pass(ui_renderer)

		if not mx then return end
		if _mode == MODE_BROWSE then
			browser.handle_input(mx, my, ui.view_service())
		elseif _mode == MODE_QUICK_SELECT then
			local svc = ui.view_service()
			if svc and svc:get("left_pressed") and wheel.play_selected() then
				close_overlay()
			end
		end
	end)

-- ── Keybind handlers ─────────────────────────────────────────────────────────

mod.keybind_browse_toggle = function()
	if _mode == MODE_BROWSE then
		close_overlay()
	else
		_mode = MODE_BROWSE
		browser.open()
	end
end

mod.keybind_quick_select = function(is_pressed)
	local use_toggle = mod:get("setting_open_mode") == "toggle"
	if use_toggle then
		if not is_pressed then return end
		if _mode == MODE_QUICK_SELECT then
			close_overlay()
		elseif #favorites.all() == 0 then
			mod:echo("No favourites yet. Open Browse and right-click a line.")
		else
			_mode = MODE_QUICK_SELECT; wheel.reset()
		end
		return
	end
	if is_pressed then
		if #favorites.all() == 0 then mod:echo("No favourites yet. Open Browse and right-click a line."); return end
		_mode = MODE_QUICK_SELECT; wheel.reset()
	elseif _mode == MODE_QUICK_SELECT then
		wheel.play_selected()
		close_overlay()
	end
end

local api = {}
mod._quick_select_module = api
return api
