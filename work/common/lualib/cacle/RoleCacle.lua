--[[
* @file : RoleCacle.lua
* @type : lua lib
* @author : chenlei
* @created : Fri Dec 27 2019 15:06:29 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色相关属性计算
* Copyright(C) 2017 IGG, All rights reserved
]]
local AttrDef = require "AttrDef"
local RoleCacle = {}

---@see 计算建筑属性加成
function RoleCacle:cacleBuildAttr( _roleAttr )
    local BuildingLogic = require "BuildingLogic"
    local buildings = BuildingLogic:getBuilding( _roleAttr.rid )
    local attr = AttrDef:getDefaultAttr()
    for _, buildingInfo in pairs(buildings) do
        if buildingInfo.level > 0 then
            --市政厅
            if buildingInfo.type == Enum.BuildingType.TOWNHALL then
                local s_BuildingTownCenter = CFG.s_BuildingTownCenter:Get(buildingInfo.level)
                for name in pairs(attr) do
                    if s_BuildingTownCenter[name] then
                        _roleAttr[name] = _roleAttr[name] + s_BuildingTownCenter[name]
                    end
                end
            end
            --城墙
            if buildingInfo.type == Enum.BuildingType.WALL then
                local s_BuildingCityWall = CFG.s_BuildingCityWall:Get(buildingInfo.level)
                for name in pairs(attr) do
                    if s_BuildingCityWall[name] then
                        _roleAttr[name] = _roleAttr[name] + s_BuildingCityWall[name]
                    end
                end
            end
            --警戒塔
            if buildingInfo.type == Enum.BuildingType.GUARDTOWER then
                local s_BuildingGuardTower = CFG.s_BuildingGuardTower:Get(buildingInfo.level)
                for name in pairs(attr) do
                    if s_BuildingGuardTower[name] then
                        _roleAttr[name] = _roleAttr[name] + s_BuildingGuardTower[name]
                    end
                end
            end
            --兵营
            if buildingInfo.type == Enum.BuildingType.BARRACKS then
                local s_BuildingCityWall = CFG.s_BuildingBarracks:Get(buildingInfo.level)
                for name in pairs(attr) do
                    if s_BuildingCityWall[name] then
                        _roleAttr[name] = _roleAttr[name] + s_BuildingCityWall[name]
                    end
                end
            end
            --靶场
            if buildingInfo.type == Enum.BuildingType.ARCHERYRANGE then
                local s_BuildingArcheryrange = CFG.s_BuildingArcheryrange:Get(buildingInfo.level)
                for name in pairs(attr) do
                    if s_BuildingArcheryrange[name] then
                        _roleAttr[name] = _roleAttr[name] + s_BuildingArcheryrange[name]
                    end
                end
            end
            --马厩
            if buildingInfo.type == Enum.BuildingType.STABLE then
                local s_BuildingStable = CFG.s_BuildingStable:Get(buildingInfo.level)
                for name in pairs(attr) do
                    if s_BuildingStable[name] then
                        _roleAttr[name] = _roleAttr[name] + s_BuildingStable[name]
                    end
                end
            end
            --攻城器厂
            if buildingInfo.type == Enum.BuildingType.SIEGE then
                local s_BuildingSiegeWorkshop = CFG.s_BuildingSiegeWorkshop:Get(buildingInfo.level)
                for name in pairs(attr) do
                    if s_BuildingSiegeWorkshop[name] then
                        _roleAttr[name] = _roleAttr[name] + s_BuildingSiegeWorkshop[name]
                    end
                end
            end
            --学院
            if buildingInfo.type == Enum.BuildingType.COLLAGE then
                local s_BuildingCampus = CFG.s_BuildingCampus:Get(buildingInfo.level)
                for name in pairs(attr) do
                    if s_BuildingCampus[name] then
                        _roleAttr[name] = _roleAttr[name] + s_BuildingCampus[name]
                    end
                end
            end
            --医院
            if buildingInfo.type == Enum.BuildingType.HOSPITAL then
                local s_BuildingHospital = CFG.s_BuildingHospital:Get(buildingInfo.level)
                for name in pairs(attr) do
                    if s_BuildingHospital[name] then
                        _roleAttr[name] = _roleAttr[name] + s_BuildingHospital[name]
                    end
                end
            end
            --城堡
            if buildingInfo.type == Enum.BuildingType.CASTLE then
                local s_BuildingCastle = CFG.s_BuildingCastle:Get(buildingInfo.level)
                for name in pairs(attr) do
                    if s_BuildingCastle[name] then
                        _roleAttr[name] = _roleAttr[name] + s_BuildingCastle[name]
                    end
                end
            end
            --斥候营地
            if buildingInfo.type == Enum.BuildingType.SCOUT_CAMP then
                local s_BuildingScoutcamp = CFG.s_BuildingScoutcamp:Get(buildingInfo.level)
                for name in pairs(attr) do
                    if s_BuildingScoutcamp[name] then
                        _roleAttr[name] = _roleAttr[name] + s_BuildingScoutcamp[name]
                    end
                end
            end
            -- 商栈
            if buildingInfo.type == Enum.BuildingType.BUSSINESS then
                local sBuildingFreight = CFG.s_BuildingFreight:Get(buildingInfo.level)
                for name in pairs(attr) do
                    if sBuildingFreight[name] then
                        _roleAttr[name] = _roleAttr[name] + sBuildingFreight[name]
                    end
                end
            end
        end
    end
