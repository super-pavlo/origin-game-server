--[[
* @file : HolyLandMgr.lua
* @type : snax single service
* @author : dingyuchao
* @created : Fri May 15 2020 13:13:41 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 圣地信息管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local Timer = require "Timer"
local RoleLogic = require "RoleLogic"
local GuildLogic = require "GuildLogic"
local HolyLandLogic = require "HolyLandLogic"
local MonumentLogic = require "MonumentLogic"
local GuildTerritoryLogic = require "GuildTerritoryLogic"
local ArmyLogic = require "ArmyLogic"
local sharedata = require "skynet.sharedata"
local LogLogic = require "LogLogic"

---@class defaultHolyLandInfoClass
local defaultHolyLandInfo = {
    objectIndex                 =               0,                      -- 地图对象索引
}

---@type table<int, defaultHolyLandInfoClass>
local holyLands = {}

---@see 圣地状态定时器
local holyLandTimers = {}

---@see 圣地地块
---@type table<int, int>
local holyLandTerritoryIds = {}

---@see 圣地状态超时处理
local function holyLandStatusTimeOut( _holyLandId )
    holyLandTimers[_holyLandId] = nil

    -- 下个状态超时时间
    local finishTime
    local nowTime = os.time()
    local updateHolyLandInfo
    local holyLandType = CFG.s_StrongHoldData:Get( _holyLandId, "type" )
    local sStrongHoldType = CFG.s_StrongHoldType:Get( holyLandType )
    local holyLandInfo = HolyLandLogic:getHolyLand( _holyLandId )
    if holyLandInfo.status == Enum.HolyLandStatus.INIT_PROTECT then
        -- 初始保护中进入初始争夺中
        HolyLandLogic:setHolyLand( _holyLandId, {
            [Enum.HolyLand.status] = Enum.HolyLandStatus.INIT_SCRAMBLE,
            [Enum.HolyLand.finishTime] = -1,
        } )
        -- 更新地图圣地信息
        updateHolyLandInfo = {
            holyLandStatus = Enum.HolyLandStatus.INIT_SCRAMBLE,
            holyLandFinishTime = -1,
        }
    elseif holyLandInfo.status == Enum.HolyLandStatus.SCRAMBLE then
        -- 常规争夺中进入常规保护中
        finishTime = nowTime + sStrongHoldType.protectTime
        HolyLandLogic:setHolyLand( _holyLandId, {
            [Enum.HolyLand.status] = Enum.HolyLandStatus.PROTECT,
            [Enum.HolyLand.finishTime] = finishTime,
        } )
        -- 更新地图圣地信息
        updateHolyLandInfo = {
            holyLandStatus = Enum.HolyLandStatus.PROTECT,
            holyLandFinishTime = finishTime,
        }
        if holyLandType == Enum.HolyLandType.LOST_TEMPLE and holyLandInfo.guildId and holyLandInfo.guildId > 0 then
            -- 占领神庙成功，添加国王记录
            local guildInfo = GuildLogic:getGuild( holyLandInfo.guildId, { Enum.Guild.abbreviationName, Enum.Guild.leaderRid } )
            local leaderInfo = RoleLogic:getRole( guildInfo.leaderRid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } )
            SM.c_king.req.Add( nil, {
                guildAbbName = guildInfo.abbreviationName,
                kingName = leaderInfo.name,
                kingTime = os.time(),
                kingHeadId = leaderInfo.headId,
                kingHeadFrameId = leaderInfo.headFrameID,
            } )
        end
        if holyLandInfo.guildId and holyLandInfo.guildId > 0 then
            MSM.GuildAttrMgr[holyLandInfo.guildId].post.addHolyLand( holyLandInfo.guildId, _holyLandId )
        end
    elseif holyLandInfo.status == Enum.HolyLandStatus.PROTECT then
        -- 常规保护中进入常规争夺中
        finishTime = nowTime + sStrongHoldType.battleTime
        HolyLandLogic:setHolyLand( _holyLandId, {
            [Enum.HolyLand.status] = Enum.HolyLandStatus.SCRAMBLE,
            [Enum.HolyLand.finishTime] = finishTime,
        } )
        -- 更新地图圣地信息
        updateHolyLandInfo = {
            holyLandStatus = Enum.HolyLandStatus.SCRAMBLE,
            holyLandFinishTime = finishTime,
        }
    end

    -- 增加圣地状态定时器
    if finishTime then
        holyLandTimers[_holyLandId] = Timer.runAt( finishTime, holyLandStatusTimeOut, _holyLandId )
    end

    -- 更新圣地信息
    if updateHolyLandInfo then
        MSM.SceneHolyLandMgr[holyLands[_holyLandId].objectIndex].post.updateHolyLandInfo( holyLands[_holyLandId].objectIndex, updateHolyLandInfo )
    end
end

---@see 初始化圣地坐标
function response.Init()
    local sStrongHoldData = CFG.s_StrongHoldData:Get()
    local sStrongHoldType = CFG.s_StrongHoldType:Get()
    local sHoldType, territoryIds
    for _, strongHoldData in pairs( sStrongHoldData ) do
        sHoldType = sStrongHoldType[strongHoldData.type]
        territoryIds = GuildTerritoryLogic:getPosTerritoryIds( { x = strongHoldData.posX, y = strongHoldData.posY }, sHoldType.territorySize )
        for _, territoryId in pairs( territoryIds ) do
            holyLandTerritoryIds[territoryId] = { holylandId = strongHoldData.ID }
        end
    end
end

---@see 初始化
function response.InitGuildHolyLands()
    local nowTime = os.time()
    local allHolyLand = HolyLandLogic:getHolyLand() or {}
    local sStrongHoldData = CFG.s_StrongHoldData:Get()
    local sStrongHoldType = CFG.s_StrongHoldType:Get()

    local sHoldType, sHoldData, objectIndex, objectType, pos, territoryIds, armyStatus, newReinforces
    -- 处理之前的圣地状态
    for holyLandId, holyLandInfo in pairs( allHolyLand ) do
        sHoldData = sStrongHoldData[holyLandId]
        sHoldType = sStrongHoldType[sHoldData.type]
        if holyLandInfo.finishTime > 0 and holyLandInfo.finishTime <= nowTime
            and not HolyLandLogic:isCheckPointType( sHoldType.group ) then
            while true do
                if holyLandInfo.status == Enum.HolyLandStatus.INIT_PROTECT then
                    -- 超过初始保护中, 下一个状态初始争夺中
                    holyLandInfo.finishTime = -1
                    holyLandInfo.status = Enum.HolyLandStatus.INIT_SCRAMBLE
                    break
                -- elseif holyLandInfo.status == Enum.HolyLandStatus.INIT_SCRAMBLE then
                    -- 无初始争夺中状态
                elseif holyLandInfo.status == Enum.HolyLandStatus.SCRAMBLE then
                    -- 超过常规争夺中, 下一状态常规保护中
                    holyLandInfo.finishTime = holyLandInfo.finishTime + sHoldType.protectTime
                    holyLandInfo.status = Enum.HolyLandStatus.PROTECT
                elseif holyLandInfo.status == Enum.HolyLandStatus.PROTECT then
                    -- 超过常规保护中, 下一个状态常规争夺中
                    holyLandInfo.finishTime = holyLandInfo.finishTime + sHoldType.battleTime
                    holyLandInfo.status = Enum.HolyLandStatus.SCRAMBLE
                end
                -- 找到当前的圣地状态，退出while循环
                if holyLandInfo.finishTime > nowTime then
                    break
                end
            end
            -- 更新圣地状态
            HolyLandLogic:setHolyLand( holyLandId, holyLandInfo )
        end
        if HolyLandLogic:isCheckPointType( sHoldType.group ) then
            -- 关卡类型
            objectType = Enum.RoleType.CHECKPOINT
        elseif HolyLandLogic:isRelicType( sHoldType.group ) then
            -- 圣物类型
            objectType = Enum.RoleType.RELIC
        end
        pos = { x = sHoldData.posX, y = sHoldData.posY }
        if not GuildLogic:checkGuild( holyLandInfo.guildId ) then
            -- 检查联盟是否存在
            holyLandInfo.guildId = 0
            HolyLandLogic:setHolyLand( holyLandId, { [Enum.HolyLand.guildId] = 0 } )
        end
        -- 圣地进入aoi
        objectIndex = MSM.MapObjectMgr[holyLandId].req.holyLandAddMap( holyLandId, pos, holyLandInfo.guildId, holyLandInfo.status, holyLandInfo.finishTime, objectType )
        holyLands[holyLandId] = { objectIndex = objectIndex }
        HolyLandLogic:setHolyLand( holyLandId, { [Enum.HolyLand.pos] = pos } )

        -- 占用地块
        territoryIds = GuildTerritoryLogic:getPosTerritoryIds( pos, sHoldType.territorySize )
        if holyLandInfo.guildId and holyLandInfo.guildId > 0 then
            -- 联盟占领圣地
            MSM.GuildHolyLandMgr[holyLandInfo.guildId].req.occupyHolyLand( holyLandInfo.guildId, holyLandId, pos, holyLandInfo.valid, territoryIds, objectIndex, true )
            newReinforces = {}
            for buildArmyIndex, reinforce in pairs( holyLandInfo.reinforces or {} ) do
                armyStatus = ArmyLogic:getArmy( reinforce.rid, reinforce.armyIndex, Enum.Army.status )
                if armyStatus and ArmyLogic:checkArmyStatus( armyStatus, Enum.ArmyStatus.GARRISONING ) then
                    newReinforces[buildArmyIndex] = reinforce
                    MSM.SceneHolyLandMgr[objectIndex].post.addGarrisonArmy( objectIndex, reinforce.rid, reinforce.armyIndex, buildArmyIndex )
                    ArmyLogic:setArmy( reinforce.rid, reinforce.armyIndex, {
                        [Enum.Army.targetArg] = { targetObjectIndex = objectIndex, pos = pos }
                    } )
                end
            end
            HolyLandLogic:setHolyLand( holyLandId, { [Enum.HolyLand.reinforces] = newReinforces } )
        end

        -- 增加圣地状态定时器
        if holyLandInfo.finishTime > 0 then
            holyLandTimers[holyLandId] = Timer.runAt( holyLandInfo.finishTime, holyLandStatusTimeOut, holyLandId )
        end
    end

    -- 检查是否有新增的圣地信息
    local finishFlag, monumentFinishTime, statusFinishTime, newHolyLand
    for holyLandId, strongHoldData in pairs( sStrongHoldData ) do
        -- 新增圣地信息
        if not allHolyLand[holyLandId] then
            sHoldType = sStrongHoldType[strongHoldData.type]
            finishFlag, monumentFinishTime = MonumentLogic:checkMonumentStatus( sHoldType.openMileStone )
            if finishFlag then
                -- 纪念碑事件已完成
                statusFinishTime = monumentFinishTime + sHoldType.initProtectTime
                if statusFinishTime <= nowTime then
                    -- 已超过初始保护时间, 进入初始争夺中
                    newHolyLand = {
                        holyLandId = holyLandId,
                        pos = { x = strongHoldData.posX, y = strongHoldData.posY },
                        status = Enum.HolyLandStatus.INIT_SCRAMBLE,
                        finishTime = -1,
                    }
                else
                    -- 未超过初始保护时间
                    newHolyLand = {
                        holyLandId = holyLandId,
                        pos = { x = strongHoldData.posX, y = strongHoldData.posY },
                        status = Enum.HolyLandStatus.INIT_PROTECT,
                        finishTime = statusFinishTime,
                    }
                end
            else
                -- 纪念碑事件未完成
                newHolyLand = {
                    holyLandId = holyLandId,
                    pos = { x = strongHoldData.posX, y = strongHoldData.posY },
                    status = Enum.HolyLandStatus.LOCK,
                    finishTime = 0,
                }
            end

            -- 更新到圣地信息中
            SM.c_holy_land.req.Add( holyLandId, newHolyLand )

            if HolyLandLogic:isCheckPointType( sHoldType.group ) then
                -- 关卡类型
                objectType = Enum.RoleType.CHECKPOINT
            elseif HolyLandLogic:isRelicType( sHoldType.group ) then
                -- 圣物类型
                objectType = Enum.RoleType.RELIC
            end
            -- 圣地进入aoi
            objectIndex = MSM.MapObjectMgr[holyLandId].req.holyLandAddMap( holyLandId, newHolyLand.pos, nil, newHolyLand.status, newHolyLand.finishTime, objectType )
            holyLands[holyLandId] = { objectIndex = objectIndex }
            -- 增加圣地状态定时器
            if newHolyLand.finishTime > 0 then
                holyLandTimers[holyLandId] = Timer.runAt( newHolyLand.finishTime, holyLandStatusTimeOut, holyLandId )
            end
        end
    end
end

---@see 占领圣地
function response.occupyHolyLand( _holyLandId, _guildId )
    local holyLandInfo = HolyLandLogic:getHolyLand( _holyLandId )
    if holyLandInfo.guildId == _guildId then
        return true
    end

    local finishTime, updateHolyLandInfo, occupyEmailIds
    local occupyFlag = 0
    local nowTime = os.time()
    -- 删除定时器
    if holyLandTimers[_holyLandId] then
        Timer.delete( holyLandTimers[_holyLandId] )
    end
    local holyLandType = CFG.s_StrongHoldData:Get( _holyLandId, "type" )
    local sStrongHoldType = CFG.s_StrongHoldType:Get( holyLandType )
    local guildInfo = GuildLogic:getGuild( _guildId, {
        Enum.Guild.abbreviationName, Enum.Guild.leaderRid, Enum.Guild.members, Enum.Guild.signs, Enum.Guild.name
    } )
    if holyLandInfo.status == Enum.HolyLandStatus.INIT_SCRAMBLE then
        -- 当前为初始争夺中
        occupyFlag = 1
        if HolyLandLogic:isCheckPointType( sStrongHoldType.group ) then
            finishTime = -1
        else
            finishTime = nowTime + sStrongHoldType.battleTime
        end
        -- 更新圣地信息
        HolyLandLogic:setHolyLand( _holyLandId, {
            [Enum.HolyLand.status] = Enum.HolyLandStatus.SCRAMBLE,
            [Enum.HolyLand.finishTime] = finishTime,
            [Enum.HolyLand.guildId] = _guildId,
            [Enum.HolyLand.valid] = true,
        } )

        -- 地图圣地信息
        updateHolyLandInfo = {
            holyLandStatus = Enum.HolyLandStatus.SCRAMBLE,
            holyLandFinishTime = finishTime,
            guildAbbName = guildInfo.abbreviationName,
            guildId = _guildId,
            guildFlagSigns = guildInfo.signs
        }
        occupyEmailIds = { sStrongHoldType.firstRewardMail, sStrongHoldType.emailId1 }
        MonumentLogic:setSchedule( nil, { guildId = _guildId, buildType = sStrongHoldType.group, type = Enum.MonumentType.SERVER_SANCTUARY, count = 1 })
        -- 发送首次占领跑马灯
        SM.MarqueeMgr.post.sendFirstHoldHolyLandMarquee( guildInfo.abbreviationName, _holyLandId )
    elseif holyLandInfo.status == Enum.HolyLandStatus.SCRAMBLE then
        -- 当前为常规争夺中
        finishTime = holyLandInfo.finishTime + sStrongHoldType.battleTimeAdd
        if HolyLandLogic:isCheckPointType( sStrongHoldType.group ) then
            finishTime = -1
        end
        -- 更新圣地信息
        HolyLandLogic:setHolyLand( _holyLandId, {
            [Enum.HolyLand.finishTime] = finishTime,
            [Enum.HolyLand.guildId] = _guildId,
            [Enum.HolyLand.valid] = true,
        } )
        -- 地图圣地信息
        updateHolyLandInfo = {
            holyLandFinishTime = finishTime,
            guildAbbName = guildInfo.abbreviationName,
            guildId = _guildId,
            guildFlagSigns = guildInfo.signs
        }
        occupyEmailIds = { sStrongHoldType.emailId1 }
    end

    -- 向联盟成员发送占领邮件
    local emailOtherInfo = {
        subTitleContents = { _holyLandId },
        emailContents = { _holyLandId },
        guildEmail = {
            strongHoldId = _holyLandId
        }
    }
    for _, emailId in pairs( occupyEmailIds ) do
        MSM.GuildMgr[_guildId].post.sendGuildEmail( _guildId, guildInfo.members, emailId, emailOtherInfo )
    end

    local objectIndex = holyLands[_holyLandId].objectIndex
    if updateHolyLandInfo then
        if holyLandType == Enum.HolyLandType.LOST_TEMPLE then
            -- 失落的神庙显示国王名称
            updateHolyLandInfo.kingName = RoleLogic:getRole( guildInfo.leaderRid, Enum.Role.name )
        end
        -- 更新aoi圣地信息
        MSM.SceneHolyLandMgr[objectIndex].post.updateHolyLandInfo( objectIndex, updateHolyLandInfo )
    end

    -- 增加圣地状态定时器
    if finishTime > 0 then
        holyLandTimers[_holyLandId] = Timer.runAt( finishTime, holyLandStatusTimeOut, _holyLandId )
    end

    local territoryIds = GuildTerritoryLogic:getPosTerritoryIds( holyLandInfo.pos, sStrongHoldType.territorySize )
    -- 之前占领的联盟释放地块
    local oldGuildInfo
    if holyLandInfo.guildId and holyLandInfo.guildId > 0 then
        oldGuildInfo = GuildLogic:getGuild( holyLandInfo.guildId, { Enum.Guild.members, Enum.Guild.abbreviationName, Enum.Guild.name } )
        MSM.GuildHolyLandMgr[holyLandInfo.guildId].req.deleteHolyLand( holyLandInfo.guildId, _holyLandId, territoryIds )
        -- 发送占领跑马灯
        SM.MarqueeMgr.post.sendHoldHolyLandMarquee( guildInfo.abbreviationName, oldGuildInfo.abbreviationName, _holyLandId )
        -- 发送圣地关卡被抢邮件
        if sStrongHoldType.emailId2 > 0 then
            local content = string.format("%s,%s", guildInfo.abbreviationName, guildInfo.name)
            emailOtherInfo = {
                subTitleContents = { _holyLandId, content },
                emailContents = { _holyLandId, content },
                guildEmail = {
                    strongHoldId = _holyLandId
                }
            }
            MSM.GuildMgr[holyLandInfo.guildId].post.sendGuildEmail( holyLandInfo.guildId, oldGuildInfo.members, sStrongHoldType.emailId2, emailOtherInfo )
        end
    end

    -- 新占领的联盟
    MSM.GuildHolyLandMgr[_guildId].req.occupyHolyLand( _guildId, _holyLandId, holyLandInfo.pos, true, territoryIds, objectIndex )

    -- 纪念碑事件
    if holyLandInfo.guildId and holyLandInfo.guildId > 0 then
        MonumentLogic:setSchedule( nil, { guildId = holyLandInfo.guildId, buildType = sStrongHoldType.group, type = Enum.MonumentType.SERVER_ALLICNCE_BUILD_COUNT, count = -1 })
    end
    MonumentLogic:setSchedule( nil, { guildId = _guildId, buildType = sStrongHoldType.group, type = Enum.MonumentType.SERVER_ALLICNCE_BUILD_COUNT, count = 1 })
    -- 更新sharedata
    if holyLandType == Enum.HolyLandType.CHECKPOINT_LEVEL_1 or holyLandType == Enum.HolyLandType.CHECKPOINT_LEVEL_2
        or holyLandType == Enum.HolyLandType.CHECKPOINT_LEVEL_3 then
        local levelPass = sharedata.query( Enum.Share.LevelPass )
        levelPass[_holyLandId].guildId = _guildId
        sharedata.update( Enum.Share.LevelPass, levelPass )
        sharedata.flush()
    end

    -- 奇观建筑占领日志
    local oldGuildName
    if oldGuildInfo then
        oldGuildName = string.format( "%s|%s", oldGuildInfo.abbreviationName or "", oldGuildInfo.name or "" )
    end
    LogLogic:holyLandOccupy( {
        holyLandId = _holyLandId, holyLandType = holyLandType, oldGuildId = holyLandInfo.guildId or 0, oldGuildName = oldGuildName or "0",
        occupyFlag = occupyFlag, guildId = _guildId, guildName = string.format( "%s|%s", guildInfo.abbreviationName or "", guildInfo.name or "" )
    } )

    return true
end

---@see 删除圣地所占地块
function response.deleteHolyLandTerritoryIds( _territoryIds )
    local newTerritoryIds = {}

    for _, territoryId in pairs( _territoryIds ) do
        if not holyLandTerritoryIds[territoryId] then
            table.insert( newTerritoryIds, territoryId )
        end
    end

    return newTerritoryIds
end

---@see 检查坐标或地块是否在圣地范围中
function response.checkInHolyLand( _territoryId, _pos, _guildFlag )
    _territoryId = _territoryId or GuildTerritoryLogic:getPosTerritoryId( _pos )
    local ret = holyLandTerritoryIds[_territoryId] and true or false
    if ret then
        if not _guildFlag then
            return ret
        else
            local holyLandInfo = HolyLandLogic:getHolyLand( holyLandTerritoryIds[_territoryId].holylandId )
            return ret, holyLandInfo.valid and holyLandInfo.guildId
        end
    end

    return false
end

---@see 获取所有圣地的信息
function response.getAllHolyLands()
    return holyLands
end

---@see 纪念碑事件解锁圣地状态
function accept.unlockHolyLands( _holyLandIds, _finishTime )
    local finishTime
    local nowTime = os.time()
    local mileStoneFinishTime = _finishTime or os.time()
    local sStrongHoldData = CFG.s_StrongHoldData:Get()
    local sStrongHoldType = CFG.s_StrongHoldType:Get()

    local sHoldData, sHoldType, objectIndex, holyLandStatus
    local updateHolyLandInfo
    for _, holyLandId in pairs( _holyLandIds ) do
        sHoldData = sStrongHoldData[holyLandId]
        sHoldType = sStrongHoldType[sHoldData.type]

        finishTime = mileStoneFinishTime + sHoldType.initProtectTime
        if finishTime <= nowTime then
            -- 超过初始保护时间, 进入初始争夺状态
            holyLandStatus = Enum.HolyLandStatus.INIT_SCRAMBLE
            finishTime = -1
        else
            -- 还在初始保护状态
            holyLandStatus = Enum.HolyLandStatus.INIT_PROTECT
        end

        -- 更新圣地状态
        HolyLandLogic:setHolyLand( holyLandId, {
            [Enum.HolyLand.status] = holyLandStatus,
            [Enum.HolyLand.finishTime] = finishTime,
        } )
        -- 更新aoi圣地信息
        objectIndex = holyLands[holyLandId].objectIndex
        updateHolyLandInfo = {
            holyLandStatus = holyLandStatus,
            holyLandFinishTime = finishTime
        }
        MSM.SceneHolyLandMgr[objectIndex].post.updateHolyLandInfo( objectIndex, updateHolyLandInfo )

        -- 增加定时器
        if finishTime > nowTime then
            holyLandTimers[holyLandId] = Timer.runAt( finishTime, holyLandStatusTimeOut, holyLandId )
        end
    end
end

---@see PMLogic重置圣地关卡属性到初始争夺中
function response.resetHolyLand( _holyLandId )
    local holyLandInfo = HolyLandLogic:getHolyLand( _holyLandId )
    if not holyLandInfo or table.empty( holyLandInfo ) then
        return
    end

    local objectIndex = holyLands[_holyLandId].objectIndex
    -- 重置圣地关卡属性
    MSM.SceneHolyLandMgr[objectIndex].req.resetHolyLand( objectIndex )

    if holyLandInfo.guildId > 0 then
        -- 联盟删除圣地
        local holyLandType = CFG.s_StrongHoldData:Get( _holyLandId, "type" )
        local sStrongHoldType = CFG.s_StrongHoldType:Get( holyLandType )
        local territoryIds = GuildTerritoryLogic:getPosTerritoryIds( holyLandInfo.pos, sStrongHoldType.territorySize )
        MSM.GuildHolyLandMgr[holyLandInfo.guildId].req.deleteHolyLand( holyLandInfo.guildId, _holyLandId, territoryIds )
    end

    -- 删除定时器
    if holyLandTimers[_holyLandId] then
        Timer.delete( holyLandTimers[_holyLandId] )
    end

    HolyLandLogic:setHolyLand( _holyLandId, {
        [Enum.HolyLand.status] = Enum.HolyLandStatus.INIT_SCRAMBLE,
        [Enum.HolyLand.finishTime] = -1,
        [Enum.HolyLand.guildId] = 0,
    } )
    local updateHolyLandInfo = {
        holyLandStatus = Enum.HolyLandStatus.INIT_SCRAMBLE,
        holyLandFinishTime = -1,
        guildId = 0,
        guildAbbName = "",
        kingName = "",
    }
    MSM.SceneHolyLandMgr[objectIndex].post.updateHolyLandInfo( objectIndex, updateHolyLandInfo )
end