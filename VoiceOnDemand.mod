return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`VoiceOnDemand` encountered an error loading the Darktide Mod Framework.")

		new_mod("VoiceOnDemand", {
			mod_script       = "VoiceOnDemand/scripts/mods/VoiceOnDemand/VoiceOnDemand",
			mod_data         = "VoiceOnDemand/scripts/mods/VoiceOnDemand/VoiceOnDemand_data",
			mod_localization = "VoiceOnDemand/scripts/mods/VoiceOnDemand/VoiceOnDemand_localization",
		})
	end,
	packages = {},
}