end

---@see 计算科技属性加成
function RoleCacle:cacleTechnologyAttr( _roleAttr )
    local technologies = _roleAttr.technologies
    local studyConfig = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.STUDY ) or {}
    for _, technologInfo in pairs(technologies) do
        if studyConfig[technologInfo.technologyType] and studyConfig[technologInfo.technologyType][technologInfo.level] then
        local technologyId = studyConfig[technologInfo.technologyType][technologInfo.level].id
            local config = CFG.s_Study:Get(technologyId)
            if config then
                for i=1,table.size(config.buffType) do
                    if _roleAttr[config.buffType[i]] then
                        _roleAttr[config.buffType[i]] = _roleAttr[config.buffType[i]] + config.buffData[i]
                    end
                end
            end
        end
    end
end

---@see 计算城市buff
function RoleCacle:cacleCityBuffAttr( _roleAttr )
    local cityBuff = _roleAttr.cityBuff
    for buffId in pairs(cityBuff) do
        local RoleLogic = require "RoleLogic"
        RoleLogic:addCityBuffAttr( _roleAttr.rid, buffId, _roleAttr, true )
    end
end

---@see 科技升级属性变化
function RoleCacle:technologyAttrChange( _roleAttr, technologyType, _level)
    local studyConfig = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.STUDY ) or {}
    local technologyId = studyConfig[technologyType][_level].id
    local s_Study = CFG.s_Study:Get(technologyId)
    local before_Study
    if _level > 1 then
        technologyId = studyConfig[technologyType][_level - 1].id
        before_Study = CFG.s_Study:Get(technologyId)
    end
    for i=1,table.size(s_Study.buffType) do
        local buffName = s_Study.buffType[i]
        if _roleAttr[buffName] then
            local addNum = s_Study.buffData[i]
            if before_Study then
                for j=1,table.size(before_Study.buffType) do
                    if before_Study.buffType[j] == buffName then
                        addNum = addNum - before_Study.buffData[j]
                    end
                end
            end
            _roleAttr[buffName] = _roleAttr[buffName] + addNum
        end
    end

    return s_Study
end

---@see vip升级属性变化
function RoleCacle:vipAttrChange( _roleAttr, _level, _oldLevel, _isLogin )
    local oldVipAttrConfig
    if _oldLevel then
        oldVipAttrConfig = CFG.s_VipAtt:Get( _oldLevel )
    end
    local vipAttrConfig = CFG.s_VipAtt:Get( _level )
    if not vipAttrConfig then
        return
    end
    for attrName, v in pairs(vipAttrConfig) do
        if attrName == "secondBuildList" then
            if _oldLevel then
                local BuildingLogic = require "BuildingLogic"
                BuildingLogic:unlockQueue( _roleAttr.rid, -1, _roleAttr, _isLogin )
            end
        elseif attrName ~= "arenaDayFreeNum" and  _roleAttr[attrName] then
            local addNum = v.add
            if oldVipAttrConfig then
                if oldVipAttrConfig[attrName] then
                    addNum = addNum - oldVipAttrConfig[attrName].add
                end
            end
            _roleAttr[attrName] = _roleAttr[attrName] + addNum
        end
    end

end

