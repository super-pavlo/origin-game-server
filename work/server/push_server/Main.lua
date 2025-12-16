--[[
* @file : Main.lua
* @type : service
* @author : linfeng
* @created : Thu Nov 23 2017 13:51:35 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : push_server 的启动文件
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
require "skynet.manager"
local sharedata = require "skynet.sharedata"
require "PushCfg"

local function initLogicLuaService()
    sharedata.new( Enum.Share.DBNODE, {} )
    sharedata.new( Enum.Share.CENTERNODE, {} )

    SM.InitServer.req.initEntityCfg(ConfigEntityCfg, CommonEntityCfg, UserEntityCfg, RoleEntityCfg)

    --init Web
    SM.Web.req.Init()
    -- init Hotfix
    SM.Hotfix.req.Init()
    -- init PkIdMgr
    MSM.PkIdMgr[0].req.Init()
    -- init MessagePush
    SM.MessagePush.req.Init()
    -- init FileUploadMgr
    MSM.FileUploadMgr[0].req.Init()
    -- init AlarmMgr
    SM.AlarmMgr.req.Init()
end

skynet.start(
    function()
        local selfNodeName = skynet.getenv("clusternode") .. skynet.getenv("serverid")
        --init log
	    SM.SysLog.req.Init(selfNodeName)

        --init debug
        local debugPort = tonumber(skynet.getenv("debugport")) or 0
        if debugPort > 0 then
            skynet.newservice("debug_console", debugPort)
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
    end
)
