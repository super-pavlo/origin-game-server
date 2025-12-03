--[[
* @file : Main.lua
* @type : service
* @author : linfeng
* @created : Fri May 11 2018 13:34:58 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 聊天服务器启动文件
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
require "skynet.manager"
require "ChatCfg"
local sharedata = require "skynet.sharedata"

local function initLogicLuaService()
	-- init sproto protocol
    SM.RegCSProtocol.req.Init()

	sharedata.new( Enum.Share.DBNODE, {} )
	sharedata.new( Enum.Share.CENTERNODE, {} )

	SM.InitServer.req.initEntityCfg(ConfigEntityCfg, CommonEntityCfg, UserEntityCfg, RoleEntityCfg)

	--init Web
	SM.Web.req.Init()
	-- init Hotfix
	SM.Hotfix.req.Init()
	-- init PkIdMgr
	MSM.PkIdMgr[0].req.Init()
	-- init ChatSave
	SM.ChatSave.req.Init()
	-- init ChatMgr
	SM.ChatMgr.req.Init()
end

skynet.start(function ()
	local selfNodeName = skynet.getenv("clusternode") .. skynet.getenv("serverid")
	--init log
	SM.SysLog.req.Init(selfNodeName)

	--init debug
	local debugPort = tonumber(skynet.getenv("debugport")) or 0
	if debugPort > 0 then
		skynet.newservice("debug_console",debugPort)
	end

	-- init enum
    SM.EnumInit.req.initAllEnum(ConfigEntityCfg, CommonEntityCfg, UserEntityCfg, RoleEntityCfg)

	--init cluster node
	SM.MonitorSubscribe.req.connectMonitorAndPush(selfNodeName)

	--init lua server
	initLogicLuaService()

	--init gate(begin listen)
	local Gamed = skynet.uniqueservice("Chatd")
	skynet.call(
		Gamed,
		"lua",
		"open",
		{
			port = tonumber(skynet.getenv("port")) or 8888,
			maxclient = tonumber(skynet.getenv("maxclient")) or 1024,
			servername = selfNodeName
		}
	)

	-- log ok
	os.execute(string.format("echo %s %s >> ok.txt", os.date("%Y-%m-%d %X"), Common.getSelfNodeName()))

	skynet.exit()
end)