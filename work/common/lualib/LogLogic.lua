--[[
* @file : LogLogic.lua
* @type : lualib
* @author : linfeng
* @created : Mon Dec 17 2018 10:09:40 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 运营相关日志逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]


local LogLogic = {}
local logNode

---@see 获取日志必要字段
function LogLogic:getRequireField( _iggid )
    -- 时间\tIGGID\tserverid
    return string.format("%s\t%s\t%s\t%s", os.date('%Y-%m-%d %H:%M:%S', os.time()), _iggid or "",
                Common.getSelfNodeName(), os.date('%Y-%m-%d %H:%M:%S', Common.getSelfNodeOpenTime()))
end

---@see 获取角色通用记录信息.用于玩家行为日志
function LogLogic:getRoleLogRequireInfo( _rid )
    local RoleLogic = require "RoleLogic"
    local roleInfo = RoleLogic:getRole( _rid )
    local lv1Num = 0
    local lv2Num = 0
    local lv3Num = 0
    local lv4Num = 0
    local lv5Num = 0
    for _, v in pairs(roleInfo.soldiers or {}) do
        if v.level == 1 then
            lv1Num = lv1Num + v.num
        elseif v.level == 2 then
            lv2Num = lv2Num + v.num
        elseif v.level == 3 then
            lv3Num = lv3Num + v.num
        elseif v.level == 4 then
            lv4Num = lv4Num + v.num
        elseif v.level == 5 then
            lv5Num = lv5Num + v.num
        end
    end

    local ArmyLogic = require "ArmyLogic"
    local armys = ArmyLogic:getArmy( _rid ) or {}
    local armyIndexs = ""
    for armyIndex in pairs( armys ) do
        if #armyIndexs > 0 then
            armyIndexs = string.format("%s/%d", armyIndexs, armyIndex)
        else
            armyIndexs = tostring(armyIndex)
        end
    end

    return string.format(
        "%d\t%s\t%d\t%s\t%s\t%d\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%d\t%d\t%d\t%s\t%d",
        _rid,                                                                   -- 角色rid
        Common.getSelfNodeName(),                                               -- 所在服务器
        roleInfo.level,                                                         -- 角色等级
        roleInfo.name,                                                          -- 角色名称
        os.date('%Y-%m-%d %H:%M:%S', roleInfo.createTime),                      -- 创角时间
        roleInfo.todayLoginTime,                                                -- 本日在线时长
        roleInfo.allLoginTime,                                                  -- 累计在线时长
        roleInfo.createVersion,                                                 -- 创角版本
        roleInfo.country,                                                       -- 角色文明
        roleInfo.combatPower,                                                   -- 角色战斗力
        roleInfo.pos.x,                                                         -- X坐标
        roleInfo.pos.y,                                                         -- Y坐标
        roleInfo.guildId or 0,                                                  -- 联盟ID
        roleInfo.activePoint or 0,                                              -- 活跃度
        roleInfo.denar,                                                         -- 代币
        roleInfo.food,                                                          -- 粮食
        roleInfo.wood,                                                          -- 木材
        roleInfo.stone,                                                         -- 石料
        roleInfo.gold,                                                          -- 金币
        lv1Num,                                                                 -- 1级士兵总量
        lv2Num,                                                                 -- 2级士兵总量
        lv3Num,                                                                 -- 3级士兵总量
        lv4Num,                                                                 -- 4级士兵总量
        lv5Num,                                                                 -- 5级士兵总量
        roleInfo.ip or "",                                                      -- 角色当前IP
        roleInfo.phone or "",                                                   -- 角色手机机型
        roleInfo.area or "",                                                    -- 角色所在地区
        roleInfo.language or 0,                                                 -- 角色当前语言
        roleInfo.testGroup or 0,                                                -- A/B测试分组
        roleInfo.platform or 0,                                                 -- 设备平台
        roleInfo.version or "",                                                 -- 客户端版本
        roleInfo.quality or "",                                                 -- 客户端画质
        roleInfo.memory or "",                                                  -- 客户端内存
        roleInfo.fps or 0,                                                      -- 客户端FPS
        roleInfo.network or "",                                                 -- 客户端网络
        roleInfo.power or 0,                                                    -- 客户端剩余电量
        roleInfo.chargeStatus or 0,                                             -- 客户端充电状态
        roleInfo.volume or 0,                                                   -- 客户端音量
        armyIndexs,                                                             -- 部队索引ID
        roleInfo.rechargeDollar or 0                                            -- 玩家累计充值美分
    )
end

---@see 记录服务器在线
function LogLogic:serverOnline( _count )
    LOG_SERVER_ONLINE("%d\t%s\t%d", Enum.LogType.SERVER_ONLINE, self:getRequireField(), _count);
end

function LogLogic:getRoleSoldiers( _rid )
    local RoleLogic = require "RoleLogic"
    local ArmyLogic = require "ArmyLogic"

    local allSoldiers = {}
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.soldiers, Enum.Role.seriousInjured } ) or {}
    -- 城内士兵
    for _, soldier in pairs( roleInfo.soldiers or {} ) do
        if not allSoldiers[soldier.level] then
            allSoldiers[soldier.level] = {}
        end

        allSoldiers[soldier.level][soldier.type] = ( allSoldiers[soldier.level][soldier.type] or 0 ) + soldier.num
    end
    -- 重伤士兵
    for _, soldier in pairs( roleInfo.seriousInjured or {} ) do
        if not allSoldiers[soldier.level] then
            allSoldiers[soldier.level] = {}
        end

        allSoldiers[soldier.level][soldier.type] = ( allSoldiers[soldier.level][soldier.type] or 0 ) + soldier.num
    end

    -- 部队中的士兵
    local armys = ArmyLogic:getArmy( _rid ) or {}
    for _, army in pairs( armys ) do
        -- 部队剩余士兵
        for _, soldier in pairs( army.soldiers or {} ) do
            if not allSoldiers[soldier.level] then
                allSoldiers[soldier.level] = {}
            end

            allSoldiers[soldier.level][soldier.type] = ( allSoldiers[soldier.level][soldier.type] or 0 ) + soldier.num
        end
        -- 部队轻伤士兵
        for _, soldier in pairs( army.minorSoldiers or {} ) do
            if not allSoldiers[soldier.level] then
                allSoldiers[soldier.level] = {}
            end

            allSoldiers[soldier.level][soldier.type] = ( allSoldiers[soldier.level][soldier.type] or 0 ) + soldier.num
        end
    end

    return string.format( "%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d",
            allSoldiers[1] and allSoldiers[1][Enum.ArmyType.INFANTRY] or 0,
            allSoldiers[1] and allSoldiers[1][Enum.ArmyType.ARCHER] or 0,
            allSoldiers[1] and allSoldiers[1][Enum.ArmyType.CAVALRY] or 0,
            allSoldiers[1] and allSoldiers[1][Enum.ArmyType.SIEGE_UNIT] or 0,
            allSoldiers[2] and allSoldiers[2][Enum.ArmyType.INFANTRY] or 0,
            allSoldiers[2] and allSoldiers[2][Enum.ArmyType.ARCHER] or 0,
            allSoldiers[2] and allSoldiers[2][Enum.ArmyType.CAVALRY] or 0,
            allSoldiers[2] and allSoldiers[2][Enum.ArmyType.SIEGE_UNIT] or 0,
            allSoldiers[3] and allSoldiers[3][Enum.ArmyType.INFANTRY] or 0,
            allSoldiers[3] and allSoldiers[3][Enum.ArmyType.ARCHER] or 0,
            allSoldiers[3] and allSoldiers[3][Enum.ArmyType.CAVALRY] or 0,
            allSoldiers[3] and allSoldiers[3][Enum.ArmyType.SIEGE_UNIT] or 0,
            allSoldiers[4] and allSoldiers[4][Enum.ArmyType.INFANTRY] or 0,
            allSoldiers[4] and allSoldiers[4][Enum.ArmyType.ARCHER] or 0,
            allSoldiers[4] and allSoldiers[4][Enum.ArmyType.CAVALRY] or 0,
            allSoldiers[4] and allSoldiers[4][Enum.ArmyType.SIEGE_UNIT] or 0,
            allSoldiers[5] and allSoldiers[5][Enum.ArmyType.INFANTRY] or 0,
            allSoldiers[5] and allSoldiers[5][Enum.ArmyType.ARCHER] or 0,
            allSoldiers[5] and allSoldiers[5][Enum.ArmyType.CAVALRY] or 0,
            allSoldiers[5] and allSoldiers[5][Enum.ArmyType.SIEGE_UNIT] or 0
        )
