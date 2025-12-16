--[[
* @file : PMLogic.lua
* @type : lua lib
* @author : linfeng
* @created : Fri Jan 19 2018 15:13:32 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : PM 相关命令解析
* Copyright(C) 2017 IGG, All rights reserved
]]

local PMLogic = {}
local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local ItemLogic = require "ItemLogic"
local ArmyLogic = require "ArmyLogic"
local ArmyTrainLogic = require "ArmyTrainLogic"
local HospitalLogic = require "HospitalLogic"
local EmailLogic = require "EmailLogic"
local HeroLogic = require "HeroLogic"
local BuildingLogic = require "BuildingLogic"
local TaskLogic = require "TaskLogic"
local GuildLogic = require "GuildLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local RechargeLogic = require "RechargeLogic"
local HolyLandLogic = require "HolyLandLogic"
local GuildTechnologyLogic = require "GuildTechnologyLogic"
local RoleCacle = require "RoleCacle"
local MonumentLogic = require "MonumentLogic"
local MapLogic = require "MapLogic"
local skynet = require "skynet"
local Timer = require "Timer"
local DenseFogLogic = require "DenseFogLogic"

---@see CMD命令帮助说明
function PMLogic:showHelp()
    return {
        --命令,                       参数,                             说明
        { cmd = "modifyAttr",                   arg = "属性名称|属性数值",                                      explan = "修改角色相关属性" },
        { cmd = "addItem",                      arg = "道具ID(多个用-分割)|道具数量",                           explan = "增加道具" },
        { cmd = "createArmy",                   arg = "主将ID|副将ID|士兵列表(id1(类型*100+等级):num-士兵id2:num)",explan = "创建军队" },
        { cmd = "addSoldiers",                  arg = "兵种类型|兵种等级|数量",                                 explan = "增加士兵" },
        { cmd = "addHosptial",                  arg = "伤兵类型|伤兵等级|数量|清空伤兵",                        explan = "增加伤兵" },
        { cmd = "addSystemEmail",               arg = "邮件ID|邮件条数",                                       explan = "增加系统邮件" },
        { cmd = "addHero",                      arg = "统帅ID",                                                explan = "增加统帅" },
        { cmd = "getItemPackage",               arg = "奖励组ID",                                              explan = "获得奖励组奖励" },
        { cmd = "sendResourceCollectEmail",     arg = "邮件ID|资源类型ID|X坐标|Y坐标|资源采集量|额外获得资源",    explan = "发送资源采集邮件" },
        { cmd = "batchAddHosptial",             arg = "伤兵类型|伤兵等级|数量",                                 explan = "批量增加伤兵" },
        { cmd = "modifyTime",                   arg = "时间",                                                  explan = "修改系统时间" },
        { cmd = "cityMove",                     arg = "X坐标|Y坐标",                                           explan = "城市迁移" },
        { cmd = "upGradeBuliding",              arg = "建筑类型|建筑等级",                                      explan = "建筑升级" },
        { cmd = "researchTechnology",           arg = "科技类型|科技等级",                                      explan = "科技升级" },
        { cmd = "disbandArmy",                  arg = "部队索引(0为解散所有部队)",                              explan = "解散部队" },
        { cmd = "addTaskStatisticsSum",         arg = "类型|参数(-1为无参数)|数量",                             explan = "增加任务累计统计数量" },
        { cmd = "scoutDenseFog",                arg = "X坐标|Y坐标",                                           explan = "解锁坐标所在迷雾" },
        { cmd = "scoutAllDenseFog",             arg = "",                                                     explan = "解锁全部迷雾" },
        { cmd = "getMapObject",                 arg = "地图对象ID",                                            explan = "获取地图对象信息" },
        { cmd = "scoutVillageCave",             arg = "村庄山洞ID(区间以-分割)",                                explan = "探索村庄山洞" },
        { cmd = "addActionForce",               arg = "行动力值",                                              explan = "增加行动力" },
        { cmd = "createBuild",                  arg = "建筑类型|X坐标|Y坐标|是否走正常建筑逻辑",                 explan = "创建建筑" },
        { cmd = "moveBuild",                    arg = "建筑索引|X坐标|Y坐标",                                   explan = "移动建筑" },
        { cmd = "deleteBuild",                  arg = "建筑索引|建筑类型",                                      explan = "删除建筑" },
        { cmd = "addMonster",                   arg = "野蛮人等级|X坐标|Y坐标",                                 explan = "城堡附近添加野蛮人" },
        { cmd = "unlockSkill",                  arg = "英雄ID",                                                explan = "解锁英雄技能" },
        { cmd = "disbandGuild",                 arg = "联盟ID",                                                explan = "解散联盟" },
        { cmd = "startBurnWall",                arg = "",                                                      explan = "城墙燃烧" },
        { cmd = "modifyGuildAttr",              arg = "联盟ID|属性名称|属性数值",                                explan = "修改联盟属性(联盟ID为0则修改角色所在联盟)" },
        { cmd = "addGuildCurrency",             arg = "联盟ID|货币类型|货币数值",                                explan = "增加联盟货币" },
        { cmd = "addGuildConsumeRecord",        arg = "联盟ID|类型|参数|消费货币",                               explan = "增加消费联盟货币记录信息" },
        { cmd = "addBuff",                      arg = "buffID",                                                explan = "增加城市buff" },
        { cmd = "addHeroExp",                   arg = "英雄ID|增加经验值",                                      explan = "增加英雄经验值" },
        { cmd = "unlockQueue",                  arg = "增加时间",                                               explan = "解锁第二队列" },
        { cmd = "refreshPost",                  arg = "",                                                      explan = "刷新驿站" },
        { cmd = "cleanRoleBag",                 arg = "",                                                      explan = "清空角色背包" },
        { cmd = "modifyGuildBuild",             arg = "联盟ID|建筑索引|属性名称|增加数值",                       explan = "修改建筑属性" },
        { cmd = "reSetActivityBox",             arg = "活动ID",                                                explan = "重置活动宝箱" },
        { cmd = "buyDenar",                     arg = "id(sprice表的商品id)|索引（限时礼包要传）",               explan = "充值" },
        { cmd = "reduceWallHp",                 arg = "减少耐久",                                               explan = "减少城墙耐久" },
        { cmd = "occupyHolyLand",               arg = "联盟ID|圣地ID",                                          explan = "占领圣地" },
        { cmd = "mileStoneUnlockHolyLands",     arg = "纪念碑事件",                                             explan = "纪念碑事件解锁圣地" },
        { cmd = "addRuneInfo",                  arg = "符文ID|X坐标|Y坐标",                                     explan = "刷新符文" },
        { cmd = "sendDiscoverEmail",            arg = "邮件ID|X坐标|Y坐标|山洞村庄ID|圣地类型ID",                 explan = "发送探索发现邮件" },
        { cmd = "sendMarquee",                  arg = "语言包ID|参数|消息",                                     explan = "发送跑马灯" },
        { cmd = "sendGuildGift",                arg = "联盟ID|礼物类型|是否购买(true购买礼物)|是否隐藏姓名",      explan = "发放联盟礼物" },
        { cmd = "upGradeAllBuilding",           arg = "最高等级,不填默认25",                                    explan = "建筑满级" },
        { cmd = "sendFormatEmail",              arg = "邮件id|标题解析|副标题解析|内容解析|测试",                 explan = "发送解析邮件（均用|分割）" },
        { cmd = "triggerLimitPackage",          arg = "礼包id|减时间",                                          explan = "触发限时礼包" },
        { cmd = "getRoleGame",                  arg = "",                                                      explan = "获取角色game节点" },
        { cmd = "addGuildTechnologyExp",        arg = "联盟ID|科技子类型|增加经验值",                            explan = "增加联盟科技经验值" },
        { cmd = "addGuildTechnologyLevel",      arg = "联盟ID|科技子类型|增加等级",                              explan = "增加联盟科技等级" },
        { cmd = "forceMoveCity",                arg = "",                                                      explan = "强制迁城" },
        { cmd = "monumentEnd",                  arg = "",                                                      explan = "结束当前纪念碑事件" },
        { cmd = "resetWallTime",                arg = "",                                                      explan = "重置城墙维修时间" },
        { cmd = "addMonsterCity",               arg = "野蛮人城寨等级|X坐标|Y坐标",                              explan = "添加野蛮人城寨" },
        { cmd = "expedtion",                    arg = "远征关卡id|星级|是否通过前面关卡",                         explan = "远征通关" },
        { cmd = "addResource",                  arg = "资源点类型|资源点等级|X坐标|Y坐标",                        explan = "添加资源点(资源点类型:1农田 2伐木场 3石矿场 4金矿场 5宝石矿)" },
        { cmd = "oneKeyUpHero",                 arg = "英雄id",                                                 explan = "英雄满级" },
        { cmd = "allLevelUp",                   arg = "",                                                       explan = "一键解锁" },
        { cmd = "updateEmailVersion",           arg = "",                                                       explan = "修改邮件版本号" },
        { cmd = "checkCityHide",                arg = "",                                                       explan = "执行城市隐藏检查逻辑" },
        { cmd = "removeCityWarCarzy",           arg = "",                                                       explan = "移除战争狂热buff" },
        { cmd = "removeCityBuff",               arg = "buffId",                                                 explan = "移除城市buff" },
        { cmd = "checkHideCity",                arg = "",                                                       explan = "检查隐藏城市" },
        { cmd = "resetHolyLand",                arg = "圣地关卡ID",                                              explan = "重置圣地关卡状态到初始争夺中" },
        { cmd = "addGuard",                     arg = "守护者类型|X坐标|Y坐标",                                  explan = "添加守护者(守护者类型:1圣所 2圣坛 3圣祠 4神庙)" },
        { cmd = "immigrate",                    arg = "目标服务器(gamex)",                                      explan = "角色移民" },
        { cmd = "summonMonster",                arg = "怪物ID",                                                 explan = "添加召唤怪物" },
        { cmd = "setRecommend",                 arg = "地区(多个地区-分割)|服务器",                               explan = "修改推荐服务器" },
        { cmd = "createGuildBuild",             arg = "类型|X坐标|Y坐标",                                       explan = "创建联盟建筑" },
        { cmd = "reSetActivity",                arg = "",                                                      explan = "重置活动" },
        { cmd = "logObjectNum",                 arg = "瓦片索引",                                               explan = "输出瓦片对象数量" },
        { cmd = "reinforceGuildBuild",          arg = "主将ID|副将ID|兵种类型|兵种等级|数量",                     explan = "联盟成员增援联盟要塞" },
        { cmd = "getGameGuildInfo",             arg = "服务器(gamex)",                                          explan = "导出联盟列表" },
        { cmd = "modifyFullProvice",            arg = "增加已满省份|删除未满省份",                               explan = "调整省份是否已满" },
        { cmd = "batchJoinGuild",               arg = "联盟ID|最小角色ID|最大角色ID",                           explan = "批量加入联盟(联盟ID为空则取角色ID所在联盟)" },
        { cmd = "cityEnterMap",                 arg = "结束角色ID",                                            explan = "回收城市进入地图" },
        { cmd = "reinforceCity",                arg = "主将ID|副将ID|兵种类型|兵种等级|数量",                    explan = "盟友增援角色城市" },
        { cmd = "batchGetRole",                 arg = "结束角色ID",                                            explan = "批量读取角色信息时间检查" },
        { cmd = "exploreDenseFog",              arg = "",                                                     explan = "探索完成全部迷雾" }
    }
