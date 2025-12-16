--[[
* @file : GuildAttrMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Mon May 18 2020 19:13:55 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟属性服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local AttrDef = require "AttrDef"
local GuildLogic = require "GuildLogic"

---@see 联盟属性信息
local guildAttrs = {}
---@see 生效的联盟圣地类型
local guildHolyLandTypes = {}

---@see 服务器重启初始化联盟属性
function response.Init()
    local centerNode = Common.getCenterNode()
    local guilds = Common.rpcCall( centerNode, "GuildProxy", "getGuildInfos", Common.getSelfNodeName() ) or {}
    for guildId, guildInfo in pairs( guilds ) do
        -- 联盟有研究科技
        if guildInfo.researchTechnologyType and guildInfo.researchTechnologyType > 0 then
            MSM.GuildTimerMgr[guildId].req.addTechnologyResearchTimer( guildId )
        end
        -- 添加联盟属性
        MSM.GuildAttrMgr[guildId].req.addGuild( guildId )
        -- 刷新旗帜上限
        GuildLogic:updateGuildFlagLimit( guildId )
        -- 检查联盟求助信息
        GuildLogic:checkGuildRequestOnReboot( guildId )
    end
end

---@see 添加联盟
function response.addGuild( _guildId )
    local sAllianceStudy = CFG.s_AllianceStudy:Get()
    local technologies = GuildLogic:getGuild( _guildId, Enum.Guild.technologies ) or {}
    local defaultAttr = AttrDef:getDefaultAttr()
    -- 计算科技属性
    local allianceStudy, technologyId
    local buffIds = {}
    for type, technology in pairs( technologies ) do
        technologyId = type * 100 + technology.level
        allianceStudy = sAllianceStudy[technologyId]
        if allianceStudy then
            if allianceStudy.attrType == Enum.GuildTechnologyAttrType.TERRITORY then
                if allianceStudy.BuffID > 0 then
                    table.insert( buffIds, allianceStudy.BuffID )
                end
            else
                for index, buffName in pairs( allianceStudy.buffType or {} ) do
                    if not defaultAttr[buffName] then
                        LOG_ERROR("addGuild not found buffName(%s)", buffName)
                        defaultAttr[buffName] = 0
                    end
                    defaultAttr[buffName] = defaultAttr[buffName] + allianceStudy.buffData[index]
                end
            end
        end
    end

    -- 计算圣地属性
    local sCityBuff = CFG.s_CityBuff:Get()
    local sStrongHoldData = CFG.s_StrongHoldData:Get()
    local sStrongHoldType = CFG.s_StrongHoldType:Get()

    local holyLandTypes = {}
    local strongHoldData, strongHoldType, cityBuff, buffData
    -- 获取联盟圣地
    local holyLands = MSM.GuildHolyLandMgr[_guildId].req.getGuildHolyLand( _guildId ) or {}
    for holyLandId in pairs( holyLands ) do
        strongHoldData = sStrongHoldData[holyLandId]
        if not holyLandTypes[strongHoldData.type] then
            strongHoldType = sStrongHoldType[strongHoldData.type]
            buffData = { strongHoldType.buffData1, strongHoldType.buffData2, strongHoldType.buffData3 }
            for _, buffId in pairs( buffData ) do
                if buffId > 0 then
                    cityBuff = sCityBuff[buffId] or {}
                    for index, attrName in pairs( cityBuff.attr or {} ) do
                        defaultAttr[attrName] = defaultAttr[attrName] + cityBuff.attrData[index]
                    end
                end
            end

            holyLandTypes[strongHoldData.type] = {}
        end
        holyLandTypes[strongHoldData.type][holyLandId] = holyLandId
    end

    guildAttrs[_guildId] = defaultAttr
    guildHolyLandTypes[_guildId] = holyLandTypes

    if #buffIds > 0 then
        MSM.GuildTerritoryMgr[_guildId].post.updateGuildTerritoryBuff( _guildId, buffIds )
    end
end

---@see 删除联盟
function accept.delGuild( _guildId )
    -- 移除联盟属性
    guildAttrs[_guildId] = nil
    guildHolyLandTypes[_guildId] = nil
end

---@see 获取联盟属性
function response.getGuildAttr( _guildId, _attrNames )
    local attrValue
    if guildAttrs[_guildId] then
        if not _attrNames then
            attrValue = guildAttrs[_guildId]
        elseif Common.isTable( _attrNames ) then
            attrValue = {}
            for _, attrName in pairs( _attrNames ) do
                attrValue[attrName] = guildAttrs[_guildId][attrName]
            end
        else
            attrValue = guildAttrs[_guildId][_attrNames]
        end
    end

    return attrValue
end

---@see 研究完成
function response.researchTechnologyFinish( _guildId, _technologyType )
    local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.technologies } )
    local sAllianceStudy = CFG.s_AllianceStudy:Get()
    local technologies = guildInfo.technologies or {}
    -- 计算科技属性
    local allianceStudy, delBuffIds, addBuffIds
    local technologyId = _technologyType * 100 + technologies[_technologyType].level
    local oldGuildAttr = {}
    local newGuildAttr = {}
    local changeAttrNames = {}
    -- 科技升级前的属性
    allianceStudy = sAllianceStudy[technologyId - 1]
    if allianceStudy then
        for index, buffName in pairs( allianceStudy.buffType or {} ) do
            if guildAttrs[_guildId] and guildAttrs[_guildId][buffName] then
                guildAttrs[_guildId][buffName] = guildAttrs[_guildId][buffName] - allianceStudy.buffData[index]
                oldGuildAttr[buffName] = allianceStudy.buffData[index]
                changeAttrNames[buffName] = true
            end
        end
        if allianceStudy.attrType == Enum.GuildTechnologyAttrType.TERRITORY then
            delBuffIds = { allianceStudy.BuffID }
        end
    end
    -- 科技升级后的属性
    allianceStudy = sAllianceStudy[technologyId]
    if allianceStudy then
        for index, buffName in pairs( allianceStudy.buffType or {} ) do
            if guildAttrs[_guildId] and guildAttrs[_guildId][buffName] then
                guildAttrs[_guildId][buffName] = guildAttrs[_guildId][buffName] + allianceStudy.buffData[index]
                newGuildAttr[buffName] = allianceStudy.buffData[index]
                changeAttrNames[buffName] = true
            end
        end
        if allianceStudy.attrType == Enum.GuildTechnologyAttrType.TERRITORY then
            addBuffIds = { allianceStudy.BuffID }
        end
    end

    -- 更新角色属性
    for memberRid in pairs( guildInfo.members ) do
        GuildLogic:updateRoleAttrChange( memberRid, oldGuildAttr, newGuildAttr )
    end
    -- 联盟属性变化回调
    GuildLogic:guildAttrChangeCallBack( _guildId, changeAttrNames )

    if delBuffIds or addBuffIds then
        MSM.GuildTerritoryMgr[_guildId].post.updateGuildTerritoryBuff( _guildId, addBuffIds, delBuffIds )
    end
