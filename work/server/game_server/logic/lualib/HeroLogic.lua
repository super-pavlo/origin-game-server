--[[
* @file : HeroLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Thu Dec 26 2019 10:39:26 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 统帅相关逻辑实现
* Copyright(C) 2017 IGG, All rights reserved
]]

local Random = require "Random"
local HeroDef = require "HeroDef"

local HeroLogic = {}

---@see 获取角色统帅指定数据
function HeroLogic:getHero( _rid, _heroId, _fields )
    return MSM.d_hero[_rid].req.Get( _rid, _heroId, _fields )
end

---@see 更新角色统帅指定数据
function HeroLogic:setHero( _rid, _heroId, _fields, _data )
    return MSM.d_hero[_rid].req.Set( _rid, _heroId, _fields, _data )
end

---@see 判断达到某等级的统帅数
function HeroLogic:checkHeroLevelCount( _rid, _level )
    local count = 0
    local heroList = self:getHero( _rid ) or {}
    for _, heroInfo in pairs(heroList) do
        if heroInfo.level >= _level then
            count = count + 1
        end
    end
    return count
end

---@see 获得一个统帅
function HeroLogic:addHero( _rid, _heroId, _isLogin, _noHeroShow, _noSync )
    -- 如果存在该统帅转化成对应数量的道具
    local heroInfo = self:getHero( _rid, _heroId )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.RECRUIT_HERO_COUNT, 1 )
    if heroInfo and not table.empty(heroInfo) then
        local sHeroInfo = CFG.s_Hero:Get(_heroId)
        local itemId = sHeroInfo.getItem
        local itemNum = sHeroInfo.getItemNum
        local ItemLogic = require "ItemLogic"
        if _isLogin then
            _noSync = true
        end
        return ItemLogic:addItem( { rid = _rid, itemId = itemId, itemNum = itemNum, eventType = Enum.LogType.HERO_GAIN_ITEM, noSync = _noSync } )
    end

    local defHeroAttr = HeroDef:getDefaultHeroAttr()
    local sHero = CFG.s_Hero:Get( _heroId )

    defHeroAttr.heroId = _heroId
    defHeroAttr.star = sHero.initStar
    defHeroAttr.level = 1
    defHeroAttr.summonTime = os.time()
    -- 判断等级是否增加天赋点
    -- local talentPoint = CFG.s_HeroLevel:Get(sHero.rare * 10000 + defHeroAttr.level, "starEffectData" )
    -- if talentPoint >= 1 then
    --     defHeroAttr.talentPoint = defHeroAttr.talentPoint + talentPoint
    -- end
    -- -- 判断星级是否增加天赋点
    -- talentPoint = CFG.s_HeroStar:Get( defHeroAttr.star, "starEffectData" )
    -- if talentPoint >= 1 then
    --     defHeroAttr.talentPoint = defHeroAttr.talentPoint + talentPoint
    -- end
    self:unlockSkill( _rid, _heroId, defHeroAttr.star, defHeroAttr )
    MSM.d_hero[_rid].req.Add( _rid, _heroId, defHeroAttr )
    if not _isLogin then
        self:syncHero( _rid, _heroId, defHeroAttr, true, nil, _noHeroShow )
    end
    local RoleLogic = require "RoleLogic"
    RoleLogic:cacleSyncHistoryPower( _rid, nil, nil, true )

    local BuildingLogic = require "BuildingLogic"
    BuildingLogic:changeDefendHero( _rid )

    local RechargeLogic = require "RechargeLogic"
    RechargeLogic:triggerLimitPackage( _rid, { type = Enum.LimitTimeType.NEW_HERO, rare = sHero.rare } )
end

---@see 推送所有统帅信息到客户端
function HeroLogic:pushAllHero( _rid )
    local heros = self:getHero( _rid ) or {}
    local syncHeroInfos = {}
    for heroId, heroInfo in pairs( heros ) do
        syncHeroInfos[heroId] = {
            heroId = heroId,
            star = heroInfo.star,
            starExp = heroInfo.starExp,
            level = heroInfo.level,
            exp = heroInfo.exp,
            summonTime = heroInfo.summonTime,
            soldierKillNum = heroInfo.soldierKillNum,
            savageKillNum = heroInfo.savageKillNum,
            skills = heroInfo.skills,
            talentPoint = heroInfo.talentPoint,
            talentTrees = heroInfo.talentTrees,
            talentIndex = heroInfo.talentIndex,
            head = heroInfo.head,
            breastPlate = heroInfo.breastPlate,
            weapon = heroInfo.weapon,
            gloves = heroInfo.gloves,
            pants = heroInfo.pants,
            accessories1 = heroInfo.accessories1,
            accessories2 = heroInfo.accessories2,
            shoes = heroInfo.shoes,
        }
    end

    Common.syncMsg( _rid, "Hero_HeroInfo", { heroInfo = syncHeroInfos } )
end