---@see 建筑属性变化
function RoleCacle:buildAttrChange( _roleAttr, _buildInfo )
    local attr = AttrDef:getDefaultAttr()
    if _buildInfo.type == Enum.BuildingType.TOWNHALL then
        local before_BuildingTownCenter
        local s_BuildingTownCenter = CFG.s_BuildingTownCenter:Get(_buildInfo.level)
        if _buildInfo.level > 1 then
            before_BuildingTownCenter = CFG.s_BuildingTownCenter:Get(_buildInfo.level - 1)
        end
        for name in pairs(attr) do
            if s_BuildingTownCenter[name] then
                local addNum = s_BuildingTownCenter[name]
                if before_BuildingTownCenter then
                    local beforeNum = before_BuildingTownCenter[name] or 0
                    addNum = addNum - beforeNum
                end
                _roleAttr[name] = _roleAttr[name] + addNum
            end
        end
    end
    --城墙
    if _buildInfo.type == Enum.BuildingType.WALL then
        local before_BuildingCityWall
        local s_BuildingCityWall = CFG.s_BuildingCityWall:Get(_buildInfo.level)
        if _buildInfo.level > 1 then
            before_BuildingCityWall = CFG.s_BuildingCityWall:Get(_buildInfo.level - 1)
        end
        for name in pairs(attr) do
            if s_BuildingCityWall[name] then
                local addNum = s_BuildingCityWall[name]
                if before_BuildingCityWall then
                    local beforeNum = before_BuildingCityWall[name] or 0
                    addNum = addNum - beforeNum
                end
                _roleAttr[name] = _roleAttr[name] + addNum
            end
        end
    end
    --警戒塔
    if _buildInfo.type == Enum.BuildingType.GUARDTOWER then
        local before_BuildingGuardTower
        local s_BuildingGuardTower = CFG.s_BuildingGuardTower:Get(_buildInfo.level)
        if _buildInfo.level > 1 then
            before_BuildingGuardTower = CFG.s_BuildingGuardTower:Get(_buildInfo.level - 1)
        end
        for name in pairs(attr) do
            if s_BuildingGuardTower[name] then
                local addNum = s_BuildingGuardTower[name]
                if before_BuildingGuardTower then
                    local beforeNum = before_BuildingGuardTower[name] or 0
                    addNum = addNum - beforeNum
                end
                _roleAttr[name] = _roleAttr[name] + addNum
            end
        end
    end
    --兵营
    if _buildInfo.type == Enum.BuildingType.BARRACKS then
        local before_BuildingBarracks
        local s_BuildingCityWall = CFG.s_BuildingBarracks:Get(_buildInfo.level)
        if _buildInfo.level > 1 then
            before_BuildingBarracks = CFG.s_BuildingBarracks:Get(_buildInfo.level - 1)
        end
        for name in pairs(attr) do
            if s_BuildingCityWall[name] then
                local addNum = s_BuildingCityWall[name]
                if before_BuildingBarracks then
                    local beforeNum = before_BuildingBarracks[name] or 0
                    addNum = addNum - beforeNum
                end
                _roleAttr[name] = _roleAttr[name] + addNum
            end
        end
    end
    --靶场
    if _buildInfo.type == Enum.BuildingType.ARCHERYRANGE then
        local before_BuildingArcheryrange
        local s_BuildingArcheryrange = CFG.s_BuildingArcheryrange:Get(_buildInfo.level)
        if _buildInfo.level > 1 then
            before_BuildingArcheryrange = CFG.s_BuildingArcheryrange:Get(_buildInfo.level - 1)
        end
        for name in pairs(attr) do
            if s_BuildingArcheryrange[name] then
                local addNum = s_BuildingArcheryrange[name]
                if before_BuildingArcheryrange then
                    local beforeNum = before_BuildingArcheryrange[name] or 0
                    addNum = addNum - beforeNum
                end
                _roleAttr[name] = _roleAttr[name] + addNum
            end
        end
    end
    --马厩
    if _buildInfo.type == Enum.BuildingType.STABLE then
        local before_BuildingStable
        local s_BuildingStable = CFG.s_BuildingStable:Get(_buildInfo.level)
        if _buildInfo.level > 1 then
            before_BuildingStable = CFG.s_BuildingStable:Get(_buildInfo.level - 1)
        end
        for name in pairs(attr) do
            if s_BuildingStable[name] then
                local addNum = s_BuildingStable[name]
                if before_BuildingStable then
                    local beforeNum = before_BuildingStable[name] or 0
                    addNum = addNum - beforeNum
                end
                _roleAttr[name] = _roleAttr[name] + addNum
            end
        end
    end
    --攻城器厂
    if _buildInfo.type == Enum.BuildingType.SIEGE then
        local before_BuildingSiegeWorkshop
        local s_BuildingSiegeWorkshop = CFG.s_BuildingSiegeWorkshop:Get(_buildInfo.level)
        if _buildInfo.level > 1 then
            before_BuildingSiegeWorkshop = CFG.s_BuildingSiegeWorkshop:Get(_buildInfo.level - 1)
        end
        for name in pairs(attr) do
            if s_BuildingSiegeWorkshop[name] then
                local addNum = s_BuildingSiegeWorkshop[name]
                if before_BuildingSiegeWorkshop then
                    local beforeNum = before_BuildingSiegeWorkshop[name] or 0
                    addNum = addNum - beforeNum
                end
                _roleAttr[name] = _roleAttr[name] + addNum
            end
        end
    end
    --学院
    if _buildInfo.type == Enum.BuildingType.COLLAGE then
        local before_BuildingCampus
        local s_BuildingCampus = CFG.s_BuildingCampus:Get(_buildInfo.level)
        if _buildInfo.level > 1 then
            before_BuildingCampus = CFG.s_BuildingCampus:Get(_buildInfo.level - 1)
        end
        for name in pairs(attr) do
            if s_BuildingCampus[name] then
                local addNum = s_BuildingCampus[name]
                if before_BuildingCampus then
                    local beforeNum = before_BuildingCampus[name] or 0
                    addNum = addNum - beforeNum
                end
                _roleAttr[name] = _roleAttr[name] + addNum
            end
        end
    end
    --医院
    if _buildInfo.type == Enum.BuildingType.HOSPITAL then
        local before_BuildingHospital
        local s_BuildingHospital = CFG.s_BuildingHospital:Get(_buildInfo.level)
        if _buildInfo.level > 1 then
            before_BuildingHospital = CFG.s_BuildingHospital:Get(_buildInfo.level - 1)
        end
        for name in pairs(attr) do
            if s_BuildingHospital[name] then
                local addNum = s_BuildingHospital[name]
                if before_BuildingHospital then
                    local beforeNum = before_BuildingHospital[name] or 0
                    addNum = addNum - beforeNum
                end
                _roleAttr[name] = _roleAttr[name] + addNum
            end
        end
    end
    --城堡
    if _buildInfo.type == Enum.BuildingType.CASTLE then
        local before_BuildingCastle
        local s_BuildingCastle = CFG.s_BuildingCastle:Get(_buildInfo.level)
        if _buildInfo.level > 1 then
            before_BuildingCastle = CFG.s_BuildingCastle:Get(_buildInfo.level - 1)
        end
        for name in pairs(attr) do
            if s_BuildingCastle[name] then
                local addNum = s_BuildingCastle[name]
                if before_BuildingCastle then
                    local beforeNum = before_BuildingCastle[name] or 0
                    addNum = addNum - beforeNum
                end
                _roleAttr[name] = _roleAttr[name] + addNum
            end
        end
    end
    --斥候营地
    if _buildInfo.type == Enum.BuildingType.SCOUT_CAMP then
        local before_BuildingScoutcamp
        local s_BuildingScoutcamp = CFG.s_BuildingScoutcamp:Get(_buildInfo.level)
        if _buildInfo.level > 1 then
            before_BuildingScoutcamp = CFG.s_BuildingScoutcamp:Get(_buildInfo.level - 1)
        end
        for name in pairs(attr) do
            if s_BuildingScoutcamp[name] then
                local addNum = s_BuildingScoutcamp[name]
                if before_BuildingScoutcamp then
                    local beforeNum = before_BuildingScoutcamp[name] or 0
                    addNum = addNum - beforeNum
                end
                _roleAttr[name] = _roleAttr[name] + addNum
            end
        end
    end
    -- 商栈
    if _buildInfo.type == Enum.BuildingType.BUSSINESS then
        local before_BuildingFreigh
        local s_BuildingFreight = CFG.s_BuildingFreight:Get(_buildInfo.level)
        if _buildInfo.level > 1 then
            before_BuildingFreigh = CFG.s_BuildingFreight:Get(_buildInfo.level - 1)
        end
        for name in pairs(attr) do
            if s_BuildingFreight[name] then
                local addNum = s_BuildingFreight[name]
                if before_BuildingFreigh then
                    local beforeNum = before_BuildingFreigh[name] or 0
                    addNum = addNum - beforeNum
                end
                _roleAttr[name] = _roleAttr[name] + addNum
            end
        end
    end
