--[[
* @file : Main.lua
* @type : service
* @author : linfeng
* @created : Thu Nov 23 2017 13:50:17 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : game_server 启动脚本
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
require "skynet.manager"
require "GameCfg"
local sharedata = require "skynet.sharedata"
local snax = require "skynet.snax"
-- 用于提前启动cluster,不能删除
local cluster = require "skynet.cluster"

local function initLogicLuaService()
    -- init share
    sharedata.new( Enum.Share.DBNODE, { name = skynet.getenv("dbnode") })
    sharedata.new( Enum.Share.CENTERNODE, { name = skynet.getenv("centernode") } )
    sharedata.new( Enum.Share.CHATNODE, { name = skynet.getenv("chatnode") } )
    sharedata.new( Enum.Share.PUSHNODE, { name = skynet.getenv("pushnode") } )

    local openTime = string.split(skynet.getenv("opentime"),"-",true)
    openTime = { year = openTime[1], month = openTime[2], day = openTime[3], hour = 0 }
    sharedata.new( Enum.Share.OPENTIME, { time = os.time(openTime) } ) -- 格林威治时间
    sharedata.new( Enum.Share.ServerStart, { start = true } )
    sharedata.new( Enum.Share.FullProvice, { } )

    -- init entity config
    SM.InitServer.req.initEntityCfg(ConfigEntityCfg, CommonEntityCfg, UserEntityCfg, RoleEntityCfg)
    -- reinit config data
    snax.newservice("ConfigData").req.reInitConfigData( true )
    -- init sproto protocol
    SM.RegCSProtocol.req.Init()
    --init Web
    SM.Web.req.Init()
    -- init Hotfix
    SM.Hotfix.req.Init()
    -- init PkIdMgr
    MSM.PkIdMgr[0].req.Init()
    -- init RoleQuery
    MSM.RoleQuery[0].req.Init()
    -- init MapLevelMgr
    SM.MapLevelMgr.req.Init()
    -- init NavMeshMapMgr
    SM.NavMeshMapMgr.req.Init()
    -- init NavMeshObstracleMgr
    SM.NavMeshObstracleMgr.req.Init()
    -- init ActivityMgr
    SM.ActivityMgr.req.Init()
    -- init MapObjectMgr
    MSM.MapObjectMgr[0].req.Init()
    -- set obstracle
    SM.NavMeshObstracleMgr.req.addObstracleImpl()
    -- init CityHideMgr
    MSM.CityHideMgr[0].req.Init()
    -- init GuildBuildInitMgr
    SM.GuildBuildInitMgr.req.Init()
    -- init GuildAttrMgr
    MSM.GuildAttrMgr[0].req.Init()
    -- init RoleHeartMgr
    MSM.RoleHeartMgr[0].req.Init()
    -- init BattleProxy
    MSM.BattleProxy[0].req.Init()
    -- init MapFixPointMgr
    SM.MapFixPointMgr.req.Init()
    -- init MapObjectInitMgr
    SM.MapObjectRefreshMgr.req.Init()
    -- init GuildNameProxy
    SM.GuildNameProxy.req.Init()
    -- init ChatPrivate
    MSM.ChatPrivate[0].req.Init()
    -- init GuildRecommendMgr
    SM.GuildRecommendMgr.req.Init()
    -- init SystemTimer
    SM.SystemTimer.req.Init()
    -- init RankMgr
    MSM.RankMgr[0].req.Init()
    -- init MonumentMgr
    SM.MonumentMgr.req.Init()
    -- init RallyMgr
    MSM.RallyMgr[0].req.Init()
    -- init ExpeditionShopMgr
    SM.ExpeditionShopMgr.req.Init()
    -- init EarlyWarningMgr
    MSM.EarlyWarningMgr[0].req.Init()
    -- init GuildMessageBoardMgr
    MSM.GuildMessageBoardMgr[0].req.Init()
    -- init MarqueeMgr
    SM.MarqueeMgr.req.Init()
    -- init SystemEmailMgr
    MSM.SystemEmailMgr[0].req.Init()
    -- init EmailCountMgr
    MSM.EmailCountMgr[0].req.Init()
    -- init EmailProxy
    MSM.EmailProxy[0].req.Init()
    -- init PushMgr
    SM.PushMgr.req.Init()
    -- init PVENavMeshMapMgr
    SM.PVENavMeshMapMgr.req.Init()
    -- init ChatProxy
    SM.ChatProxy.req.Init()
    -- init CheckPointAStarMgr
    MSM.CheckPointAStarMgr[0].req.Init()
    -- init AccountMgr
    SM.AccountMgr.req.Init()
    -- init BattleReportUploadMgr
    MSM.BattleReportUploadMgr[0].req.Init()
    -- init RoleImmigrateMgr
    MSM.RoleImmigrateMgr[0].req.Init()
    -- 初始化远征地图服务
    SM.ExpeditionAoiSpaceMgr.req.Init()
    -- init OnlineMgr
    SM.OnlineMgr.req.Init()
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
        local ret, err = xpcall(initLogicLuaService, debug.traceback)
        if not ret then
            LOG_ERROR(err)
            -- send error to chat
            Common.sendGameOpenFail( selfNodeName, err )
            -- wait 3s exit
            skynet.sleep(300)
            skynet.abort()
        end

        --init gate(begin listen)
        local Gamed = skynet.uniqueservice("Gamed")
        skynet.call(
            Gamed,
            "lua",
            "open",
            {
                port = tonumber(skynet.getenv("port")) or 8888,
                maxclient = tonumber(skynet.getenv("maxclient")) or 1024,
                servername = selfNodeName,
            }
        )

        -- log ok
        os.execute(string.format("echo %s %s >> ok.txt", os.date("%Y-%m-%d %X"), Common.getSelfNodeName()))

        -- send ok to chat
        Common.sendGameOpenSuccess( selfNodeName )

        --exit
        skynet.exit()
    end
)
