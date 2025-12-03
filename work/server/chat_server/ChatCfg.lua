--[[
* @file : ChatCfg.lua
* @type : lua lib
* @author : linfeng
* @created : Fri May 11 2018 13:35:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 聊天服务器配置
* Copyright(C) 2017 IGG, All rights reserved
]]

ConfigEntityCfg = {
	{ name = "s_ChatChannel", key = "ID" },
	{ name = "s_Config", key = "ID" },
}

CommonEntityCfg = {
	{ name = "c_pkid", key = "id", value = "value" },
	{ name = "c_chat", key = "gameNode", value = "value", attr = "chatMsgInfo", mainIndex = "channelType" },
	{ name = "c_chat_guild", key = "gameNode", value = "value", attr = "chatMsgInfo", mainIndex = "guildId" },
}

UserEntityCfg = {

}

RoleEntityCfg = {

}