--[[
* @file : Main.lua
* @type : service
* @author : linfeng 九  零  一 起 玩 w w w . 9 0 1 7  5 . co m
* @created : Thu Nov 23 2017 13:49:41 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : battle_server 启动主文件
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
require "BattleCfg"
local sharedata = require "skynet.sharedata"

local function initLogicLuaService( )
	sharedata.new( Enum.Share.DBNODE, {} )
	sharedata.new( Enum.Share.CENTERNODE, {} )

	-- init InitServer
	SM.InitServer.req.initEntityCfg(ConfigEntityCfg, CommonEntityCfg, UserEntityCfg, RoleEntityCfg)
	-- init BattleLoop
	MSM.BattleLoop[0].req.Init()
	-- init BattleConfigData
	snax.newservice("BattleConfigData").req.reInitConfigData()
	--init Web
	SM.Web.req.Init()
	-- init Hotfix
	SM.Hotfix.req.Init()
	-- init PkIdMgr
	MSM.PkIdMgr[0].req.Init()
end

skynet.start(function ()
	local selfNodeName = skynet.getenv("clusternode")..skynet.getenv("serverid")
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

	-- log ok
	os.execute(string.format("echo %s %s >> ok.txt", os.date("%Y-%m-%d %X"), Common.getSelfNodeName()))

	skynet.exit()
end)