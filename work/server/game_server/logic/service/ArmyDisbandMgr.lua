--[[
* @file : ArmyDisbandMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Mon Jul 06 2020 09:52:44 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 部队解散服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local queue = require "skynet.queue"
local TaskLogic = require "TaskLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local RoleLogic = require "RoleLogic"
local EmailLogic = require "EmailLogic"
local BuildingLogic = require "BuildingLogic"
local ArmyLogic = require "ArmyLogic"
local RoleSync = require "RoleSync"
local RankLogic = require "RankLogic"
local Random = require "Random"
local HeroLogic = require "HeroLogic"
local GuildLogic = require "GuildLogic"
local ArmyMarchLogic = require "ArmyMarchLogic"
local LogLogic = require "LogLogic"
local SoldierLogic = require "SoldierLogic"

local armyLocks = {}

---@see 解散部队
function response.disbandArmy( _rid, _armyIndex, _noSync, _isReboot )
    if not armyLocks[_rid] then
        armyLocks[_rid] = { lock = queue() }
    end

    armyLocks[_rid].lock(
        function ()
            local roleInfo = RoleLogic:getRole( _rid, {
                Enum.Role.extraResourcesMulti,
                Enum.Role.guildBuildPoint, Enum.Role.guildId, Enum.Role.actionForce, Enum.Role.iggid
            } )
            local armyInfo = ArmyLogic:getArmy( _rid, _armyIndex )
            -- 返还行动力
            ArmyMarchLogic:checkReturnActionForce( _rid, roleInfo, armyInfo )
            local addSoldierInfo = {}
            -- 剩余未受伤士兵信息返回角色士兵列表
            for _, soldierInfo in pairs( armyInfo.soldiers or {} ) do
                if not addSoldierInfo[soldierInfo.id] then
                    addSoldierInfo[soldierInfo.id] = { id = soldierInfo.id, num = 0, minor = 0 }
                end
                addSoldierInfo[soldierInfo.id].num = addSoldierInfo[soldierInfo.id].num + soldierInfo.num
            end
            -- 剩余轻伤士兵信息返回角色士兵列表
            for _, soldierInfo in pairs( armyInfo.minorSoldiers or {} ) do
                if not addSoldierInfo[soldierInfo.id] then
                    addSoldierInfo[soldierInfo.id] = { id = soldierInfo.id, num = 0, minor = 0 }
                end
                addSoldierInfo[soldierInfo.id].num = addSoldierInfo[soldierInfo.id].num + soldierInfo.num
            end

            if not _isReboot then
                -- 士兵回城处理
                local addSoldiers = {}
                table.merge( addSoldiers, armyInfo.soldiers or {} )
                table.merge( addSoldiers, armyInfo.minorSoldiers or {} )
                ArmyLogic:addSoldierCallback( _rid, addSoldiers, true )
            end

            local extraResource, sResource
            local sResourceGatherType = CFG.s_ResourceGatherType:Get()
            -- 军队采集额外获得资源百分比
            local extraResourcesMulti = roleInfo.extraResourcesMulti or 0
            -- 主将技能和天赋
            extraResourcesMulti = extraResourcesMulti + ( HeroLogic:getHeroAttr( _rid, armyInfo.mainHeroId, "extraResourcesMulti" ) or 0 )
            -- 副将的技能
            if armyInfo.deputyHeroId and armyInfo.deputyHeroId > 0 then
                extraResourcesMulti = extraResourcesMulti + ( HeroLogic:getHeroAttr( _rid, armyInfo.deputyHeroId, "extraResourcesMulti", true ) or 0 )
            end

            local logType = Enum.LogType.COLLECT_RESOURCE_GAIN_CURRENCY
            local taskType = Enum.TaskType.MAP_RESOURCE
            local roleStatisticsType = Enum.RoleStatisticsType.RESOURCE_COLLECT
            local resourceNum, taskStatisticsSum, roleStatistics
            local dailyTaskSchedules = {}
            local guildCurrencyType, resourceType, emailId, resourceTypeId, resourceReportType
            -- 获取军队采集负载
            for _, loadInfo in pairs( armyInfo.resourceLoads or {} ) do
                emailId = nil
                if loadInfo.resourceTypeId and loadInfo.resourceTypeId > 0 then
                    sResource = sResourceGatherType[loadInfo.resourceTypeId]
                    resourceType = sResource.type
                    emailId = sResource.mail
                    resourceTypeId = loadInfo.resourceTypeId
                    resourceReportType = Enum.ResourceReportType.RESOURCE
                elseif loadInfo.guildBuildType and loadInfo.guildBuildType > 0 then
                    -- 联盟资源中心采集
                    resourceType = GuildBuildLogic:resourceBuildTypeToResourceType( loadInfo.guildBuildType )
                    emailId = CFG.s_AllianceBuildingType:Get( loadInfo.guildBuildType, "mail" )
                    resourceTypeId = loadInfo.guildBuildType
                    resourceReportType = Enum.ResourceReportType.RESOURCE_CENTER
                end

                extraResource = math.floor( loadInfo.load * extraResourcesMulti / 1000 )
                resourceNum = loadInfo.load + extraResource
                guildCurrencyType = nil
                if resourceType == Enum.ResourceType.FARMLAND then
                    -- 农田采集量
                    RoleLogic:addFood( _rid, resourceNum, _noSync, logType, loadInfo.resourceTypeId )
                    ArmyLogic:ActivityRoleMgr( _rid, Enum.ActivityActionType.COLLECTION_FOOD_COUNT, Enum.ActivityActionType.COLLECTION_FOOD_NUM, resourceNum )
                    guildCurrencyType = Enum.CurrencyType.allianceFood
                elseif resourceType == Enum.ResourceType.WOOD then
                    -- 木材采集量
                    RoleLogic:addWood( _rid, resourceNum, _noSync, logType, loadInfo.resourceTypeId )
                    ArmyLogic:ActivityRoleMgr( _rid, Enum.ActivityActionType.COLLECTION_WOOD_COUNT, Enum.ActivityActionType.COLLECTION_WOOD_NUM, resourceNum )
                    guildCurrencyType = Enum.CurrencyType.allianceWood
                elseif resourceType == Enum.ResourceType.STONE then
                    -- 石料采集量
                    RoleLogic:addStone( _rid, resourceNum, _noSync, logType, loadInfo.resourceTypeId )
                    ArmyLogic:ActivityRoleMgr( _rid, Enum.ActivityActionType.COLLECTION_STONE_COUNT, Enum.ActivityActionType.COLLECTION_STONE_NUM, resourceNum )
                    guildCurrencyType = Enum.CurrencyType.allianceStone
                elseif resourceType == Enum.ResourceType.GOLD then
                    -- 金矿采集量
                    RoleLogic:addGold( _rid, resourceNum, _noSync, logType, loadInfo.resourceTypeId )
                    ArmyLogic:ActivityRoleMgr( _rid, Enum.ActivityActionType.COLLECTION_GOLD_COUNT, Enum.ActivityActionType.COLLECTION_GOLD_NUM, resourceNum )
                    guildCurrencyType = Enum.CurrencyType.allianceGold
                elseif resourceType == Enum.ResourceType.DENAR then
                    -- 宝石采集量
                    RoleLogic:addDenar( _rid, resourceNum, _noSync, logType, loadInfo.resourceTypeId )
                    ArmyLogic:ActivityRoleMgr( _rid, Enum.ActivityActionType.COLLECTION_DENAR_COUNT, Enum.ActivityActionType.COLLECTION_DENAR_NUM, resourceNum )
                end

                -- 【【Bug转需求】【额外掉落活动】目前游戏中，采集野外资源，就只派一个兵，也可以触发奖励，策划确认下是否ok】https://www.tapd.cn/64603723/prong/stories/view/1164603723001006017
                if resourceType ~= Enum.ResourceType.DENAR and resourceNum > 0 then
                    -- 取对应的1级田信息
                    local config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.RESOURCE_TYPE )
                    local maxCount = config[resourceType][1]
                    local activityDropLimitTimes = CFG.s_Config:Get("activityDropLimitTimes")
                    local count = resourceNum / maxCount // 1
                    local modNum = resourceNum - count * maxCount
                    if count > activityDropLimitTimes then
                        count = activityDropLimitTimes
                    end
                    local rate = math.floor(modNum / maxCount * 1000 )
                    if rate < 1 then rate = 1 end
                    local randomRate = Random.Get(1, 1000)
                    if rate > randomRate then
                        count = count + 1
                    end
                    for _ = 1, count do
                        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.COLLECTION_RES_ACTION, 1 )
                    end
                end

                if resourceNum > 0 then
                    if emailId then
                        -- 发送采集报告邮件
                        EmailLogic:sendResourceCollectEmail( _rid, emailId, resourceTypeId, loadInfo.pos, loadInfo.load, extraResource, _noSync, resourceReportType )
                    end
                    -- 增加任务统计信息
                    TaskLogic:addTaskStatisticsSum( _rid, taskType, resourceType, resourceNum, true )
                    taskStatisticsSum = TaskLogic:addTaskStatisticsSum( _rid, taskType, Enum.TaskArgDefault, resourceNum, true )
                    dailyTaskSchedules[taskType] = { arg = resourceType, addNum = resourceNum }
                    -- 增加角色统计
                    roleStatistics = RoleLogic:addRoleStatistics( _rid, roleStatisticsType, resourceNum, true )
                    RankLogic:update( _rid, Enum.RankType.ROLE_RES, roleStatistics[roleStatisticsType].num )
                    -- 角色在联盟领土采集资源，联盟获取相应资源量
                    if guildCurrencyType and roleInfo.guildId and roleInfo.guildId > 0 and loadInfo.isGuildTerritory
                        and roleInfo.guildId == ( loadInfo.guildId or 0 ) then
                        local allianceResourceScale = CFG.s_Config:Get( "allianceResourceScale" ) or 0
                        if allianceResourceScale > 0 then
                            local addCurrency = math.floor( loadInfo.load / allianceResourceScale )
                            if addCurrency > 0 then
                                MSM.GuildMgr[roleInfo.guildId].post.addGuildCurrency( roleInfo.guildId, guildCurrencyType, addCurrency )
                            end
                        end
                    end
                end
            end

            -- 增加联盟个人积分
            if armyInfo.guildBuildPoint and armyInfo.guildBuildPoint > 0 then
                local addGuildBuildPoint = armyInfo.guildBuildPoint
                local allianceCoinRewardDailyLimit = CFG.s_Config:Get( "allianceCoinRewardDailyLimit" )
                if ( roleInfo.guildBuildPoint or 0 ) + addGuildBuildPoint > allianceCoinRewardDailyLimit then
                    addGuildBuildPoint = allianceCoinRewardDailyLimit - ( roleInfo.guildBuildPoint or 0 )
                end
                if addGuildBuildPoint > 0 then
                    roleInfo.guildBuildPoint = ( roleInfo.guildBuildPoint or 0 ) + addGuildBuildPoint
                    RoleLogic:addGuildPoint( _rid, addGuildBuildPoint, _noSync, Enum.LogType.GUILD_BUILD_GAIN_POINT )
                    -- 增加联盟积分
                    if roleInfo.guildId and roleInfo.guildId > 0 then
                        GuildLogic:addGuildCurrency( roleInfo.guildId, Enum.CurrencyType.leaguePoints, addGuildBuildPoint )
                    end
                end
            end

            -- 参与建造联盟建筑时间
            if armyInfo.guildBuildTime and armyInfo.guildBuildTime > 0 then
                if roleInfo.guildId and roleInfo.guildId > 0 then
                    MSM.GuildMgr[roleInfo.guildId].post.updateGuildRank( roleInfo.guildId, _rid, Enum.RankType.ALLIACEN_ROLE_BUILD, armyInfo.guildBuildTime )
                end
            end

            -- 更新军队信息和士兵信息
            RoleLogic:setRole( _rid, { [Enum.Role.guildBuildPoint] = roleInfo.guildBuildPoint } )
            -- 添加士兵回角色身上
            SoldierLogic:addSoldier( _rid, addSoldierInfo, true )
            -- 删除部队
            MSM.d_army[_rid].req.Delete( _rid, _armyIndex )
            if not _noSync then
                local roleSyncInfo = {}
                if taskStatisticsSum then
                    roleSyncInfo.taskStatisticsSum = { [taskType] = taskStatisticsSum[taskType] }
                end
                if roleStatistics then
                    roleSyncInfo.roleStatistics = { [roleStatisticsType] = roleStatistics[roleStatisticsType] }
                end
                -- 通知客户端
                RoleSync:syncSelf( _rid, roleSyncInfo, true )
                -- 通知客户端部队解散
                ArmyLogic:syncArmy( _rid, _armyIndex, { mainHeroId = 0 }, true )
            end
            -- 驻防修改
            BuildingLogic:changeDefendHero( _rid, _noSync )
            -- 更新每日任务进度
            TaskLogic:updateTaskSchedule( _rid, dailyTaskSchedules, _noSync )

            -- 发送推送
            SM.PushMgr.post.sendPush( { pushRid = _rid, pushType = Enum.PushType.ARMY_RETURN, args = { arg1 = RoleLogic:getRole( _rid, Enum.Role.name) } } )
            LogLogic:roleArmyChange( {
                logType = Enum.LogType.DISBAND_ARMY, rid = _rid, iggid = roleInfo.iggid, soldiers = armyInfo.soldiers,
                minorSoldiers = armyInfo.minorSoldiers, mainHeroId = armyInfo.mainHeroId or 0, deputyHeroId = armyInfo.deputyHeroId or 0,
                armyIndex = _armyIndex
            } )
        end
    )
end

---@see 获取部队新的索引
function response.getNewArmyIndex( _rid )
    if not armyLocks[_rid] then
        armyLocks[_rid] = { lock = queue() }
    end

    return armyLocks[_rid].lock(
        function ()
            local lastArmyIndex = RoleLogic:getRole( _rid, Enum.Role.lastArmyIndex ) or 0
            if lastArmyIndex <= 0 then
                -- 角色已有部队
                local allArmy = ArmyLogic:getArmy( _rid ) or {}
                for armyIndex in pairs( allArmy ) do
                    if lastArmyIndex < armyIndex then
                        lastArmyIndex = armyIndex
                    end
                end
            end

            lastArmyIndex = lastArmyIndex + 1
            RoleLogic:setRole( _rid, { [Enum.Role.lastArmyIndex] = lastArmyIndex } )

            return lastArmyIndex
        end
    )
end