end

local function checkPos( _xPos, _yPos )
    assert( _xPos > 0 and _xPos < 1200, string.format( "X坐标:%s 错误(0~1200)", tostring(_xPos) ) )
    assert( _yPos > 0 and _yPos < 1200, string.format( "Y坐标:%s 错误(0~1200)", tostring(_yPos) ) )
end

function PMLogic:batchGetRole( _rid, _endRid )
    local timercore = require "timer.core"
    _rid = tonumber( _rid ) or 0
    _endRid = tonumber( _endRid ) or 0

    local startTime = timercore.getmillisecond()
    for rid = _rid, _endRid do
        RoleLogic:getRole( rid )
    end
    local endTime = timercore.getmillisecond()
    LOG_INFO("batchGetRole rid(%d~%d) all attr use time %s ms", _rid, _endRid, tostring(endTime - startTime))

    startTime = timercore.getmillisecond()
    for rid = _rid, _endRid do
        RoleLogic:getRole( rid, Enum.Role.level )
    end
    endTime = timercore.getmillisecond()
    LOG_INFO("batchGetRole rid(%d~%d) level attr use time %s ms", _rid, _endRid, tostring(endTime - startTime))
end

--#################################角色相关模块##########################
---@see 修改属性
function PMLogic:modifyAttr( _rids, _attrName, _attrValue )
    if type(_rids) == "string" then
        _rids = string.split( _rids, "|", true )
    else
        _rids = { _rids }
    end

    for _, rid in pairs(_rids) do
        local roleAttr = RoleLogic:getRole( rid, _attrName )
        if roleAttr then
            -- 属性名称正确
            local value = roleAttr + tonumber(_attrValue)
            RoleLogic:setRole( rid, _attrName, value )
            -- 同步
            RoleSync:syncSelf( rid, { [_attrName] = value }, true )
        else
            LOG_DEBUG("PMLogic:modifyAttr error, rid(%d) not found attrName(%s)", rid, _attrName)
        end
    end
end

---@see 增加道具
function PMLogic:addItem( _rid, _itemId, _itemNum )
    local itemIds = string.split( _itemId, "-", true )
    for _, itemId in pairs(itemIds) do
        local sitemInfo = CFG.s_Item:Get( itemId )

        if sitemInfo.subType ~= Enum.ItemSubType.ARMS and sitemInfo.subType ~= Enum.ItemSubType.HELMET and sitemInfo.subType ~= Enum.ItemSubType.BREASTPLATE
        and sitemInfo.subType ~= Enum.ItemSubType.GLOVES and sitemInfo.subType ~= Enum.ItemSubType.PANTS and sitemInfo.subType ~= Enum.ItemSubType.ACCESSORIES
        and sitemInfo.subType ~= Enum.ItemSubType.SHOES then
            ItemLogic:addItem( { rid = _rid, itemId = itemId, itemNum = _itemNum } )
        else
            for _ = 1, _itemNum do
                ItemLogic:addItem( { rid = _rid, itemId = itemId, itemNum = 1 } )
            end
        end
    end
end

---@see 增加士兵
function PMLogic:addSoldiers( _rid, _type, _level, _addNum )
    if _type and _level and _addNum and _level <= 5 and _type <= 4 then
        ArmyTrainLogic:addSoldiers( _rid, _type, _level, _addNum, Enum.LogType.TRAIN_ARMY, nil, true )
    end
end

---@see 增加伤兵
function PMLogic:addHosptial( _rid, _type, _level, _addNum, _clean )
    if _clean and _clean > 0 then
        RoleLogic:setRole( _rid, Enum.Role.seriousInjured, {} )
        -- 同步
        RoleSync:syncSelf( _rid, { [Enum.Role.seriousInjured] = {} }, true )
    elseif _type and _level and _addNum and _level <= 5 and _type <= 4 then
        local soldiers = {}
        local config = ArmyTrainLogic:getArmsConfig( _rid, _type, _level )
        local id =config.ID
        soldiers[id] = { id = id , type = _type, level = _level, num= _addNum }
        HospitalLogic:addToHospital( _rid, soldiers, true )
    end
end

---@see 增加伤兵
function PMLogic:batchAddHosptial( _rid, _types, _levels, _addNums )
    if _types and _levels and _addNums then
        local typesInfo = string.split( _types, "|")
        local levelsInfo = string.split( _levels, "|")
        local addNumsInfo = string.split( _addNums, "|")
        local soldiers = {}
        for i=1,table.size(typesInfo) do
            if tonumber(typesInfo[i]) <= 4 and tonumber(levelsInfo[i]) <= 5 then
                local config = ArmyTrainLogic:getArmsConfig( _rid, tonumber(typesInfo[i]), tonumber(levelsInfo[i]) )
                local id =config.ID
                soldiers[id] = { id = id , type = tonumber(typesInfo[i]), level = tonumber(levelsInfo[i]), num = tonumber(addNumsInfo[i]) }
            end
        end
        HospitalLogic:addToHospital( _rid, soldiers, true )
    end
end

---@see 城市迁移
function PMLogic:cityMove( _rid, _xPos, _yPos )
    _xPos = tonumber( _xPos )
    _yPos = tonumber( _yPos )
    if _rid and _xPos and _yPos then
        checkPos( _xPos, _yPos )
        -- 更新当前城市坐标
        local toPos = { x = _xPos * 600, y = _yPos * 600 }
        RoleLogic:setRole( _rid, { [Enum.Role.pos] = toPos } )
        RoleSync:syncSelf( _rid, { [Enum.Role.pos] = toPos }, true )
        -- 地图城市对象移动
        local cityId = RoleLogic:getRole( _rid, Enum.Role.cityId )
        local cityIndex = RoleLogic:getRoleCityIndex( _rid )
        MSM.MapObjectMgr[_rid].req.cityMove( _rid, cityId, cityIndex, toPos )
    end
end

---@see 强制迁城
function PMLogic:forceMoveCity( _rid )
    RoleLogic:forceMoveCity( _rid )
end

