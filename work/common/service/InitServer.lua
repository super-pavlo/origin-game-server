--[[
* @file : InitServer.lua
* @type : snax single service
* @author : linfeng
* @created : Fri Mar 09 2018 10:22:07 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 初始化集群文件相关服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
local EntityImpl = require "EntityImpl"
local EntityLoad = require "EntityLoad"
local cluster = require "skynet.cluster"

function response.initCluseterNode( selfNodeName )
    local f = assert(io.open(skynet.getenv("cluster"),"w+"))
    f:write("__nowaiting = true\n")
    -- 写入monitor和self node
    local monitorName = skynet.getenv("monitornode")
    local monitorIp = skynet.getenv("monitorip")
    local monitorPort = skynet.getenv("monitorport")

    local clusterName = selfNodeName
    local clusterIp = skynet.getenv("clusterip")
    local clusterPort = skynet.getenv("clusterport")
    local config = monitorName.."=\""..monitorIp..":"..monitorPort.."\"\n"
    f:write(config)
    if clusterName ~= monitorName then
        config = clusterName.."=\""..clusterIp..":"..clusterPort.."\"\n"
        f:write(config)
    end
    f:close()

    cluster.reload()
end

function response.initEntityCfg(ConfigEntity, CommonEntity, UserEntity, RoleEntity)
    EntityImpl:setEntityCfg(ConfigEntity, CommonEntity, UserEntity, RoleEntity)
    EntityLoad.loadConfig()
    EntityLoad.loadCommon()

    -- 显性启动数据服务
    for _, cfg in pairs(CommonEntity) do
        SM[cfg.name].req.empty()
    end
    for _, cfg in pairs(UserEntity) do
        MSM[cfg.name][0].req.empty()
    end
    for _, cfg in pairs(RoleEntity) do
        MSM[cfg.name][0].req.empty()
    end
end