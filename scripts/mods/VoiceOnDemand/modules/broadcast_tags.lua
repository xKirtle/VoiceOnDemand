local mod = get_mod("VoiceOnDemand")

if mod._broadcast_tags_module then return mod._broadcast_tags_module end

-- Map of on-demand VO rule_name -> { concept, tag } for the lines the engine's
-- networked dialogue system can actually replicate to other players. Extracted
-- from the base dialogues/generated/on_demand_vo.lua define_rule criterias
-- (concept + trigger_id/enemy_tag/item_tag). These are the only VO lines that
-- can broadcast; every other line can only ever play locally.
local TAGS = {
	-- Communication wheel callouts
	["com_wheel_vo_enemy_over_here"]                    = { "on_demand_com_wheel", "location_enemy_there" },
	["com_wheel_vo_follow_you"]                         = { "on_demand_com_wheel", "answer_following" },
	["com_wheel_vo_for_the_emperor"]                    = { "on_demand_com_wheel", "com_cheer" },
	["com_wheel_vo_location_attention"]                 = { "on_demand_com_wheel", "location_over_here" },
	["com_wheel_vo_location_ping"]                      = { "on_demand_com_wheel", "location_this_way" },
	["com_wheel_vo_my_pleasure_a"]                      = { "on_demand_com_wheel", "com_my_pleasure" },
	["com_wheel_vo_need_ammo"]                          = { "on_demand_com_wheel", "com_need_ammo" },
	["com_wheel_vo_need_health"]                        = { "on_demand_com_wheel", "com_need_health" },
	["com_wheel_vo_need_that"]                          = { "on_demand_com_wheel", "answer_need" },
	["com_wheel_vo_no"]                                 = { "on_demand_com_wheel", "answer_no" },
	["com_wheel_vo_take_this_a"]                        = { "on_demand_com_wheel", "com_take_this" },
	["com_wheel_vo_thank_you"]                          = { "on_demand_com_wheel", "com_thank_you" },
	["com_wheel_vo_thank_you_delayed"]                  = { "on_demand_com_wheel", "com_thank_you_delayed" },
	["com_wheel_vo_yes"]                                = { "on_demand_com_wheel", "answer_yes" },

	-- Enemy smart-tag callouts
	["seen_netgunner_flee"]                             = { "on_demand_vo_tag_enemy", "seen_netgunner_flee" },
	["smart_tag_vo_enemy_captain"]                      = { "on_demand_vo_tag_enemy", "renegade_captain" },
	["smart_tag_vo_enemy_chaos_hound"]                  = { "on_demand_vo_tag_enemy", "chaos_hound" },
	["smart_tag_vo_enemy_chaos_mutant_charger"]         = { "on_demand_vo_tag_enemy", "cultist_mutant" },
	["smart_tag_vo_enemy_chaos_ogryn_armored_executor"] = { "on_demand_vo_tag_enemy", "chaos_ogryn_executor" },
	["smart_tag_vo_enemy_chaos_ogryn_bulwark"]          = { "on_demand_vo_tag_enemy", "chaos_ogryn_bulwark" },
	["smart_tag_vo_enemy_chaos_ogryn_heavy_gunner"]     = { "on_demand_vo_tag_enemy", "chaos_ogryn_gunner" },
	["smart_tag_vo_enemy_chaos_poxwalker_bomber"]       = { "on_demand_vo_tag_enemy", "chaos_poxwalker_bomber" },
	["smart_tag_vo_enemy_chaos_spawn"]                  = { "on_demand_vo_tag_enemy", "chaos_spawn" },
	["smart_tag_vo_enemy_cultist_flamer"]               = { "on_demand_vo_tag_enemy", "cultist_flamer" },
	["smart_tag_vo_enemy_cultist_grenadier"]            = { "on_demand_vo_tag_enemy", "cultist_grenadier" },
	["smart_tag_vo_enemy_cultist_holy_stubber_gunner"]  = { "on_demand_vo_tag_enemy", "cultist_gunner" },
	["smart_tag_vo_enemy_cultist_shocktrooper"]         = { "on_demand_vo_tag_enemy", "cultist_shocktrooper" },
	["smart_tag_vo_enemy_daemonhost_witch"]             = { "on_demand_vo_tag_enemy", "aggroed" },
	["smart_tag_vo_enemy_daemonhost_witch_not_alerted"] = { "on_demand_vo_tag_enemy", "chaos_daemonhost" },
	["smart_tag_vo_enemy_houndmaster"]                  = { "on_demand_vo_tag_enemy", "chaos_ogryn_houndmaster" },
	["smart_tag_vo_enemy_netgunner"]                    = { "on_demand_vo_tag_enemy", "renegade_netgunner" },
	["smart_tag_vo_enemy_plague_ogryn"]                 = { "on_demand_vo_tag_enemy", "chaos_plague_ogryn" },
	["smart_tag_vo_enemy_scab_flamer"]                  = { "on_demand_vo_tag_enemy", "renegade_flamer" },
	["smart_tag_vo_enemy_traitor_executor"]             = { "on_demand_vo_tag_enemy", "renegade_executor" },
	["smart_tag_vo_enemy_traitor_grenadier"]            = { "on_demand_vo_tag_enemy", "renegade_grenadier" },
	["smart_tag_vo_enemy_traitor_scout_shocktrooper"]   = { "on_demand_vo_tag_enemy", "renegade_shocktrooper" },
	["smart_tag_vo_enemy_traitor_sniper"]               = { "on_demand_vo_tag_enemy", "renegade_sniper" },

	-- Item / pickup smart-tag callouts
	["smart_tag_stimm_concentration_a"]                 = { "on_demand_vo_tag_item", "pup_stimm_concentration" },
	["smart_tag_stimm_health_a"]                        = { "on_demand_vo_tag_item", "pup_stimm_health" },
	["smart_tag_stimm_power_a"]                         = { "on_demand_vo_tag_item", "pup_stimm_power" },
	["smart_tag_stimm_speed_a"]                         = { "on_demand_vo_tag_item", "pup_stimm_speed" },
	["smart_tag_vo_pickup_ammo"]                        = { "on_demand_vo_tag_item", "pup_ammo" },
	["smart_tag_vo_pickup_battery"]                     = { "on_demand_vo_tag_item", "pup_battery" },
	["smart_tag_vo_pickup_container"]                   = { "on_demand_vo_tag_item", "pup_container" },
	["smart_tag_vo_pickup_control_rod"]                 = { "on_demand_vo_tag_item", "pup_control_rod" },
	["smart_tag_vo_pickup_deployed_ammo_crate"]         = { "on_demand_vo_tag_item", "pup_deployed_ammo_crate" },
	["smart_tag_vo_pickup_deployed_medical_crate"]      = { "on_demand_vo_tag_item", "pup_deployed_medical_crate" },
	["smart_tag_vo_pickup_forge_metal"]                 = { "on_demand_vo_tag_item", "pup_forge_metal" },
	["smart_tag_vo_pickup_medical_crate"]               = { "on_demand_vo_tag_item", "pup_medical_crate" },
	["smart_tag_vo_pickup_platinum"]                    = { "on_demand_vo_tag_item", "pup_platinum" },
	["smart_tag_vo_pickup_side_mission_consumable"]     = { "on_demand_vo_tag_item", "pup_side_mission_consumable" },
	["smart_tag_vo_pickup_side_mission_grimoire"]       = { "on_demand_vo_tag_item", "pup_side_mission_grimoire" },
	["smart_tag_vo_pickup_side_mission_tome"]           = { "on_demand_vo_tag_item", "pup_side_mission_tome" },
	["smart_tag_vo_small_grenade"]                      = { "on_demand_vo_tag_item", "pup_small_grenade" },
	["smart_tag_vo_station_health"]                     = { "on_demand_vo_tag_item", "station_health" },
	["smart_tag_vo_station_health_without_battery"]     = { "on_demand_vo_tag_item", "station_health_without_battery" },
}

mod._broadcast_tags_module = TAGS
return TAGS
