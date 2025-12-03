--[[
 * @file : RoleImmigrateMgr.lua
 * @type : multi snax service
 * @author : linfeng
 * @created : 2020-09-01 15:28:09
 * @Last Modified time: 2020-09-01 15:28:09
 * @department : Arabic Studio
 * @brief : 角色移民管理服务
 * Copyright(C) 2020 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local MapLogic = require "MapLogic"
local EntityLoad = require "EntityLoad"
local ItemLogic = require "ItemLogic"
local EmailLogic = require "EmailLogic"
local ScoutsLogic = require "ScoutsLogic"
local Random = require "Random"
local RoleLogic = require "RoleLogic"

function init( index )
    snax.enablecluster()
    cluster.register(SERVICE_NAME .. index)
end

function response.Init()
    -- body
end

---@see 其他服务器角色移民到本服务器
function response.immigrateFromOtherServer( _oldRid, _uid, _iggid, _gameNode, _dbNode )
    -- 创建角色
    local newRid = MSM.d_role[0].req.NewId()
    -- 认为角色在线,加快创建速度
    EntityLoad.loadRole( newRid )
    -- 随机该区域内的空闲坐标
    local pos, setObstracleRef = MapLogic:randomCityIdlePos( newRid, _uid, nil, nil, true )
    if not pos then
        pos = MapLogic:randomCityIdlePos( newRid, _uid, nil, nil, nil, true )
        LOG_ERROR("uid(%d) immigrateFromOtherServer, not found pos, set to center!", _uid)
    end

    -- 从远程db获取角色信息
    local roleInfo = Common.rpcMultiCall( _dbNode, "d_role", "Get", _oldRid )
    roleInfo.pos = pos
    roleInfo.rid = newRid
    local ret = MSM.d_role[newRid].req.Add( newRid, roleInfo )
    if not ret then
        LOG_ERROR("createRole, add record to d_role fail, uid(%d)", _uid)
        -- 卸载角色数据(此时角色未登录,直接落地数据)
        EntityLoad.unLoadRole( newRid )
        return
    end

    -- 该城市进入地图
    local cityId = MSM.MapObjectMgr[newRid].req.cityAddMap( newRid, roleInfo.name, roleInfo.level, roleInfo.country, pos )
    RoleLogic:setRole( newRid, Enum.Role.cityId, cityId )
    -- 添加到隐藏城市服务中
    MSM.CityHideMgr[newRid].post.addCity( newRid )

    -- 移除阻挡
    if setObstracleRef then
        SM.NavMeshObstracleMgr.post.delObstracleByRef( setObstracleRef )
    end

    -- 道具信息
    local itemInfos = Common.rpcMultiCall( _dbNode, "d_item", "Get", _oldRid ) or {}
    for _, itemInfo in pairs(itemInfos) do
        ItemLogic:addItem({
            rid = newRid,
            itemId = itemInfo.itemId,
            itemNum = itemInfo.itemNum,
        })
    end

    -- 建筑信息
    local buildInfos = Common.rpcMultiCall( _dbNode, "d_building", "Get", _oldRid ) or {}
    for buildingIndex, buildInfo in pairs(buildInfos) do
        MSM.d_building[newRid].req.Add( newRid, buildingIndex, buildInfo )
    end

    -- 邮件信息
    local emailInfos = Common.rpcMultiCall( _dbNode, "d_email", "Get", _oldRid ) or {}
    for emailIndex, emailInfo in pairs(emailInfos) do
        EmailLogic:addEmail( newRid, emailIndex, emailInfo )
    end

    -- 英雄信息
    local heroInfos = Common.rpcMultiCall( _dbNode, "d_hero", "Get", _oldRid ) or {}
    for heroId, heroInfo in pairs(heroInfos) do
        MSM.d_hero[newRid].req.Add( newRid, heroId, heroInfo )
    end

    -- 斥候信息
    local scoutsInfos = Common.rpcMultiCall( _dbNode, "d_scouts", "Get", _oldRid ) or {}
    for scoutIndex, scoutsInfo in pairs(scoutsInfos) do
        ScoutsLogic:addScouts( newRid, scoutIndex, scoutsInfo )
    end

    -- 任务信息
    local taskInfos = Common.rpcMultiCall( _dbNode, "d_task", "Get", _oldRid ) or {}
    for taskId, taskInfo in pairs(taskInfos) do
        MSM.d_task[newRid].req.Add( newRid, taskId, taskInfo )
    end

    -- 创建角色数量+1
    Common.redisExecute({ "incr", "gameRoleCount_" .. Common.getSelfNodeName() })

    -- 上报给登陆服务器
    local allLoginds = Common.getClusterNodeByName("login", true)
    if not Common.rpcMultiCall(allLoginds[Random.Get(1, #allLoginds)], "RoleQuery", "ChangeRoleGameNode",
                                _uid, _iggid, _oldRid, newRid, Common.getSelfNodeName()) then
        LOG_ERROR("immigrateFromOtherServer, ChangeRoleGameNode fail, uid(%d)", _uid)
        -- 删除角色
        MSM.d_role[newRid].req.Delete(newRid)
        -- 卸载角色数据(此时角色未登录,直接落地数据)
        EntityLoad.unLoadRole( newRid )
        return
    end

    return newRid
end