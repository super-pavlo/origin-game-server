--[[
* @file : CityHideLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Wed Jul 22 2020 18:44:55 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 城市隐藏相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local MapLogic = require "MapLogic"
local RoleLogic = require "RoleLogic"
local ArmyLogic = require "ArmyLogic"
local GuildLogic = require "GuildLogic"
local ScoutsLogic = require "ScoutsLogic"
local BattleCreate = require "BattleCreate"
local DenseFogLogic = require "DenseFogLogic"
local TransportLogic = require "TransportLogic"
local MapProvinceLogic = require "MapProvinceLogic"

local CityHideLogic = {}

---@see 隐藏城市处理
function CityHideLogic:hideCity( _rid, _isReboot, _checkTime )
    local hideCityExitAlliance = CFG.s_Config:Get( "hideCityExitAlliance" ) or 9
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.cityId, Enum.Role.guildId, Enum.Role.level } )
    if roleInfo.guildId > 0 then
        -- 盟主不回收城市
        if ( GuildLogic:getRoleGuildJob( roleInfo.guildId, _rid ) or 0 ) == Enum.GuildJob.LEADER then
            return
        end

        -- 角色等级小于指定等级，退出联盟
        if roleInfo.level <= hideCityExitAlliance then
            MSM.GuildMgr[roleInfo.guildId].req.exitGuild( roleInfo.guildId, _rid, Enum.GuildExitType.EXIT )
        end

        roleInfo.guildId = 0
    end

    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    -- 城市退出战斗
    local cityStatus = MSM.SceneCityMgr[cityIndex].req.getCityStatus( cityIndex )
    if cityStatus and ArmyLogic:checkArmyStatus( cityStatus, Enum.ArmyStatus.BATTLEING ) then
        BattleCreate:exitBattle( cityIndex, true )
    end
    -- 角色部队解散处理
    ArmyLogic:checkArmyOnForceMoveCity( _rid )
    -- 斥候回城处理
    ScoutsLogic:checkScoutsOnForceMoveCity( _rid )
    -- 运输队伍回城处理
    TransportLogic:forceMoveTransport( _rid )
    if not _isReboot then
        -- 城市离开地图
        MSM.MapObjectMgr[_rid].req.cityLeave( _rid, roleInfo.cityId, cityIndex )
        -- 通知盟友删除小地图盟友城市
        if roleInfo.guildId > 0 then
            local allOnlineMembers = GuildLogic:getAllOnlineMember( roleInfo.guildId )
            if #allOnlineMembers > 0 then
                GuildLogic:syncGuildMemberPos( allOnlineMembers, nil, _rid )
            end
        end
    end

    RoleLogic:setRole( _rid, Enum.Role.cityId, 0 )

    if not _checkTime then
        -- 更新地图城市数量管理服务
        SM.MapCityMgr.post.subCityNum()
    end
end

---@see 检查城市是否需要隐藏
function CityHideLogic:checkCityHide( _cityHides )
    local nowTime = os.time()
    local sCityHideData = CFG.s_CityHideData:Get()
    for rid, cityInfo in pairs( _cityHides ) do
        if sCityHideData[cityInfo.level] then
            if cityInfo.lastLogoutTime + sCityHideData[cityInfo.level].hideCityTime <= nowTime
                and cityInfo.createTime + sCityHideData[cityInfo.level].hideCityTime <= nowTime
                and SM.MapCityMgr.req.checkSubCityNum() then
                -- 角色离线时间超过设定值
                self:hideCity( rid, nil, true )
                _cityHides[rid] = nil
            end
        end
    end
end

---@see 角色登录时检查城市是否隐藏
function CityHideLogic:checkCityHideOnRoleLogin( _rid, _uid )
    local roleInfo = RoleLogic:getRole( _rid, {
        Enum.Role.cityId, Enum.Role.pos, Enum.Role.name, Enum.Role.country, Enum.Role.level,
        Enum.Role.noviceGuideStep, Enum.Role.denseFogOpenFlag, Enum.Role.guildId
    } )
    local cityPos
    local mapCityInfo = SM.c_map_object.req.Get( roleInfo.cityId )
    if roleInfo.cityId <= 0 or not mapCityInfo then
        -- 当前城市处于隐藏状态
        local provinceIndex = MapProvinceLogic:getPosInProvince( roleInfo.pos )
        cityPos = MapLogic:randomCityIdlePos( _rid, _uid or 0, provinceIndex, true )
        local cityId = MSM.MapObjectMgr[_rid].req.cityAddMap( _rid, roleInfo.name, roleInfo.level, roleInfo.country, cityPos )
        RoleLogic:setRole( _rid, { [Enum.Role.cityId] = cityId, [Enum.Role.pos] = cityPos } )
        -- 开城堡附近迷雾
        if not roleInfo.denseFogOpenFlag then
            DenseFogLogic:openDenseFogInPos( _rid, cityPos, 2 * Enum.DesenFogSize, true )
        end
        -- 完成新手引导且无和平护盾的要进行城堡重生表现
        local maxGuideStage = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.MAX_GUIDE_STAGE )
        if RoleLogic:checkGuideFinish( roleInfo.noviceGuideStep, maxGuideStage ) and not RoleLogic:checkShield( _rid ) then
            RoleLogic:setRole( _rid, Enum.Role.wallHpNotify, true )
        end
        -- 添加到角色推荐和角色昵称查询服务中
        SM.RoleRecommendMgr.post.initRole( _rid, roleInfo )
    else
        if mapCityInfo.objectPos.x ~= roleInfo.pos.x or mapCityInfo.objectPos.y ~= roleInfo.pos.y then
            cityPos = mapCityInfo.objectPos
            RoleLogic:setRole( _rid, Enum.Role.pos, mapCityInfo.objectPos )
        end
    end
    -- 从城市隐藏服务中删除
    MSM.CityHideMgr[_rid].req.deleteCity( _rid )
    -- 角色在联盟中，同步角色位置给联盟成员
    if cityPos and roleInfo.guildId > 0 then
        local allOnlineMembers = GuildLogic:getAllOnlineMember( roleInfo.guildId ) or {}
        if #allOnlineMembers > 0 then
            GuildLogic:syncGuildMemberPos( allOnlineMembers, { [_rid] = { rid = _rid, pos = cityPos } } )
        end
    end
end

---@see 角色退出时检查城市是否隐藏
function CityHideLogic:checkCityHideOnRoleLogout( _rid )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.level, Enum.Role.noviceGuideStep } )
    if CFG.s_CityHideData:Get( roleInfo.level ) then
        local maxGuideStage = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.MAX_GUIDE_STAGE )
        if not RoleLogic:checkGuideFinish( roleInfo.noviceGuideStep, maxGuideStage )
            and CFG.s_Config:Get( "hideNewCityFlag" ) == Enum.RoleNewCityHide.YES then
            self:hideCity( _rid )
        else
            -- 添加到城市隐藏服务
            MSM.CityHideMgr[_rid].post.addCity( _rid )
        end
    end
end

return CityHideLogic