end

---@see 计算文明属性加成
function RoleCacle:reduceCivilizationAttr( _roleAttr )
    local country = _roleAttr.country
    local s_Civilization = CFG.s_Civilization:Get( country )
    for i=1,table.size(s_Civilization.civilizationAdd) do
        if _roleAttr[s_Civilization.civilizationAdd[i]] then
            _roleAttr[s_Civilization.civilizationAdd[i]] = _roleAttr[s_Civilization.civilizationAdd[i]] - s_Civilization.civilizationAddData[i]
        end
    end
end

---@see 计算文明属性加成
function RoleCacle:cacleCivilizationAttr( _roleAttr )
    local country = _roleAttr.country
    local s_Civilization = CFG.s_Civilization:Get( country )
    for i=1,table.size(s_Civilization.civilizationAdd) do
        if _roleAttr[s_Civilization.civilizationAdd[i]] then
            _roleAttr[s_Civilization.civilizationAdd[i]] = _roleAttr[s_Civilization.civilizationAdd[i]] + s_Civilization.civilizationAddData[i]
        end
    end
end

---@see 计算建筑战力
function RoleCacle:cacleBuildPower( _roleAttr )
    local BuildingLogic = require "BuildingLogic"
    local buildings = BuildingLogic:getBuilding( _roleAttr.rid ) or {}

    local power = 0
    local buildLevelId, buildingLevelData
    local sBuildingLevelData = CFG.s_BuildingLevelData:Get()
    -- 计算所有建筑的战力属性
    for _, buildingInfo in pairs( buildings ) do
        buildLevelId = buildingInfo.type * 100 + buildingInfo.level
        buildingLevelData = sBuildingLevelData[buildLevelId]
        power = power + ( buildingLevelData and buildingLevelData.power or 0 )
    end

    return power