end

---@see 记录角色创建
function LogLogic:roleCreate( _args )
    LOG_ROLE_CREATE("%d\t%d\t%s\t%s", Enum.LogType.ROLE_CREATE, _args.rid, self:getRequireField( _args.iggid ),
                    self:getRoleLogRequireInfo( _args.rid ))
end

---@see 记录角色登陆日志
function LogLogic:roleLogin( _args )
    local now = os.time()
    local logoutInterval = now - _args.lastLogoutTime
    if logoutInterval == now then
        logoutInterval = 0 -- 首次登陆
    end
    LOG_ROLE_LOGIN("%d\t%s\t%d\t%s\t%s", Enum.LogType.ROLE_LOGIN, self:getRequireField( _args.iggid ),
                    logoutInterval, self:getRoleSoldiers( _args.rid ), self:getRoleLogRequireInfo( _args.rid ))

    -- 向日志服务器发送角色登陆日志
    if logNode == nil then
        local skynet = require "skynet"
        logNode = "log" .. skynet.getenv("lognode")
    end
    Common.rpcMultiSend( logNode, "LogProxy", "roleLogin", _args.rid, {
        gameId = _args.gameId, serverId = Common.getSelfNodeId(),
        iggid = _args.iggid, ip = _args.ip
    })
end