---@see 更新同步统帅信息
function HeroLogic:syncHero( _rid, _heroId, _field, _haskv, _block, _noHeroShow )
    local heroInfo
    local syncInfo = {}
    if not _haskv then
        if type( _heroId ) == "table" then
            -- 同步多个统帅
            for _, heroId in pairs( _heroId ) do
                heroInfo = self:getHero( _rid, heroId )
                heroInfo.heroId = heroId
                syncInfo[heroId] = heroInfo
            end
        else
            heroInfo = self:getHero( _rid, _heroId )
            heroInfo.heroId = _heroId
            syncInfo[_heroId] = heroInfo
        end
    else
        if _heroId then
            _field.heroId = _heroId
            syncInfo[_heroId] = _field
        else
            syncInfo = _field
        end
    end

    -- 同步
    Common.syncMsg( _rid, "Hero_HeroInfo",  { heroInfo = syncInfo, noShow = _noHeroShow }, _block )
end

---@see 判断统帅当前技能等级是否都满了
function HeroLogic:checkHeroSkillFull( _rid, _heroId )
    local heroInfo = self:getHero( _rid, _heroId )
    if not heroInfo or table.empty( heroInfo ) then
        return true
    end
    if table.size(heroInfo.skills) < 4 then
        return false
    end
    for _, skillInfo in pairs(heroInfo.skills) do
        if CFG.s_HeroSkillEffect:Get( skillInfo.skillId * 1000 + skillInfo.skillLevel + 1) then
            return false
        end
    end
    return true
end

---@see 统帅升级技能需要道具个数
function HeroLogic:getUpLevelSkillItemCount( _rid, _heroId )
    local heroInfo = self:getHero( _rid, _heroId )
    if not heroInfo or table.empty( heroInfo ) then
        return -1
    end
    local sHero = CFG.s_Hero:Get(_heroId)
    local level = 0
    for _, skillInfo in pairs(heroInfo.skills) do
        level = level + skillInfo.skillLevel
    end
    level = level - table.size(heroInfo.skills) + 1
    local sHeroSkillLevel = CFG.s_HeroSkillLevel:Get(level)
    if sHero.rare == Enum.HeroRareType.NORMAL then
        return sHeroSkillLevel.costItem1
    elseif sHero.rare == Enum.HeroRareType.EXCELLENT then
        return sHeroSkillLevel.costItem2
    elseif sHero.rare == Enum.HeroRareType.ELITE then
        return sHeroSkillLevel.costItem3
    elseif sHero.rare == Enum.HeroRareType.EPIC then
        return sHeroSkillLevel.costItem4
    elseif sHero.rare == Enum.HeroRareType.LEGEND then
        return sHeroSkillLevel.costItem5
    end
end

---@see 统帅技能升级
function HeroLogic:heroSkillLevelUp( _rid, _heroId )
    local heroInfo = self:getHero( _rid, _heroId )
    local skillIds = {}
    for _, skillInfo in pairs(heroInfo.skills) do
        if CFG.s_HeroSkillEffect:Get( skillInfo.skillId * 1000 + skillInfo.skillLevel + 1) then
            table.insert( skillIds, { id = skillInfo.skillId, rate = 1000 } )
        end
    end
    -- 扣除道具
    local ItemLogic = require "ItemLogic"
    local sHero = CFG.s_Hero:Get(_heroId)
    local count = self:getUpLevelSkillItemCount( _rid, _heroId )
    ItemLogic:delItemById( _rid, sHero.getItem, count, nil, Enum.LogType.HERO_LEVEL_UP_COST_ITEM )
    local skillLevel = 0
    local skillId = Random.GetId(skillIds)
    for _, skillInfo in pairs(heroInfo.skills) do
        if skillInfo.skillId == skillId then
            skillInfo.skillLevel = skillInfo.skillLevel + 1
            skillLevel = skillInfo.skillLevel
        end
    end
    self:setHero( _rid, _heroId, heroInfo )
    self:syncHero( _rid, _heroId, heroInfo, true, true )
    local RoleLogic = require "RoleLogic"
    RoleLogic:cacleSyncHistoryPower( _rid, nil, nil, true )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.HERO_SKILL_LEVEL_COUNT, 1 )

    if CFG.s_HeroSkill:Get( _heroId * 100 + 5) and self:checkHeroSkillFull( _rid, _heroId ) then
        self:heroAwake( _rid, _heroId )
    end

    -- 部队战斗属性更新
    local BattleAttrLogic = require "BattleAttrLogic"
    BattleAttrLogic:syncObjectAttrToBattleServer( _rid )
    -- 部队采集属性更新
    local ResourceLogic = require "ResourceLogic"
    ResourceLogic:roleArmyCollectSpeedChange( _rid )
    -- 部队技能变化
    self:updateMapArmyHero( _rid, _heroId )
    -- 增加统帅技能升级次数
    local TaskLogic = require "TaskLogic"
    TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.HERO_SKILL_NUM, Enum.TaskArgDefault, 1 )

    return { skillId = skillId, skillLevel = skillLevel }
end

---@see 判断统帅是否已经觉醒
function HeroLogic:checkHeroWake( _rid, _heroId )
    local heroInfo = self:getHero( _rid, _heroId )
    if not heroInfo then
        return false
    end
    return table.size(heroInfo.skills or {}) >= 5