end

---@see 计算科技战力
function RoleCacle:cacleTechnologyPower( _roleAttr )
    local power = 0
    local addPower
    local sStudy = CFG.s_Study:Get()
    local studyConfig = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.STUDY ) or {}
    local technologyId
    -- 计算所有科技的战力属性
    for technologyType, technology in pairs( _roleAttr.technologies or {} ) do
        technologyId = studyConfig[technologyType] and studyConfig[technologyType][technology.level] and studyConfig[technologyType][technology.level].id or 0
        addPower = sStudy[technologyId] and sStudy[technologyId].power or 0
        power = power + addPower
    end

    return power
end

---@see 计算部队战力
function RoleCacle:cacleArmyPower( _roleAttr )
    local power = 0
    local armyInfo
    -- 待命士兵
    for _, soldierInfo in pairs( _roleAttr.soldiers or {} ) do
        armyInfo = CFG.s_Arms:Get( soldierInfo.id )
        if armyInfo then
            power = power + armyInfo.militaryCapability * soldierInfo.num
        end
    end

    -- 晋升中的士兵
    local ArmyTrainLogic = require "ArmyTrainLogic"
    for _, queueInfo in pairs( _roleAttr.armyQueue or {} ) do
        if queueInfo.oldArmyLevel and queueInfo.oldArmyLevel > 0 then
            local config = ArmyTrainLogic:getArmsConfig( _roleAttr.rid, queueInfo.armyType, queueInfo.oldArmyLevel, nil, _roleAttr.country )
            armyInfo = CFG.s_Arms:Get( config.ID )
            if armyInfo then
                power = power + armyInfo.militaryCapability * queueInfo.armyNum
            end
        end
    end

    -- 守城、出征中的士兵
    local ArmyLogic = require "ArmyLogic"
    local allArmy = ArmyLogic:getArmy( _roleAttr.rid )
    for armyIndex, army in pairs( allArmy or {} ) do
        if Common.isTable(army) then
            for _, soldierInfo in pairs( army.soldiers or {} ) do
                armyInfo = CFG.s_Arms:Get( soldierInfo.id )
                if armyInfo then
                    power = power + armyInfo.militaryCapability * soldierInfo.num
                end
            end
            -- 轻伤士兵
            for _, soldierInfo in pairs( army.minorSoldiers or {} ) do
                armyInfo = CFG.s_Arms:Get( soldierInfo.id )
                if armyInfo then
                    power = power + armyInfo.militaryCapability * soldierInfo.num
                end
            end
        else
            LOG_ERROR("rid(%s) invalid armyInfo(%s)", tostring(_roleAttr.rid), tostring(allArmy))
            allArmy[armyIndex] = nil
            ArmyLogic:setArmy( _roleAttr.rid, armyIndex, {} )
        end
    end

    return power