---@see 记录角色登出日志
function LogLogic:roleLogout( _args )
    LOG_ROLE_LOGOUT("%d\t%s\t%d\t%s\t%s", Enum.LogType.ROLE_LOGOUT, self:getRequireField( _args.iggid ),
                    os.time() - _args.lastLoginTime, self:getRoleSoldiers( _args.rid ), self:getRoleLogRequireInfo( _args.rid ))
    -- 向日志服务器发送角色登出日志
    if logNode == nil then
        local skynet = require "skynet"
        logNode = "log" .. skynet.getenv("lognode")
    end
    Common.rpcMultiSend( logNode, "LogProxy", "roleLogout", _args.rid, {
        gameId = _args.gameId, serverId = Common.getSelfNodeId(),
        iggid = _args.iggid, ip = _args.ip,
        onlineSeconds = _args.onlineSeconds
    })
end

---@see 记录建筑创建
function LogLogic:buildCreate( _args )
    LOG_BUILD_CREATE("%d\t%s\t%d\t%d\t%s", _args.logType, self:getRequireField( _args.iggid ),
                _args.buildingId, _args.costTime, self:getRoleLogRequireInfo( _args.rid ))
end

---@see 记录士兵增减
function LogLogic:armsChange( _args )
    local logType2 = tostring( _args.logType2 )
    LOG_ARMY_CHANGE("%d\t%s\t%s\t%d\t%d\t%d\t%d\t%s", _args.logType, self:getRequireField( _args.iggid ),
                logType2, _args.armsID, _args.changeNum, _args.oldNum, _args.newNum, self:getRoleLogRequireInfo( _args.rid ))
end

---@see 新手引导
function LogLogic:roleGuide( _args )
    LOG_GUIDE("%d\t%s\t%d\t%s", Enum.LogType.ROLE_GUIDE, self:getRequireField( _args.iggid ),
                _args.guideId, self:getRoleLogRequireInfo( _args.rid ))
end

---@see 任务
function LogLogic:roleTask( _args )
    LOG_TASK("%d\t%s\t%d\t%s", Enum.LogType.TASK_AWARD, self:getRequireField( _args.iggid ),
                _args.taskId, self:getRoleLogRequireInfo( _args.rid ))