---@see 解锁坐标所在迷雾
function PMLogic:scoutDenseFog( _rid, _xPos, _yPos )
    if _xPos and _yPos then
        local roleDenseFog = RoleLogic:getRole( _rid, Enum.Role.denseFog )
        checkPos( _xPos, _yPos )
        -- 计算出当前位置处于哪个迷雾格子中
        local x = math.floor( _xPos * 600 / 1800 )
        local y = math.floor( _yPos * 600 / 1800 )
        local pos = x + y * 400
        local index = math.floor( pos / 64 ) + 1
        if not roleDenseFog[index] then
            roleDenseFog[index] = { index = index, rule = 0 }
        end
        local denseRule = roleDenseFog[index]
        local thisIndex = pos % 64
        local thisRule = denseRule.rule & ( 1 << thisIndex )

        if thisRule == 0 then
            -- 处于迷雾状态,开启迷雾
            roleDenseFog[index].rule = denseRule.rule ~ ( 1 << thisIndex )
            RoleLogic:setRole( _rid, Enum.Role.denseFog, roleDenseFog )
            -- 同步给客户端
            Common.syncMsg( _rid, "Map_DenseFogOpen", { denseFogIndex = { index } } )
        end
    end
end

---@see 解锁全部迷雾
function PMLogic:scoutAllDenseFog( _rid )
    RoleLogic:setRole( _rid, { [Enum.Role.denseFog] = {}, [Enum.Role.denseFogOpenFlag] = true } )
    RoleSync:syncSelf( _rid, { [Enum.Role.denseFog] = {}, [Enum.Role.denseFogOpenFlag] = true }, true )
end

---@see 探索完成全部迷雾
function PMLogic:exploreDenseFog( _rid )
    local denseFog = {}
    for i = 1, 2500 do
        denseFog[i] = { index = i, rule = -1 }
    end

    RoleLogic:setRole( _rid, { [Enum.Role.denseFog] = denseFog, [Enum.Role.denseFogOpenFlag] = false } )
    RoleSync:syncSelf( _rid, { [Enum.Role.denseFog] = denseFog, [Enum.Role.denseFogOpenFlag] = false }, true )
end

---@see 增加行动力
function PMLogic:addActionForce( _rid, _addActionForce )
    _addActionForce = tonumber( _addActionForce ) or 0
    if _addActionForce ~= 0 then
        RoleLogic:addActionForce( _rid, _addActionForce, nil, 0, 0 )
    end
end

---@see 增加城市buff
function PMLogic:addBuff( _rid, _buffId )
    RoleLogic:addCityBuff( _rid, _buffId )
end

---@see 解锁驿站
function PMLogic:refreshPost( _rid )
    RoleLogic:refreshPost( _rid )
end

---@see 清空背包
function PMLogic:cleanRoleBag( _rid )
    for itemIndex, itemInfo in pairs( ItemLogic:getItem( _rid ) or {} ) do
        ItemLogic:delItem( _rid, itemIndex, itemInfo.overlay, nil, 0 )
    end
end

---@see 移除城市战争狂热buff
function PMLogic:removeCityWarCarzy( _rid )
    for i = 20101, 20113 do
        RoleLogic:removeCityBuff( _rid, i )
    end
end

---@see 移除城市buff
function PMLogic:removeCityBuff( _rid, _id )
    RoleLogic:removeCityBuff( _rid, _id )
end

--#################################军队相关模块##########################
---@see 创建军队
function PMLogic:createArmy( _rid, _mainHeroId, _deputyHeroId, _soldierArg )
    if not _mainHeroId or not _soldierArg or #_soldierArg <= 0 then
        LOG_DEBUG("PMLogic:modifyAttr error, arg error", _rid)
    end
    if not _deputyHeroId or #_deputyHeroId <= 0 then
        _deputyHeroId = nil
    end

    local soldiers = {}
    local soldierInfo, soldierId
    local soldierList = string.split( _soldierArg, "-" )
    for _, soldier in pairs( soldierList ) do
        soldierInfo = string.split( soldier, ":" )
        soldierId = tonumber( soldierInfo[1] )
        soldiers[soldierId] = {
            id = soldierId, level = soldierId % 100, num = tonumber( soldierInfo[2] )
        }
        soldiers[soldierId].type = math.tointeger( ( soldierId - soldiers[soldierId].level ) / 100 // 1 )
    end


    ArmyLogic:createArmy( _rid, _mainHeroId, _deputyHeroId, soldiers )
end

---@see 解散部队
function PMLogic:disbandArmy( _rid, _Index )
    local armyIndexs = {}
    _Index = tonumber( _Index )
    if _Index and _Index > 0 then
        table.insert( armyIndexs, _Index )
    else
        local allArmy = ArmyLogic:getArmy( _rid )
        for armyIndex in pairs( allArmy ) do
            table.insert( armyIndexs, armyIndex )
        end
    end

    local objectIndex, armyInfo, serviceIndex, targetObjectIndex, pos
    for _, armyIndex in pairs( armyIndexs ) do
        armyInfo = ArmyLogic:getArmy( _rid, armyIndex )
        if not ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
            objectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, armyIndex )
            if objectIndex then
                -- 删除地图上的对象
                MSM.AoiMgr[Enum.MapLevel.ARMY].req.armyLeave( Enum.MapLevel.ARMY, objectIndex, { x = -1, y = -1 } )
                -- 移除军队索引信息
                MSM.RoleArmyMgr[_rid].post.deleteRoleArmyIndex( _rid, armyIndex )
            end
            -- 解散军队
            ArmyLogic:disbandArmy( _rid, armyIndex )
        else
            -- 召回部队
            targetObjectIndex = armyInfo.targetArg and armyInfo.targetArg.targetObjectIndex
            if targetObjectIndex then
                pos = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectPos( targetObjectIndex )
                if pos then
                    serviceIndex = MapLogic:getObjectService( pos )
                    MSM.ResourceMgr[serviceIndex].req.callBackArmy( _rid, armyIndex )
                else
                    ArmyLogic:disbandArmy( _rid, armyIndex )
                end
            else
                ArmyLogic:disbandArmy( _rid, armyIndex )
            end
        end
    end
end

---@see 获取角色所在game
function PMLogic:getRoleGame( _rid )
    local gameNode = RoleLogic:getRoleGameNode( _rid )
    assert( false, gameNode or "no find" )
end

--#################################邮件相关模块##########################
function PMLogic:addSystemEmail(_rid, _emailId, _num )
    for _ = 1, _num or 1 do
        EmailLogic:addSystemEmail( _rid, _emailId )
    end
end

---@see 发送资源采集邮件
function PMLogic:sendResourceCollectEmail( _rid, _emailId, _resourceTypeId, _xPos, _yPos, _resource, _extraResource )
    if _rid and _emailId and _resourceTypeId and _xPos and _yPos and _resource then
        EmailLogic:sendResourceCollectEmail( _rid, _emailId, _resourceTypeId, { x = _xPos, y = _yPos }, _resource, _extraResource )
    end
end

---@see 发送探索发现报告邮件
function PMLogic:sendDiscoverEmail( _rid, _emailId, _xPos, _yPos, _mapFixPointId, _strongHoldType )
    local emailOtherInfo = {
        discoverReport = {
            pos = { x = _xPos, y =_yPos },
            mapFixPointId = tonumber( _mapFixPointId ),
            strongHoldType = tonumber( _strongHoldType ),
        },
        subType = Enum.EmailSubType.DISCOVER_REPORT,
    }

    EmailLogic:sendEmail( _rid, _emailId, emailOtherInfo )
end

---@see 发送解析邮件
function PMLogic:sendFormatEmail( _rid, _emailId, _title, _subTitle, _contents, _test )
    if _test > 0 then
        EmailLogic:sendEmail( _rid, 100026, { rewards = { groupId =50001,wood = 10000} } )
        return
    end
    local titleContents
    local emailContents
    local subTitleContents
    if _title then
        _title = string.split(_title, "|")
        titleContents = {}
        for i = 1, table.size(_title) do
            table.insert(titleContents, _title[i])
        end
    end
    if _subTitle then
        _subTitle = string.split(_subTitle, "|")
        subTitleContents = {}
        for i = 1, table.size(_subTitle) do
            table.insert(subTitleContents, _subTitle[i])
        end
    end
    if _contents then
        _contents = string.split(_contents, "|")
        emailContents = {}
        for i = 1, table.size(_contents) do
            table.insert(emailContents, _contents[i])
        end
    end
    EmailLogic:sendEmail( _rid, _emailId, { emailContents = emailContents, subTitleContents = subTitleContents, titleContents = titleContents } )
end

---@see 修改邮件版本号
function PMLogic:updateEmailVersion( _rids )
    local rids = string.split( _rids, "-" )
    if #rids > 1 then
        for i = tonumber(rids[1]), tonumber(rids[2]) do
            EmailLogic:updateEmailVersion( i, true )
        end
    else
        EmailLogic:updateEmailVersion( tonumber( rids[1] ), true )
    end