end

---@see 计算角色战力
function RoleCacle:cacleRolePower( _roleAttr )
    -- 建筑战力
    local power = self:cacleBuildPower( _roleAttr ) or 0
    -- 科技战力
    power = power + ( self:cacleTechnologyPower( _roleAttr ) or 0 )
    -- 部队战力
    power = power + ( self:cacleArmyPower( _roleAttr ) or 0 )

    -- 统帅战力
    local HeroCacle = require "HeroCacle"
    local HeroLogic = require "HeroLogic"
    local heros = HeroLogic:getHero( _roleAttr.rid ) or {}
    for _, heroInfo in pairs( heros ) do
        power = power + HeroCacle:caclePower( heroInfo )
    end
    return power
end

---@see 计算联盟官职增加属性
function RoleCacle:cacleGuildOfficerAttr( _roleAttr, _oldOfficerId, _newOfficerId )
    local attrValue, officerInfo
    local sAllianceOfficially = CFG.s_AllianceOfficially:Get()
    if _oldOfficerId then
        -- 扣除旧官职ID属性
        officerInfo = sAllianceOfficially[_oldOfficerId] or {}
        for index, attrName in pairs( officerInfo.add or {} ) do
            attrValue = officerInfo.addData and officerInfo.addData[index] or 0
            if _roleAttr[attrName] then
                _roleAttr[attrName] = _roleAttr[attrName] - attrValue
            end
        end
    end
    if _roleAttr.guildId and _roleAttr.guildId > 0 then
        -- 当前在联盟中
        if not _newOfficerId then
            -- 获取新的官职ID
            local GuildLogic = require "GuildLogic"
            local guildOfficers = GuildLogic:getGuild( _roleAttr.guildId, Enum.Guild.guildOfficers ) or {}
            for officerId, officer in pairs( guildOfficers ) do
                if officer.rid == _roleAttr.rid then
                    _newOfficerId = officerId
                end
            end
        end
        if _newOfficerId then
            -- 增加新官职ID属性
            officerInfo = sAllianceOfficially[_newOfficerId] or {}
            for index, attrName in pairs( officerInfo.add or {} ) do
                attrValue = officerInfo.addData and officerInfo.addData[index] or 0
                if _roleAttr[attrName] then
                    _roleAttr[attrName] = _roleAttr[attrName] + attrValue
                end
            end
        end
    end
end

---@see 计算联盟科技和圣地属性
function RoleCacle:cacleGuildAttr( _roleAttr, _oldGuildAttr, _newGuildAttr )
    -- 移除旧的联盟属性
    for name, value in pairs( _oldGuildAttr or {} ) do
        _roleAttr[name] = _roleAttr[name] - value
    end

    if not _newGuildAttr then
        -- 获取新的联盟属性
        if _roleAttr.guildId and _roleAttr.guildId > 0 then
            _newGuildAttr = MSM.GuildAttrMgr[_roleAttr.guildId].req.getGuildAttr( _roleAttr.guildId )
        end
    end

    -- 添加新的联盟属性
    for name, value in pairs( _newGuildAttr or {} ) do
        _roleAttr[name] = _roleAttr[name] + value
    end
end

---@see 取出战斗需要使用的角色属性
function RoleCacle:getRoleBattleAttr( _rid, _roleInfo )
    local RoleLogic = require "RoleLogic"
    local roleInfo = _roleInfo or RoleLogic:getRole( _rid )
    local battleAttr = AttrDef:getDefaultBattleAttr()
    local objectAttr = {}
    for name in pairs(battleAttr) do
        objectAttr[name] = roleInfo[name]
    end

    return objectAttr
end