end

---@see 货币增减
function LogLogic:currencyChange( _args )
    local logType2 = tostring( _args.logType2 )
    LOG_CURRENCY("%d\t%s\t%s\t%d\t%d\t%d\t%d\t%s", _args.logType, self:getRequireField( _args.iggid ),
                logType2, _args.currencyId, _args.changeNum, _args.oldNum, _args.newNum, self:getRoleLogRequireInfo( _args.rid ))
end

---@see 道具增减
function LogLogic:itemChange( _args )
    local logType2 = tostring( _args.logType2 )
    LOG_ITEM("%d\t%s\t%s\t%d\t%d\t%d\t%d\t%s", _args.logType, self:getRequireField( _args.iggid ),
                logType2, _args.itemId, _args.changeNum, _args.oldNum, _args.newNum, self:getRoleLogRequireInfo( _args.rid ))
end

---@see 创建角色操作日志
function LogLogic:createClick( _args )
    LOG_CREATE_CLICK("%d\t%s\t%d", Enum.LogType.CREATE_CLICK, self:getRequireField( _args.iggid ), _args.operateId)
end

---@see 新手剧情日志
function LogLogic:guideDialog( _args )
    LOG_GUIDE_DIALOG("%d\t%s\t%d\t%s", Enum.LogType.NOVICE_PLOT, self:getRequireField( _args.iggid ), _args.plotId, self:getRoleLogRequireInfo( _args.rid ))
end

---@see 功能引导日志
function LogLogic:funcGuide( _args )
    LOG_FUNC_GUIDE("%d\t%s\t%d\t%s", Enum.LogType.FUNC_GUIDE, self:getRequireField( _args.iggid ), _args.guideId or 0, self:getRoleLogRequireInfo( _args.rid ) )
end

---@see 角色部队变化
function LogLogic:roleArmyChange( _args )
    local lv1Num = 0
    local lv2Num = 0
    local lv3Num = 0
    local lv4Num = 0
    local lv5Num = 0
    for _, v in pairs( _args.soldiers or {} ) do
        if v.level == 1 then
            lv1Num = lv1Num + v.num
        elseif v.level == 2 then
            lv2Num = lv2Num + v.num
        elseif v.level == 3 then
            lv3Num = lv3Num + v.num
        elseif v.level == 4 then
            lv4Num = lv4Num + v.num
        elseif v.level == 5 then
            lv5Num = lv5Num + v.num
        end
    end
    for _, v in pairs( _args.minorSoldiers or {} ) do
        if v.level == 1 then
            lv1Num = lv1Num + v.num
        elseif v.level == 2 then
            lv2Num = lv2Num + v.num
        elseif v.level == 3 then
            lv3Num = lv3Num + v.num
        elseif v.level == 4 then
            lv4Num = lv4Num + v.num
        elseif v.level == 5 then
            lv5Num = lv5Num + v.num
        end
    end
    LOG_ROLE_ARMY( "%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s", _args.logType, self:getRequireField( _args.iggid ), _args.mainHeroId,
                    _args.deputyHeroId, _args.armyIndex or 0, lv1Num, lv2Num, lv3Num, lv4Num, lv5Num, self:getRoleLogRequireInfo( _args.rid ) )
end

---@see 联盟日志
function LogLogic:roleGuild( _args )
    LOG_ROLE_GUILD( "%d\t%s\t%d\t%s\t%d\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d", Enum.LogType.ROLE_GUILD,
            self:getRequireField( _args.iggid ), _args.guildId, _args.createIggId or "", _args.createTime, _args.iggid,
            _args.abbreviationName, _args.name, _args.giftLevel, _args.currencies[Enum.CurrencyType.leaguePoints].num,
            _args.currencies[Enum.CurrencyType.allianceFood].num, _args.currencies[Enum.CurrencyType.allianceWood].num,
            _args.currencies[Enum.CurrencyType.allianceStone].num, _args.currencies[Enum.CurrencyType.allianceGold].num,
            _args.fortressFlag, _args.territory, table.size( _args.members or {} ), _args.memberLimit or 0 )
