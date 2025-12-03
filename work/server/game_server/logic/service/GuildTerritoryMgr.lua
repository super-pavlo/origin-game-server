--[[
* @file : GuildTerritoryMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Thu Jul 02 2020 17:07:32 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟领土管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local GuildLogic = require "GuildLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local GuildTerritoryLogic = require "GuildTerritoryLogic"
local ResourceLogic = require "ResourceLogic"
local snax = require "skynet.snax"

---@see 联盟领土信息
---@class defaultGuildTerritoryInfoClass
local defaultGuildTerritoryInfo = {
    ---@see 联盟ID
    guildId                     =                   0,
    ---@see 领土颜色
    colorId                     =                   0,
    ---@see 有效领地
    validTerritoryIds           =                   {},
    ---@see 无效领地
    invalidTerritoryIds         =                   {},
    ---@see 预占领的领地ID
    preOccupyTerritoryIds       =                   {},
}

---@see 联盟领土线信息
---@class defaultGuildTerritoryLineInfoClass
local defaultGuildTerritoryLineInfo = {
    ---@see 联盟ID
    guildId                     =                   0,
    ---@see 领土颜色
    colorId                     =                   0,
    ---@see 有效领地线
    validLines                  =                   {},
    ---@see 无效领地线
    invalidLines                =                   {},
}

---@see 联盟地块占用信息
---@type table<int, defaultGuildTerritoryInfoClass>
local guildTerritories = {}

---@see 联盟地块buffId
---@type table<int, table<int, int>>
local guildTerritoryBuffIds = {}

---@see 联盟领土线信息
---@type tabke<int, defaultGuildTerritoryLineInfoClass>
local guildTerritoryLines = {}

---@see 获取联盟领土信息
function response.getGuildTerritories( _guildId )
    if not _guildId then
        return guildTerritories
    else
        return guildTerritories[_guildId]
    end
end

---@see 检查联盟无效地块是否变为有效地块
local function checkGuildInvalidTerritory( _guildId, _fromPos )
    local checkFlag = not table.empty( _fromPos or {} )
    local newInvalidTerritoryIds = {}
    local changeInvalidTerritoryIds = {}
    local guildTerritory = guildTerritories[_guildId]
    if guildTerritory then
        for territoryId in pairs( guildTerritory.invalidTerritoryIds ) do
            -- 当前有要塞且地块可到达要塞
            if checkFlag and MSM.AStarMgr[_guildId].req.findPath( _guildId, _fromPos, GuildTerritoryLogic:territoryIdToSearchMapPos( territoryId ) ) then
                guildTerritory.validTerritoryIds[territoryId] = territoryId
                table.insert( changeInvalidTerritoryIds, territoryId )
            else
                newInvalidTerritoryIds[territoryId] = territoryId
            end
        end

        guildTerritory.invalidTerritoryIds = newInvalidTerritoryIds
    end

    return changeInvalidTerritoryIds
end

---@see 联盟增加地块
function response.addGuildTerritory( _guildId, _territoryIds, _preOccupyTerritoryIds, _noSync )
    if not guildTerritories[_guildId] then
        ---@type defaultGuildTerritoryInfoClass
        local territoryInfo = const( table.copy( defaultGuildTerritoryInfo, true ) )
        territoryInfo.guildId = _guildId
        territoryInfo.colorId = GuildLogic:getTerritoryColor( _guildId )

        guildTerritories[_guildId] = territoryInfo
    end

    local validTerritoryIds
    local invalidTerritoryIds
    local delGuildTerritoryids = {
        guildId = _guildId,
        colorId = guildTerritories[_guildId].colorId,
        validTerritoryIds = {},
        invalidTerritoryIds = {},
        preOccupyTerritoryIds = {},
    }
    if _territoryIds and #_territoryIds > 0 then
        local delPreOccupyTerritoryIds = {}
        validTerritoryIds = {}
        invalidTerritoryIds = {}
        -- 判断每个地块的有效失效状态
        local fromPos = GuildBuildLogic:getGuildSearchMapPos( _guildId )
        for _, territoryId in pairs( _territoryIds ) do
            if not table.empty( fromPos ) and MSM.AStarMgr[_guildId].req.findPath( _guildId, fromPos, GuildTerritoryLogic:territoryIdToSearchMapPos( territoryId ) ) then
                guildTerritories[_guildId].validTerritoryIds[territoryId] = territoryId
                table.insert( validTerritoryIds, territoryId )
            else
                guildTerritories[_guildId].invalidTerritoryIds[territoryId] = territoryId
                table.insert( invalidTerritoryIds, territoryId )
            end

            if guildTerritories[_guildId].preOccupyTerritoryIds[territoryId] then
                guildTerritories[_guildId].preOccupyTerritoryIds[territoryId] = nil
                table.insert( delPreOccupyTerritoryIds, territoryId )
            end
        end

        if #validTerritoryIds > 0 then
            -- 无效变有效的地块
            local changeTerritoryIds = checkGuildInvalidTerritory( _guildId, fromPos )
            table.merge( validTerritoryIds, changeTerritoryIds )
            table.merge( delGuildTerritoryids.invalidTerritoryIds, changeTerritoryIds )
            -- 有效地块资源点属性修改
            SM.ResourcePointMgr.req.addGuildTerritoryResourcePoint( _guildId, validTerritoryIds )
            -- 刷新有效地块中的野外资源田联盟简称
            ResourceLogic:resourceGuildAbbNameChange( validTerritoryIds, GuildLogic:getGuild( _guildId, Enum.Guild.abbreviationName ) )
            -- 联盟地块中的资源田采集速度变化
            ResourceLogic:resourceTerritoryStatusChange( validTerritoryIds )
            -- 更新资源中心中部队采集速度
            GuildBuildLogic:updateResourceCenterArmyCollectSpeed( _guildId, validTerritoryIds )
        end

        if #delPreOccupyTerritoryIds > 0 then
            delGuildTerritoryids.preOccupyTerritoryIds = delPreOccupyTerritoryIds
        end
    end
    -- 预占领地块
    local preOccupyTerritoryIds = {}
    for _, territoryId in pairs( _preOccupyTerritoryIds or {} ) do
        if guildTerritories[_guildId].validTerritoryIds[territoryId] then
            -- 删除有效地块
            guildTerritories[_guildId].validTerritoryIds[territoryId] = nil
            table.insert( delGuildTerritoryids.validTerritoryIds, territoryId )
        elseif guildTerritories[_guildId].invalidTerritoryIds[territoryId] then
            -- 删除无效地块
            guildTerritories[_guildId].invalidTerritoryIds[territoryId] = nil
            table.insert( delGuildTerritoryids.invalidTerritoryIds, territoryId )
        end
        -- 增加预占领地块
        if not guildTerritories[_guildId].preOccupyTerritoryIds[territoryId] then
            guildTerritories[_guildId].preOccupyTerritoryIds[territoryId] = territoryId
            table.insert( preOccupyTerritoryIds, territoryId )
        end
    end

    -- 通知本服领土变化信息
    local addGuildTerritories = {
        {
            guildId = _guildId,
            colorId = guildTerritories[_guildId].colorId,
            validTerritoryIds = not table.empty( validTerritoryIds ) and validTerritoryIds or nil,
            invalidTerritoryIds = not table.empty( invalidTerritoryIds ) and invalidTerritoryIds or nil,
            preOccupyTerritoryIds = not table.empty( preOccupyTerritoryIds ) and preOccupyTerritoryIds or nil,
        }
    }
    local delGuildTerritories
    if #delGuildTerritoryids.validTerritoryIds > 0 or #delGuildTerritoryids.invalidTerritoryIds > 0
        or #delGuildTerritoryids.preOccupyTerritoryIds > 0 then
        delGuildTerritories = { delGuildTerritoryids }
    end

    if not _noSync then
        GuildTerritoryLogic:syncGuildTerritories( nil, nil, addGuildTerritories, delGuildTerritories )
    end

    -- 刷新联盟领地线条
    snax.self().post.refreshGuildTerritoryLine( _guildId )

    return addGuildTerritories, delGuildTerritories
end

---@see 地块状态变化
function accept.guildTerritoryStatusChange( _guildId, _territoryIds )
    if guildTerritories[_guildId] then
        local validTerritoryIds = {}
        local invalidTerritoryIds = {}
        local allTerritoryIds = {}
        local fromPos = GuildBuildLogic:getGuildSearchMapPos( _guildId )
        local checkFlag = not table.empty( fromPos )
        for _, territoryId in pairs( _territoryIds ) do
            if checkFlag and MSM.AStarMgr[_guildId].req.findPath( _guildId, fromPos, GuildTerritoryLogic:territoryIdToSearchMapPos( territoryId ) ) then
                -- 当前为有效状态
                if guildTerritories[_guildId].invalidTerritoryIds[territoryId] then
                    guildTerritories[_guildId].invalidTerritoryIds[territoryId] = nil
                    guildTerritories[_guildId].validTerritoryIds[territoryId] = territoryId
                    table.insert( validTerritoryIds, territoryId )
                    table.insert( allTerritoryIds, territoryId )
                end
            else
                -- 当前为失效状态
                if guildTerritories[_guildId].validTerritoryIds[territoryId] then
                    guildTerritories[_guildId].validTerritoryIds[territoryId] = nil
                    guildTerritories[_guildId].invalidTerritoryIds[territoryId] = territoryId
                    table.insert( invalidTerritoryIds, territoryId )
                    table.insert( allTerritoryIds, territoryId )
                end
            end
        end

        if #validTerritoryIds > 0 then
            -- 有效地块资源点属性修改
            SM.ResourcePointMgr.req.addGuildTerritoryResourcePoint( _guildId, validTerritoryIds )
            -- 刷新有效地块中的野外资源田联盟简称
            ResourceLogic:resourceGuildAbbNameChange( validTerritoryIds, GuildLogic:getGuild( _guildId, Enum.Guild.abbreviationName ) )
        end

        if #invalidTerritoryIds > 0 then
            -- 失效地块资源点属性修改
            SM.ResourcePointMgr.req.delGuildTerritoryResourcePoint( _guildId, _territoryIds )
            -- 刷新有效地块中的野外资源田联盟简称
            ResourceLogic:resourceGuildAbbNameChange( invalidTerritoryIds, "" )
        end

        if #allTerritoryIds > 0 then
            -- 联盟地块中的资源田采集速度变化
            ResourceLogic:resourceTerritoryStatusChange( allTerritoryIds )
            -- 更新资源中心中部队采集速度
            GuildBuildLogic:updateResourceCenterArmyCollectSpeed( _guildId, allTerritoryIds )
        end

        -- 通知本服领土变化信息
        if #validTerritoryIds > 0 or #invalidTerritoryIds > 0 then
            GuildTerritoryLogic:syncGuildTerritories( nil, nil,
                {
                    { guildId = _guildId, validTerritoryIds = validTerritoryIds, invalidTerritoryIds = invalidTerritoryIds }
                },
                {
                    { guildId = _guildId, validTerritoryIds = invalidTerritoryIds, invalidTerritoryIds = validTerritoryIds }
                }
            )
        end

        -- 刷新联盟领地线条
        snax.self().post.refreshGuildTerritoryLine( _guildId )
    end
end

---@see 删除联盟地块占用
function response.deleteGuildTerritory( _guildId, _territoryIds, _lock, _disbandGuild, _noSync )
    if guildTerritories[_guildId] then
        local delValidTerritoryIds = {}
        local delInvalidTerritoryIds = {}
        local delPreOccupyTerritoryIds = {}
        for _, territoryId in pairs( _territoryIds ) do
            if guildTerritories[_guildId].validTerritoryIds[territoryId] then
                -- 删除有效地块
                guildTerritories[_guildId].validTerritoryIds[territoryId] = nil
                table.insert( delValidTerritoryIds, territoryId )
            elseif guildTerritories[_guildId].invalidTerritoryIds[territoryId] then
                -- 删除无效地块
                guildTerritories[_guildId].invalidTerritoryIds[territoryId] = nil
                table.insert( delInvalidTerritoryIds, territoryId )
            elseif guildTerritories[_guildId].preOccupyTerritoryIds[territoryId] then
                -- 删除预占领地块
                guildTerritories[_guildId].preOccupyTerritoryIds[territoryId] = nil
                table.insert( delPreOccupyTerritoryIds, territoryId )
            end
        end
        -- 失效地块资源点属性修改
        SM.ResourcePointMgr.req.delGuildTerritoryResourcePoint( _guildId, _territoryIds, _lock, _disbandGuild )
        -- 刷新失效地块中的野外资源田联盟简称
        ResourceLogic:resourceGuildAbbNameChange( _territoryIds, "" )

        -- 联盟地块中的资源田采集速度变化
        ResourceLogic:resourceTerritoryStatusChange( delValidTerritoryIds )
        -- 更新资源中心中部队采集速度
        GuildBuildLogic:updateResourceCenterArmyCollectSpeed( _guildId, delValidTerritoryIds )
        -- 通知本服领土变化信息
        local delGuildTerritories
        if #delValidTerritoryIds > 0 or #delInvalidTerritoryIds > 0 or #delPreOccupyTerritoryIds > 0 then
            delGuildTerritories = { {
                guildId = _guildId,
                validTerritoryIds = not table.empty( delValidTerritoryIds ) and delValidTerritoryIds or nil,
                invalidTerritoryIds = not table.empty( delInvalidTerritoryIds ) and delInvalidTerritoryIds or nil,
                preOccupyTerritoryIds = not table.empty( delPreOccupyTerritoryIds ) and delPreOccupyTerritoryIds or nil,
            } }

            if not _noSync then
                GuildTerritoryLogic:syncGuildTerritories( nil, nil, nil, delGuildTerritories )
            end
        end

        if not _disbandGuild then
            -- 刷新联盟领地线条
            snax.self().post.refreshGuildTerritoryLine( _guildId )
        end

        return delGuildTerritories
    end
end

---@see 修改领土颜色
function accept.modifyGuildTerritoryColor( _guildId, _colorId )
    if guildTerritories[_guildId] then
        guildTerritories[_guildId].colorId = _colorId
    end
    if guildTerritoryLines[_guildId] then
        guildTerritoryLines[_guildId].colorId = _colorId
    end
    -- 通知本服领土变化信息
    GuildTerritoryLogic:syncGuildTerritories( nil, { [_guildId] = { guildId = _guildId, colorId = _colorId } } )
end

---@see 检查是否与联盟领土接壤
function response.checkGuildValidTerritory( _guildId, _territoryIds, _centerTerritoryId )
    if guildTerritories[_guildId] then
        local noTerritoryIds = {}
        for _, territoryId in pairs( _territoryIds or {} ) do
            if not guildTerritories[_guildId].validTerritoryIds[territoryId]
                and not guildTerritories[_guildId].invalidTerritoryIds[territoryId] then
                table.insert( noTerritoryIds, territoryId )
            end
        end

        if #noTerritoryIds > 0 then
            -- 设置为可行走点
            MSM.AStarMgr[_guildId].req.setWalkable( _guildId, noTerritoryIds )
        end

        local fromPos = GuildBuildLogic:getGuildSearchMapPos( _guildId )
        local toPos = GuildTerritoryLogic:territoryIdToSearchMapPos( _centerTerritoryId )
        local flag = MSM.AStarMgr[_guildId].req.findPath( _guildId, fromPos, toPos )

        if #noTerritoryIds > 0 then
            -- 设置为不可行走点
            MSM.AStarMgr[_guildId].req.setUnwalkable( _guildId, noTerritoryIds )
        end

        return flag
    end
end

---@see 检查指定坐标是否在联盟领土中
function response.checkGuildTerritoryPos( _guildId, _pos )
    if guildTerritories[_guildId] then
        local territoryId = GuildTerritoryLogic:getPosTerritoryId( _pos )
        if guildTerritories[_guildId].validTerritoryIds[territoryId] then
            return true, guildTerritoryBuffIds[_guildId] or {}
        end
    end

    return false, guildTerritoryBuffIds[_guildId] or {}
end

---@see 更新联盟领土地块buffId
function accept.updateGuildTerritoryBuff( _guildId, _addBuffIds, _delBuffIds )
    if not guildTerritoryBuffIds[_guildId] then
        guildTerritoryBuffIds[_guildId] = {}
    end

    for _, buffId in pairs( _delBuffIds or {} ) do
        table.removevalue( guildTerritoryBuffIds[_guildId], buffId )
    end

    for _, buffId in pairs( _addBuffIds or {} ) do
        table.insert( guildTerritoryBuffIds[_guildId], buffId )
    end
    -- 更新联盟成员部队buff
    GuildTerritoryLogic:updateArmyTerritoryBuff( _guildId )
end

---@see 联盟解散清除联盟领土信息和领土buffId信息
function accept.cleanGuildTerritory( _guildId )
    guildTerritories[_guildId] = nil
    guildTerritoryBuffIds[_guildId] = nil
    guildTerritoryLines[_guildId] = nil
end

---@see 联盟领土变化线条刷新
function accept.refreshGuildTerritoryLine( _guildId )
    if guildTerritories[_guildId] then
        local validLines = GuildTerritoryLogic:refreshTerritoryLines( guildTerritories[_guildId].validTerritoryIds )
        local invalidLines = GuildTerritoryLogic:refreshTerritoryLines( guildTerritories[_guildId].invalidTerritoryIds )
        if not guildTerritoryLines[_guildId] then
            ---@type defaultGuildTerritoryLineInfoClass
            local territoryLineInfo = const( table.copy( defaultGuildTerritoryLineInfo, true ) )
            territoryLineInfo.guildId = _guildId
            territoryLineInfo.colorId = GuildLogic:getTerritoryColor( _guildId )
            territoryLineInfo.validLines = validLines
            territoryLineInfo.invalidLines = invalidLines

            guildTerritoryLines[_guildId] = territoryLineInfo
        else
            guildTerritoryLines[_guildId].validLines = validLines
            guildTerritoryLines[_guildId].invalidLines = invalidLines
        end
    end
end

---@see 获取联盟领土线条信息
function response.getGuildTerritoryLines( _guildId )
    if _guildId then
        return guildTerritoryLines[_guildId]
    else
        return guildTerritoryLines
    end
end