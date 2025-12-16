--[[
* @file : MonitorSubscribe.lua
* @type : service
* @author : linfeng
* @created : Thu Nov 23 2017 14:36:12 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 非 monitor_server 的订阅服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local tonumber = tonumber
local EntityLoad = require "EntityLoad"
local Timer = require "Timer"
local sharedata = require "skynet.sharedata"
local queue = require "skynet.queue"

local monitorNodeName
local thisNodeName
local listenFlag = false
local reloadConfigLock

---@see 健康检查
local function clusterHold()
    local timeout, ret = Common.timeoutRun(5, Common.rpcCall, monitorNodeName, "MonitorPublish", "heart", thisNodeName)
    if timeout or not ret then
        -- reconnect
        snax.self().req.connectMonitorAndPush(thisNodeName, true)
    end
end

---@see 记录在线人数
local function recordOnline()
    --local LogLogic = require "LogLogic"
    --LogLogic:serverOnline()
end

function init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)
    monitorNodeName = assert(skynet.getenv("monitornode"))
    reloadConfigLock = queue()
    SM.GCMgr.req.Init()
end

local function clusterOpen( port )
    listenFlag = true
    cluster.open(tonumber(port))
end

---@see 连接到monitor节点.并推送自身的节点信息
function response.connectMonitorAndPush(selfNodeName, noFork)
    local clusterIp = assert(skynet.getenv("clusterip"))
    local clusterPort = assert(skynet.getenv("clusterport"))
    local webIp = assert(skynet.getenv("webip"))
    local webPort = assert(skynet.getenv("webport"))

    if not listenFlag then
        -- init clusterInfo
        SM.InitServer.req.initCluseterNode( selfNodeName )
        -- init selfNodeName
        sharedata.new( Enum.Share.NODENAME, { name = selfNodeName } )
        sharedata.new( Enum.Share.NODELINENAME, { name = selfNodeName } )
    end

    thisNodeName = selfNodeName
    local connRet
    -- 先监听自身的cluster
    if not listenFlag then clusterOpen( clusterPort ) end
    while not connRet do
        _, connRet = Common.timeoutRun( 30, Common.rpcCall, monitorNodeName, "MonitorPublish", "sync",
                                        selfNodeName, clusterIp, clusterPort, webIp, webPort )
        skynet.sleep(100) -- sleep 1s
    end

    -- hold cluster connect
    if not noFork then
        Timer.runEvery( 300, clusterHold )
        if thisNodeName:find("game") ~= nil then
            -- log server start
            --local LogLogic = require "LogLogic"
            --LogLogic:serverStatus( { status = 1 } )
            -- log server online
            Timer.runEveryMin( recordOnline )
        end
    end
end

---@see 同步集群节点信息
function response.syncClusterInfo(clusterInfo)
    -- reload clustername.lua
    SM.Rpc.req.updateClusterName(clusterInfo)
    return true
end

---@see 重载本节点的静态配置数据
function response.reloadConfig()
    return reloadConfigLock(function ()
        if Enum.DebugMode then
            -- 重新 git pull common/config
            os.execute("cd common/config && git pull && cd -")
        end
        -- 重载配置缓存
        SM.ReadConfig.req.reLoad()
        EntityLoad.loadConfig( true )

        -- reinit config data
        if thisNodeName:find("game") ~= nil then
            snax.newservice("ConfigData").req.reInitConfigData()
            -- 与策划确认暂时关闭这个功能
            --SM.ActivityMgr.post.resetActivityTimeInfo()
        elseif thisNodeName:find("battle") ~= nil then
            snax.newservice("BattleConfigData").req.reInitConfigData()
        end
        LOG_INFO("load config data ok!")
    end)
end

local function closeCluster()
    if thisNodeName:find("game") ~= nil then
        -- log server stop
        local LogLogic = require "LogLogic"
        --LogLogic:serverStatus( { status = 0 } )
    end
    -- 通知关服成功
    Common.sendCloseNodeSuccess( thisNodeName )
    -- 等待2s关闭
    skynet.sleep(200)
    -- 关闭log
    snax.kill(SM.SysLog)
    skynet.abort()
end

---@see 重启集群.如果是gameserver.centerserver.dbserver.需要先落地数据
function response.restartCluster()
    if thisNodeName:find("game") ~= nil then
        -- 通知军队退出战斗
        local ArmyLogic = require "ArmyLogic"
        pcall(ArmyLogic.notifyArmyExitBattle, ArmyLogic)
        -- gameserver,需要先断开所有连接,并拒绝连接(Gamed.clean_handler->Agent.cleanAgent)
        pcall(skynet.call, "Gamed", "lua", "clean")
        -- 检查是否有忙碌服务
        local GuildLogic = require "GuildLogic"
        pcall(GuildLogic.checkServiceBusy, GuildLogic)
    end

    pcall(EntityLoad.unLoadRole)
    pcall(EntityLoad.unLoadCommon)

    LOG_INFO("close this Cluster Node(%s) after 2s", thisNodeName)
    -- 关闭掉此节点
    Timer.runAfter(10,closeCluster)
end

---@see 重启自身
function accept.closeAndStart()
    if thisNodeName:find("game") ~= nil then
        -- 通知军队退出战斗
        local ArmyLogic = require "ArmyLogic"
        ArmyLogic:notifyArmyExitBattle()
        -- gameserver,需要先断开所有连接,并拒绝连接(Gamed.clean_handler->Agent.cleanAgent)
        pcall(skynet.call, "Gamed", "lua", "clean")
    end

    -- EntityLoad.unLoadUser()
    EntityLoad.unLoadRole()
    EntityLoad.unLoadCommon()

    LOG_INFO("close this Cluster Node(%s) after 2s", thisNodeName)
    -- 2s后关闭掉此节点
    Timer.runAfter(200,closeCluster)
end