end

---@see 奇观建筑占领日志
function LogLogic:holyLandOccupy( _args )
    LOG_ROLE_STRONG_HOLD( "%d\t%s\t%d\t%d\t%d\t%s\t%d\t%d\t%s", Enum.LogType.HOLYLAND_OCCUPY, self:getRequireField( _args.iggid ),
            _args.holyLandId, _args.holyLandType, _args.oldGuildId, _args.oldGuildName, _args.occupyFlag, _args.guildId, _args.guildName )
end

---@see 地狱活动日志
function LogLogic:roleActivityInfernal( _args )
    LOG_ROLE_ACTIVITYINFERNAL( "%d\t%s\t%d\t%d\t%s", Enum.LogType.ROLE_ACTIVITYINFERNAL,
            self:getRequireField( _args.iggid ), _args.id, _args.stage, self:getRoleLogRequireInfo( _args.rid ) )
end

---@see 征服之始日志
function LogLogic:roleActivityDaysType( _args )
    LOG_ROLE_ACTIVITYDAYSTYPE( "%d\t%s\t%d\t%s", Enum.LogType.ROLE_ACTIVITYDAYSTYPE,
            self:getRequireField( _args.iggid ), _args.id, self:getRoleLogRequireInfo( _args.rid ) )
end

---@see 征服之始日志
function LogLogic:roleNewActivityDaysType( _args )
    LOG_ROLE_NEWACTIVITYDAYSTYPE( "%d\t%s\t%d\t%s", Enum.LogType.ROLE_NEWACTIVITYDAYSTYPE,
            self:getRequireField( _args.iggid ), _args.id, self:getRoleLogRequireInfo( _args.rid ) )
end

---@see 服务器纪念碑日志
function LogLogic:roleEvolution( _args )
    LOG_ROLE_EVOLUTION( "%d\t%s\t%d\t%d", Enum.LogType.ROLE_EVOLUTION,
            self:getRequireField( _args.iggid ), _args.id, _args.count )
end

---@see 斥候派遣日志
function LogLogic:roleScout( _args )
    LOG_ROLE_SCOUT( "%d\t%s\t%d\t%d\t%s", _args.logType or 0, self:getRequireField( _args.iggid ),
                _args.logType2 or 0, _args.logType3 or 0, self:getRoleLogRequireInfo( _args.rid ) )
end

---@see 斥候派遣日志
function LogLogic:roleRecharge( _args )
    LOG_ROLE_PLAYER_RECHARGE( "%d\t%s\t%d\t%s\t%s", Enum.LogType.ROLE_RECHARGE or 0, self:getRequireField( _args.iggid ),
                _args.id or 0, _args.price or "0", self:getRoleLogRequireInfo( _args.rid ) )
end

---@see 联盟建筑基础日志
function LogLogic:guildBuild( _args )
    LOG_GUILD_BUILD( "%d\t%s\t%d\t%d\t%d\t%d\t%s", _args.logType or 0, self:getRequireField( _args.iggid ), _args.guildId or 0,
                _args.buildIndex or 0, _args.buildType or 0, _args.buildNum, tostring(_args.logType2 or "") )
end

