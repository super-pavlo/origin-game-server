--[[
* @file : Main.lua
* @type : service
* @author : linfeng
* @created : Thu Nov 23 2017 13:54:05 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : monitor_server 的启动文件
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
require "skynet.manager"
require "MonitorCfg"
local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local sharedata = require "skynet.sharedata"

local function initLogicLuaService(selfNodeName)
    -- init clusterInfo
    SM.InitServer.req.initCluseterNode( selfNodeName )

    snax.uniqueservice("MonitorPublish", selfNodeName)
    sharedata.new( Enum.Share.NODENAME, { name = selfNodeName } )
    sharedata.new( Enum.Share.DBNODE, {} )
    sharedata.new( Enum.Share.CENTERNODE, {} )

    --init Web
    SM.Web.req.Init()
    -- init Hotfix
    SM.Hotfix.req.Init()
end

skynet.start(
    function()
        local selfNodeName = skynet.getenv("clusternode")
        --init log
	    SM.SysLog.req.Init(selfNodeName)

        --init debug
        local debugPort = tonumber(skynet.getenv("debugport")) or 0
        if debugPort > 0 then
            skynet.newservice("debug_console", debugPort)
        end

        -- init enum
        SM.EnumInit.req.initAllEnum(ConfigEntityCfg, CommonEntityCfg, UserEntityCfg, RoleEntityCfg)

        --init lua server
        initLogicLuaService(selfNodeName)

        --init cluster node
        cluster.open(tonumber(skynet.getenv("clusterport")))

        -- log ok
	    os.execute(string.format("echo %s %s >> ok.txt", os.date("%Y-%m-%d %X"), Common.getSelfNodeName()))

        skynet.exit()
    end
)
