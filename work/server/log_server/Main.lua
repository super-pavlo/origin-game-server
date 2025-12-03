--[[
 * @file : Main.lua
 * @type : service
 * @author : linfeng
 * @created : 2019-03-12 10:23:37
 * @Last Modified time: 2019-03-12 10:23:37
 * @department : Arabic Studio
 * @brief : blog_server 启动主文件
 * Copyright(C) 2019 IGG, All rights reserved
]]

local skynet = require "skynet"
require "skynet.manager"
require "LogCfg"
local sharedata = require "skynet.sharedata"

local function initLogicLuaService( )
	sharedata.new( Enum.Share.DBNODE, {} )
	sharedata.new( Enum.Share.CENTERNODE, {} )

	SM.InitServer.req.initEntityCfg(ConfigEntityCfg, CommonEntityCfg, UserEntityCfg, RoleEntityCfg)
	--init Web
	SM.Web.req.Init()
	-- init Hotfix
	SM.Hotfix.req.Init()
	-- init PkIdMgr
	MSM.PkIdMgr[0].req.Init()
	-- init LogProxy
	MSM.LogProxy[0].req.Init()
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