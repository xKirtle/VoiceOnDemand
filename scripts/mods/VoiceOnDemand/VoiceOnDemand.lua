local mod = get_mod("VoiceOnDemand")

-- Load in dependency order; each module is a singleton via mod._*_module
mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/ui")
mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/favorites")
mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/display_names")
mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/icons")
mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/vo_browser")
mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/browser")
mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/wheel")
mod:io_dofile("VoiceOnDemand/scripts/mods/VoiceOnDemand/modules/quick_select")

-- Fallbacks so the mod framework never errors on missing keybind functions
local function noop() end
mod.keybind_browse_toggle = mod.keybind_browse_toggle or noop
mod.keybind_quick_select  = mod.keybind_quick_select  or noop
