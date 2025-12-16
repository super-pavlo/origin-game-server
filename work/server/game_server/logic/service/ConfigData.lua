 --[[
* @file : ConfigData.lua
* @type : snax single service
* @author : linfeng
* @created : Thu Dec 07 2017 14:57:29 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 重新初始化静态数据组织结构,便于程序访问
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local Timer = require "Timer"
local DenseFogLogic = require "DenseFogLogic"
local EntityImpl = require "EntityImpl"

-- ---@see 根据建筑类型建筑等级重新划分建筑升级表
-- local function reInitsBuildingLevelData()
--     local sBuildingLevelData = CFG.s_BuildingLevelData:Get()
--     local newSBuildingLevelData = {}
--     for _, buildingLevelData in pairs(sBuildingLevelData) do
--         if not newSBuildingLevelData[buildingLevelData.type] then newSBuildingLevelData[buildingLevelData.type] = {} end
--         if not newSBuildingLevelData[buildingLevelData.type][buildingLevelData.level] then
--             newSBuildingLevelData[buildingLevelData.type][buildingLevelData.level] = buildingLevelData
--         end
--     end
--     SM.s_BuildingLevelData.req.Set( newSBuildingLevelData )
-- end


---@see 根据建筑等级重新划分兵营建筑表
local function reInitsBuildingBarracks()
    local sBuildingBarracks = EntityImpl:loadConfig( "s_BuildingBarracks" )
    local newSBuildingBarracks = {}
    for _, buildingBarracks in pairs(sBuildingBarracks) do
        newSBuildingBarracks[buildingBarracks.level] = buildingBarracks
    end
    SM.s_BuildingBarracks.req.Set( newSBuildingBarracks )
end

---@see 根据建筑等级重新划分弓兵建筑表
local function reInitsBuildingArcheryrange()
    local sBuildingArcheryrange = EntityImpl:loadConfig( "s_BuildingArcheryrange" )
    local newSBuildingArcheryrange = {}
    for _, buildingArcheryrange in pairs(sBuildingArcheryrange) do
        newSBuildingArcheryrange[buildingArcheryrange.level] = buildingArcheryrange
    end
    SM.s_BuildingArcheryrange.req.Set( newSBuildingArcheryrange )
end

---@see 根据建筑等级重新划分骑兵建筑表
local function reInitsBuildingStable()
    local sBuildingStable = EntityImpl:loadConfig( "s_BuildingStable" )
    local newSBuildingStable = {}
    for _, buildingStable in pairs(sBuildingStable) do
        newSBuildingStable[buildingStable.level] = buildingStable
    end
    SM.s_BuildingStable.req.Set( newSBuildingStable )
end

---@see 根据建筑等级重新划分攻城建筑表
local function reInitsBuildingSiegeWorkshop()
    local sBuildingSiegeWorkshop = EntityImpl:loadConfig( "s_BuildingSiegeWorkshop" )
    local newSBuildingSiegeWorkshop = {}
    for _, buildingSiegeWorkshop in pairs(sBuildingSiegeWorkshop) do
        newSBuildingSiegeWorkshop[buildingSiegeWorkshop.level] = buildingSiegeWorkshop
    end
    SM.s_BuildingSiegeWorkshop.req.Set( newSBuildingSiegeWorkshop )
end

---@see 根据建筑等级重新划分市政厅表
local function reInitsBuildingTownCenter()
    local sBuildingTownCenter = EntityImpl:loadConfig( "s_BuildingTownCenter" )
    local newSBuildingTownCenter = {}
    for _, buildingTownCenter in pairs(sBuildingTownCenter) do
        newSBuildingTownCenter[buildingTownCenter.level] = buildingTownCenter
    end
    SM.s_BuildingTownCenter.req.Set( newSBuildingTownCenter )
end

---@see 根据建筑等级重新划分城墙表
local function reInitsBuildingCityWall()
    local sBuildingCityWall = EntityImpl:loadConfig( "s_BuildingCityWall" )
    local newSBuildingCityWall = {}
    for _, buildingCityWall in pairs(sBuildingCityWall) do
        newSBuildingCityWall[buildingCityWall.level] = buildingCityWall
    end
    SM.s_BuildingCityWall.req.Set( newSBuildingCityWall )
end

---@see 根据建筑等级重新划分警戒塔表
local function reInitsBuildingGuardTower()
    local sBuildingGuardTower = EntityImpl:loadConfig( "s_BuildingGuardTower" )
    local newSBuildingGuardTower = {}
    for _, buildingGuardTower in pairs(sBuildingGuardTower) do
        newSBuildingGuardTower[buildingGuardTower.level] = buildingGuardTower
    end
    SM.s_BuildingGuardTower.req.Set( newSBuildingGuardTower )
end

---@see 根据建筑等级重新划分学院表
local function reInitsBuildingCampus()
    local sBuildingCampus = EntityImpl:loadConfig( "s_BuildingCampus" )
    local newSBuildingCampus = {}
    for _, buildingCampus in pairs(sBuildingCampus) do
        newSBuildingCampus[buildingCampus.level] = buildingCampus
    end
    SM.s_BuildingCampus.req.Set( newSBuildingCampus )
end

---@see 根据建筑等级重新划分医院表
local function reInitsBuildingHospital()
    local sBuildingHospital = EntityImpl:loadConfig( "s_BuildingHospital" )
    local newSBuildingHospital = {}
    for _, buildingHospital in pairs(sBuildingHospital) do
        newSBuildingHospital[buildingHospital.level] = buildingHospital
    end
    SM.s_BuildingHospital.req.Set( newSBuildingHospital )
end

---@see 根据建筑等级重新划分城堡表
local function reInitsBuildingCastle()
    local sBuildingCastle = EntityImpl:loadConfig( "s_BuildingCastle" )
    local newSBuildingCastle = {}
    for _, buildingCastle in pairs(sBuildingCastle) do
        newSBuildingCastle[buildingCastle.level] = buildingCastle
    end
    SM.s_BuildingCastle.req.Set( newSBuildingCastle )
end

---@see 根据建筑等级重新划分斥候营地表
local function reInitsBuildingScoutcamp()
    local sBuildingScoutcamp = EntityImpl:loadConfig( "s_BuildingScoutcamp" )
    local newSBuildingScoutcamp = {}
    for _, buildingScoutcamp in pairs(sBuildingScoutcamp) do
        newSBuildingScoutcamp[buildingScoutcamp.level] = buildingScoutcamp
    end
    SM.s_BuildingScoutcamp.req.Set( newSBuildingScoutcamp )
end

---@see 根据建筑等级重新划分商栈表
local function reInitsBuildingFreight()
    local sBuildingFreight = EntityImpl:loadConfig( "s_BuildingFreight" )
    local newSBuildingFreight = {}
    for _, buildingFreight in pairs(sBuildingFreight) do
        newSBuildingFreight[buildingFreight.level] = buildingFreight
    end
    SM.s_BuildingFreight.req.Set( newSBuildingFreight )
end


---@see 更新s_ZeroEmpty表
local function addSZeroEmpty( _attrName, _attrValue )
    local sZeroEmpty = CFG.s_ZeroEmpty:Get() or {}
    local newsZeroEmpty = {}
    for key, value in pairs( sZeroEmpty ) do
        newsZeroEmpty[key] = value
    end
    newsZeroEmpty[_attrName] = _attrValue

    SM.s_ZeroEmpty.req.Set( newsZeroEmpty )
end

---@see 从s_Arms初始化StudyId到s_ZeroEmpty中s_Arms
local function initSAmryStudy()
    local sArmsInfos = CFG.s_Arms:Get()
    local sArmsStudy = {}

    for _, armsInfo in pairs(sArmsInfos) do
        if armsInfo.subType == 1 then
            if not sArmsStudy[armsInfo.armsType] then sArmsStudy[armsInfo.armsType] = {} end
            if not sArmsStudy[armsInfo.armsType][armsInfo.armsLv] then
                sArmsStudy[armsInfo.armsType][armsInfo.armsLv] = { armsType = armsInfo.armsType, armsLv = armsInfo.armsLv, studyId = armsInfo.studyID }
            end
        end
    end
    addSZeroEmpty( Enum.ZeroEmptyType.ARMY_STUDY , sArmsStudy )
end

---@see 根据文明兵种类型兵种id取出对应配置表
local function reInitsArms()
    local sCivilization = CFG.s_Civilization:Get()
    local sArmsInfos = CFG.s_Arms:Get()
    local newTable = {}
    for _, civilization in pairs(sCivilization) do
        if not newTable[civilization.ID] then newTable[civilization.ID] = {} end
        local featureArms = civilization.featureArms
        for _, id in pairs(featureArms) do
            if id > 0 then
                local armsInfo = CFG.s_Arms:Get(id)
                if not newTable[civilization.ID][armsInfo.armsType] then newTable[civilization.ID][armsInfo.armsType] = {} end
                newTable[civilization.ID][armsInfo.armsType][armsInfo.armsLv] = armsInfo
            end
        end
        for _, info in pairs(sArmsInfos) do
            if not newTable[civilization.ID][info.armsType] then newTable[civilization.ID][info.armsType] = {} end
            if not newTable[civilization.ID][info.armsType][info.armsLv] and info.subType == Enum.ArmySubType.COMMON then
                newTable[civilization.ID][info.armsType][info.armsLv] = info
            end
        end
    end
    addSZeroEmpty( Enum.ZeroEmptyType.ARMY, newTable )
end


---@see 根据建筑类型等级重新划分s_BuildingResourcesProduce
local function reInitsBuildingResourcesProduce()
    local sBuildingResourcesProduce = EntityImpl:loadConfig( "s_BuildingResourcesProduce" )
    local newSBuildingResourbcesProduce = {}
    for _, buildingResourcesProduce in pairs(sBuildingResourcesProduce) do
        if not newSBuildingResourbcesProduce[buildingResourcesProduce.type] then newSBuildingResourbcesProduce[buildingResourcesProduce.type] = {} end
        newSBuildingResourbcesProduce[buildingResourcesProduce.type][buildingResourcesProduce.level] = buildingResourcesProduce
    end
    SM.s_BuildingResourcesProduce.req.Set( newSBuildingResourbcesProduce )
end

---@see 重新划分s_ItemPackage
local function reInitsItemPackage()
    local sItemPackage = EntityImpl:loadConfig( "s_ItemPackage" )
    local newSItemPackage = {}
    for _, itemPackage in pairs( sItemPackage ) do
        if not newSItemPackage[itemPackage.group] then newSItemPackage[itemPackage.group] = {} end
        table.insert( newSItemPackage[itemPackage.group], itemPackage )
    end
    SM.s_ItemPackage.req.Set( newSItemPackage )
end

---@see 从s_Study初始化studyType到s_ZeroEmpty中
local function initsStudy()
    local sStudyInfos = CFG.s_Study:Get()
    local sStudy = {}

    for _, studyInfo in pairs(sStudyInfos) do
        if not sStudy[studyInfo.studyType] then sStudy[studyInfo.studyType] = {} end
        if not sStudy[studyInfo.studyType][studyInfo.studyLv] then
            sStudy[studyInfo.studyType][studyInfo.studyLv] = { id = studyInfo.ID }
        end
    end
    addSZeroEmpty( Enum.ZeroEmptyType.STUDY , sStudy )
end

---@see 初始化s_TaskChapter表中的任务id到s_ZeroEmpty中
local function initSTaskChapter()
    local sTaskChapter = CFG.s_TaskChapter:Get()
    local chapterTasks = {}

    for _, taskChapter in pairs( sTaskChapter ) do
        if not chapterTasks[taskChapter.chapterId] then
            chapterTasks[taskChapter.chapterId] = {}
        end
        chapterTasks[taskChapter.chapterId][taskChapter.ID] = true
    end

    addSZeroEmpty( Enum.ZeroEmptyType.CHAPTER_TASK, chapterTasks )
end

---@see 重置s_MonsterRefreshLevel表索引
local function initSMonsterRefreshLevel()
    local sMonsterRefreshLevel = EntityImpl:loadConfig( "s_MonsterRefreshLevel" )
    local newSMonsterRefreshLevel = {}
    local barbarianRefreshs = {}
    local monsterCityRefreshs = {}
    local openDayArg

    for _, refreshInfo in pairs( sMonsterRefreshLevel ) do
        openDayArg = string.format( "%d-%d", refreshInfo.serverLevelMin, refreshInfo.serverLevelMax )
        if refreshInfo.chance > 0 then
            if not newSMonsterRefreshLevel[refreshInfo.monsterType] then
                newSMonsterRefreshLevel[refreshInfo.monsterType] = {}
            end

            if not newSMonsterRefreshLevel[refreshInfo.monsterType][openDayArg] then
                newSMonsterRefreshLevel[refreshInfo.monsterType][openDayArg] = {}
            end
            if not newSMonsterRefreshLevel[refreshInfo.monsterType][openDayArg][refreshInfo.zoneLevel] then
                newSMonsterRefreshLevel[refreshInfo.monsterType][openDayArg][refreshInfo.zoneLevel] = {}
            end
            table.insert( newSMonsterRefreshLevel[refreshInfo.monsterType][openDayArg][refreshInfo.zoneLevel], {
                id = refreshInfo, rate = refreshInfo.chance
            } )
        end

        if refreshInfo.monsterType == Enum.MonsterType.BARBARIAN then
            if not barbarianRefreshs[openDayArg] then
                barbarianRefreshs[openDayArg] = refreshInfo.monsterLevel
            else
                if barbarianRefreshs[openDayArg] < refreshInfo.monsterLevel then
                    barbarianRefreshs[openDayArg] = refreshInfo.monsterLevel
                end
            end
        elseif refreshInfo.monsterType == Enum.MonsterType.BARBARIAN_CITY then
            if not monsterCityRefreshs[refreshInfo.zoneLevel] then
                monsterCityRefreshs[refreshInfo.zoneLevel] = {}
            end
            table.insert( monsterCityRefreshs[refreshInfo.zoneLevel], { monsterLevel = refreshInfo.monsterLevel, chance = refreshInfo.chance } )
        end
    end

    SM.s_MonsterRefreshLevel.req.Set( newSMonsterRefreshLevel )
    addSZeroEmpty( Enum.ZeroEmptyType.BARBARIAN_REFRESH, barbarianRefreshs )
    addSZeroEmpty( Enum.ZeroEmptyType.MONSTER_CITY_REFRESH, monsterCityRefreshs )
end

---@see 重置s_MonsterPoint表索引
local function initSMonsterPoint()
    local MapLogic = require "MapLogic"

    local sMonsterPoint = EntityImpl:loadConfig( "s_MonsterPoint" )
    local newSMonsterPoint = {}
    local posMultiple = Enum.MapPosMultiple
    local zoneIndex, pos
    local guardGroupPoint = {}
    for _, point in pairs( sMonsterPoint ) do
        pos = { x = point.posX * posMultiple, y = point.posY * posMultiple }
        zoneIndex = MapLogic:getZoneIndexByPos( pos )
        if point.type ~= Enum.MonsterType.HOLYLAND_GUARDIAN then
            if not newSMonsterPoint[point.type] then
                newSMonsterPoint[point.type] = {}
            end
            if not newSMonsterPoint[point.type][zoneIndex] then
                newSMonsterPoint[point.type][zoneIndex] = {}
            end
            table.insert( newSMonsterPoint[point.type][zoneIndex], pos )
        else
            if not guardGroupPoint[point.group] then
                guardGroupPoint[point.group] = {}
            end
            table.insert( guardGroupPoint[point.group], { id = pos, rate = 1 } )
        end
    end

    SM.s_MonsterPoint.req.Set( newSMonsterPoint )
    addSZeroEmpty( Enum.ZeroEmptyType.GUARD_GROUP_POINT, guardGroupPoint )
end

---@see 重置s_ResourceGatherPoint表索引
local function initSResourceGatherPoint()
    local MapLogic = require "MapLogic"

    local sResourceGatherPoint = EntityImpl:loadConfig( "s_ResourceGatherPoint" )
    local newSResourceGatherPoint = {}
    local posMultiple = Enum.MapPosMultiple
    local zoneIndex, pos
    for _, point in pairs( sResourceGatherPoint ) do
        pos = { x = point.posX * posMultiple, y = point.posY * posMultiple }
        zoneIndex = MapLogic:getZoneIndexByPos( pos )
        if not newSResourceGatherPoint[zoneIndex] then
            newSResourceGatherPoint[zoneIndex] = {}
        end
        table.insert( newSResourceGatherPoint[zoneIndex], pos )
    end

    SM.s_ResourceGatherPoint.req.Set( newSResourceGatherPoint )
end

---@see 重置s_ResourceGatherRule表索引
local function initSResourceGatherRule()
    local sResourceGatherRule = EntityImpl:loadConfig( "s_ResourceGatherRule" )
    local newSResourceGatherRule = {}

    local resourceId
    for _, ruleInfo in pairs( sResourceGatherRule ) do
        if ruleInfo.resourceGatherCnt > 0 then
            if not newSResourceGatherRule[ruleInfo.ruleId] then
                newSResourceGatherRule[ruleInfo.ruleId] = {}
            end
            resourceId = ruleInfo.resourceGatherType * 10000 + ruleInfo.resourceGatherLevel
            newSResourceGatherRule[ruleInfo.ruleId][resourceId] = ruleInfo
        end
    end

    SM.s_ResourceGatherRule.req.Set( newSResourceGatherRule )
end

---@see 重置s_BuildingAllianceCenter表索引
local function initSBuildingAllianceCenter()
    local sBuildingAllianceCenter = EntityImpl:loadConfig( "s_BuildingAllianceCenter" )
    local newSBuildingAllianceCenter = {}

    for _, buildInfo in pairs( sBuildingAllianceCenter ) do
        newSBuildingAllianceCenter[buildInfo.level] = buildInfo
    end

    SM.s_BuildingAllianceCenter.req.Set( newSBuildingAllianceCenter )
end

---@see 重置s_MonsterTroopsAttr表索引
local function initSMonsterTroopsAttr()
    local sMonsterTroopsAttr = EntityImpl:loadConfig( "s_MonsterTroopsAttr" )
    local newMonsterTroopsAttr = {}

    for _, monsterTroopsAttr in pairs( sMonsterTroopsAttr ) do
        if not newMonsterTroopsAttr[monsterTroopsAttr.group] then
            newMonsterTroopsAttr[monsterTroopsAttr.group] = {}
        end
        table.insert( newMonsterTroopsAttr[monsterTroopsAttr.group], monsterTroopsAttr )
    end

    SM.s_MonsterTroopsAttr.req.Set( newMonsterTroopsAttr )
end

---@see 重置s_VillageRewardData表索引
local function initSVillageRewardData()
    local sVillageRewardData = EntityImpl:loadConfig( "s_VillageRewardData" )
    local newVillageRewardData = {}

    for _, villageRewardData in pairs( sVillageRewardData ) do
        if not newVillageRewardData[villageRewardData.reqLevel] then
            newVillageRewardData[villageRewardData.reqLevel] = {}
        end
        table.insert( newVillageRewardData[villageRewardData.reqLevel], { id = villageRewardData, rate = villageRewardData.chance } )
    end

    SM.s_VillageRewardData.req.Set( newVillageRewardData )
end

---@see 更新s_MapFixPoint表坐标
local function initSMapFixPoint()
    local sMapFixPoint = EntityImpl:loadConfig( "s_MapFixPoint" )
    local newMapFixPoint = {}
    local villageCaves = {}

    local denseFogIndex, bitIndex
    local posMultiple = Enum.MapPosMultiple
    for id, mapFixPoint in pairs( sMapFixPoint ) do
        mapFixPoint.posX = mapFixPoint.posX * posMultiple
        mapFixPoint.posY = mapFixPoint.posY * posMultiple

        newMapFixPoint[id] = mapFixPoint

        denseFogIndex, bitIndex = DenseFogLogic:getDenseFogIndexByPos( { x = mapFixPoint.posX, y = mapFixPoint.posY } )
        if not villageCaves[denseFogIndex] then
            villageCaves[denseFogIndex] = {}
        end
        if not villageCaves[denseFogIndex][bitIndex] then
            villageCaves[denseFogIndex][bitIndex] = {}
        end
        table.insert( villageCaves[denseFogIndex][bitIndex], id )
    end

    SM.s_MapFixPoint.req.Set( newMapFixPoint )
    addSZeroEmpty( Enum.ZeroEmptyType.VILLAGE_CAVE, villageCaves )
end

---@see 重置s_BuildingMail表索引
local function initSBuildingMail()
    local sBuildingMail = EntityImpl:loadConfig( "s_BuildingMail" )
    local newBuildingMail = {}

    for _, buildingMailData in pairs( sBuildingMail ) do
        if not newBuildingMail[buildingMailData.buildingType] then
            newBuildingMail[buildingMailData.buildingType] = {}
        end
        newBuildingMail[buildingMailData.buildingType][buildingMailData.level] = buildingMailData.mailID
    end

    SM.s_BuildingMail.req.Set( newBuildingMail )
end

---@see 从s_Item初始化subType到s_ZeroEmpty中
local function initSSubItemType()
    local sItemInfos = CFG.s_Item:Get()
    local sSubItemType = {}

    for itemID, itemInfo in pairs( sItemInfos ) do
        if not sSubItemType[itemInfo.subType] then sSubItemType[itemInfo.subType] = {} end
        table.insert( sSubItemType[itemInfo.subType], { id = itemID, rate = 1 } )
    end

    addSZeroEmpty( Enum.ZeroEmptyType.SUB_ITEM_TYPE, sSubItemType )
end

---@see 根据等级初始化酒馆箱子表
local function initSBuildingTavern()
    local sBuildingTavern = EntityImpl:loadConfig( "s_BuildingTavern" )
    local newSBuildingTavern= {}

    for _, info in pairs( sBuildingTavern ) do
       newSBuildingTavern[info.level] = info
    end

    SM.s_BuildingTavern.req.Set( newSBuildingTavern )
end

---@see 从s_TaskDaily初始化age到s_ZeroEmpty中
local function initSAgeDailyTask()
    local sTaskDaily = CFG.s_TaskDaily:Get()
    local ageDailyTasks = {}

    for taskId, taskInfo in pairs( sTaskDaily ) do
        for _, age in pairs( taskInfo.age or {} ) do
            if not ageDailyTasks[age] then
                ageDailyTasks[age] = {}
            end
            ageDailyTasks[age][taskId] = true
        end
    end

    addSZeroEmpty( Enum.ZeroEmptyType.DAILY_TASK, ageDailyTasks )
end

---@see 重置s_TaskActivityReward表
local function initSTaskActivityReward()
    local sTaskActivityReward = EntityImpl:loadConfig( "s_TaskActivityReward" )
    local newSTaskActivityReward = {}
    for age, taskActivityReward in pairs( sTaskActivityReward ) do
        newSTaskActivityReward[age] = {}
        newSTaskActivityReward[age][taskActivityReward.activePoints1] = taskActivityReward.reward1
        newSTaskActivityReward[age][taskActivityReward.activePoints2] = taskActivityReward.reward2
        newSTaskActivityReward[age][taskActivityReward.activePoints3] = taskActivityReward.reward3
        newSTaskActivityReward[age][taskActivityReward.activePoints4] = taskActivityReward.reward4
        newSTaskActivityReward[age][taskActivityReward.activePoints5] = taskActivityReward.reward5
    end

    SM.s_TaskActivityReward.req.Set( newSTaskActivityReward )
end

---@see 重置s_HeroSkillLevel表
local function initSHeroSkillLevel()
    local sHeroSkillLevel = EntityImpl:loadConfig( "s_HeroSkillLevel" )
    local newSHeroSkillLevel = {}
    for _, heroSkillLevel in pairs( sHeroSkillLevel ) do
        newSHeroSkillLevel[heroSkillLevel.level] = heroSkillLevel
    end
    SM.s_HeroSkillLevel.req.Set( newSHeroSkillLevel )
end


---@see 重置s_HeroSkill初始化到s_ZeroEmpty表
local function initSHeroSkill()
    local sHeroSkill = CFG.s_HeroSkill:Get()
    local newsHeroSkill = {}
    for _, heroSkill in pairs( sHeroSkill ) do
        local heroId = heroSkill.ID / 100 // 1
        if not newsHeroSkill[heroId] then newsHeroSkill[heroId] = {} end
        newsHeroSkill[heroId][heroSkill.open] = heroSkill.ID
    end
    addSZeroEmpty( Enum.ZeroEmptyType.HERO_SKILL_OPEN, newsHeroSkill )
end

---@see 重置s_AllianceMember表索引
local function initSAllianceMember()
    local sAllianceMember = EntityImpl:loadConfig( "s_AllianceMember" )
    local newAllianceMember = {}

    for _, allianceMember in pairs( sAllianceMember ) do
        newAllianceMember[allianceMember.lv] = allianceMember.researchersLimit
    end

    SM.s_AllianceMember.req.Set( newAllianceMember )
end

---@see 重置s_AllianceMemberJurisdiction表索引
local function initSAllianceMemberJurisdiction()
    local sAllianceMemberJurisdiction = EntityImpl:loadConfig( "s_AllianceMemberJurisdiction" )
    local newJurisdiction = {}

    for _, jurisdiction in pairs( sAllianceMemberJurisdiction ) do
        if not newJurisdiction[jurisdiction.type] then
            newJurisdiction[jurisdiction.type] = {}
        end
        newJurisdiction[jurisdiction.type][Enum.GuildJob.R1] = jurisdiction.R1
        newJurisdiction[jurisdiction.type][Enum.GuildJob.R2] = jurisdiction.R2
        newJurisdiction[jurisdiction.type][Enum.GuildJob.R3] = jurisdiction.R3
        newJurisdiction[jurisdiction.type][Enum.GuildJob.R4] = jurisdiction.R4
        newJurisdiction[jurisdiction.type][Enum.GuildJob.LEADER] = jurisdiction.R5
    end

    SM.s_AllianceMemberJurisdiction.req.Set( newJurisdiction )
end

---@see 重置s_ActivityTargetType初始化到s_ZeroEmpty表
local function reinitSActivityTargetType()
    local sActivityTargetType = CFG.s_ActivityTargetType:Get()
    local newsActivityTargetType = {}
    for _, activityTargerTypeInfo in pairs( sActivityTargetType ) do
        if not newsActivityTargetType[activityTargerTypeInfo.activityType] then
            newsActivityTargetType[activityTargerTypeInfo.activityType] = {}
        end
        newsActivityTargetType[activityTargerTypeInfo.activityType][activityTargerTypeInfo.ID] = activityTargerTypeInfo
    end
    addSZeroEmpty( Enum.ZeroEmptyType.ACTIVITY_TRAGET_TYPE, newsActivityTargetType )
end

---@see 重置s_ActivityTargetType初始化到s_ZeroEmpty表
local function initSHeroStarExp()
    local sHeroStarExp = EntityImpl:loadConfig( "s_HeroStarExp" )
    local newsHeroStarExp = {}
    for _, heroStarExp in pairs( sHeroStarExp ) do
        if not newsHeroStarExp[heroStarExp.itemID] then
            newsHeroStarExp[heroStarExp.itemID] = heroStarExp
        end
    end
    SM.s_HeroStarExp.req.Set( newsHeroStarExp )
end

---@see 重置s_AllianceBuildingType表索引
local function initSAllianceBuildingType()
    local sAllianceBuildingType = EntityImpl:loadConfig( "s_AllianceBuildingType" )
    local newSAllianceBuildingType = {}

    for _, buildType in pairs( sAllianceBuildingType ) do
        if not newSAllianceBuildingType[buildType.type] then
            newSAllianceBuildingType[buildType.type] = buildType
        end
    end

    SM.s_AllianceBuildingType.req.Set( newSAllianceBuildingType )
end

---@see 重置s_AllianceBuildingData表索引
local function initSAllianceBuildingData()
    local sAllianceBuildingData = EntityImpl:loadConfig( "s_AllianceBuildingData" )
    local newSAllianceBuildingData = {}

    for buildingDataId, buildingData in pairs( sAllianceBuildingData ) do
        newSAllianceBuildingData[buildingDataId] = {}
        newSAllianceBuildingData[buildingDataId].currencyCost = {}
        if buildingData.food > 0 then
            newSAllianceBuildingData[buildingDataId].currencyCost[Enum.CurrencyType.allianceFood] = buildingData.food
        end
        if buildingData.wood > 0 then
            newSAllianceBuildingData[buildingDataId].currencyCost[Enum.CurrencyType.allianceWood] = buildingData.wood
        end
        if buildingData.stone > 0 then
            newSAllianceBuildingData[buildingDataId].currencyCost[Enum.CurrencyType.allianceStone] = buildingData.stone
        end
        if buildingData.coin > 0 then
            newSAllianceBuildingData[buildingDataId].currencyCost[Enum.CurrencyType.allianceGold] = buildingData.coin
        end
        if buildingData.fund > 0 then
            newSAllianceBuildingData[buildingDataId].currencyCost[Enum.CurrencyType.leaguePoints] = buildingData.fund
        end
    end

    SM.s_AllianceBuildingData.req.Set( newSAllianceBuildingData )
end

---@see 重置s_ActivityDropType初始化到s_ZeroEmpty表
local function reinitSActivityDropType()
    local sActivityDropType = CFG.s_ActivityDropType:Get()
    local newsActivityDropType = {}
    for _, activityTargerTypeInfo in pairs( sActivityDropType ) do
        if not newsActivityDropType[activityTargerTypeInfo.activityType] then newsActivityDropType[activityTargerTypeInfo.activityType] = {} end
        newsActivityDropType[activityTargerTypeInfo.activityType][activityTargerTypeInfo.ID] = activityTargerTypeInfo
    end
    addSZeroEmpty( Enum.ZeroEmptyType.ACTIVITY_DROP_TYPE, newsActivityDropType )
end

---@see 重置s_ActivityEndHanding初始化到s_ZeroEmpty表
local function reinitSActivityEndHanding()
    local sActivityEndHanding = CFG.s_ActivityEndHanding:Get()
    local newsActivityEndHanding = {}
    for _, activityTargerTypeInfo in pairs( sActivityEndHanding ) do
        if not newsActivityEndHanding[activityTargerTypeInfo.activityType] then newsActivityEndHanding[activityTargerTypeInfo.activityType] = {} end
        newsActivityEndHanding[activityTargerTypeInfo.activityType][activityTargerTypeInfo.ID] = activityTargerTypeInfo
    end
    addSZeroEmpty( Enum.ZeroEmptyType.ACTIVITY_EXCHANGE_TYPE, newsActivityEndHanding )
end

---@see 重置s_ActivityDaysType初始化到s_ZeroEmpty表
local function reinitSActivityDaysType()
    local sActivityDaysType = CFG.s_ActivityDaysType:Get()
    local newsActivityDaysType = {}
    for _, activityDaysType in pairs( sActivityDaysType ) do
        if not newsActivityDaysType[activityDaysType.activityType] then newsActivityDaysType[activityDaysType.activityType] = {} end
        newsActivityDaysType[activityDaysType.activityType][activityDaysType.ID] = activityDaysType
    end
    addSZeroEmpty( Enum.ZeroEmptyType.ACTIVITY_DAYS_TYPE, newsActivityDaysType )
    newsActivityDaysType = {}
    for _, activityDaysType in pairs( sActivityDaysType ) do
        if not newsActivityDaysType[activityDaysType.activityType] then newsActivityDaysType[activityDaysType.activityType] = {} end
        if not newsActivityDaysType[activityDaysType.activityType][activityDaysType.day] then
            newsActivityDaysType[activityDaysType.activityType][activityDaysType.day] = {}
        end
        table.insert(newsActivityDaysType[activityDaysType.activityType][activityDaysType.day], activityDaysType)
    end
    addSZeroEmpty( Enum.ZeroEmptyType.ACTIVITY_DAYS, newsActivityDaysType )
end


---@see 重置s_MysteryStore初始化到s_ZeroEmpty表
local function reinitSMysteryStore()
    local sMysteryStore = CFG.s_MysteryStore:Get()
    local newsMysteryStore = {}
    for _, mysteryStore in pairs( sMysteryStore ) do
        if not newsMysteryStore[mysteryStore.group] then newsMysteryStore[mysteryStore.group] = {} end
        newsMysteryStore[mysteryStore.group][mysteryStore.ID] = mysteryStore
    end
    addSZeroEmpty( Enum.ZeroEmptyType.MYSTERY_STORE, newsMysteryStore )
end

---@see 重置s_MysteryStore初始化到s_ZeroEmpty表
local function initSMysteryStorePro()
    local sMysteryStorePro = EntityImpl:loadConfig( "s_MysteryStorePro" )
    local newsMysteryStorePro = {}
    for _, info in pairs( sMysteryStorePro ) do
        if not newsMysteryStorePro[info.group] then newsMysteryStorePro[info.group] = {} end
        newsMysteryStorePro[info.group][info.ID] = info
    end
    SM.s_MysteryStorePro.req.Set( newsMysteryStorePro )
end

---@see 重置s_ActivityKillType初始化到s_ZeroEmpty表
local function reinitSActivityKillType()
    local sActivityKillType = CFG.s_ActivityKillType:Get()
    local newsActivityKillType = {}
    local newsKillType = {}
    for _, info in pairs( sActivityKillType ) do
        if not newsActivityKillType[info.activityType] then newsActivityKillType[info.activityType] = {} end
        if not newsKillType[info.activityType] then newsKillType[info.activityType] = {} end
        newsKillType[info.activityType][info.stage] = info
        if not newsActivityKillType[info.activityType][info.lv] then newsActivityKillType[info.activityType][info.lv] = {} end
        newsActivityKillType[info.activityType][info.lv][info.ID] = info
    end
    addSZeroEmpty( Enum.ZeroEmptyType.ACTIVITY_KILL, newsActivityKillType )
    addSZeroEmpty( Enum.ZeroEmptyType.ACTIVITY_KILL_STAGE, newsKillType )
end


---@see 重置s_ActivityKillIntegral初始化到s_ZeroEmpty表
local function reinitSActivityKillTypeIntegral()
    local sActivityKillIntegral = CFG.s_ActivityKillIntegral:Get()
    local newsActivityKillIntegral = {}
    for _, info in pairs( sActivityKillIntegral ) do
        if not newsActivityKillIntegral[info.activityType] then newsActivityKillIntegral[info.activityType] = {} end
        if not newsActivityKillIntegral[info.activityType][info.groupsType] then newsActivityKillIntegral[info.activityType][info.groupsType] = {} end
        newsActivityKillIntegral[info.activityType][info.groupsType][info.ID] = info
    end
    addSZeroEmpty( Enum.ZeroEmptyType.ACTIVITY_KILL_INT, newsActivityKillIntegral )
end

---@see 重置s_ActivityRankingType表
local function initSActivityRankingType()
    local sActivityRankingType = EntityImpl:loadConfig( "s_ActivityRankingType" )
    local newsActivityRankingType = {}
    for _, activityRankingType in pairs( sActivityRankingType ) do
        if not newsActivityRankingType[activityRankingType.activityType] then newsActivityRankingType[activityRankingType.activityType] = {} end
        newsActivityRankingType[activityRankingType.activityType][activityRankingType.ID] = activityRankingType
    end
    SM.s_ActivityRankingType.req.Set( newsActivityRankingType )
end

---@see 重置s_itemRewardChoice表
local function initSItemRewardChoice()
    local sItemRewardChoice = EntityImpl:loadConfig( "s_ItemRewardChoice" )
    local newsItemRewardChoice = {}
    for _, itemRewardChoice in pairs( sItemRewardChoice ) do
        if not newsItemRewardChoice[itemRewardChoice.group] then newsItemRewardChoice[itemRewardChoice.group] = {} end
        newsItemRewardChoice[itemRewardChoice.group][itemRewardChoice.ID] = itemRewardChoice
    end
    SM.s_ItemRewardChoice.req.Set( newsItemRewardChoice )
end

---@see 重置s_Vip表
local function initSVip()
    local sVip = EntityImpl:loadConfig( "s_Vip" )
    local newsVip = {}
    for _, vip in pairs( sVip ) do
        if not newsVip[vip.level] then newsVip[vip.level] = {} end
        newsVip[vip.level] = vip
    end
    SM.s_Vip.req.Set( newsVip )
end

---@see 重置s_Vip表
local function initSVipAtt()
    local sVipAtt = EntityImpl:loadConfig( "s_VipAtt" )
    local newsVip = {}
    for _, vipAtt in pairs( sVipAtt ) do
        if not newsVip[vipAtt.levelGroup] then newsVip[vipAtt.levelGroup] = {} end
        newsVip[vipAtt.levelGroup][vipAtt.att] = vipAtt
    end
    SM.s_VipAtt.req.Set( newsVip )
end

---@see 重置s_EvolutionMileStone表
local function initSEvolutionMileStone()
    local sEvolutionMileStone = EntityImpl:loadConfig( "s_EvolutionMileStone" )
    local newsEvolutionMileStone = {}
    for _, evolutionMileStone in pairs( sEvolutionMileStone ) do
        if not newsEvolutionMileStone[evolutionMileStone.order] then newsEvolutionMileStone[evolutionMileStone.order] = {} end
        newsEvolutionMileStone[evolutionMileStone.order] = evolutionMileStone
    end
    SM.s_EvolutionMileStone.req.Set( newsEvolutionMileStone )
end

---@see 重置s_HeroLevel表索引
local function initSHeroLevel()
    local sHeroLevel = EntityImpl:loadConfig( "s_HeroLevel" )
    local newSHeroLevel = {}

    for _, heroLevel in pairs( sHeroLevel ) do
        newSHeroLevel[heroLevel.rareGroup * 10000 + heroLevel.lv] = heroLevel
    end

    SM.s_HeroLevel.req.Set( newSHeroLevel )
end

---@see 重置s_RechargeSale初始化到s_ZeroEmpty表
local function reinitSRechargeSale()
    local sRechargeSale = CFG.s_RechargeSale:Get()
    local newsRechargeSale = {}
    for _, info in pairs( sRechargeSale ) do
        if not newsRechargeSale[info.group] then newsRechargeSale[info.group] = {} end
        if not newsRechargeSale[info.group][info.gears] then newsRechargeSale[info.group][info.gears] = info end
    end
    addSZeroEmpty( Enum.ZeroEmptyType.RECHARGE_SALE, newsRechargeSale )
end

---@see 重置s_ExpeditionShop初始化到s_ZeroEmpty表
local function reinitSExpeditionShop()
    local sExpeditionShop = CFG.s_ExpeditionShop:Get()
    local newsExpeditionShop = {}
    for _, expeditionShop in pairs( sExpeditionShop ) do
        if not newsExpeditionShop[expeditionShop.groupID] then newsExpeditionShop[expeditionShop.groupID] = {} end
        newsExpeditionShop[expeditionShop.groupID][expeditionShop.ID] = expeditionShop
    end
    addSZeroEmpty( Enum.ZeroEmptyType.EXPEDITION_STORE, newsExpeditionShop )
end

---@see 重置s_EvolutionRankReward
local function reinitSEvolutionRankReward()
    local sEvolutionRankReward = EntityImpl:loadConfig( "s_EvolutionRankReward" )
    local newsEvolutionRankReward = {}
    for _, EvolutionRankReward in pairs( sEvolutionRankReward ) do
        if not newsEvolutionRankReward[EvolutionRankReward.type] then newsEvolutionRankReward[EvolutionRankReward.type] = {} end
        newsEvolutionRankReward[EvolutionRankReward.type][EvolutionRankReward.ID] = EvolutionRankReward
    end
    SM.s_EvolutionRankReward.req.Set( newsEvolutionRankReward )
end

-- ---@see 重置s_ActivityInfernal
-- local function reinitSActivityInfernal()
--     local sActivityInfernal = CFG.s_ActivityInfernal:Get()
--     local newsActivityInfernal = {}
--     for _, activityInfernal in pairs( sActivityInfernal ) do
--         if not newsActivityInfernal[activityInfernal.cityAge] then newsActivityInfernal[activityInfernal.cityAge] = {} end
--         if not newsActivityInfernal[activityInfernal.cityAge][activityInfernal.difficulty] then newsActivityInfernal[activityInfernal.cityAge][activityInfernal.difficulty] = {} end
--         newsActivityInfernal[activityInfernal.cityAge][activityInfernal.difficulty][activityInfernal.ID] = activityInfernal
--     end
--     SM.s_ActivityInfernal.req.Set( newsActivityInfernal )
-- end

---@see 重置s_MonsterLootRule
local function reinitSMonsterLootRule()
    local sMonsterLootRule = EntityImpl:loadConfig( "s_MonsterLootRule" )
    local newsMonsterLootRule = {}
    for _, MonsterLootRule in pairs( sMonsterLootRule ) do
        if not newsMonsterLootRule[MonsterLootRule.group] then newsMonsterLootRule[MonsterLootRule.group] = {} end
        newsMonsterLootRule[MonsterLootRule.group][MonsterLootRule.ID] = MonsterLootRule
    end
    SM.s_MonsterLootRule.req.Set( newsMonsterLootRule )
end

---@see 获取野蛮人城寨对应的纪念碑事件
local function reinitSMonster()
    local sMonster = CFG.s_Monster:Get()
    local monsterCityStones = {}
    local maxMonsterRadius = 0
    local maxMonsterCityRadius = 0

    for monsterId, monster in pairs( sMonster ) do
        if monster.type == Enum.MonsterType.BARBARIAN_CITY then
            table.insert( monsterCityStones, { monsterId = monsterId, level = monster.level, openMileStone = monster.openMileStone } )
            if maxMonsterCityRadius < monster.radiusCollide then
                maxMonsterCityRadius = monster.radiusCollide
            end
        elseif monster.type == Enum.MonsterType.BARBARIAN then
            if maxMonsterRadius < monster.radiusCollide then
                maxMonsterRadius = monster.radiusCollide
            end
        end
    end

    table.sort( monsterCityStones, function( a, b )
        return a.level > b.level
    end )

    addSZeroEmpty( Enum.ZeroEmptyType.MONSTER_CITY_STONE, monsterCityStones )
    addSZeroEmpty( Enum.ZeroEmptyType.MONSTER_MAX_RADIUS, maxMonsterRadius )
    addSZeroEmpty( Enum.ZeroEmptyType.MONSTER_CITY_MAX_RADIUS, maxMonsterCityRadius )
end

---@see 获取圣地对应的纪念碑解锁事件
local function reinitSStrongHoldType()
    local sStrongHoldType = CFG.s_StrongHoldType:Get()
    local sStrongHoldData = CFG.s_StrongHoldData:Get()

    local holyLandStones = {}
    local newSStrongHoldData = {}

    for dataId, holdData in pairs( sStrongHoldData ) do
        if not newSStrongHoldData[holdData.type] then
            newSStrongHoldData[holdData.type] = {}
        end

        newSStrongHoldData[holdData.type][dataId] = true
    end

    for typeId, holdType in pairs( sStrongHoldType ) do
        if not holyLandStones[holdType.openMileStone] then
            holyLandStones[holdType.openMileStone] = {}
        end

        for holyDataId in pairs( newSStrongHoldData[typeId] or {} ) do
            table.insert( holyLandStones[holdType.openMileStone], holyDataId )
        end
    end

    addSZeroEmpty( Enum.ZeroEmptyType.HOLY_LAND_STORE, holyLandStones )
end

---@see 获取圣地所在迷雾块
local function reinitSStrongHoldData()
    local sStrongHoldData = EntityImpl:loadConfig( "s_StrongHoldData" )

    local newSStrongHoldData = {}
    local holyLandDensefogs = {}
    local denseFogIndex, bitIndex
    local posMultiple = Enum.MapPosMultiple

    for holdDataId, holdData in pairs( sStrongHoldData ) do
        holdData.posX = holdData.posX * posMultiple
        holdData.posY = holdData.posY * posMultiple
        holdData.posX1 = holdData.posX1 * posMultiple
        holdData.posX2 = holdData.posX2 * posMultiple
        holdData.posY1 = holdData.posY1 * posMultiple
        holdData.posY2 = holdData.posY2 * posMultiple

        newSStrongHoldData[holdDataId] = holdData

        denseFogIndex, bitIndex = DenseFogLogic:getDenseFogIndexByPos( { x = holdData.posX, y = holdData.posY } )
        if not holyLandDensefogs[denseFogIndex] then
            holyLandDensefogs[denseFogIndex] = {}
        end
        if not holyLandDensefogs[denseFogIndex][bitIndex] then
            holyLandDensefogs[denseFogIndex][bitIndex] = {}
        end
        table.insert( holyLandDensefogs[denseFogIndex][bitIndex], holdDataId )
    end

    SM.s_StrongHoldData.req.Set( newSStrongHoldData )
    addSZeroEmpty( Enum.ZeroEmptyType.HOLY_LAND_DENSEFOG, holyLandDensefogs )
end

---@see 重置s_EquipMaterial
local function reinitSEquipMaterial()
    local sEquipMaterial = EntityImpl:loadConfig( "s_EquipMaterial" )
    local newsEquipMaterial = {}
    local materialGroup = {}
    local drawingGroup = {}
    for _, equipMaterial in pairs( sEquipMaterial ) do
        newsEquipMaterial[equipMaterial.itemID] = equipMaterial
        if equipMaterial.rare and equipMaterial.rare > 0 then
            if not materialGroup[equipMaterial.group] then materialGroup[equipMaterial.group] = {} end
            materialGroup[equipMaterial.group][equipMaterial.rare] = equipMaterial
        else
            drawingGroup[equipMaterial.mix] = equipMaterial
        end
    end
    addSZeroEmpty( Enum.ZeroEmptyType.MATERIAL, materialGroup )
    addSZeroEmpty( Enum.ZeroEmptyType.DRAW, drawingGroup )
    SM.s_EquipMaterial.req.Set( newsEquipMaterial )
end

---@see 重置s_Equip
local function reinitSEquip()
    local sEquip = EntityImpl:loadConfig( "s_Equip" )
    local newsEquip = {}
    for _, equip in pairs( sEquip ) do
        newsEquip[equip.itemID] = equip
    end
    SM.s_Equip.req.Set( newsEquip )
end

---@see 重置s_AllianceStudy表索引
local function reinitSAllianceStudy()
    local sAllianceStudy = EntityImpl:loadConfig( "s_AllianceStudy" )
    local newSAllianceStudy = {}

    for _, allianceStudy in pairs( sAllianceStudy ) do
        newSAllianceStudy[allianceStudy.studyType * 100 + allianceStudy.studyLv] = allianceStudy
    end

    SM.s_AllianceStudy.req.Set( newSAllianceStudy )
end

---@see 重置s_AllianceDonateRanking表索引
local function reinitSAllianceDonateRanking()
    local sAllianceDonateRanking = EntityImpl:loadConfig( "s_AllianceDonateRanking" )
    local newSAllianceDonateRanking = {}

    for _, allianceDonateRanking in pairs( sAllianceDonateRanking ) do
        if not newSAllianceDonateRanking[allianceDonateRanking.type] then
            newSAllianceDonateRanking[allianceDonateRanking.type] = {}
        end
        table.insert( newSAllianceDonateRanking[allianceDonateRanking.type], allianceDonateRanking )
    end

    SM.s_AllianceDonateRanking.req.Set( newSAllianceDonateRanking )
end


---@see 重置s_ActivityReapType表索引
local function reinitSActivityReapType()
    local sActivityReapType = EntityImpl:loadConfig( "s_ActivityReapType" )
    local newSActivityReapType = {}

    for _, activityReapType in pairs( sActivityReapType ) do
        newSActivityReapType[activityReapType.lv] = activityReapType
    end

    SM.s_ActivityReapType.req.Set( newSActivityReapType )
end

---@see 重置s_HeroTalentGainTree
local function reinitSHeroTalentGainTree()
    local sHeroTalentGainTree = CFG.s_HeroTalentGainTree:Get()
    local newsHeroTalentGainTree = {}
    for _, heroTalentGainTree in pairs( sHeroTalentGainTree ) do
        if not newsHeroTalentGainTree[heroTalentGainTree.gainTree] then newsHeroTalentGainTree[heroTalentGainTree.gainTree] = {} end
        newsHeroTalentGainTree[heroTalentGainTree.gainTree][heroTalentGainTree.ID] = heroTalentGainTree
    end
    addSZeroEmpty( Enum.ZeroEmptyType.TALENT, newsHeroTalentGainTree )
end


---@see 重置s_HeroTalentGainTree
local function reinitSHeroTalentMastery()
    local sHeroTalentMastery = EntityImpl:loadConfig( "s_HeroTalentMastery" )
    local newsHeroTalentMastery = {}
    for _, heroTalentMastery in pairs( sHeroTalentMastery ) do
        if not newsHeroTalentMastery[heroTalentMastery.group] then newsHeroTalentMastery[heroTalentMastery.group] = {} end
        newsHeroTalentMastery[heroTalentMastery.group][heroTalentMastery.needTalentPoint] = heroTalentMastery
    end

    SM.s_HeroTalentMastery.req.Set( newsHeroTalentMastery )
    --addSZeroEmpty( Enum.ZeroEmptyType.TALENT, newsHeroTalentGainTree )
end

---@see 英雄天赋点表
local function reinitHeroTalent()
    local sHeroLevel = CFG.s_HeroLevel:Get()
    local heroLevelInfo = {}
    for _, heroLevel in pairs(sHeroLevel) do
        if not heroLevelInfo[heroLevel.rareGroup] then heroLevelInfo[heroLevel.rareGroup] = {} end
        if heroLevel.starEffectData > 0 then
            heroLevelInfo[heroLevel.rareGroup][heroLevel.lv] = heroLevel.starEffectData
        end
    end
    local sHeroStar = CFG.s_HeroStar:Get()
    local heroStarInfo = {}
    for _, heroStar in pairs(sHeroStar) do
        heroStarInfo[heroStar.ID] = heroStar.starEffectData
    end
    addSZeroEmpty( Enum.ZeroEmptyType.HERO_LEVEL_TALENT, heroLevelInfo )
    addSZeroEmpty( Enum.ZeroEmptyType.HERO_STAR_TALENT, heroStarInfo )
end

---@see 远征表
-- local function reinitSExpedition()
--     local sExpedition = CFG.s_Expedition:Get()
--     local newExpedition = {}
--     for _, expedition in pairs(sExpedition) do
--         newExpedition[expedition.level] = expedition.ID
--     end
--     addSZeroEmpty( Enum.ZeroEmptyType.EXPEDITION, newExpedition )
-- end

---@see 商品表
local function reinitSPrice()
    local sPrice = CFG.s_Price:Get()
    local newPrice ={}
    local newPriceSale = {}
    for _, price in pairs(sPrice) do
        if price.rechargeID and price.rechargeID > 0 then
            newPrice[price.rechargeID] = price
        end
        if price.rechargeID and price.rechargeID > 0 and price.rechargeType == Enum.RechargeType.SALE then
            if not newPriceSale[price.rechargeID] then newPriceSale[price.rechargeID] = {} end
            newPriceSale[price.rechargeID][price.rechargeTypeID] = price
        end
    end
    addSZeroEmpty( Enum.ZeroEmptyType.PRICE, newPrice )
    addSZeroEmpty( Enum.ZeroEmptyType.SALEPRICE, newPriceSale )
end

---@see 每个省份的中心点
local function reinitSMapBarrierConnect()
    local sMapBarrierConnect = CFG.s_MapBarrierConnect:Get()
    local posInfo = {}
    local mapConnectLength = CFG.s_Config:Get( "mapConnectLength" )
    for _, mapBarrierConnect in pairs(sMapBarrierConnect) do
        if mapBarrierConnect.zoneCenter > 0 then
            local y = math.modf((mapBarrierConnect.ID - 1) / mapConnectLength) // 1
            local x = math.fmod((mapBarrierConnect.ID - 1), mapConnectLength) // 1
            posInfo[mapBarrierConnect.zoneCenter] = { x = x, y = y}
        end
    end

    addSZeroEmpty( Enum.ZeroEmptyType.CHECK_POINT_POS, posInfo )
end


---@see 重置s_ResourceGatherRule表索引
local function initSResourceGatherType()
    local sResourceGatherType = CFG.s_ResourceGatherType:Get()
    local newSResourceGatherType = {}

    for _, resourceGatherType in pairs( sResourceGatherType ) do
        if resourceGatherType.resAmount > 0 then
            if not newSResourceGatherType[resourceGatherType.type] then
                newSResourceGatherType[resourceGatherType.type] = {}
            end
            newSResourceGatherType[resourceGatherType.type][resourceGatherType.level] = resourceGatherType.resAmount
        end
    end

    addSZeroEmpty( Enum.ZeroEmptyType.RESOURCE_TYPE, newSResourceGatherType )
end

---@see 重置s_CityHideData表索引
local function initSCityHideData()
    local sCityHideData = EntityImpl:loadConfig( "s_CityHideData" )
    local levels = table.indexs( sCityHideData )
    table.sort( levels )
    local maxLevel = levels[#levels]
    local allLevels = {}

    for i = 1, maxLevel do
        if #levels <= 0 then
            break
        end
        if i <= levels[1] then
            allLevels[i] = levels[1]
        end
        if i == levels[1] then
            table.remove( levels, 1 )
        end
    end

    local newSCityHideData = {}
    for level, dataLevel in pairs( allLevels ) do
        newSCityHideData[level] = { ID = level, hideCityTime = sCityHideData[dataLevel].hideCityTime * 3600 }
    end

    SM.s_CityHideData.req.Set( newSCityHideData )
end

---@see 获取最大引导步骤
local function initSGuide()
    local sGuide = CFG.s_Guide:Get()
    local maxGuideStage = 1
    for _, guideInfo in pairs( sGuide ) do
        if guideInfo.stage > maxGuideStage then
            maxGuideStage = guideInfo.stage
        end
    end

    addSZeroEmpty( Enum.ZeroEmptyType.MAX_GUIDE_STAGE, maxGuideStage )
end

---@see 根据坐标索引关卡
local function reinitSStrongHoldDataPos()
    local sStrongHoldData = CFG.s_StrongHoldData:Get()
    local strongHold = {}
    for _, strongHoldData in pairs( sStrongHoldData ) do
        if strongHoldData.type == Enum.HolyLandType.CHECKPOINT_LEVEL_1 or strongHoldData.type == Enum.HolyLandType.CHECKPOINT_LEVEL_2 or
            strongHoldData.type == Enum.HolyLandType.CHECKPOINT_LEVEL_3 then
            local x = strongHoldData.posX
            local y = strongHoldData.posY
            if not strongHold[x] then strongHold[x] = {} end
            strongHold[x][y] = strongHoldData
        end
    end
    addSZeroEmpty( Enum.ZeroEmptyType.HOLD_POS, strongHold )
end

---@see 根据坐标索引关卡
local function reinitSActivityIntegralType()
    local sActivityIntegralType = EntityImpl:loadConfig( "s_ActivityIntegralType" )
    local newActivityIntegralType = {}
    for _, activityIntegralType in pairs( sActivityIntegralType ) do
        if not newActivityIntegralType[activityIntegralType.activityType] then
            newActivityIntegralType[activityIntegralType.activityType] = {}
        end
        newActivityIntegralType[activityIntegralType.activityType][activityIntegralType.stage] = activityIntegralType
    end
    SM.s_ActivityIntegralType.req.Set( newActivityIntegralType )
end

---@see 根据转盘类型重新划分转盘表
local function reInitsTurnTableDraw()
    local sTurnTableDraw = EntityImpl:loadConfig( "s_TurntableDraw" )
    local newSTurnTableDraw = {}
    for _, turnTableDraw in pairs(sTurnTableDraw) do
        newSTurnTableDraw[turnTableDraw.type] = turnTableDraw
    end
    SM.s_TurntableDraw.req.Set( newSTurnTableDraw )
end

---@see 根据转盘类型重新划分转盘表
local function reInitsEvolutionGoalFillData()
    local sEvolutionGoalFillData = CFG.s_EvolutionGoalFillData:Get()
    local newSEvolutionGoalFillData = {}
    for _, evolutionGoalFillData in pairs(sEvolutionGoalFillData) do
        if not newSEvolutionGoalFillData[evolutionGoalFillData.ruleId] then
            newSEvolutionGoalFillData[evolutionGoalFillData.ruleId] = {}
        end
        table.insert(newSEvolutionGoalFillData[evolutionGoalFillData.ruleId], evolutionGoalFillData)
    end
    addSZeroEmpty( Enum.ZeroEmptyType.FIX_TIME, newSEvolutionGoalFillData )
end

---@see 重新初始化
function response.reInitConfigData( _isBootInit )
    -- reinit s_BuildingLevelData
    --reInitsBuildingLevelData()
    -- reinit s_BuildingBarracks
    reInitsBuildingBarracks()
    -- reinit s_BuildingArcheryrange
    reInitsBuildingArcheryrange()
    -- reinit s_BuildingStable
    reInitsBuildingStable()
    -- reinit s_BuildingSiegeWorkshop
    reInitsBuildingSiegeWorkshop()
    -- reinit s_BuildingTownCenter
    reInitsBuildingTownCenter()
    -- reinit s_BuildingCityWall
    reInitsBuildingCityWall()
    -- reinit s_BuildingGuardTower
    reInitsBuildingGuardTower()
    -- reinit s_BuildingCampus
    reInitsBuildingCampus()
    -- reinit s_BuildingHospital
    reInitsBuildingHospital()
    -- reinit s_BuildingCastle
    reInitsBuildingCastle()
    -- reinit s_BuildingScoutcamp
    reInitsBuildingScoutcamp()
    -- init SAmryStudy
    initSAmryStudy()
    -- reinit s_BuildingResourcesProduce
    reInitsBuildingResourcesProduce()
    -- reinit s_ItemPackage
    reInitsItemPackage()
    -- reinit s_Study
    initsStudy()
    -- reinit s_Arms
    reInitsArms()
    -- init s_TaskChapter
    initSTaskChapter()
    -- init s_MonsterRefreshLevel
    initSMonsterRefreshLevel()
    -- init s_MonsterPoint
    initSMonsterPoint()
    -- init s_ResourceGatherPoint
    initSResourceGatherPoint()
    -- init s_ResourceGatherRule
    initSResourceGatherRule()
    -- init s_BuildingAllianceCenter
    initSBuildingAllianceCenter()
    -- init s_MonsterTroopsAttr
    initSMonsterTroopsAttr()
    -- init s_VillageRewardData
    initSVillageRewardData()
    -- init s_MapFixPoint
    initSMapFixPoint()
    -- init s_BuildingMails
    initSBuildingMail()
    -- init s_Item
    initSSubItemType()
    -- init s_BuildingTavern
    initSBuildingTavern()
    -- init s_TaskDaily
    initSAgeDailyTask()
    -- init s_TaskActivityReward
    initSTaskActivityReward()
    -- init s_HeroSkillLevel
    initSHeroSkillLevel()
    -- init s_HeroSkill
    initSHeroSkill()
    -- init s_AllianceMember
    initSAllianceMember()
    -- init s_AllianceMemberJurisdiction
    initSAllianceMemberJurisdiction()
    -- reinit s_AllianceMemberJurisdiction
    reinitSActivityTargetType()
    -- init s_HeroStarExp
    initSHeroStarExp()
    -- init s_AllianceBuildingType
    initSAllianceBuildingType()
    -- init s_AllianceBuildingData
    initSAllianceBuildingData()
    -- reinit s_ActivityDropType
    reinitSActivityDropType()
    -- reinit s_ActivityEndHanding
    reinitSActivityEndHanding()
    -- reinit s_ActivityDaysType
    reinitSActivityDaysType()
    -- reinit s_MysteryStore
    reinitSMysteryStore()
    -- init s_MysteryStorePro
    initSMysteryStorePro()
    -- reinit s_ActivityKillType
    reinitSActivityKillType()
    -- reinit s_ActivityKillIntegral
    reinitSActivityKillTypeIntegral()
    -- init s_ActivityRankingType
    initSActivityRankingType()
    -- init s_itemRewardChoice
    initSItemRewardChoice()
    -- init s_Vip
    initSVip()
    -- init s_VipAtt
    initSVipAtt()
    -- init s_EvolutionMileStone
    initSEvolutionMileStone()
    -- init s_HeroLevel
    initSHeroLevel()
    -- init s_RechargeSale
    reinitSRechargeSale()
    -- init s_BuildingFreight
    reInitsBuildingFreight()
    -- init s_ExpeditionShop
    reinitSExpeditionShop()
    -- init s_EvolutionRankReward
    reinitSEvolutionRankReward()
    -- init s_ActivityInfernal
    --reinitSActivityInfernal()
    -- init s_MonsterLootRule
    reinitSMonsterLootRule()
    -- init s_Monster
    reinitSMonster()
    -- init s_StrongHoldData
    reinitSStrongHoldData()
    -- init s_StrongHoldType
    reinitSStrongHoldType()
    -- init s_EquipMaterial
    reinitSEquipMaterial()
    -- init s_Equip
    reinitSEquip()
    -- init s_AllianceStudy
    reinitSAllianceStudy()
    -- init s_AllianceDonateRanking
    reinitSAllianceDonateRanking()
    -- init s_ActivityReapType
    reinitSActivityReapType()
    -- init s_HeroTalentGainTree
    reinitSHeroTalentGainTree()
    -- init s_HeroTalentMastery
    reinitSHeroTalentMastery()
    -- init s_HeroTalent
    reinitHeroTalent()
    -- reinit s_Price
    reinitSPrice()
    -- reinit s_MapBarrierConnect
    reinitSMapBarrierConnect()
    -- reinit s_ResourceGatherType
    initSResourceGatherType()
    -- reinit s_CityHideData
    initSCityHideData()
    -- reinit s_Guide
    initSGuide()
    -- reinit s_StrongHoldData
    reinitSStrongHoldDataPos()
    -- reinit s_ActivityIntegralType
    reinitSActivityIntegralType()
    -- reinit reInitsTurnTableDraw
    reInitsTurnTableDraw()
    -- reinit reInitsEvolutionGoalFillData
    reInitsEvolutionGoalFillData()
    -- 清除Configs.data数据
    SM.ReadConfig.req.clean()

    Timer.runAfter( 3 * 100, function ()
        snax.exit()
    end)
end