end
--#################################统帅相关模块##########################
---@see 增加统帅
function PMLogic:addHero( _rid, _heroId )
    local heroInfo = HeroLogic:getHero( _rid, _heroId )
    if not heroInfo or table.empty( heroInfo ) then
        HeroLogic:addHero( _rid, _heroId )
    else
        LOG_DEBUG("PMLogic:addHero error, rid(%d) already have heroId(%d)", _rid, _heroId)
    end
end

---@see 解锁统帅所有技能
function PMLogic:unlockSkill( _rid, _heroId )
    local heroInfo = HeroLogic:getHero( _rid, _heroId )
    if not heroInfo or table.empty(heroInfo) then
        return
    end
    for i=1,5 do
        local skillId = _heroId * 100 + i
        if CFG.s_HeroSkill:Get( skillId ) then
            local maxLevel = 1
            for j=1,5 do
                if CFG.s_HeroSkillEffect:Get( skillId * 1000 + j) then
                    if j >= maxLevel then
                        maxLevel = j
                    end
                end
            end
            table.insert( heroInfo.skills, { skillId = skillId, skillLevel = maxLevel })
        end
    end
    HeroLogic:setHero( _rid, _heroId, heroInfo )
    HeroLogic:syncHero( _rid, _heroId, heroInfo, true)
end


---@see 解锁统帅所有技能
function PMLogic:oneKeyUpHero( _rid, _heroId )
    HeroLogic:pmUse( _rid, _heroId )
end

--#################################道具相关模块##########################
function PMLogic:getItemPackage( _rid, _groupId )
    if _rid and _groupId then
        ItemLogic:getItemPackage( _rid, _groupId )
    end
end

--#################################建筑相关模块##########################

---@see 建筑升满
function PMLogic:upGradeAllBuilding( _rid, _maxLevel )
    local buildings = BuildingLogic:getBuilding( _rid )
    _maxLevel = tonumber(_maxLevel) or 25
    for buildIndex in pairs( buildings ) do
        local buildInfo = BuildingLogic:getBuilding( _rid, buildIndex )
        if buildInfo.level > 25 then
            BuildingLogic:setBuilding( _rid, buildIndex, "level", 25 )
        end
        if buildInfo.level < _maxLevel then
            for i = buildInfo.level, _maxLevel do
                if CFG.s_BuildingLevelData:Get( buildInfo.type * 100 + i + 1 ) then
                    BuildingLogic:upGradeBuildCallBack( _rid, buildIndex )
                end
            end
        end
    end
end

---@see 建筑升级
function PMLogic:upGradeBuliding( _rid, _buildType, _level )
    local buildings = BuildingLogic:getBuilding( _rid )
    for _, buildInfo in pairs( buildings ) do
        if buildInfo.type == _buildType then
            buildInfo.level = _level
            MSM.d_building[_rid].req.Set( _rid, buildInfo.buildingIndex, buildInfo )
            BuildingLogic:syncBuilding( _rid, buildInfo.buildingIndex, buildInfo, true )
        end
    end
    -- 市政厅升级，同步修改角色属性等级
    if _buildType == Enum.BuildingType.TOWNHALL then
        RoleLogic:setRole( _rid, { [Enum.Role.level] = _level } )
        RoleSync:syncSelf( _rid, { [Enum.Role.level] = _level }, true )
        local cityIndex = RoleLogic:getRoleCityIndex( _rid )
        MSM.SceneCityMgr[cityIndex].post.updateCityLevel( cityIndex, _level )
    end
    RoleLogic:initRoleAttr( _rid )
end

---@see 创建建筑
function PMLogic:createBuild( _rid, _type, _xPos, _yPos, _normal )
    if _normal then
        return BuildingLogic:createBuliding( _rid, _type, _xPos, _yPos )
    end
    local newIndex = BuildingLogic:getFreeBuildingIndex( _rid )
    local version = RoleLogic:addVersion( _rid )
    local buildInfo = { buildingIndex = newIndex, type = _type , level = 1, finishTime = -1, pos = { x = _xPos, y = _yPos }, version = version,
                            lastRewardTime = 0 }
    MSM.d_building[_rid].req.Add( _rid, newIndex, buildInfo )
    BuildingLogic:syncBuilding( _rid, newIndex, buildInfo, true )
end

---@see 移动建筑
function PMLogic:moveBuild( _rid, _index, _xPos, _yPos )
    local buildInfo = BuildingLogic:getBuilding( _rid, _index )
    local version = RoleLogic:addVersion( _rid )
    buildInfo.pos = { x = _xPos, y = _yPos }
    buildInfo.version = version
    MSM.d_building[_rid].req.Set( _rid, _index, buildInfo )
    BuildingLogic:syncBuilding( _rid, _index, buildInfo, true )
end

---@see 删除建筑
function PMLogic:deleteBuild( _rid, _index, _type )
    local synBuildInfo = {}
    if _index then
        BuildingLogic:deleteBuilding( _rid, _index )
        synBuildInfo[_index] = { buildingIndex = _index, level = -1 }
        BuildingLogic:syncBuilding( _rid, _index, synBuildInfo, true )
    else
        local buildings = BuildingLogic:getBuilding( _rid )
        local indexs = {}
        for _, buildInfo in pairs( buildings ) do
            if buildInfo.type == _type then
                indexs[buildInfo.buildingIndex] = buildInfo.buildingIndex
            end
        end
        for buildingIndex in pairs(indexs) do
            BuildingLogic:deleteBuilding( _rid, buildingIndex )
            synBuildInfo[buildingIndex] = { buildingIndex = buildingIndex, level = -1 }
            BuildingLogic:syncBuilding( _rid, buildingIndex, synBuildInfo, true )
        end
    end
end

---@see 城墙燃烧
function PMLogic:startBurnWall( _rid )
    BuildingLogic:startBurnWall( _rid )
end

---@see 永久解锁第二队列
function PMLogic:unlockQueue( _rid, _sec)
    BuildingLogic:unlockQueue( _rid, _sec )
end

---@see 扣除城墙耐久
function PMLogic:reduceWallHp( _rid, _num )
    local buildInfo = BuildingLogic:getBuildingInfoByType( _rid, Enum.BuildingType.WALL )[1]
    if not buildInfo then
        return false
    end
    buildInfo.lostHp = ( buildInfo.lostHp or 0 ) + _num
    MSM.d_building[_rid].req.Set( _rid, buildInfo.buildingIndex, buildInfo )
    BuildingLogic:syncBuilding( _rid, buildInfo.buildingIndex, buildInfo, true )
end

--#################################科技相关模块##########################
function PMLogic:researchTechnology( _rid, _technologyType, _level )
    local technologies = RoleLogic:getRole( _rid, Enum.Role.technologies )
    if _technologyType == 0 then
        local studys = CFG.s_Study:Get()
        for _, info in pairs(studys) do
            if technologies[info.studyType] then
                if info.studyLv > technologies[info.studyType].level then
                    technologies[info.studyType].level = info.studyLv
                end
            else
                technologies[info.studyType] = { technologyType = info.studyType, level = info.studyLv }
            end
        end
    elseif _technologyType == -1 then
        technologies = {}
    else
        local studyConfig = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.STUDY ) or {}
        local config = studyConfig[_technologyType][_level]
        if not config then
            return
        end
        if not technologies[_technologyType] then
            technologies[_technologyType] = { technologyType = _technologyType, level = _level }
        else
            technologies[_technologyType].level = _level
        end
    end
    RoleLogic:setRole( _rid, { [Enum.Role.technologies] = technologies } )
    RoleSync:syncSelf( _rid, { [Enum.Role.technologies] = technologies } , true )
    local roleInfo = RoleLogic:getRole( _rid )
    RoleCacle:cacleTechnologyAttr( roleInfo )
    RoleLogic:setRole( _rid, roleInfo )
end

--#################################系统相关模块##########################
---@see 修改系统时间
function PMLogic:modifyTime( _, _time )
    local gameNode = Common.getSelfNodeName()
    assert( gameNode == "game3", "是不是傻, 去改game3的时间去！！！" )
    -- 时间不能向后改
    local timeInfo = string.split( _time, " " )
    local timeStamp = {}
    local yearInfo = string.split( timeInfo[1], "-", true )
    timeStamp.year = yearInfo[1]
    timeStamp.month = yearInfo[2]
    timeStamp.day = yearInfo[3]
    local hourInfo = string.split( timeInfo[2], ":", true )
    timeStamp.hour = hourInfo[1]
    timeStamp.min = hourInfo[2]
    timeStamp.sec = hourInfo[3]

    if os.time( timeStamp ) < os.time() then
        assert(false, "set time less nowtime, invalid")
    end
    -- 不能修改为跨天后的时间，会影响角色跨天定时器
    assert( not Timer.isDiffDay( os.time( timeStamp ) ), "是不是傻, 不能跨天改时间" )

    os.execute(string.format("date -s '%s'", _time))
