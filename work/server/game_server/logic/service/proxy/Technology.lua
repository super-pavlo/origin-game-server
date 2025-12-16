--[[
* @file : Technology.lua
* @type : snax multi service
* @author : chenlei
* @created : Fri Jan 03 2020 15:39:25 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 科技相关协议代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local BuildingLogic = require "BuildingLogic"
local TechnologyLogic = require "TechnologyLogic"

---@see 科技研究
function response.ResearchTechnology( msg )
    local rid = msg.rid
    local technologyType = msg.technologyType
    local immediately = msg.immediately
    -- 判断学院是否在升级
    local buildQueue = RoleLogic:getRole( rid, Enum.Role.buildQueue )
    local buildingInfo = BuildingLogic:getBuildingInfoByType( rid, Enum.BuildingType.COLLAGE )
    if table.empty( buildingInfo ) then
        LOG_ERROR("rid(%d) ResearchTechnology fail, this buildingType(%d) not build", rid, Enum.BuildingType.COLLAGE)
        return nil, ErrorCode.TECHNOLOGY_COLLAGE_NOT_BUILD
    end
    local collageInfo = buildingInfo[1]
    for _, queue in pairs( buildQueue ) do
        if queue.buildingIndex == collageInfo.buildingIndex and queue.finishTime > 0 then
            LOG_ERROR("rid(%d) ResearchTechnology fail, this building(%d) updating", rid, collageInfo.buildingIndex)
            return nil, ErrorCode.TECHNOLOGY_COLLAGE_UPDATE
        end
    end
    -- 判断是否正在研究
    local technologyQueue = RoleLogic:getRole( rid, Enum.Role.technologyQueue ) or {}
    if not immediately and technologyQueue and technologyQueue.technologyType and technologyQueue.technologyType > 0 then
        LOG_ERROR("rid(%d) ResearchTechnology fail, technology is researching", rid)
        return nil, ErrorCode.TECHNOLOGY_RESEARCHING
    end
    local studyConfig = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.STUDY ) or {}
    local technologies = RoleLogic:getRole( rid, Enum.Role.technologies ) or {}
    local level = 0
    if not table.empty(technologies) and technologies[technologyType] and technologies[technologyType].level  then
        level = technologies[technologyType].level
    end
    local config = studyConfig[technologyType][level + 1]
    if not config then
        LOG_ERROR("rid(%d) ResearchTechnology fail, not find this level(%d) technology(%d) ", rid, level + 1, technologyType)
        return nil, ErrorCode.TECHNOLOGY_CONFIG_NOT_FIND
    end
    local technologyId = config.id
    -- 判断前置是否满足
    config = CFG.s_Study:Get(technologyId)
    for i=1,4 do
        if config["preconditionStudy"..i] > 0 then
            if not technologies[config["preconditionStudy"..i]] or technologies[config["preconditionStudy"..i]].level < config["preconditionLv"..i] then
                LOG_ERROR("rid(%d) ResearchTechnology fail, preTechnology(%d) is lock ", rid, technologyType)
                return nil, ErrorCode.TECHNOLOGY_PRE_LOCK
            end
        end
    end
    -- 判断学院等级是否满足
    if collageInfo.level < config.campusLv then
        LOG_ERROR("rid(%d) ResearchTechnology fail, campusLv not enough", rid)
        return nil, ErrorCode.TECHNOLOGY_CAMPUS_LV_NOT_ENOUGH
    end
    if immediately then
        local args = {}
        args.rid = rid
        args.technologyType = technologyType
        if technologyQueue.technologyType == technologyType then
            LOG_ERROR("rid(%d) ResearchTechnology immediately fail, preTechnology(%d) is update ", rid, technologyType)
            return nil, ErrorCode.TECHNOLOGY_IMMEDIATELY_ERROR
        end
        return MSM.RoleQueueMgr[rid].req.immediatelyComplete( args )
    end
    -- 判断资源是否充足
    if config.needFood then
        if not RoleLogic:checkFood( rid, config.needFood ) then
            LOG_ERROR("rid(%d) ResearchTechnology error, food not enough", rid)
            return nil, ErrorCode.ROLE_FOOD_NOT_ENOUGH
        end
    end
    if config.needWood then
        if not RoleLogic:checkWood( rid, config.needWood ) then
            LOG_ERROR("rid(%d) ResearchTechnology error, wood not enough", rid)
            return nil, ErrorCode.ROLE_WOOD_NOT_ENOUGH
        end
    end
    if config.needStone then
        if not RoleLogic:checkStone( rid, config.needStone ) then
            LOG_ERROR("rid(%d) ResearchTechnology error, stone not enough", rid)
            return nil, ErrorCode.ROLE_STONE_NOT_ENOUGH
        end
    end
    if config.needGold then
        if not RoleLogic:checkGold( rid, config.needGold ) then
            LOG_ERROR("rid(%d) ResearchTechnology error, coin not enough", rid)
            return nil, ErrorCode.ROLE_GOLD_NOT_ENOUGH
        end
    end
    return TechnologyLogic:researchTechnology( rid, technologyType )
end

---@see 领取科技
function response.AwardTechnology( msg )
    local rid = msg.rid
    -- 判断科技是否研究完成
    local technologyQueue = RoleLogic:getRole( rid, Enum.Role.technologyQueue ) or {}
    if technologyQueue.finishTime > 0 or not technologyQueue.technologyType or technologyQueue.technologyType <= 0 then
        LOG_ERROR("rid(%d) AwardTechnology error, not award technology", rid)
        return nil, ErrorCode.TECHNOLOGY_NOT_AWARD
    end
    return TechnologyLogic:awardTechnology( rid )
end

---@see 终止科技研究
function response.StopTechnology( msg )
    local rid = msg.rid
    -- 判断科技是否研究完成
    local technologyQueue = RoleLogic:getRole( rid, Enum.Role.technologyQueue ) or {}
    if technologyQueue.finishTime <= 0 then
        LOG_ERROR("rid(%d) StopTechnology error, not research technology", rid)
        return nil, ErrorCode.TECHNOLOGY_NOT_RESEARCH
    end
    return TechnologyLogic:stopTechnology( rid )
end