end

---@see 判断统帅是否存在
function HeroLogic:checkHeroExist( _rid, _heroId )
    if not _heroId or _heroId <= 0 then
        return true
    end
    local level = self:getHero( _rid, _heroId, Enum.Hero.level )
    return level ~= nil
end

---@see 判断统帅是否处于待命状态
function HeroLogic:checkHeroIdle( _rid, _heroIds )
    local ArmyLogic = require "ArmyLogic"
    local allArmy = ArmyLogic:getArmy( _rid ) or {}
    if not Common.isTable(_heroIds) then
        _heroIds = { _heroIds }
    end
    for _, armyInfo in pairs( allArmy ) do
        if table.exist(_heroIds, armyInfo.mainHeroId ) then
            return false, armyInfo.armyIndex
        end
        if armyInfo.deputyHeroId and armyInfo.deputyHeroId > 0 then
            if table.exist(_heroIds, armyInfo.deputyHeroId ) then
                return false, armyInfo.armyIndex
            end
        end
    end

    return true
end

---@see 技能觉醒
function HeroLogic:heroAwake( _rid, _heroId )
    local heroInfo = self:getHero( _rid, _heroId )
    local skillId = _heroId * 100 + 5
    local new = true
    for _, skillInfo in pairs( heroInfo.skills or {} ) do
        if skillInfo.skillId == skillId then
            new = false
            break
        end
    end
    if new then
        table.insert(heroInfo.skills, { skillId = skillId, skillLevel = 1 } )
    end
    self:setHero( _rid, _heroId, heroInfo )
    self:syncHero( _rid, _heroId, heroInfo, true)
    local RoleLogic = require "RoleLogic"
    RoleLogic:cacleSyncHistoryPower( _rid, nil, nil, true )
    return { skillId = skillId, skillLevel = 1 }
end

---@see 获取角色统帅技能
function HeroLogic:getRoleAllHeroSkills( _rid, _mainHeroId, _deputyHeroId )
    local mainHeroInfo
    local mainEffect
    if _mainHeroId and _mainHeroId > 0 then
        mainHeroInfo = self:getHero( _rid, _mainHeroId )
        mainEffect = self:getHeroTalentAttr( _rid, _mainHeroId )
    end
    local deputyHeroInfo
    if _deputyHeroId and _deputyHeroId > 0 then
        deputyHeroInfo = self:getHero( _rid, _deputyHeroId )
    end


    local allHeroSkills = {}
    local mainHeroSkills
    if mainHeroInfo and mainHeroInfo.skills then
        mainHeroSkills = mainHeroInfo.skills
        if mainEffect and mainEffect.battleSkill then
            for skillId in pairs(mainEffect.battleSkill) do
                table.insert( mainHeroSkills, { skillId = skillId, skillLevel = 1, talent = true } )
            end
        end
        table.merge( allHeroSkills, mainHeroSkills )
    end

    local deputyHeroSkills
    if deputyHeroInfo and deputyHeroInfo.skills then
        for _, skillInfo in pairs(deputyHeroInfo.skills) do
            skillInfo.deputySkill = true -- 标记为副将技能
        end
        deputyHeroSkills = deputyHeroInfo.skills
        table.merge( allHeroSkills, deputyHeroInfo.skills )
    end
    return allHeroSkills, mainHeroSkills, deputyHeroSkills
end

---@see 获取怪物统帅技能
function HeroLogic:getMonsterAllHeroSkills( _monsterId )
    local allHeroSkills = {}
    local mainHeroSkills = {}
    local deputyHeroSkills = {}
    local mainHeroId
    local deputyHeroId
    local sMonsterInfo = CFG.s_Monster:Get( _monsterId )
    if sMonsterInfo then
        if sMonsterInfo.monsterTroopsId and sMonsterInfo.monsterTroopsId > 0 then
            local sMonsterTroopsInfo = CFG.s_MonsterTroops:Get( sMonsterInfo.monsterTroopsId )
            -- 获取主将
            local mainHeroInfo = CFG.s_Hero:Get(sMonsterTroopsInfo.heroID1)
            mainHeroId = sMonsterTroopsInfo.heroID1
            if mainHeroInfo then
                for index, skillId in pairs(mainHeroInfo.skill) do
                    if index <= 4 and sMonsterTroopsInfo["hero1SkillLevel"..index] > 0 then
                        table.insert( mainHeroSkills, { skillId = skillId, skillLevel = sMonsterTroopsInfo["hero1SkillLevel"..index] } )
                    elseif index == 5 and sMonsterTroopsInfo.hero1AwakenSkill > 0 then
                        table.insert( mainHeroSkills, { skillId = skillId, skillLevel = 1 } )
                    end
                end
                table.merge( allHeroSkills, mainHeroSkills )
            end

            -- 获取副将
            local deputyHeroInfo = CFG.s_Hero:Get(sMonsterTroopsInfo.heroID2)
            deputyHeroId = sMonsterTroopsInfo.heroID2
            if deputyHeroInfo then
                for index, skillId in pairs(deputyHeroInfo.skill) do
                    if index <= 4 and sMonsterTroopsInfo["hero2SkillLevel"..index] > 0 then
                        table.insert( deputyHeroSkills, { skillId = skillId, skillLevel = sMonsterTroopsInfo["hero2SkillLevel"..index], deputySkill = true } )
                    elseif index == 5 and sMonsterTroopsInfo.hero2AwakenSkill > 0 then
                        table.insert( deputyHeroSkills, { skillId = skillId, skillLevel = 1, deputySkill = true } )
                    end
                end
                table.merge( allHeroSkills, deputyHeroSkills )
            end
        end
    end

    return allHeroSkills, mainHeroSkills, deputyHeroSkills, mainHeroId, deputyHeroId
