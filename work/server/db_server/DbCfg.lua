--[[
* @file : DbCfg.lua
* @type : lualib
* @author : linfeng
* @created : Thu Nov 23 2017 14:10:53 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : db_server 数据配置文件
* Copyright(C) 2017 IGG, All rights reserved
]]

ConfigEntityCfg = {

}

CommonEntityCfg = {
	{ name = "c_pkid", key = "id", value = "value" },
	{ name = "c_map_object", key = "id", value = "value" },
	{ name = "c_refresh", key = "id", value = "value" },
	{ name = "c_activity", key = "id", value = "value" },
	{ name = "c_guild_building", key = "guildId", value = "value", attr = "buildInfo", mainIndex = "buildIndex" },
	{ name = "c_role_power", key = "rid", value = "value" },
	{ name = "c_alliance_power", key = "guildId", value = "value" },
	{ name = "c_alliance_kill", key = "guildId", value = "value" },
	{ name = "c_alliance_flag", key = "guildId", value = "value" },
	{ name = "c_townhall", key = "rid", value = "value" },
	{ name = "c_role_kill", key = "rid", value = "value" },
	{ name = "c_role_collect_res", key = "rid", value = "value" },
	{ name = "c_reserve", key = "rid", value = "value" },
	{ name = "c_combat_first", key = "rid", value = "value" },
	{ name = "c_rise_up", key = "rid", value = "value" },
	{ name = "c_kill_type", key = "id", value = "value" },
	{ name = "c_kill_type_history", key = "id", value = "value" },
	{ name = "c_monument", key = "id", value = "value" },
	{ name = "c_expedition", key = "rid", value = "value" },
	{ name = "c_expeditionShop", key = "id", value = "value" },
	{ name = "c_holy_land", key = "id", value = "value" },
	{ name = "c_king", key = "id", value = "value" },
	{ name = "c_system", key = "id", value = "value" },
	{ name = "c_systemmail", key = "id", value = "value", nojson = true },
	{ name = "c_guild_message_board", key = "guildId", value = "value", attr = "messageInfo", mainIndex = "messageIndex" },
	{ name = "c_guild_gift", key = "guildId", value = "value", attr = "giftInfo", mainIndex = "giftIndex" },
	{ name = "c_guild_role_power", key = "guildId", value = "value", attr = "rolePowerInfo", mainIndex = "rid" },
	{ name = "c_guild_role_kill", key = "guildId", value = "value", attr = "roleKillInfo", mainIndex = "rid" },
	{ name = "c_guild_role_donate", key = "guildId", value = "value", attr = "roleDonateInfo", mainIndex = "rid" },
	{ name = "c_guild_role_build", key = "guildId", value = "value", attr = "roleBuildInfo", mainIndex = "rid" },
	{ name = "c_guild_role_help", key = "guildId", value = "value", attr = "roleHelpInfo", mainIndex = "rid" },
	{ name = "c_guild_resource_help", key = "guildId", value = "value", attr = "resourceHelpInfo", mainIndex = "rid" },
	{ name = "c_guild_shop", key = "guildId", value = "value" },
	{ name = "c_recharge", key = "id", value = "value" },
	{ name = "c_tribe_king", key = "guildId", value = "value" },
	{ name = "c_fight_horn", key = "rid", value = "value" },
	{ name = "c_fight_horn_alliance", key = "guildId", value = "value" },
}

UserEntityCfg = {

}

RoleEntityCfg = {
	{ name = "d_role", key = "rid", value = "value", alljson = true },
	{ name = "d_user", key = "uid", value = "value", noLoad = true },
	{ name = "d_building", key = "rid", value = "value", attr = "buildInfo", mainIndex = "buildIndex" },
	{ name = "d_item", key = "rid", value = "value", attr = "itemInfo", mainIndex = "itemIndex" },
	{ name = "d_email", key = "rid", value = "value", attr = "emailInfo", mainIndex = "emailIndex" },
	{ name = "d_hero", key = "rid", value = "value", attr = "heroInfo", mainIndex = "heroId" },
	{ name = "d_army", key = "rid", value = "value", attr = "armyInfo", mainIndex = "armyIndex" },
	{ name = "d_scouts", key = "rid", value = "value", attr = "scoutsInfo", mainIndex = "scoutsIndex" },
	{ name = "d_task", key = "rid", value = "value", attr = "taskInfo", mainIndex = "taskId" },
	{ name = "d_transport", key = "rid", value = "value", attr = "transportInfo", mainIndex = "transportIndex" },
	{ name = "d_chat", key = "rid", value = "value", attr = "privateChatInfo", mainIndex = "rid" },
}