end

---@see 失去圣地联盟属性变化
function accept.loseHolyLand( _guildId, _holyLandId )
    if not guildAttrs[_guildId] then return end
    -- 是否存在此圣地
    local sStrongHoldData = CFG.s_StrongHoldData:Get( _holyLandId )
    if guildHolyLandTypes[_guildId] and guildHolyLandTypes[_guildId][sStrongHoldData.type]
        and guildHolyLandTypes[_guildId][sStrongHoldData.type][_holyLandId] then
        guildHolyLandTypes[_guildId][sStrongHoldData.type][_holyLandId] = nil
    else
        return
    end
    -- 还有其他该类型的圣地生效中
    if table.size( guildHolyLandTypes[_guildId][sStrongHoldData.type] ) > 0 then
        return
    else
        guildHolyLandTypes[_guildId][sStrongHoldData.type] = nil
    end

    local oldGuildAttr = {}
    -- 计算圣地属性
    local cityBuff
    local sCityBuff = CFG.s_CityBuff:Get()
    local sStrongHoldType = CFG.s_StrongHoldType:Get( sStrongHoldData.type )
    local buffData = { sStrongHoldType.buffData1, sStrongHoldType.buffData2, sStrongHoldType.buffData3 }
    local changeAttrNames = {}
    for _, buffId in pairs( buffData ) do
        if buffId > 0 then
            cityBuff = sCityBuff[buffId] or {}
            for index, attrName in pairs( cityBuff.attr or {} ) do
                guildAttrs[_guildId][attrName] = ( guildAttrs[_guildId][attrName] or 0 ) - ( cityBuff.attrData[index] or 0 )
                oldGuildAttr[attrName] = cityBuff.attrData[index]
                changeAttrNames[attrName] = true
            end
        end
    end

    local members = GuildLogic:getGuild( _guildId, Enum.Guild.members ) or {}
    -- 更新角色属性
    for memberRid in pairs( members ) do
        GuildLogic:updateRoleAttrChange( memberRid, oldGuildAttr )
    end
    -- 联盟属性变化回调
    GuildLogic:guildAttrChangeCallBack( _guildId, changeAttrNames )
end

---@see 占有圣地联盟属性变化
function accept.addHolyLand( _guildId, _holyLandId )
    -- 是否存在此圣地
    local sStrongHoldData = CFG.s_StrongHoldData:Get( _holyLandId )
    if not guildHolyLandTypes[_guildId] then guildHolyLandTypes[_guildId] = {} end
    if guildHolyLandTypes[_guildId][sStrongHoldData.type] then
        guildHolyLandTypes[_guildId][sStrongHoldData.type][_holyLandId] = _holyLandId
        return
    else
        guildHolyLandTypes[_guildId][sStrongHoldData.type] = {}
        guildHolyLandTypes[_guildId][sStrongHoldData.type][_holyLandId] = _holyLandId
    end

    local newGuildAttr = {}
    -- 计算圣地属性
    local cityBuff
    local changeAttrNames = {}
    local sCityBuff = CFG.s_CityBuff:Get()
    local sStrongHoldType = CFG.s_StrongHoldType:Get( sStrongHoldData.type )
    local buffData = { sStrongHoldType.buffData1, sStrongHoldType.buffData2, sStrongHoldType.buffData3 }
    for _, buffId in pairs( buffData ) do
        if buffId > 0 then
            cityBuff = sCityBuff[buffId] or {}
            for index, attrName in pairs( cityBuff.attr or {} ) do
                guildAttrs[_guildId][attrName] = guildAttrs[_guildId][attrName] + cityBuff.attrData[index]
                newGuildAttr[attrName] = cityBuff.attrData[index]
                changeAttrNames[attrName] = true
            end
        end
    end

    local members = GuildLogic:getGuild( _guildId, Enum.Guild.members ) or {}
    -- 更新角色属性
    for memberRid in pairs( members ) do
        GuildLogic:updateRoleAttrChange( memberRid, nil, newGuildAttr )
    end
    -- 联盟属性变化回调
    GuildLogic:guildAttrChangeCallBack( _guildId, changeAttrNames )
end