end

---@see 获取怪物主将副将的星级
function HeroLogic:getMonsterStar( _monsterId )
    local monsterTroopsId = CFG.s_Monster:Get( _monsterId, "monsterTroopsId" ) or 0
    if monsterTroopsId > 0 then
        local sMonsterTroopsInfo = CFG.s_MonsterTroops:Get( monsterTroopsId )
        if sMonsterTroopsInfo then
            return sMonsterTroopsInfo.hero1Star, sMonsterTroopsInfo.hero2Star
        end
    end
end

---@see 解锁技能
function HeroLogic:unlockSkill( _rid, _heroId, _star, _heroInfo )
    local heroInfo = _heroInfo or self:getHero( _rid, _heroId )
    local heroConfig = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.HERO_SKILL_OPEN ) or {}
    if heroConfig[_heroId][_star] and _star ~= 5 then
        local new = true
        for _, skillInfo in pairs( heroInfo.skills or {} ) do
            if skillInfo.skillId == heroConfig[_heroId][_star] then
                new = false
                break
            end
        end
        if new then
            table.insert(heroInfo.skills, { skillId =  heroConfig[_heroId][_star], skillLevel = 1 })
        end
    end
end

---@see 增加统帅经验
function HeroLogic:addHeroExp( _rid, _heroId, _addExp )
    local heroInfo = self:getHero( _rid, _heroId )
    local sHeroStar = CFG.s_HeroStar:Get(heroInfo.star)
    if heroInfo.level == sHeroStar.starLimit then
        return false
    end
    local sHero = CFG.s_Hero:Get( _heroId )
    local heroLevelId = sHero.rare * 10000 + heroInfo.level
    local exp = CFG.s_HeroLevel:Get( heroLevelId, "exp" )

    local newExp = heroInfo.exp + _addExp
    heroInfo.exp = newExp
    -- 如果超过经验，则进行升级操作
    local uplevel = false
    while heroInfo.exp >= exp do
        heroInfo.level = heroInfo.level + 1
        local RechargeLogic = require "RechargeLogic"
        RechargeLogic:triggerLimitPackage( _rid, { type = Enum.LimitTimeType.HERO_LEVEL_UP, rare = sHero.rare, level = heroInfo.level } )
        uplevel = true
        -- -- 判断是否有增加天赋点
        -- local talentPoint = CFG.s_HeroLevel:Get(sHero.rare * 10000 + heroInfo.level, "starEffectData" )
        -- if talentPoint >= 1 then
        --     heroInfo.talentPoint = heroInfo.talentPoint + talentPoint
        -- end
        -- 判断星级，判断是否经验溢出
        if heroInfo.level == sHeroStar.starLimit then
            heroInfo.exp = 0
            break
        else
            heroInfo.exp = heroInfo.exp - exp
            heroLevelId = sHero.rare * 10000 + heroInfo.level
            exp = CFG.s_HeroLevel:Get( heroLevelId, "exp" )
        end
    end
    self:setHero( _rid, _heroId, heroInfo )
    self:syncHero( _rid, _heroId, heroInfo, true, true)
    if uplevel then
        local RoleLogic = require "RoleLogic"
        RoleLogic:cacleSyncHistoryPower( _rid, nil, nil, true )
        self:updateMapArmyHero( _rid, _heroId, heroInfo.level )
        local ArmyLogic = require "ArmyLogic"
        ArmyLogic:updateArmyInfoOnHeroInfoChange( _rid, _heroId, heroInfo.level )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.HERO_LEVEL_COUNT )
    end
    return true
end