end

--#################################任务相关模块##########################
function PMLogic:addTaskStatisticsSum( _rid, _type, _arg, _num )
    if _rid and _type and _num then
        _arg = _arg or -1
        TaskLogic:addTaskStatisticsSum( _rid, _type, _arg, _num )
    end
end

--#################################地图相关模块##########################
function PMLogic:getMapObject( _, _targetIndex )
    if _targetIndex then
        local targetTypeInfo = MSM.MapObjectTypeMgr[_targetIndex].req.getObjectInfo( _targetIndex )
        LOG_INFO("getMapObject targetIndex(%d) mapObject(%s)", _targetIndex, tostring(targetTypeInfo))
    end
end

---@see 探索村庄山洞
function PMLogic:scoutVillageCave( _rid, _villageCaveId )
    local pointIdList = string.split( _villageCaveId, "-" )
    if #pointIdList >= 1 then
        local min = tonumber( pointIdList[1] ) or 0
        local max = tonumber( pointIdList[2] or pointIdList[1] ) or 0
        if max > 0 then
            for id = min, max do
                RoleLogic:villageCaveScoutCallBack( _rid, id )
            end
        end
    end
end

---@see 城堡附近添加野蛮人
function PMLogic:addMonster( _rid, _levels, _xPos, _yPos )
    _xPos = tonumber( _xPos )
    _yPos = tonumber( _yPos )
    local pos
    if not _xPos or not _yPos then
        local rolePos = RoleLogic:getRole( _rid, Enum.Role.pos )
        pos = { x = rolePos.x + 1000, y = rolePos.y + 1000 }
    else
        checkPos( _xPos, _yPos )
        pos = { x = _xPos * 600, y = _yPos * 600 }
    end

    local monsterId = 1000 + ( tonumber( _levels ) or 1 )
    local sMonster = CFG.s_Monster:Get( monsterId )
    if sMonster and not table.empty( sMonster ) and sMonster.type == Enum.MonsterType.BARBARIAN then
        local serviceIndex = MapLogic:getObjectService( pos )
        MSM.MonsterMgr[serviceIndex].req.addMonster( monsterId, pos )
    end
end

---@see 添加符文
function PMLogic:addRuneInfo( _rid, _runeId, _xPos, _yPos )
    _xPos = tonumber( _xPos )
    _yPos = tonumber( _yPos )
    local pos
    if not _xPos or not _yPos then
        local rolePos = RoleLogic:getRole( _rid, Enum.Role.pos )
        pos = { x = rolePos.x + 1000, y = rolePos.y + 1000 }
    else
        checkPos( _xPos, _yPos )
        pos = { x = _xPos * 600, y = _yPos * 600 }
    end

    -- 掉落符文到地图上
    local objectIndex = Common.newMapObjectIndex()
    MSM.RuneMgr[objectIndex].post.addRuneInfo( _runeId, pos, 10001, objectIndex )
end

---@see 添加野蛮人城寨
function PMLogic:addMonsterCity( _, _level, _xPos, _yPos )
    _xPos = tonumber(_xPos)
    _yPos = tonumber(_yPos)
    if _xPos and _yPos then
        checkPos( _xPos, _yPos )
        local pos = { x = _xPos * 600, y = _yPos * 600 }
        local serviceIndex = MapLogic:getObjectService( pos )
        local monsterId = Enum.MonsterType.BARBARIAN_CITY * 1000 + tonumber( _level )
        MSM.MonsterCityMgr[serviceIndex].post.addMonsterCity( monsterId, pos )
    end
end

---@see 添加资源点
function PMLogic:addResource( _rid, _type, _level, _xPos, _yPos )
    local pos
    _xPos = tonumber(_xPos)
    _yPos = tonumber(_yPos)
    if _xPos and _yPos then
        pos = { x = _xPos * 600, y = _yPos * 600 }
    else
        local rolePos = RoleLogic:getRole( _rid, Enum.Role.pos )
        if rolePos then
            pos = { x = rolePos.x + 1000, y = rolePos.y + 1000 }
        end
    end

    if pos then
        local resourceId = _type * 10000 + _level
        local serviceIndex = MapLogic:getObjectService( pos )
        MSM.ResourceMgr[serviceIndex].req.addResource( resourceId, pos )
    end
end

---@see 执行城市隐藏检查逻辑
function PMLogic:checkCityHide()
    local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
    for i = 1, multiSnaxNum do
        MSM.CityHideMgr[i].post.cityHide()
    end
end

---@see 检查隐藏城市
function PMLogic:checkHideCity( _rids )
    local rids = string.split( _rids, "-" )
    local cityId
    if #rids > 1 then
        for i = tonumber(rids[1]), tonumber(rids[2]) do
            cityId = RoleLogic:getRole( i, Enum.Role.cityId )
            if cityId and cityId > 0 and not SM.c_map_object.req.Get( cityId ) then
                RoleLogic:setRole( i, Enum.Role.cityId, 0 )
            end
        end
    else
        cityId = RoleLogic:getRole( tonumber(rids[1]), Enum.Role.cityId ) or 0
        if cityId and cityId > 0 and not SM.c_map_object.req.Get( cityId ) then
            RoleLogic:setRole( tonumber(rids[1]), Enum.Role.cityId, 0 )
        end
    end
end

---@see 重置圣地关卡状态到初始争夺中
function PMLogic:resetHolyLand( _, _holyLandId )
    _holyLandId = tonumber(_holyLandId)
    if _holyLandId and _holyLandId > 0 then
        SM.HolyLandMgr.req.resetHolyLand( _holyLandId )
    end
end

---@see 添加守护者
function PMLogic:addGuard( _rid, _type, _xPos, _yPos )
    local pos
    _xPos = tonumber(_xPos)
    _yPos = tonumber(_yPos)
    if _xPos and _yPos then
        pos = { x = _xPos * 600, y = _yPos * 600 }
    else
        local rolePos = RoleLogic:getRole( _rid, Enum.Role.pos )
        if rolePos then
            pos = { x = rolePos.x + 1000, y = rolePos.y + 1000 }
        end
    end

    if pos then
        local monsterId = 3000 + _type
        local holyLandId = 10001
        local sMonster = CFG.s_Monster:Get( monsterId )
        if sMonster and not table.empty( sMonster ) and sMonster.type == Enum.MonsterType.HOLYLAND_GUARDIAN then
            MSM.HolyLandGuardMgr[holyLandId].req.addGuard( holyLandId, pos, monsterId )
        end
    end
end

---@see 添加召唤怪物
function PMLogic:summonMonster( _rid, _monsterId )
    local objectIndex = Common.newMapObjectIndex()
    MSM.MonsterSummonMgr[objectIndex].req.summonMonster( _rid, _monsterId, objectIndex )
end

---@see 添加召唤怪物
function PMLogic:logObjectNum( _, _zoneIndex )
    _zoneIndex = tonumber(_zoneIndex)
    local resources, monsters, monsterCitys
    if _zoneIndex then
        local serviceIndex = MapLogic:getObjectService( nil, _zoneIndex )
        resources = MSM.ResourceMgr[serviceIndex].req.getZoneObjectNum( _zoneIndex )
        monsters = MSM.MonsterMgr[serviceIndex].req.getZoneObjectNum( _zoneIndex )
        monsterCitys = MSM.MonsterCityMgr[serviceIndex].req.getZoneObjectNum( _zoneIndex )
    else
        resources = {}
        monsters = {}
        monsterCitys = {}
        local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
        for i = 1, multiSnaxNum do
            table.mergeEx(
                resources,
                MSM.ResourceMgr[i].req.getZoneObjectNum()
            )
            table.mergeEx(
                monsters,
                MSM.MonsterMgr[i].req.getZoneObjectNum()
            )
            table.mergeEx(
                monsterCitys,
                MSM.MonsterCityMgr[i].req.getZoneObjectNum()
            )
        end
    end

    local logInfo = ""
    local size = 0
    for index, num in pairs( resources ) do
        logInfo = string.format( "%s zone(%d):monster(%d),resource(%d),monsterCity(%d)",
            logInfo, index, monsters[index] or 0, num, monsterCitys[index] or 0)
        size = size + 1
        if size == 50 then
            LOG_INFO("logObjectNum:%s", logInfo)
            logInfo = ""
            size = 0
        end
    end
    if size > 0 then
        LOG_INFO("logObjectNum:%s", logInfo)
    end
end

