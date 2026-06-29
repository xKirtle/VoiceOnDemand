local mod = get_mod("VoiceOnDemand")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "options",
				type = "group",
				sub_widgets = {
					{
						setting_id = "setting_open_mode",
						type = "dropdown",
						default_value = "hold",
						options = {
							{ text = "setting_open_mode_hold",   value = "hold" },
							{ text = "setting_open_mode_toggle", value = "toggle" },
						},
						tooltip = "setting_open_mode_desc",
					},
					{
						setting_id = "setting_vo_scope",
						type = "dropdown",
						default_value = "local",
						options = {
							{ text = "setting_vo_scope_local",     value = "local" },
							{ text = "setting_vo_scope_broadcast", value = "broadcast" },
						},
						tooltip = "setting_vo_scope_desc",
					},
					{
						setting_id = "setting_ui_scale",
						type = "numeric",
						default_value = 1.0,
						range = { 0.5, 2.0 },
						decimals_number = 2,
						tooltip = "setting_ui_scale_desc",
					},
				},
			},
			{
				setting_id = "keybinds",
				type = "group",
				sub_widgets = {
					{
						setting_id = "keybind_browse_toggle",
						type = "keybind",
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "keybind_browse_toggle",
						default_value = {},
					},
					{
						setting_id = "keybind_quick_select",
						type = "keybind",
						keybind_trigger = "held",
						keybind_type = "function_call",
						function_name = "keybind_quick_select",
						default_value = {},
					},
				},
			},
		},
	},
}