---@see 增加统帅星级经验
function HeroLogic:addHeroStarExp( _rid, _heroId, _addExp )
    local heroInfo = self:getHero( _rid, _heroId )
    if not CFG.s_HeroStar:Get(heroInfo.star + 1) then
        return false
    end
    local isUpdateStar = false
    local sHeroStar = CFG.s_HeroStar:Get(heroInfo.star)
    local exp = 0
    local sHero = CFG.s_Hero:Get(_heroId)
    if sHero.rare == Enum.HeroRareType.NORMAL then
        exp = sHeroStar.rare1
    elseif sHero.rare == Enum.HeroRareType.EXCELLENT then
        exp = sHeroStar.rare2
    elseif sHero.rare == Enum.HeroRareType.ELITE then
        exp = sHeroStar.rare3
    elseif sHero.rare == Enum.HeroRareType.EPIC then
        exp = sHeroStar.rare4
    elseif sHero.rare == Enum.HeroRareType.LEGEND then
        exp = sHeroStar.rare5
    end
    local newExp = heroInfo.starExp + _addExp
    heroInfo.starExp = newExp
    -- 如果超过经验，则进行升级操作
    while heroInfo.starExp >= exp do
        isUpdateStar = true
        heroInfo.star = heroInfo.star + 1
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.HERO_STAR_LEVEL_COUNT, 1 )
        self:unlockSkill( _rid, _heroId, heroInfo.star, heroInfo )
        -- 判断星级，判断是否经验溢出
        sHeroStar = CFG.s_HeroStar:Get(heroInfo.star + 1)
        -- -- 判断是否有增加天赋点
        -- local talentPoint = CFG.s_HeroStar:Get( heroInfo.star, "starEffectData" )
        -- if talentPoint >= 1 then
        --     heroInfo.talentPoint = heroInfo.talentPoint + talentPoint
        -- end
        if not sHeroStar then
            heroInfo.starExp = 0
            break
        else
            sHeroStar = CFG.s_HeroStar:Get(heroInfo.star)
            heroInfo.starExp = heroInfo.starExp - exp
            if sHero.rare == Enum.HeroRareType.NORMAL then
                exp = sHeroStar.rare1
            elseif sHero.rare == Enum.HeroRareType.EXCELLENT then
                exp = sHeroStar.rare2
            elseif sHero.rare == Enum.HeroRareType.ELITE then
                exp = sHeroStar.rare3
            elseif sHero.rare == Enum.HeroRareType.EPIC then
                exp = sHeroStar.rare4
            elseif sHero.rare == Enum.HeroRareType.LEGEND then
                exp = sHeroStar.rare5
            end
        end
    end
    self:setHero( _rid, _heroId, heroInfo )
    self:syncHero( _rid, _heroId, heroInfo, true, true)
    if isUpdateStar then
        local RoleLogic = require "RoleLogic"
        RoleLogic:cacleSyncHistoryPower( _rid, nil, nil, true )
        self:updateMapArmyHero( _rid, _heroId )
    end
    return true
end

---@see 更新部队统帅信息
function HeroLogic:updateMapArmyHero( _rid, _heroId, _newLevel )
    local ArmyLogic = require "ArmyLogic"
    local RoleLogic = require "RoleLogic"
    local BattleAttrLogic = require "BattleAttrLogic"
    local armyInfos = ArmyLogic:getArmy( _rid )
    local mainHeroId = RoleLogic:getRole( _rid, Enum.Role.mainHeroId )
    local deputyHeroId = RoleLogic:getRole( _rid, Enum.Role.deputyHeroId )
    if _heroId == mainHeroId or deputyHeroId == _heroId then
        local cityIndex = RoleLogic:getRoleCityIndex( _rid )
        local skills = self:getRoleAllHeroSkills( _rid, mainHeroId, deputyHeroId )
        local mainHeroLevel = self:getHeroLevel( _rid, mainHeroId )
        local deputyHeroLevel = self:getHeroLevel( _rid, deputyHeroId )
        local talentAttr = self:getHeroTalentAttr( _rid, mainHeroId ).battleAttr
        if cityIndex then
            BattleAttrLogic:syncObjectHeroChange( cityIndex, Enum.RoleType.ARMY, mainHeroId , mainHeroLevel, deputyHeroId, deputyHeroLevel, skills, talentAttr )
        end
    end
    for armyIndex, armyInfo in pairs(armyInfos) do
        if armyInfo.mainHeroId == _heroId or armyInfo.deputyHeroId == _heroId then
            local skills = self:getRoleAllHeroSkills( _rid, armyInfo.mainHeroId, armyInfo.deputyHeroId )
            local mainHeroLevel = self:getHeroLevel( _rid, armyInfo.mainHeroId )
            local deputyHeroLevel = self:getHeroLevel( _rid, armyInfo.deputyHeroId )
            local talentAttr = self:getHeroTalentAttr(_rid, armyInfo.mainHeroId).battleAttr
            local objectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, armyIndex )
            if objectIndex then
                BattleAttrLogic:syncObjectHeroChange( objectIndex, Enum.RoleType.ARMY, armyInfo.mainHeroId , mainHeroLevel, armyInfo.deputyHeroId, deputyHeroLevel, skills, talentAttr )
            end

            if _newLevel then
                if armyInfo.mainHeroId == _heroId then
                    ArmyLogic:setArmy( _rid, armyIndex, { [Enum.Army.mainHeroLevel] = _newLevel } )
                else
                    ArmyLogic:setArmy( _rid, armyIndex, { [Enum.Army.deputyHeroLevel] = _newLevel } )
                end
            end
            -- 部队采集属性更新
            local ResourceLogic = require "ResourceLogic"
            ResourceLogic:roleArmyCollectSpeedChange( _rid, armyIndex )
            break
        end
    end
end