function LogLogic:getSoldiers( _soldiers )
    local allSoldiers = {}
    for _, soldier in pairs( _soldiers or {} ) do
        if not allSoldiers[soldier.level] then
            allSoldiers[soldier.level] = {}
        end

        allSoldiers[soldier.level][soldier.type] = ( allSoldiers[soldier.level][soldier.type] or 0 ) + soldier.num
    end

    return string.format( "%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d",
            allSoldiers[1] and allSoldiers[1][Enum.ArmyType.INFANTRY] or 0,
            allSoldiers[1] and allSoldiers[1][Enum.ArmyType.CAVALRY] or 0,
            allSoldiers[1] and allSoldiers[1][Enum.ArmyType.ARCHER] or 0,
            allSoldiers[1] and allSoldiers[1][Enum.ArmyType.SIEGE_UNIT] or 0,
            allSoldiers[2] and allSoldiers[2][Enum.ArmyType.INFANTRY] or 0,
            allSoldiers[2] and allSoldiers[2][Enum.ArmyType.CAVALRY] or 0,
            allSoldiers[2] and allSoldiers[2][Enum.ArmyType.ARCHER] or 0,
            allSoldiers[2] and allSoldiers[2][Enum.ArmyType.SIEGE_UNIT] or 0,
            allSoldiers[3] and allSoldiers[3][Enum.ArmyType.INFANTRY] or 0,
            allSoldiers[3] and allSoldiers[3][Enum.ArmyType.CAVALRY] or 0,
            allSoldiers[3] and allSoldiers[3][Enum.ArmyType.ARCHER] or 0,
            allSoldiers[3] and allSoldiers[3][Enum.ArmyType.SIEGE_UNIT] or 0,
            allSoldiers[4] and allSoldiers[4][Enum.ArmyType.INFANTRY] or 0,
            allSoldiers[4] and allSoldiers[4][Enum.ArmyType.CAVALRY] or 0,
            allSoldiers[4] and allSoldiers[4][Enum.ArmyType.ARCHER] or 0,
            allSoldiers[4] and allSoldiers[4][Enum.ArmyType.SIEGE_UNIT] or 0,
            allSoldiers[5] and allSoldiers[5][Enum.ArmyType.INFANTRY] or 0,
            allSoldiers[5] and allSoldiers[5][Enum.ArmyType.CAVALRY] or 0,
            allSoldiers[5] and allSoldiers[5][Enum.ArmyType.ARCHER] or 0,
            allSoldiers[5] and allSoldiers[5][Enum.ArmyType.SIEGE_UNIT] or 0
        )
end

---@see 联盟建筑建造部队加入.离开日志
function LogLogic:guildBuildTroops( _args )
    LOG_GUILD_BUILD_TROOP( "%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s", _args.logType or 0, self:getRequireField( _args.iggid ),
                _args.guildId or 0, _args.buildIndex or 0, _args.buildType or 0, _args.rid or 0, _args.mainHeroId or 0,
                _args.deputyHeroId or 0, _args.buildTime or 0, self:getSoldiers( _args.soldiers ) )
end

function LogLogic:getMarchSoldiers( _args )
    local normalSoldiers = {}
    local minorSoldiers = {}

    for _, soldier in pairs( _args.soldiers or {} ) do
        if not normalSoldiers[soldier.level] then
            normalSoldiers[soldier.level] = 0
        end

        normalSoldiers[soldier.level] = normalSoldiers[soldier.level] + ( soldier.num or 0 )
    end

    for _, soldier in pairs( _args.minorSoldiers or {} ) do
        if not minorSoldiers[soldier.level] then
            minorSoldiers[soldier.level] = 0
        end

        minorSoldiers[soldier.level] = minorSoldiers[soldier.level] + ( soldier.num or 0 )
    end

    return string.format( "%d|%d\t%d|%d\t%d|%d\t%d|%d\t%d|%d",
        normalSoldiers[1] or 0, minorSoldiers[1] or 0,
        normalSoldiers[2] or 0, minorSoldiers[2] or 0,
        normalSoldiers[3] or 0, minorSoldiers[3] or 0,
        normalSoldiers[4] or 0, minorSoldiers[4] or 0,
        normalSoldiers[5] or 0, minorSoldiers[5] or 0
    )
end

---@see 部队行军日志
function LogLogic:troopsMarch( _args )
    LOG_TROOPS_MARCH( "%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%d|%d\t%s", Enum.LogType.ROLE_ARMY_MARCH, self:getRequireField( _args.iggid ),
                _args.armyIndex or 0, _args.status or 0, _args.objectType or -1, _args.targetId or 0, _args.mainHeroId or 0,
                _args.deputyHeroId or 0, self:getMarchSoldiers( _args ), _args.pos and _args.pos.x or 0, _args.pos and _args.pos.y or 0,
                self:getRoleLogRequireInfo( _args.rid ) )
end

return LogLogic