---@see 调整省份是否已满
function PMLogic:modifyFullProvice( _, _addProvice, _delProvice )
    local sharedata = require "skynet.sharedata"
    local FullProvice = table.copy( sharedata.query( Enum.Share.FullProvice ), true )
    _addProvice = tonumber( _addProvice )
    if _addProvice then
        FullProvice[_addProvice] = true
    end

    _delProvice = tonumber( _delProvice )
    if _delProvice then
        FullProvice[_delProvice] = nil
    end

    sharedata.update( Enum.Share.FullProvice, FullProvice )
    sharedata.flush()
end

---@see 回收城市进入地图
function PMLogic:cityEnterMap( _startRid, _endRid )
    _startRid = tonumber( _startRid ) or 0
    _endRid = tonumber( _endRid ) or _startRid

    local fields = { Enum.Role.cityId, Enum.Role.name, Enum.Role.level, Enum.Role.country, Enum.Role.guildId }
    for rid = _startRid, _endRid do
        local roleInfo = RoleLogic:getRole( rid, fields ) or {}
        if not table.empty( roleInfo ) then
            local mapCityInfo = SM.c_map_object.req.Get( roleInfo.cityId )
            if roleInfo.cityId <= 0 or not mapCityInfo then
                -- 城市不在地图上
                local cityPos = MapLogic:randomCityIdlePos( rid, 0, nil, true )
                local cityId = MSM.MapObjectMgr[rid].req.cityAddMap( rid, roleInfo.name, roleInfo.level, roleInfo.country, cityPos )
                RoleLogic:setRole( rid, { [Enum.Role.cityId] = cityId, [Enum.Role.pos] = cityPos } )
                -- 开城堡附近迷雾
                if not roleInfo.denseFogOpenFlag then
                    DenseFogLogic:openDenseFogInPos( rid, cityPos, 2 * Enum.DesenFogSize, true )
                end
                -- 角色在联盟中，同步角色位置给联盟成员
                if cityPos and roleInfo.guildId > 0 then
                    local allOnlineMembers = GuildLogic:getAllOnlineMember( roleInfo.guildId ) or {}
                    if #allOnlineMembers > 0 then
                        GuildLogic:syncGuildMemberPos( allOnlineMembers, { [rid] = { rid = rid, pos = cityPos } } )
                    end
                end
            end
        end
    end
end
--#################################联盟相关模块##########################
---@see 解散联盟
function PMLogic:disbandGuild( _rid, _guildId )
    _guildId = _guildId or RoleLogic:getRole( _rid, Enum.Role.guildId )
    if _guildId and _guildId > 0 then
        GuildLogic:disbandGuild( _guildId )
    end
end

---@see 修改属性
function PMLogic:modifyGuildAttr( _rid, _guildId, _attrName, _attrValue )
    _guildId = tonumber( _guildId )
    if not _guildId or _guildId <= 0 then
        _guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
        if _guildId <= 0 then
            return
        end
    end

    if not GuildLogic:checkGuild( _guildId ) then
        return
    end

    local guildValue = GuildLogic:getGuild( _guildId, _attrName )
    if guildValue then
        guildValue = guildValue + tonumber( _attrValue )
        GuildLogic:setGuild( _guildId, _attrName, guildValue )
        local members = GuildLogic:getGuild( _guildId, Enum.Guild.members ) or {}
        for memberRid in pairs( members ) do
            GuildLogic:syncGuild( memberRid, { [_attrName] = guildValue }, true )
        end
    end
end

---@see 增加消费联盟货币记录信息
function PMLogic:addGuildConsumeRecord( _rid, _guildId, _type, _args, _consumeCurrencies )
    _guildId = tonumber( _guildId )
    if not _guildId or _guildId <= 0 then
        _guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
        if _guildId <= 0 then
            return
        end
    end

    if not GuildLogic:checkGuild( _guildId ) then
        return
    end

    _args = string.split( _args, "-" )
    local consumeCurrencies = {}
    local consumeList = string.split( _consumeCurrencies, "-" )
    for _, consume in pairs( consumeList ) do
        local consumeArgs = string.split( consume, ":" )
        consumeCurrencies[consumeArgs[1]] = {
            type = consumeArgs[1],
            num = consumeArgs[2],
        }
    end
    -- 增加消费联盟货币记录信息
    GuildLogic:addConsumeRecord( _guildId, _rid, _type, _args, consumeCurrencies )
end

---@see 增加联盟货币
function PMLogic:addGuildCurrency( _rid, _guildId, _type, _addNum )
    _guildId = tonumber( _guildId )
    if not _guildId or _guildId <= 0 then
        _guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
        if _guildId <= 0 then
            return
        end
    end
    if not GuildLogic:checkGuild( _guildId ) then
        return
    end
    _type = tonumber( _type )
    if _type then
        GuildLogic:addGuildCurrency( _guildId, _type, _addNum )
    else
        for type = 107, 111 do
            GuildLogic:addGuildCurrency( _guildId, type, 999999999 )
        end
    end
end

---@see 修改建筑属性
function PMLogic:modifyGuildBuild( _rid, _guildId, _buildIndex, _attrName, _addValue )
    _guildId = tonumber( _guildId )
    if not _guildId or _guildId <= 0 then
        _guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    end

    if not _guildId or _guildId <= 0 then return end

    local buildInfo = GuildBuildLogic:getGuildBuild( _guildId, _buildIndex ) or {}
    if buildInfo[_attrName] then
        GuildBuildLogic:setGuildBuild( _guildId, _buildIndex, { [_attrName] = buildInfo[_attrName] + _addValue } )
    end
end

---@see 占领圣地
function PMLogic:occupyHolyLand( _rid, _guildId, _holyLandId )
    _guildId = tonumber( _guildId )
    if not _guildId or _guildId <= 0 then
        _guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    end
    _holyLandId = tonumber(_holyLandId) or 0
    if _guildId > 0 and _holyLandId > 0 then
        SM.HolyLandMgr.req.occupyHolyLand( _holyLandId, _guildId )
    end
end

---@see 纪念碑事件解锁圣地
function PMLogic:mileStoneUnlockHolyLands( _, _mileStoneId )
    if _mileStoneId then
        HolyLandLogic:mileStoneUnlockHolyLands( _mileStoneId )
    end
end

---@see 发放礼物
function PMLogic:sendGuildGift( _rid, _guildId, _giftType, _isBuy, _isHideName )
    _guildId = tonumber( _guildId )
    _guildId = _guildId or RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
    if _guildId > 0 then
        local buyRid
        if _isBuy == "true" then
            buyRid = _rid
            if _isHideName == "true" then
                _isHideName = true
            else
                _isHideName = false
            end
        end
        MSM.GuildMgr[_guildId].post.sendGuildGift( _guildId, _giftType, buyRid, _isHideName )
    end
end

---@see 增加联盟科技经验值
function PMLogic:addGuildTechnologyExp( _rid, _guildId, _technologyType, _addExp )
    _guildId = tonumber( _guildId )
    _guildId = _guildId or RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
    if _guildId > 0 then
        local technologies = GuildLogic:getGuild( _guildId, Enum.Guild.technologies ) or {}
        if technologies then
            if not technologies[_technologyType] then
                technologies[_technologyType] = {
                    type = _technologyType,
                    level = 0,
                    exp = _addExp
                }
            else
                technologies[_technologyType].exp = technologies[_technologyType].exp + _addExp
            end
            local technologyId = _technologyType * 100 + technologies[_technologyType].level + 1
            local sAllianceStudy = CFG.s_AllianceStudy:Get( technologyId )
            if technologies[_technologyType].exp > sAllianceStudy.progress then
                technologies[_technologyType].exp = sAllianceStudy.progress
            end

            -- 更新联盟科技点信息
            GuildLogic:setGuild( _guildId, { [Enum.Guild.technologies] = technologies } )
        end
    end
end

---@see 增加联盟科技等级
function PMLogic:addGuildTechnologyLevel( _rid, _guildId, _technologyType, _addLevel )
    _guildId = tonumber( _guildId )
    _guildId = _guildId or RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
    _addLevel = tonumber( _addLevel ) or 1
    if _guildId > 0 then
        local technologies = GuildLogic:getGuild( _guildId, Enum.Guild.technologies ) or {}
        if not technologies[_technologyType] then
            technologies[_technologyType] = {
                type = _technologyType,
                level = _addLevel,
                exp = 0
            }
        else
            technologies[_technologyType].level = technologies[_technologyType].level + _addLevel
        end
        -- 更新联盟科技信息
        GuildLogic:setGuild( _guildId, { [Enum.Guild.technologies] = technologies } )
        -- 更新联盟属性
        MSM.GuildAttrMgr[_guildId].req.researchTechnologyFinish( _guildId, _technologyType )
        -- 通知客户端
        local onlineMembers = GuildLogic:getAllOnlineMember( _guildId )
        GuildTechnologyLogic:syncGuildTechnology( onlineMembers, { [_technologyType] = technologies[_technologyType] } )
    end