---@see 获取统帅等级
function HeroLogic:getHeroLevel( _rid, _heroId )
    local heroInfo = self:getHero( _rid, _heroId )
    if heroInfo and not table.empty(heroInfo) then
        return heroInfo.level or 0
    else
        return 0
    end
end

---@see 将领换防回调
function HeroLogic:changeDefenseHeroCallback( _rid, _mainHeroId, _deputyHeroId )
    -- 如果城市处于战斗中
    local RoleLogic = require "RoleLogic"
    local ArmyLogic = require "ArmyLogic"
    local BattleAttrLogic = require "BattleAttrLogic"
    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    if cityIndex and cityIndex > 0 then
        local cityInfo = MSM.SceneCityMgr[cityIndex].req.getCityInfo( cityIndex )
        if cityInfo then
            if ArmyLogic:checkArmyStatus( cityInfo.status, Enum.ArmyStatus.BATTLEING ) then
                -- 通知战斗服务器
                local skills = self:getRoleAllHeroSkills( _rid, _mainHeroId, _deputyHeroId )
                local mainHeroLevel = self:getHeroLevel( _rid, _mainHeroId )
                local deputyHeroLevel = self:getHeroLevel( _rid, _deputyHeroId )
                BattleAttrLogic:syncObjectHeroChange( cityIndex, Enum.RoleType.CITY, _mainHeroId, mainHeroLevel, _deputyHeroId, deputyHeroLevel, skills )
            end
            -- 通知地图城市,主将更换
            MSM.SceneCityMgr[cityIndex].post.syncCityMainHero( cityIndex, _mainHeroId )
        end
    end
end

---@see 统帅技能属性
function HeroLogic:cancleskillAttr( _rid, _heroId )
    local heroInfo = self:getHero( _rid, _heroId )
    -- 计算技能增加的属性
    local battleAttr = {}
    for _, skillInfo in pairs(heroInfo.skills) do
        local sHeroSkillEffect = CFG.s_HeroSkillEffect:Get( skillInfo.skillId * 1000 + skillInfo.skillLevel )
        if sHeroSkillEffect then
            for index, name in pairs(sHeroSkillEffect.attrType) do
                if not battleAttr[name] then battleAttr[name] = 0 end
                battleAttr[name] = battleAttr[name] + ( sHeroSkillEffect.attrNumber[index] or 0 )
            end
        end
    end
    return battleAttr
end

---@see 升级统帅天赋
function HeroLogic:upLevelTalent( _rid, _heroId, _id, _index )
    local heroInfo = self:getHero( _rid, _heroId )
    --heroInfo.talentPoint = heroInfo.talentPoint - 1
    if not heroInfo.talentTrees[_index] then heroInfo.talentTrees[_index] = { index = _index, talentTree = {}, name = "" } end
    table.insert(heroInfo.talentTrees[_index].talentTree, _id)
    self:setHero( _rid, _heroId, heroInfo )
    self:syncHero( _rid, _heroId, heroInfo, true, true)
    -- 增加统帅天赋点选次数
    local TaskLogic = require "TaskLogic"
    TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.HERO_TALENT_NUM, Enum.TaskArgDefault, 1 )
    -- 计算天赋战力
    local RoleLogic = require "RoleLogic"
    RoleLogic:cacleSyncHistoryPower( _rid, nil, nil, true )
    self:updateMapArmyHero( _rid, _heroId )
    return { result = true }
end

---@see 判断统帅能否学习该天赋
function HeroLogic:checkHeroStudyTalent( _heroId, _id )
    local talent = CFG.s_Hero:Get(_heroId, "talent")
    for _, talentId in pairs( talent ) do
        local gainTree = CFG.s_HeroTalent:Get(talentId, "gainTree")
        local talentConfig = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.TALENT)
        gainTree = tonumber(gainTree)
        if talentConfig[gainTree][_id] then
            return true
        end
    end
    return false
end

---@see 判断天赋点是否充足
function HeroLogic:checkTalentPoint( _rid, _heroId, _index )
    local heroInfo = HeroLogic:getHero( _rid, _heroId )
    local rare = CFG.s_Hero:Get( _heroId, "rare" )
    local heroLevel = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.HERO_LEVEL_TALENT)[rare]
    local heroStar = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.HERO_STAR_TALENT)
    local talentPoint = 0
    -- 统帅等级影响的天赋点
    for level, point in pairs(heroLevel) do
        if heroInfo.level >= level then
            talentPoint = talentPoint + point
        end
    end
    -- 统帅星级影响天赋点
    for star, point in pairs(heroStar) do
        if heroInfo.star >= star then
            talentPoint = talentPoint + point
        end
    end
    if not heroInfo.talentTrees[_index] and talentPoint > 0 then return true end
    if heroInfo.talentTrees[_index] then
        for _ in pairs(heroInfo.talentTrees[_index].talentTree) do
            talentPoint = talentPoint - 1
        end
        if talentPoint > 0 then return true end
    end
    return false
end