---@see 角色属性变化处理
function RoleCacle:checkRoleAttrChange( _rid, _oldRoleAttr, _newRoleAttr )
    local RoleLogic = require "RoleLogic"
    local BattleAttrLogic = require "BattleAttrLogic"
    local ResourceLogic = require "ResourceLogic"

    -- 战斗属性有无变化
    local battleAttr = AttrDef:getDefaultBattleAttr()
    for name in pairs( battleAttr ) do
        if ( _oldRoleAttr[name] or 0 ) ~= ( _newRoleAttr[name] or 0 ) then
            BattleAttrLogic:syncObjectAttrToBattleServer( _rid )
            break
        end
    end

    -- 角色行动力恢复速度变化
    local attrName = Enum.Role.vitalityRecoveryMulti
    if ( _oldRoleAttr[attrName] or 0 ) ~= ( _newRoleAttr[attrName] or 0 ) then
        RoleLogic:actionForceRecoverChange( _rid )
    end

    -- 角色行动力上限是否变化
    attrName = Enum.Role.maxVitality
    if ( _oldRoleAttr[attrName] or 0 ) ~= ( _newRoleAttr[attrName] or 0 ) then
        RoleLogic:actionForceLimitChange( _rid )
    end

    -- 角色采集速度是否变化
    local collectSpeedChange
    local collectSpeedName = {
        Enum.Role.getFoodSpeedMulti, Enum.Role.getWoodSpeedMulti, Enum.Role.getStoneSpeedMulti,
        Enum.Role.getGlodSpeedMulti, Enum.Role.getDiamondSpeedMulti
    }
    for _, name in pairs( collectSpeedName ) do
        if ( _oldRoleAttr[name] or 0 ) ~= ( _newRoleAttr[name] or 0 ) then
            collectSpeedChange = true
            ResourceLogic:roleArmyCollectSpeedChange( _rid )
            break
        end
    end
    -- 部队负载量是否变化
    attrName = Enum.Role.troopsSpaceMulti
    if not collectSpeedChange and ( _oldRoleAttr[attrName] or 0 ) ~= ( _newRoleAttr[attrName] or 0 ) then
        ResourceLogic:checkResourceArmyOnLoadChange( _rid )
    end

    -- 部队速度变化
    local addSpeedAttr = {
        infantryMoveSpeed = 0,                  -- 步兵行军速度
        cavalryMoveSpeed = 0,                   -- 骑兵行军速度
        bowmenMoveSpeed = 0,                    -- 弓兵行军速度
        siegeCarMoveSpeed = 0,                  -- 攻城器械行军速度
        infantryMoveSpeedMulti = 0,             -- 步兵行军速度百分比
        cavalryMoveSpeedMulti = 0,              -- 骑兵行军速度百分比
        bowmenMoveSpeedMulti = 0,               -- 弓兵行军速度百分比
        siegeCarMoveSpeedMulti = 0,             -- 攻城器械行军速度百分比
        allTerrMoveSpeedMulti = 0,              -- 联盟领地移动速度加成
        rallyMoveSpeedMulti = 0,                -- 集结部队行军速度千分比
        marchSpeedMulti = 0,                    -- 部队行军速度百分比
    }

    for name in pairs( addSpeedAttr ) do
        if ( _oldRoleAttr[name] or 0 ) ~= ( _newRoleAttr[name] or 0 ) then
            local ArmyLogic = require "ArmyLogic"
            local allArmys = ArmyLogic:getArmy( _rid ) or {}
            local objectIndexs = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid ) or {}
            local mapArmyInfo
            for armyIndex, armyInfo in pairs( allArmys ) do
                if objectIndexs[armyIndex] then
                    mapArmyInfo = MSM.SceneArmyMgr[objectIndexs[armyIndex]].req.getArmyInfo( objectIndexs[armyIndex] )
                    if mapArmyInfo then
                        ArmyLogic:reCacleArmySpeed( objectIndexs[armyIndex], mapArmyInfo, nil, armyInfo, mapArmyInfo.isInGuildTerritory )
                    end
                end
            end
            break
        end
    end

    -- TODO:斥候速度变化

    -- 资源产量变化
    local produceName = {
        Enum.Role.foodCapacityMulti, Enum.Role.woodCapacityMulti, Enum.Role.stoneCapacityMulti,
        Enum.Role.glodCapacityMulti
    }

    local BuildingLogic = require "BuildingLogic"
    for _, name in pairs( produceName ) do
        if ( _oldRoleAttr[name] or 0 ) ~= ( _newRoleAttr[name] or 0 ) then
            BuildingLogic:changeBuildingGain( _rid, name, _oldRoleAttr[name] or 0 )
        end
    end
end

return RoleCacle