end

---@see 联盟成员增援联盟要塞
function PMLogic:reinforceGuildBuild( _rid, _mainHeroId, _deputyHeroId, _type, _level, _num )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
    assert(guildId > 0, string.format("rid(%d) not in guild", _rid))
    local guildBuilds = GuildBuildLogic:getGuildBuild( guildId ) or {}
    local centerFortress, buildIndex
    for index, buildInfo in pairs( guildBuilds ) do
        if buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS then
            buildIndex = index
            centerFortress = buildInfo
            break
        end
    end
    assert(buildIndex and buildIndex > 0, string.format("guild(%d) not have center fortress", guildId))
    local objectIndex = MSM.GuildBuildIndexMgr[guildId].req.getGuildBuildIndex( guildId, buildIndex ) or 0
    if objectIndex > 0 then
        local targetArg = { targetObjectIndex = objectIndex }
        local reinforceRoles = {}
        local reinforces = centerFortress.reinforces or {}
        for _, reinforce in pairs( reinforces ) do
            reinforceRoles[reinforce.rid] = reinforce.armyIndex
        end

        _mainHeroId = tonumber( _mainHeroId ) or 4000
        _deputyHeroId = tonumber( _deputyHeroId )

        local config, soldiers, soldierId, reinforceIndex, armyIndex
        _type = tonumber( _type ) or 1
        _level = tonumber( _level ) or 1
        _num = tonumber( _num ) or 10
        assert(_type >= 1 and _type <= 4, string.format("type(%d) error", _type))
        assert(_level >= 1 and _level <= 5, string.format("level(%d) error", _level))

        local armyNum = 0
        local armyStatus = Enum.ArmyStatus.GARRISONING
        local members = GuildLogic:getGuild( guildId, Enum.Guild.members ) or {}
        for memberRid in pairs( members ) do
            if not reinforceRoles[memberRid] then
                -- 解散所有的部队
                self:disbandArmy( memberRid )
                config = ArmyTrainLogic:getArmsConfig( memberRid, _type, _level ) or {}
                if not table.empty( config ) then
                    soldierId = config.ID
                    soldiers = RoleLogic:getRole( memberRid, Enum.Role.soldiers ) or {}
                    if not soldiers[soldierId] or soldiers[soldierId].num < _num then
                        ArmyTrainLogic:addSoldiers( memberRid, _type, _level, _num, Enum.LogType.TRAIN_ARMY, nil, true )
                    end
                    if not HeroLogic:checkHeroExist( memberRid, _mainHeroId ) then
                        HeroLogic:addHero( memberRid, _mainHeroId )
                    end
                    if not HeroLogic:checkHeroExist( memberRid, _deputyHeroId ) then
                        HeroLogic:addHero( memberRid, _deputyHeroId )
                    end
                    soldiers = {
                        [soldierId] = {
                            id = soldierId,
                            type = _type,
                            level = _level,
                            num = _num,
                            minor = 0
                        }
                    }
                    armyIndex = ArmyLogic:createArmy( memberRid, _mainHeroId, _deputyHeroId, soldiers, 0, nil, targetArg, armyStatus )
                    if armyIndex and armyIndex > 0 then
                        reinforceIndex = MSM.GuildMgr[guildId].req.getFreeBuildArmyIndex( guildId, buildIndex )
                        reinforces[reinforceIndex] = {
                            reinforceIndex = reinforceIndex,
                            rid = memberRid,
                            armyIndex = armyIndex,
                            startTime = os.time(),
                        }
                        armyNum = armyNum + 1
                        MSM.SceneGuildBuildMgr[objectIndex].post.addGarrisonArmy( objectIndex, memberRid, armyIndex, reinforceIndex )
                    end
                end
            end
        end
        GuildBuildLogic:setGuildBuild( guildId, buildIndex, Enum.GuildBuild.reinforces, reinforces )
        -- 清空关注角色
        local forcusRids = MSM.SceneGuildBuildMgr[objectIndex].req.getFocusRids( objectIndex ) or {}
        for memberRid in pairs( forcusRids ) do
            MSM.SceneGuildBuildMgr[objectIndex].post.deleteFocusRid( objectIndex, memberRid )
        end
        -- 更新联盟建筑建造时间
        if armyNum > 0 and centerFortress.status == Enum.GuildBuildStatus.BUILDING then
            MSM.GuildTimerMgr[guildId].req.resetGuildBuildTimer( guildId, buildIndex )
        end
        assert(false, string.format("增援成功%d支部队", armyNum))
    end
end

---@see 联盟成员增援盟友城市
function PMLogic:reinforceCity( _rid, _mainHeroId, _deputyHeroId, _type, _level, _num )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.guildId, Enum.Role.reinforces, Enum.Role.pos } ) or {}
    local guildId = roleInfo.guildId or 0
    assert(guildId > 0, string.format("rid(%d) not in guild", _rid))

    _mainHeroId = tonumber( _mainHeroId ) or 4000
    _deputyHeroId = tonumber( _deputyHeroId ) or 0

    _type = tonumber( _type ) or 1
    _level = tonumber( _level ) or 1
    _num = tonumber( _num ) or 10

    local config, roleSoldiers, soldierId, armyIndex, armyInfo, memberInfo, soldiers
    local armyStatus = Enum.ArmyStatus.GARRISONING
    local objectIndex = RoleLogic:getRoleCityIndex( _rid ) or 0
    assert( objectIndex > 0, string.format("rid(%d) not in map", _rid) )
    local members = GuildLogic:getGuild( guildId, Enum.Guild.members ) or {}
    local reinforces = roleInfo.reinforces or {}
    local targetArg = { targetObjectIndex = objectIndex, pos = roleInfo.pos }
    for memberRid in pairs( members ) do
        if memberRid ~= _rid and not reinforces[memberRid] then
            config = ArmyTrainLogic:getArmsConfig( memberRid, _type, _level ) or {}
            if not table.empty( config ) then
                soldierId = config.ID
                memberInfo = RoleLogic:getRole( memberRid, { Enum.Role.soldiers, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } ) or {}
                roleSoldiers = memberInfo.soldiers or {}
                if not roleSoldiers[soldierId] or roleSoldiers[soldierId].num < _num then
                    ArmyTrainLogic:addSoldiers( memberRid, _type, _level, _num, Enum.LogType.TRAIN_ARMY, nil, true )
                end
                if not HeroLogic:checkHeroExist( memberRid, _mainHeroId ) then
                    HeroLogic:addHero( memberRid, _mainHeroId )
                end
                if _deputyHeroId and _deputyHeroId > 0 and not HeroLogic:checkHeroExist( memberRid, _deputyHeroId ) then
                    HeroLogic:addHero( memberRid, _deputyHeroId )
                end

                soldiers = {
                    [soldierId] = {
                        id = soldierId,
                        type = _type,
                        level = _level,
                        num = _num,
                        minor = 0
                    }
                }

                armyIndex, armyInfo = ArmyLogic:createArmy( memberRid, _mainHeroId, _deputyHeroId, soldiers, 0, nil, targetArg, armyStatus )
                if armyIndex then
                    local defaultReinforceCity = {}
                    defaultReinforceCity.reinforceRid = memberRid
                    defaultReinforceCity.armyIndex = armyIndex
                    defaultReinforceCity.arrivalTime = os.time()
                    defaultReinforceCity.objectIndex = 0
                    defaultReinforceCity.mainHeroId = armyInfo.mainHeroId
                    defaultReinforceCity.mainHeroLevel = armyInfo.mainHeroLevel
                    defaultReinforceCity.deputyHeroId = armyInfo.deputyHeroId
                    defaultReinforceCity.deputyHeroLevel = 0
                    if _deputyHeroId and _deputyHeroId > 0 then
                        defaultReinforceCity.deputyHeroLevel = armyInfo.deputyHeroLevel
                    end
                    defaultReinforceCity.soldiers = armyInfo.soldiers
                    defaultReinforceCity.name = memberInfo.name
                    defaultReinforceCity.headId = memberInfo.headId
                    defaultReinforceCity.headFrameID = memberInfo.headFrameID
                    reinforces[memberRid] = defaultReinforceCity

                    ArmyLogic:updateArmyInfo( memberRid, armyIndex, { reinforceRid = _rid }, true )
                end
            end
        end
    end

    -- 添加到角色中
    RoleLogic:setRole( _rid, Enum.Role.reinforces, reinforces )
    -- 通知客户端
    RoleSync:syncSelf( _rid, { [Enum.Role.reinforces] = reinforces }, true )
end