---@see 判断天赋前置是否学习
function HeroLogic:checkHeroStudyTalentPre( _rid, _heroId, _index, _id )
    local heroInfo = self:getHero( _rid, _heroId )
    local level = CFG.s_HeroTalentGainTree:Get( _id, "level" )
    if level == 1 then
        return true
    end
    if not heroInfo.talentTrees or not heroInfo.talentTrees[_index] or not heroInfo.talentTrees[_index].talentTree then
        return false
    end
    local talentTree = heroInfo.talentTrees[_index].talentTree or {}
    for _, id in pairs(talentTree) do
        if CFG.s_HeroTalentGainTree:Get( id, "level" ) + 1 == level then
            return true
        end
    end
    return false
end

---@see 判断天赋前置是否学习
function HeroLogic:checkHeroStudyTalentSame( _rid, _heroId, _index, _id )
    local heroInfo = self:getHero( _rid, _heroId )
    local level = CFG.s_HeroTalentGainTree:Get( _id, "level" )
    if not heroInfo.talentTrees or not heroInfo.talentTrees[_index] or not heroInfo.talentTrees[_index].talentTree then
        return true
    end
    local talentTree = heroInfo.talentTrees[_index].talentTree or {}
    for _, id in pairs(talentTree) do
        if CFG.s_HeroTalentGainTree:Get( id, "level" ) == level then
            return false
        end
    end
    return true
end

---@see 返回天赋影响的属性
function HeroLogic:getHeroTalentAttr( _rid, _heroId )
    local heroInfo = self:getHero( _rid, _heroId )
    local talentTree = {}
    if heroInfo.talentTrees and heroInfo.talentTrees[heroInfo.talentIndex] then
        talentTree = heroInfo.talentTrees[heroInfo.talentIndex].talentTree
    end
    local battleSkill = {}
    local battleAttr = {}
    -- 根据天赋分组计算点数
    local talentCount = {}

    -- 计算天赋加成
    for _, id in pairs(talentTree) do
        local sHeroTalentGainTree = CFG.s_HeroTalentGainTree:Get( id )
        if sHeroTalentGainTree.battleSkillID and sHeroTalentGainTree.battleSkillID > 0 then
            battleSkill[sHeroTalentGainTree.battleSkillID] = sHeroTalentGainTree.battleSkillID
        end
        local attrType = sHeroTalentGainTree.attrType
        local attrNumber = sHeroTalentGainTree.attrNumber
        for i=1,table.size(attrType) do
            local attrName = attrType[i]
            local num = attrNumber[i]
            if not battleAttr[attrName] then battleAttr[attrName] = 0 end
            battleAttr[attrName] = battleAttr[attrName] + num
        end
        local gainTree = sHeroTalentGainTree.gainTree
        if not talentCount[gainTree] then talentCount[gainTree] = 0 end
        talentCount[gainTree] = talentCount[gainTree] + 1
    end
    -- 计算专精加成
    local sHeroTalentMastery = CFG.s_HeroTalentMastery:Get()
    for gainTree, count in pairs(talentCount) do
        for i=count,1, -1 do
            local heroTalentMastery = sHeroTalentMastery[gainTree][i]
            if heroTalentMastery then
                if heroTalentMastery.battleSkillID and heroTalentMastery.battleSkillID > 0 then
                    battleSkill[heroTalentMastery.battleSkillID] = heroTalentMastery.battleSkillID
                end
                local attrType = heroTalentMastery.attrType
                local attrNumber = heroTalentMastery.attrNumber
                for j=1,table.size(attrType) do
                    local attrName = attrType[j]
                    local num = attrNumber[j]
                    if not battleAttr[attrName] then battleAttr[attrName] = 0 end
                    battleAttr[attrName] = battleAttr[attrName] + num
                end
            end
        end
    end
    return { battleSkill = battleSkill, battleAttr = battleAttr }
end

---@see 返回统帅属性
function HeroLogic:getHeroAttr( _rid, _heroId, _attrName, _notCancleTalent )
    local num = 0
    if not _heroId or _heroId <= 0 then
        return num
    end
    local effect
    if not _notCancleTalent then
        -- 天赋
        effect = self:getHeroTalentAttr( _rid, _heroId )
        if effect and effect.battleAttr and effect.battleAttr[_attrName] then
            num = num + effect.battleAttr[_attrName]
        end
        -- 装备
        effect = self:getHeroEquipAttr( _rid, _heroId )
        if effect and effect.battleAttr and effect.battleAttr[_attrName] then
            num = num + effect.battleAttr[_attrName]
        end
    end
    effect = self:cancleskillAttr( _rid, _heroId )
    if effect and effect[_attrName] then
        num = num + effect[_attrName]
    end
    return num
end


---@see 返回统帅装备影响的属性和技能
function HeroLogic:getHeroEquipAttr( _rid, _heroId )
    local heroInfo = self:getHero( _rid, _heroId )
    local equips = { Enum.Hero.head,  Enum.Hero.breastPlate, Enum.Hero.weapon, Enum.Hero.gloves,
                Enum.Hero.pants, Enum.Hero.accessories1, Enum.Hero.accessories2, Enum.Hero.shoes }
    local battleSkill = {}
    local battleAttr = {}

    local sEquipAtt = CFG.s_EquipAtt:Get()
    local sEquip = CFG.s_Equip:Get()
    local ItemLogic = require "ItemLogic"
    local equipCompose = {}
    for _, pos in pairs(equips) do
        repeat
            if heroInfo[pos] and heroInfo[pos] > 0 then
                local itemInfo = ItemLogic:getItem( _rid, heroInfo[pos] )
                if not itemInfo or table.empty(itemInfo) then
                    break -- 道具装不存在了
                end
                local attr = sEquip[itemInfo.itemId].att
                local compose = sEquip[itemInfo.itemId].compose
                if compose > 0 then
                    if not equipCompose[compose] then equipCompose[compose] = 0 end
                    equipCompose[compose] = equipCompose[compose] + 1
                end
                for i=1,table.size(attr) do
                    local attrKey = attr[i]
                    local attrName = sEquipAtt[attrKey].att
                    if not battleAttr[attrName] then battleAttr[attrName] = 0 end
                    local num = sEquip[itemInfo.itemId].attAddEx[i]
                    -- 判断是否专属
                    if itemInfo.exclusive and itemInfo.exclusive > 0 and self:checkHeroTalent( _heroId, itemInfo.exclusive ) then
                        local equipTalentPromote = CFG.s_Config:Get("equipTalentPromote")
                        num = math.ceil( equipTalentPromote * num * 2 ) / 2
                    end
                    battleAttr[attrName] = battleAttr[attrName] + num
                end
            end
        until true
    end
    -- 计算套装属性
    for compose, count in pairs(equipCompose) do
        local sEquipCompose = CFG.s_EquipCompose:Get(compose)
        if count >= 2 then
            local attr = sEquipCompose.compose2
            for i=1,table.size(attr) do
                local attrKey = attr[i]
                local attrName = sEquipAtt[attrKey].att
                if not battleAttr[attrName] then battleAttr[attrName] = 0 end
                local num = sEquipCompose.compose2AddEx[i]
                battleAttr[attrName] = battleAttr[attrName] + num
            end
        end
        if count >= 4 then
            local attr = sEquipCompose.compose4
            for i=1,table.size(attr) do
                local attrKey = attr[i]
                local attrName = sEquipAtt[attrKey].att
                if not battleAttr[attrName] then battleAttr[attrName] = 0 end
                local num = sEquipCompose.compose4AddEx[i]
                battleAttr[attrName] = battleAttr[attrName] + num
            end
        end
        if count >= 6 then
            local attr = sEquipCompose.compose6
            for i=1,table.size(attr) do
                local attrKey = attr[i]
                local attrName = sEquipAtt[attrKey].att
                if not battleAttr[attrName] then battleAttr[attrName] = 0 end
                local num = sEquipCompose.compose6AddEx[i]
                battleAttr[attrName] = battleAttr[attrName] + num
            end
        end
        if count >= 8 then
            local attr = sEquipCompose.compose8
            for i=1,table.size(attr) do
                local attrKey = attr[i]
                local attrName = sEquipAtt[attrKey].att
                if not battleAttr[attrName] then battleAttr[attrName] = 0 end
                local num = sEquipCompose.compose8AddEx[i]
                battleAttr[attrName] = battleAttr[attrName] + num
            end
        end
    end
    return { battleSkill = battleSkill, battleAttr = battleAttr }
end

---@see 判断统帅是否拥有某种天赋
function HeroLogic:checkHeroTalent( _heroId, _type )
    local talent = CFG.s_Hero:Get( _heroId, "talent" )
    for _, id in pairs(talent) do
        local type = CFG.s_HeroTalent:Get( id, "type" )
        if _type == type then
            return true
        end
    end
    return false
end

---@see 一键升级统帅
function HeroLogic:pmUse( _rid, _heroId )
    while true do
        local result = self:addHeroStarExp( _rid, _heroId, 1000000 )
        if not result then break end
    end
    while true do
        local result = self:addHeroExp( _rid, _heroId, 1000000 )
        if not result then break end
    end
    while true do
        if self:checkHeroSkillFull( _rid, _heroId ) then
            break
        end
        self:heroSkillLevelUp( _rid, _heroId )
    end
end

---@see 扣除主将技能天赋减免行动力和副将技能减免行动力
function HeroLogic:subHeroVitality( _rid, _armyInfo, _mainHeroId, _deputyHeroId, _vitality )
    _mainHeroId = _mainHeroId or ( _armyInfo and _armyInfo.mainHeroId )
    if _mainHeroId and _mainHeroId > 0 then
        _vitality = _vitality - self:getHeroAttr( _rid, _mainHeroId, Enum.Role.vitalityReduction )
    end

    _deputyHeroId = _deputyHeroId or ( _armyInfo and _armyInfo.deputyHeroId )
    if _deputyHeroId and _deputyHeroId > 0 then
        _vitality = _vitality - self:getHeroAttr( _rid, _deputyHeroId, Enum.Role.vitalityReduction, true )
    end

    return math.max( _vitality, 0 )
end

return HeroLogic