---@see 导出联盟列表
function PMLogic:getGameGuildInfo( _, _gameNode )
    if not _gameNode or #_gameNode <= 0 then
        _gameNode = Common.getSelfNodeName()
    end

    local guildInfo, content, fortressBuild, guildBuilds, finishTime
    local centerNode = Common.getCenterNode()
    local fileName = string.format("%s.txt", _gameNode)
    os.execute(string.format("echo \"\" > %s", fileName))
    local guildIds = Common.rpcCall( centerNode, "GuildProxy", "getGuildIds", _gameNode ) or {}
    for guildId in pairs( guildIds ) do
        guildInfo = GuildLogic:getGuild( guildId ) or {}
        fortressBuild = nil
        guildBuilds = Common.rpcCall( _gameNode, "c_guild_building", "Get", guildId ) or {}
        for _, buildInfo in pairs( guildBuilds ) do
            if buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS then
                fortressBuild = buildInfo
                break
            end
        end

        if fortressBuild then
            finishTime = fortressBuild.buildRateInfo and fortressBuild.buildRateInfo.finishTime or nil
            content = string.format( "%d\t%s\t%d\t1\t%s\t%s",
                            guildId,
                            os.date("%Y-%m-%d %H:%M:%S", guildInfo.createTime),
                            guildInfo.leaderRid,
                            os.date("%Y-%m-%d %H:%M:%S", fortressBuild.createTime),
                            finishTime and os.date("%Y-%m-%d %H:%M:%S", finishTime) or ""
                            )
        else
            content = string.format( "%d\t%s\t%d", guildId, os.date("%Y-%m-%d %H:%M:%S", guildInfo.createTime), guildInfo.leaderRid )
        end
        os.execute(string.format("echo %s >> %s", content, fileName))
    end
end

---@see 批量加入联盟
function PMLogic:batchJoinGuild( _rid, _guildId, _startRid, _endRid )
    _guildId = tonumber( _guildId ) or 0
    if _guildId <= 0 then
        _rid = tonumber( _rid ) or 0
        if _rid > 0 then
            _guildId = RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
        end
    end

    assert( _guildId > 0, "联盟ID错误" )
    _startRid = tonumber( _startRid ) or 0
    _endRid = tonumber( _endRid ) or 0

    local joinNum = 0
    for memberRid = _startRid, _endRid do
        if RoleLogic:getRole( memberRid, Enum.Role.level ) and ( RoleLogic:getRole( memberRid, Enum.Role.guildId ) or 0 ) <= 0 then
            -- 存在且不再联盟中的角色加入联盟
            if not GuildLogic:joinGuild( _guildId, memberRid, Enum.GuildJob.R1 ) then
                break
            end
            joinNum = joinNum + 1
        end
    end

    assert(false, string.format("成功加入联盟%d个角色", joinNum))
end

--#################################活动相关模块##########################
function PMLogic:reSetActivityBox( _rid, _activityId )
    local activity = RoleLogic:getRole( _rid, Enum.Role.activity )
    if activity[_activityId] then activity[_activityId].rewardBox = true end
    RoleLogic:setRole( _rid, { [Enum.Role.activity] = activity } )
end

--#################################充值相关模块##########################
function PMLogic:buyDenar( _rid, _id, _index )
    local data = {
        rid = _rid,
        pc_id = _id,
        sn = os.time(),
        iggid = RoleLogic:getRole( _rid, Enum.Role.iggid ),
        index = _index,
    }
    SM.RechargeMgr.req.recharge(data)
end

---@see 触发限时礼包
function PMLogic:triggerLimitPackage( _rid, _id, _time )
    local id = CFG.s_Price:Get(_id).rechargeTypeID
    local sRechargeLimitTimeBag = CFG.s_RechargeLimitTimeBag:Get( id )
    local roleInfo = RoleLogic:getRole( _rid , { Enum.Role.limitTimePackage, Enum.Role.newLimitPackageCount } )
    local limitTimePackage = roleInfo.limitTimePackage
    local newLimitPackageCount = roleInfo.newLimitPackageCount
    local newIndex = RechargeLogic:getFreeIndex( _rid )
    local synChangeInfo = {}
    limitTimePackage[newIndex] = { index = newIndex, id = _id, expiredTime = -1 }
    if table.size(limitTimePackage) <= 10 then
        limitTimePackage[newIndex].expiredTime = os.time() + sRechargeLimitTimeBag.time - _time
        MSM.RoleTimer[_rid].req.addLimitPackageTimer( _rid, newIndex, limitTimePackage[newIndex].expiredTime )
    end
    RoleLogic:setRole( _rid, { [Enum.Role.battleLostPower] = 0 } )
    synChangeInfo[newIndex] = limitTimePackage[newIndex]
    RoleLogic:setRole( _rid, { [Enum.Role.limitTimePackage] = limitTimePackage, [Enum.Role.newLimitPackageCount] = newLimitPackageCount } )
    RoleSync:syncSelf( _rid, { [Enum.Role.limitTimePackage] = synChangeInfo }, true )
end

---@see 发送跑马灯
function PMLogic:sendMarquee( _, _languageId, _args, _msg )
    if _args then
        _args = string.split( _args, "-" )
    end

    local RoleChatLogic = require "RoleChatLogic"
    RoleChatLogic:sendMarquee( _languageId, _args, _msg )
end

---@see 纪念碑事件解锁圣地
function PMLogic:monumentEnd()
    MonumentLogic:monumentEnd()
end

---@see 纪念碑事件解锁圣地
function PMLogic:resetWallTime( _rid )
    local buildInfo = BuildingLogic:getBuildingInfoByType( _rid, Enum.BuildingType.WALL )[1]
    buildInfo.serviceTime = 0
    MSM.d_building[_rid].req.Set( _rid, buildInfo.buildingIndex, buildInfo )
    BuildingLogic:syncBuilding( _rid, buildInfo.buildingIndex, buildInfo, true )
end

---@see 远征通关
function PMLogic:expedtion( _rid, _id, _star,_floor )
    local expeditionInfo = RoleLogic:getRole( _rid, Enum.Role.expeditionInfo )
    local RankLogic = require "RankLogic"
    if _floor then
        for i = 1, _id do
            if not expeditionInfo[i] then
                expeditionInfo[i] = { id = i, star = 3, reward = true, finishTime = os.time() }
                local syncInfo = {}
                syncInfo[i] = expeditionInfo[i]
                -- 更新记录
                RoleLogic:setRole( _rid, { [Enum.Role.expeditionInfo] = expeditionInfo } )
                -- 通知客户端
                RoleSync:syncSelf( _rid, { [Enum.Role.expeditionInfo] = syncInfo }, true, true )
                -- 更新排行版
                RankLogic:update( _rid, Enum.RankType.EXPEDITION, i, nil, 3 )
            end
        end
    else
        if not expeditionInfo[_id] then
            expeditionInfo[_id] = { id = _id, star = _star, reward = true, finishTime = os.time() }
            local syncInfo = {}
            syncInfo[_id] = expeditionInfo[_id]
            -- 更新记录
            RoleLogic:setRole( _rid, { [Enum.Role.expeditionInfo] = expeditionInfo } )
            -- 通知客户端
            RoleSync:syncSelf( _rid, { [Enum.Role.expeditionInfo] = syncInfo }, true, true )
            RankLogic:update( _rid, Enum.RankType.EXPEDITION, _id, nil, _star )
        end
    end
end

---@see 一键解锁
function PMLogic:allLevelUp( _rid )
    self:upGradeAllBuilding( _rid)
    self:researchTechnology( _rid, 0 )
    self:scoutAllDenseFog( _rid )
    local sHero = CFG.s_Hero:Get()
    for id, heroInfo in pairs( sHero ) do
        if heroInfo.getItem > 0 and heroInfo.listDisplay <= 0 then
            self:addHero( _rid, id )
        end
    end
    for i = 1, 4 do
        for j = 1, 5 do
            PMLogic:addSoldiers( _rid, i, j, 1000000 )
        end
    end
end

---@see 移民
function PMLogic:immigrate( _rid, _targetGameNode )
    MSM.Role[_rid].req.Immigrate( { rid = _rid, targetGameNode = _targetGameNode } )
end

---@see 推荐服务器
function PMLogic:setRecommend( _, _areas, _gameNode )
    local loginNode = assert( Common.getClusterNodeByName( "login1" ) )
    if loginNode then
        local config = {
            {
                serverNode = _gameNode,
                recommendArea = string.split( _areas, "-" )
            }
        }
        Common.rpcMultiCall( loginNode, "AccountRefer", "updateRecommendConfig", config )
    end
end

---@see 创建联盟建筑
function PMLogic:createGuildBuild( _rid, _type, _x, _y )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    if guildId > 0 then
        MSM.GuildMgr[guildId].req.createGuildBuild( guildId, _rid, _type, { x = _x * 600, y = _y * 600 }, true )
    end
end

---@see 重置活动
function PMLogic:reSetActivity( _ )
    SM.ActivityMgr.req.PmSetActivity()
end

return PMLogic