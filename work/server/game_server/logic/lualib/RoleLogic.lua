--[[
* @file : RoleLogic.lua
* @type : lualib
* @author : linfeng
* @created : Wed Nov 22 2017 09:25:31 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色相关逻辑实现
* Copyright(C) 2017 IGG, All rights reserved
]]

local math = math
local RoleSync = require "RoleSync"
local RoleDef = require "RoleDef"
local Random = require "Random"
local EntityLoad = require "EntityLoad"
local Timer = require "Timer"
local LogLogic = require "LogLogic"
local reg = require "reg.core"
local RoleCacle = require "RoleCacle"
local MapObjectLogic = require "MapObjectLogic"
local timerCore = require "timer.core"
local SoldierLogic = require "SoldierLogic"
local AttrDef = require "AttrDef"

local RoleLogic = {}

---@see 获取角色指定数据
---@return defaultRoleAttrClass
function RoleLogic:getRole( _rid, _fields, _noCheck )
    local roleInfo = MSM.d_role[_rid].req.Get( _rid, _fields )
    if _noCheck then
        return roleInfo
    end
    -- 可能返回nil或者空的table或者返回数量和fields数量不一致
    if not roleInfo or ( table.empty( roleInfo ) and Common.isTable(_fields) ) then
        -- 返回nil或者empty table
        if _fields then
            -- 可能是获取的不落地的字段,这时候如果角色不在线,要重新计算
            roleInfo = self:initRoleAttr( _rid )
            if roleInfo then
                if type(_fields) == "table" then
                    local ret = {}
                    for _, field in pairs(_fields) do
                        if roleInfo[field] ~= nil then
                            ret[field] = roleInfo[field]
                        end
                    end
                    return ret
                else
                    if roleInfo[_fields] ~= nil then
                        return roleInfo[_fields]
                    else
                        LOG_WARNING("getRole rid(%s) after initRoleAttr still not found(%s), stack:%s", tostring(_rid), tostring(_fields), debug.traceback())
                        return
                    end
                end
            else
                LOG_WARNING("getRole not found rid(%s) info, after initRoleAttr, statck:%s", tostring(_rid), debug.traceback())
                return
            end
        else
            -- 获取的是全数据,没获取到,那就是rid不存在
            LOG_WARNING("getRole not found rid(%s) info, statck:%s", tostring(_rid), debug.traceback())
            return
        end
    elseif Common.isTable( _fields ) then
        -- 返回的字段长度和获取的不一致
        if #_fields ~= table.size(roleInfo) then
            roleInfo = self:initRoleAttr( _rid )
            if roleInfo then
                local ret = {}
                for _, field in pairs(_fields) do
                    if roleInfo[field] ~= nil then
                        ret[field] = roleInfo[field]
                    end
                end
                return ret
            else
                LOG_WARNING("getRole not found rid(%s) info, after initRoleAttr, statck:%s", tostring(_rid), debug.traceback())
                return
            end
        else
            return roleInfo
        end
    end

    if not _fields then
        -- 取全数据,判断是否离线了
        if roleInfo and roleInfo.online == nil then
            roleInfo = self:initRoleAttr( _rid )
        end
    end
    -- 这里是正常获取的
    return roleInfo
end

---@see 获取角色摘要信息
function RoleLogic:getRoleBrief( _rid )
    local gameNode = self:getRoleGameNode( _rid )
    local fields = { Enum.Role.rid, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.level, Enum.Role.guildId }
    local roleInfo = Common.rpcMultiCall( gameNode, "d_role", "Get", _rid, fields )

    if roleInfo then
        roleInfo.guildName = ""
        if roleInfo.guildId > 0 then
            roleInfo.guildName = Common.rpcCall( gameNode, "c_guild", "Get", roleInfo.guildId, Enum.Guild.abbreviationName )
        end
    end

    return roleInfo
end

---@see 更新角色指定数据
function RoleLogic:setRole( _rid, _fields, _data )
    return MSM.d_role[_rid].req.Set( _rid, _fields, _data )
end

---@see 锁定更新角色数据
function RoleLogic:lockSetRole( _rid, _fields, _data )
    return MSM.d_role[_rid].req.LockSet( _rid, _fields, _data )
end

---@see 角色登陆
function RoleLogic:onRoleLogin( _iggid, _uid, _rid, _username, _keeprole, _secret,
                                _account, _fd, _agentHandle, _agentName, _otherArg )
    if not _keeprole then
        -- 加载角色数据
        EntityLoad.loadRole( _rid )
        -- 提前设置online = true
        self:setRole( _rid, { [Enum.Role.online] = true } )
        -- 初始化属性
        self:initRoleAttr( _rid )
    end

    local lastLoginTime = self:getRole( _rid, Enum.Role.lastLoginTime )
    -- 设置角色城堡索引、客户端设备信息
    self:setRole( _rid, {
                            [Enum.Role.ip] = _otherArg.ip,
                            [Enum.Role.gameId] = _otherArg.gameId,
                            [Enum.Role.phone] = _otherArg.phone,
                            [Enum.Role.area] = _otherArg.area,
                            [Enum.Role.language] = _otherArg.language,
                            [Enum.Role.platform] = _otherArg.platform,
                            [Enum.Role.version] = _otherArg.version,
                            [Enum.Role.lastLoginTime] = os.time(),
                            [Enum.Role.online] = true,
                            [Enum.Role.fd] = _fd or 0,
                            [Enum.Role.secret] = _secret or "",
                            [Enum.Role.isAfk] = false
                        }
                )

    -- 添加心跳
    MSM.RoleHeartMgr[_rid].post.addRoleHeart( _rid )
    -- 记录登陆
    local roleInfo = self:getRole( _rid, {
        Enum.Role.lastLoginTime,
        Enum.Role.lastLogoutTime,
        Enum.Role.todayLoginTime,
        Enum.Role.guildId,
        Enum.Role.denseFogOpenFlag,
        Enum.Role.gameId,
        Enum.Role.ip,
        Enum.Role.newActivityOpenTime,
    } )
    if not roleInfo.newActivityOpenTime or roleInfo.newActivityOpenTime == 0 then
        self:setRole( _rid, { [Enum.Role.newActivityOpenTime] = os.time() } )
    end
    local ActivityLogic = require "ActivityLogic"
    ActivityLogic:resetHall( _rid )
    ActivityLogic:checkActivityOpen( _rid, true )
    -- 计算本日在线时长
    if Timer.getDiffDays( os.time(), roleInfo.lastLogoutTime ) > 0 or roleInfo.lastLogoutTime == 0 then
        -- 隔天登陆了,本地在线时长清0
        roleInfo.todayLoginTime = 0
        -- 登陆设置活动进度
        --MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.LOGIN_DAY, 1 )
    end
    -- 角色在联盟中更新联盟修改标识
    if roleInfo.guildId and roleInfo.guildId > 0 then
        MSM.GuildIndexMgr[roleInfo.guildId].post.addMemberIndex( roleInfo.guildId, _rid )
    end
    LogLogic:roleLogin( {
                            iggid = _iggid,
                            rid = _rid,
                            ip = roleInfo.ip,
                            gameId = roleInfo.gameId,
                            lastLoginTime = roleInfo.lastLoginTime,
                            lastLogoutTime = roleInfo.lastLogoutTime,
                            todayLoginTime = roleInfo.todayLoginTime
                        }
                    )

    local GuildLogic = require "GuildLogic"
    if not _keeprole then
        -- 修复装备
        RoleLogic:fixEquip( _rid )
        -- 检查队列状态（服务器重启）
        local BuildingLogic = require "BuildingLogic"
        BuildingLogic:checkBuildQueue( _rid )
        local ArmyTrainLogic = require "ArmyTrainLogic"
        ArmyTrainLogic:checkArmyQueue( _rid )
        local TechnologyLogic = require "TechnologyLogic"
        TechnologyLogic:checkTechnologyQueue( _rid )
        local HospitalLogic = require "HospitalLogic"
        HospitalLogic:checkTreatmentQueue( _rid )
        -- 创建定时器(AFK的时候再次登录不创建定时器)
        MSM.RoleTimer[_rid].req.OnRoleLoginTimer( _rid, lastLoginTime )
        -- 增加恢复行动力定时器
        self:addActionForceTimerOnLogin( _rid )
        -- 登录检查角色部队信息
        local ArmyLogic = require "ArmyLogic"
        ArmyLogic:checkArmyOnRoleLogin( _rid )
        -- 斥候状态修正
        local ScoutsLogic = require "ScoutsLogic"
        ScoutsLogic:checkScoutsObjectIndex( _rid )
        -- 酒馆定时器判断
        BuildingLogic:addGoldFreeOnLogin( _rid, true )
        -- 登陆处理个人排行版信息
        local RankLogic = require "RankLogic"
        RankLogic:roleLogin( _rid )
        -- 登陆处理城市buff
        self:cityBuffLogin( _rid )
        -- 商栈信息检测
        local TransportLogic = require "TransportLogic"
        TransportLogic:checkTransportOnRoleLogin( _rid, true )
        -- 检查是否需要开启圣地迷雾
        local DenseFogLogic = require "DenseFogLogic"
        if not roleInfo.denseFogOpenFlag then
            local HolyLandLogic = require "HolyLandLogic"
            HolyLandLogic:checkHolyLandDensefog( _rid, true )
            -- 检查角色迷雾是否已全部探索完
            DenseFogLogic:checkDenseFogOnRoleLogin( _rid, true )
        end
        -- 判断迷雾全开
        DenseFogLogic:onRoleLoginCheckOpenAllDenseFog( _rid )
        -- 计算每种类型资源满的时候
        --BuildingLogic:roleLoginCancelResources( _rid )
        BuildingLogic:checkMaterialQueue( _rid )
        -- 登录处理部分活动进度
        ActivityLogic:loginSetActivity( _rid, true )
        -- 登录发送联盟不活跃邮件
        Timer.runAfter( 200, GuildLogic.sendInactiveMembersEmail, GuildLogic, _rid )
    end
    -- 发送系统邮件
    MSM.SystemEmailMgr[_rid].req.onRoleLoginSendMail( _rid )
    -- 充值相关
    local RechargeLogic = require "RechargeLogic"
    RechargeLogic:onRolelogin( _rid )
    -- 登陆处理神秘商人
    self:loginPost( _rid, true )
    ActivityLogic:loginAutoExchange( _rid )
    self:checkPushSetting( _rid )
    -- 检查城市是否隐藏
    local CityHideLogic = require "CityHideLogic"
    CityHideLogic:checkCityHideOnRoleLogin( _rid, _uid )
    -- 检查角色联盟ID是否正确
    GuildLogic:checkRoleGuildOnRoleLogin( _rid )
    -- 刷新联盟中的角色战力
    GuildLogic:refreshGuildRolePower( _rid )
    -- 增加在线人数
    SM.OnlineMgr.post.addOnline( _rid, roleInfo.gameId )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.LOGIN_DAY, 1 )
    return true
end

---@see 角色进入AOI
function RoleLogic:roleEnterAoi( _rid, _keeprole,  _fd, _secret )
    local roleInfo = self:getRole( _rid, { Enum.Role.pos, Enum.Role.noviceGuideStep } )
    local sceneMgrObj = Common.getSceneMgr( Enum.MapLevel.CITY )
    local guideHideMapObject = CFG.s_Config:Get("guideHideMapObject")
    if not _keeprole then
        -- 新手引导未完成到指定步骤,不加入AOI
        if roleInfo.noviceGuideStep >= guideHideMapObject then
            -- 加入大地图AOI
            SM.MapLevelMgr.req.roleEnterMapLevel( _rid, roleInfo.pos, _fd, _secret )
        end
    else
        if roleInfo.noviceGuideStep >= guideHideMapObject then
            -- 更新fd,username
            sceneMgrObj.req.updateRoleFdSecret( _rid, _fd, _secret )
            -- 先 Leave 后 Enter
            SM.MapLevelMgr.req.roleReEnterMapLevel( _rid, roleInfo.pos, _fd, _secret )
        end
    end
end

---@see 角色断线
function RoleLogic:onRoleAfk( _iggid, _uid, _rid )
    if not _rid then
        return
    end
    -- 角色离开大地图AOI
    SM.MapLevelMgr.req.roleLeaveMapLevel( _rid )
    -- 移除心跳
    MSM.RoleHeartMgr[_rid].post.removeRoleHeart( _rid )
    local lastLogoutTime = os.time()
    local roleInfo = self:getRole( _rid, {
        Enum.Role.lastLoginTime, Enum.Role.todayLoginTime, Enum.Role.allLoginTime,
        Enum.Role.guildId, Enum.Role.focusBuildObject, Enum.Role.gameId, Enum.Role.ip
    } )
    -- 累计在线时长
    local onlineSeconds = lastLogoutTime - roleInfo.lastLoginTime
    roleInfo.allLoginTime = roleInfo.allLoginTime + onlineSeconds
    -- 本日在线时长
    if Timer.getDiffDays( lastLogoutTime, roleInfo.lastLoginTime ) > 0 then
        local nowDate = os.date( "*t", lastLogoutTime )
        roleInfo.todayLoginTime = nowDate.hour * 3600 + nowDate.min * 60 + nowDate.sec
    else
        roleInfo.todayLoginTime = roleInfo.todayLoginTime + onlineSeconds
    end
    -- 角色在联盟中更新联盟修改标识
    if roleInfo.guildId and roleInfo.guildId > 0 then
        MSM.GuildIndexMgr[roleInfo.guildId].post.addMemberIndex( roleInfo.guildId, _rid )
    end
    -- 移除角色关心的建筑
    for objectIndex, type in pairs( roleInfo.focusBuildObject or {} ) do
        if type == Enum.RoleBuildFocusType.GUILD_BUILD then
            MSM.SceneGuildBuildMgr[objectIndex].post.deleteFocusRid( objectIndex, _rid, true )
        elseif type == Enum.RoleBuildFocusType.HOLY_LAND then
            MSM.SceneHolyLandMgr[objectIndex].post.deleteFocusRid( objectIndex, _rid, true )
        end
    end
    -- 远征处理
    local ExpeditionLogic = require "ExpeditionLogic"
    ExpeditionLogic:exitExpedition( _rid )
    -- 刷新联盟中的角色战力
    local GuildLogic = require "GuildLogic"
    GuildLogic:refreshGuildRolePower( _rid )
    -- 更新角色信息
    self:setRole( _rid, {
                            [Enum.Role.requestEmail] = false,
                            [Enum.Role.lastLogoutTime] = lastLogoutTime,
                            [Enum.Role.todayLoginTime] = roleInfo.todayLoginTime,
                            [Enum.Role.allLoginTime] = roleInfo.allLoginTime,
                            [Enum.Role.isAfk] = true,
                            [Enum.Role.guildIndexs] = {},
                            [Enum.Role.exclusive] = false,
                        }
                )
    -- 减少在线人数
    SM.OnlineMgr.post.delOnline( _rid, roleInfo.gameId )
    -- 添加到隐藏城市服务中
    MSM.CityHideMgr[_rid].post.addCity( _rid )

    -- 保存数据
    EntityLoad.saveRole( _rid )
    -- 记录登出
    LogLogic:roleLogout( {
                            iggid = _iggid, rid = _rid, gameId = roleInfo.gameId,
                            lastLogoutTime = lastLogoutTime, lastLoginTime = roleInfo.lastLoginTime,
                            onlineSeconds = onlineSeconds, ip = roleInfo.ip } )
end

---@see 角色登出
function RoleLogic:onRoleLogout( _rid )
    -- 城市隐藏处理
    local CityHideLogic = require "CityHideLogic"
    CityHideLogic:checkCityHideOnRoleLogout( _rid )
    -- 移除定时器
    MSM.RoleTimer[_rid].req.OnRoleLogoutTimer( _rid )
    -- 卸载角色数据
    EntityLoad.unLoadRole( _rid )
end

---@see 获取角色详细属性用于推送给客户端
function RoleLogic:pushRole( _uid, _rid, _isRightNow )
    local ret = {}
    local _roleBase = self:getRole( _rid )
    ret.uid = _uid
    ret.rid = _rid
    ret.name = _roleBase.name
    ret.pos = _roleBase.pos
    ret.level = _roleBase.level
    ret.country = _roleBase.country
    ret.buildQueue = _roleBase.buildQueue
    ret.food = _roleBase.food
    ret.wood = _roleBase.wood
    ret.stone = _roleBase.stone
    ret.gold = _roleBase.gold
    ret.denar = _roleBase.denar
    ret.actionForce = _roleBase.actionForce
    ret.soldiers = _roleBase.soldiers
    ret.armyQueue = _roleBase.armyQueue
    ret.technologies = _roleBase.technologies
    ret.buildVersion = _roleBase.buildVersion
    ret.mainLineTaskId = _roleBase.mainLineTaskId
    ret.finishSideTasks = _roleBase.finishSideTasks
    ret.taskStatisticsSum = _roleBase.taskStatisticsSum
    ret.technologyQueue = _roleBase.technologyQueue
    ret.seriousInjured = _roleBase.seriousInjured
    ret.historyPower = _roleBase.historyPower
    ret.roleStatistics = _roleBase.roleStatistics
    ret.chapterId = _roleBase.chapterId
    ret.chapterTasks = _roleBase.chapterTasks
    ret.treatmentQueue = _roleBase.treatmentQueue
    ret.serverTime = timerCore.getmillisecond()
    ret.noviceGuideStep = _roleBase.noviceGuideStep
    ret.reinforces = _roleBase.reinforces
    ret.denseFog = _roleBase.denseFog
    ret.situStation = _roleBase.situStation
    ret.barbarianLevel = _roleBase.barbarianLevel
    ret.emailVersion = _roleBase.emailVersion
    ret.lastActionForceTime = _roleBase.lastActionForceTime
    ret.villageCaves = _roleBase.villageCaves
    ret.killCount = _roleBase.killCount
    ret.combatPower = _roleBase.combatPower
    ret.createTime = _roleBase.createTime
    ret.isChangeAge = _roleBase.isChangeAge
    ret.silverFreeCount = _roleBase.silverFreeCount
    ret.openNextSilverTime = _roleBase.openNextSilverTime
    ret.goldFreeCount = _roleBase.goldFreeCount
    ret.addGoldFreeAddTime = _roleBase.addGoldFreeAddTime
    ret.activePoint = _roleBase.activePoint
    ret.activePointRewards = _roleBase.activePointRewards
    ret.guildId = _roleBase.guildId
    ret.mainHeroId = _roleBase.mainHeroId
    ret.deputyHeroId = _roleBase.deputyHeroId
    ret.cityBuff = _roleBase.cityBuff
    ret.guildHelpPoint = _roleBase.guildHelpPoint
    ret.guildPoint = _roleBase.guildPoint
    local ActivityLogic = require "ActivityLogic"
    ret.activityTimeInfo = ActivityLogic:sendActivityInfo(_rid)
    ret.maxChatUniqueIndex = _roleBase.maxChatUniqueIndex
    ret.headList = _roleBase.headList
    ret.headFrameList = _roleBase.headFrameList
    ret.headFrameID = _roleBase.headFrameID
    ret.activity = _roleBase.activity
    ret.chatNoDisturbInfo = _roleBase.chatNoDisturbInfo
    ret.headId = _roleBase.headId
    ret.guardTowerHp = _roleBase.guardTowerHp
    ret.mysteryStore = _roleBase.mysteryStore
    ret.vip = _roleBase.vip
    ret.continuousLoginDay = _roleBase.continuousLoginDay
    ret.vipFreeBox = _roleBase.vipFreeBox
    ret.vipSpecialBox = _roleBase.vipSpecialBox
    ret.vipExpFlag = _roleBase.vipExpFlag
    ret.recharge = _roleBase.recharge
    ret.riseRoad = _roleBase.riseRoad
    ret.freeDaily = _roleBase.freeDaily
    ret.rechargeSale = _roleBase.rechargeSale
    ret.riseRoadPackage = _roleBase.riseRoadPackage
    ret.dailyPackage = _roleBase.dailyPackage
    ret.rechargeFirst = _roleBase.rechargeFirst
    ret.growthFund = _roleBase.growthFund
    ret.growthFundReward = _roleBase.growthFundReward
    ret.expedition = _roleBase.expedition
    ret.vipStore = _roleBase.vipStore
    ret.supply = _roleBase.supply
    ret.limitTimePackage = _roleBase.limitTimePackage
    ret.expeditionCoin = _roleBase.expeditionCoin
    ret.buyActionForceCount = _roleBase.buyActionForceCount
    ret.materialQueue = _roleBase.materialQueue
    ret.lastGuildDonateTime = _roleBase.lastGuildDonateTime
    ret.guildDonateCostDenar = _roleBase.guildDonateCostDenar
    ret.joinGuildTime = _roleBase.joinGuildTime
    ret.praiseFlag = _roleBase.praiseFlag
    ret.silence = _roleBase.silence
    ret.gameId = _roleBase.gameId
    ret.noviceGuideStepEx = _roleBase.noviceGuideStepEx
    ret.emailSendCntPerHour = MSM.EmailCountMgr[_rid].req.getSendEmails(_rid) or 0
    ret.denseFogOpenFlag = _roleBase.denseFogOpenFlag
    ret.pushSetting = _roleBase.pushSetting
    ret.historySoldiers = _roleBase.historySoldiers
    ret.expeditionInfo = _roleBase.expeditionInfo
    ret.eventTrancking = _roleBase.eventTrancking
    ret.gameNode = Common.getSelfNodeName()
    ret.itemAddTroopsCapacity = _roleBase.itemAddTroopsCapacity
    ret.itemAddTroopsCapacityCount = _roleBase.itemAddTroopsCapacityCount
    ret.markers = _roleBase.markers
    ret.activityActivePoint = _roleBase.activityActivePoint
    ret.abTestGroup = _roleBase.abTestGroup
    ret.usedMoveCityTypes = _roleBase.usedMoveCityTypes

    Common.syncMsg( _rid, "Role_RoleInfo", { roleInfo = ret }, _isRightNow, _isRightNow, nil, nil, true )
end

---@see 创建角色
function RoleLogic:createRole( _uid, _rid, _pos, _country, _iggid, _version, _languageId )
    -- 认为角色在线,加快创建速度
    EntityLoad.loadRole( _rid )
    -- 名字前缀
    local namPrefix = CFG.s_Config:Get("initialAcquiescentName_" .. _languageId)
    -- 角色名字
    local name = string.format(namPrefix, math.modf( ( _rid ~ 1106859 ) + Common.getSelfNodeId() * 10000000 ))
    local sConfig = CFG.s_Config:Get()
    local roleInfo = RoleDef:getDefaultRoleAttr()
    -- 更新角色属性
    roleInfo.uid = _uid
    roleInfo.rid = _rid
    roleInfo.name = name
    roleInfo.pos = _pos
    roleInfo.level = 1
    roleInfo.country = _country
    roleInfo.headId = 0
    roleInfo.iggid = _iggid
    roleInfo.createTime = os.time()
    -- 获得初始粮食
    roleInfo.food = sConfig.initialFood or 0
    -- 获得初始木材
    roleInfo.wood = sConfig.initialWood or 0
    -- 获得初始石料
    roleInfo.stone = sConfig.initialStone or 0
    -- 获得初始金币
    roleInfo.gold = sConfig.initialGold or 0
    -- 获得初始钻石
    roleInfo.denar = sConfig.initialDiamond or 0
    -- 创角版本
    roleInfo.createVersion = _version
    -- 默认领取第一个章节任务
    roleInfo.chapterId = 1
    -- 默认联盟科技捐献使用钻石数
    roleInfo.guildDonateCostDenar = sConfig.AllianceGemGiftNum

    -- 记录并解锁初始头像框
    local headFrameID
    for ID, v in pairs(CFG.s_PlayerHead:Get()) do
        if v.group == Enum.RoleHeadType.HEAD_FRAME and v.initial > 0 then
            headFrameID = ID
        end
    end
    roleInfo.headFrameID = headFrameID

    -- 初始化推送信息
    local sPushMessageGroup = CFG.s_PushMessageGroup:Get()
    local pushSetting = {}
    for id, info in pairs(sPushMessageGroup) do
        pushSetting[id] = { id = id, open = info.pushDefault }
    end
    roleInfo.pushSetting = pushSetting

    -- 角色所在区域开启迷雾
    local DenseFogLogic = require "DenseFogLogic"
    roleInfo.denseFog = DenseFogLogic:openDenseFogInPos( _rid, _pos, 2 * Enum.DesenFogSize, true, true )
    local ret = MSM.d_role[_rid].req.Add( _rid, roleInfo )
    if not ret then
        LOG_ERROR("createRole, add record to d_role fail, uid(%d)", _uid)
        -- 卸载角色数据(此时角色未登录,直接落地数据)
        EntityLoad.unLoadRole( _rid )
        return
    end

    -- 上报给登陆服务器
    local allLoginds = Common.getClusterNodeByName("login", true)
    if not Common.rpcMultiCall(allLoginds[Random.Get(1, #allLoginds)], "RoleQuery", "AddRoleList", _uid, _rid, name, Common.getSelfNodeName()) then
        LOG_ERROR("createRole, AddRoleList fail, uid(%d)", _uid)
        -- 删除角色
        MSM.d_role[_rid].req.Delete(_rid)
        -- 卸载角色数据(此时角色未登录,直接落地数据)
        EntityLoad.unLoadRole( _rid )
        return
    end

    -- 该城市进入地图
    local cityId = MSM.MapObjectMgr[_rid].req.cityAddMap( _rid, name, 1, _country, _pos )
    self:setRole( _rid, Enum.Role.cityId, cityId )
    -- 添加到隐藏城市服务中
    MSM.CityHideMgr[_rid].post.addCity( _rid )

    -- 领取初始主线任务
    local TaskLogic = require "TaskLogic"
    TaskLogic:taskAccept( _rid, sConfig.initTaskMain, true )

    -- 创建初始建筑队列
    local BuildingLogic = require "BuildingLogic"
    BuildingLogic:createBuildQueue( _rid )

    -- 创建初始建筑信息
    BuildingLogic:initBuilding( _rid )

    -- 创角给士兵
    local ArmyTrainLogic = require "ArmyTrainLogic"
    ArmyTrainLogic:createRoleGiveSoldiers( _rid )

    -- 创角给道具
    local ItemLogic = require "ItemLogic"
    ItemLogic:createRoleGiveItems(_rid)

    -- 增加初始护盾
    self:createRoleAddCityBuff( _rid, CFG.s_Config:Get("initialBuff") )

    -- 添加角色名称到角色推荐服务
    MSM.RoleNameMgr[_rid].post.addRole( _rid, name )

    -- 添加角色名字到名字表
    SM.GuildNameProxy.req.addRoleName( roleInfo.name, roleInfo.rid, Common.getSelfNodeName() )

    -- 记录日志
    LogLogic:roleCreate( { iggid = _iggid, rid = _rid } )

    -- 卸载角色数据(此时角色未登录,直接落地数据)
    EntityLoad.unLoadRole( _rid )

    return true
end

---@see 检查金币是否足够
function RoleLogic:checkGold( _rid, _checkGold )
    assert(_rid and _checkGold)
    local gold = self:getRole( _rid, Enum.Role.gold )
    return gold >= _checkGold
end

---@see 增加金币
function RoleLogic:addGold( _rid, _addGold, _noSync, _logType, _logExtraType )
    local _, gold, oldGold = self:lockSetRole( _rid, Enum.Role.gold, _addGold )
    if not _noSync then
        -- 同步到客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.gold] = gold }, true )
    end
    local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
    -- 记录日志
    LogLogic:currencyChange( { rid = _rid, logType = _logType, logType2 = _logExtraType,
            currencyId = Enum.CurrencyType.gold, changeNum = _addGold, oldNum = oldGold, newNum = gold, iggid = iggid } )
    -- 判断资源阈值
    local goldLimit = CFG.s_GameWarning:Get( Enum.ResourceLimitType.GOLD, "num" )
    if goldLimit and gold > goldLimit then
        Common.sendResourceAlarm( _rid, Enum.ResourceLimitType.GOLD, gold )
    end
    return gold, oldGold
end

---@see 检查粮食是否足够
function RoleLogic:checkFood( _rid, _checkFood )
    assert(_rid and _checkFood)
    local food = self:getRole( _rid, Enum.Role.food )
    return food >= _checkFood
end

---@see 增加粮食
function RoleLogic:addFood( _rid, _addFood, _noSync, _logType, _logExtraType )
    if _addFood == 0 then return end
    local _, food, oldFood = self:lockSetRole( _rid, Enum.Role.food, _addFood )
    if not _noSync then
        -- 同步到客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.food] = food }, true )
    end
    local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
    -- 记录日志
    LogLogic:currencyChange( { rid = _rid, logType = _logType, logType2 = _logExtraType,
            currencyId = Enum.CurrencyType.food, changeNum = _addFood, oldNum = oldFood, newNum = food, iggid = iggid } )
    -- 判断资源阈值
    local foodLimit = CFG.s_GameWarning:Get( Enum.ResourceLimitType.FOOD, "num" )
    if foodLimit and food > foodLimit then
        Common.sendResourceAlarm( _rid, Enum.ResourceLimitType.FOOD, food )
    end
    return food, oldFood
end

---@see 检查木材是否足够
function RoleLogic:checkWood( _rid, _checkWood )
    assert(_rid and _checkWood)
    local wood = self:getRole( _rid, Enum.Role.wood )
    return wood >= _checkWood
end

---@see 增加木材
function RoleLogic:addWood( _rid, _addWood, _noSync, _logType, _logExtraType )
    if _addWood == 0 then return end
    local _, wood, oldWood = self:lockSetRole( _rid, Enum.Role.wood, _addWood )
    if not _noSync then
        -- 同步到客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.wood] = wood }, true )
    end

    local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
    -- 记录日志
    LogLogic:currencyChange( { rid = _rid, logType = _logType, logType2 = _logExtraType,
            currencyId = Enum.CurrencyType.wood, changeNum = _addWood, oldNum = oldWood, newNum = wood, iggid = iggid } )
    -- 判断资源阈值
    local woodLimit = CFG.s_GameWarning:Get( Enum.ResourceLimitType.WOOD, "num" )
    if woodLimit and wood > woodLimit then
        Common.sendResourceAlarm( _rid, Enum.ResourceLimitType.WOOD, wood )
    end
    return wood, oldWood
end

---@see 检查石料是否足够
function RoleLogic:checkStone( _rid, _checkStone )
    assert(_rid and _checkStone)
    local stone = self:getRole( _rid, Enum.Role.stone )
    return stone >= _checkStone
end

---@see 增加石料
function RoleLogic:addStone( _rid, _addStone, _noSync, _logType, _logExtraType )
    if _addStone == 0 then return end
    local _, stone, oldStone = self:lockSetRole( _rid, Enum.Role.stone, _addStone )
    if not _noSync then
        -- 同步到客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.stone] = stone }, true )
    end

    local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
    -- 记录日志
    LogLogic:currencyChange( { rid = _rid, logType = _logType, logType2 = _logExtraType,
            currencyId = Enum.CurrencyType.stone, changeNum = _addStone, oldNum = oldStone, newNum = stone, iggid = iggid } )
    -- 判断资源阈值
    local stoneLimit = CFG.s_GameWarning:Get( Enum.ResourceLimitType.STONE, "num" )
    if stoneLimit and stone > stoneLimit then
        Common.sendResourceAlarm( _rid, Enum.ResourceLimitType.STONE, stone )
    end
    return stone, oldStone
end

---@see 检查宝石是否足够
function RoleLogic:checkDenar( _rid, _checkDenar )
    assert(_rid and _checkDenar)
    local denar = self:getRole( _rid, Enum.Role.denar )
    return denar >= _checkDenar
end

---@see 增加宝石
function RoleLogic:addDenar( _rid, _addDenar, _noSync, _logType, _logExtraType )
    if _addDenar == 0 then return end
    local _, denar, oldDenar = self:lockSetRole( _rid, Enum.Role.denar, _addDenar )
    if not _noSync then
        -- 同步到客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.denar] = denar }, true )
    end

    local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
    -- 记录日志
    LogLogic:currencyChange( { rid = _rid, logType = _logType, logType2 = _logExtraType,
            currencyId = Enum.CurrencyType.denar, changeNum = _addDenar, oldNum = oldDenar, newNum = denar, iggid = iggid } )
    if _addDenar < 0 then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.USER_DENAR, -_addDenar )
    end
    -- 判断资源阈值
    local denarLimit = CFG.s_GameWarning:Get( Enum.ResourceLimitType.DENAR, "num" )
    if denarLimit and denar > denarLimit then
        Common.sendResourceAlarm( _rid, Enum.ResourceLimitType.DENAR, denar )
    end
    return denar, oldDenar
end

---@see 检查联盟个人积分是否足够
function RoleLogic:checkGuildPoint( _rid, _checkGuildPoint )
    assert(_rid and _checkGuildPoint)
    local guildPoint = self:getRole( _rid, Enum.Role.guildPoint )
    return guildPoint >= _checkGuildPoint
end

---@see 增加联盟个人积分
function RoleLogic:addGuildPoint( _rid, _addGuildPoint, _noSync, _logType, _logExtraType )
    if _addGuildPoint == 0 then return end
    local _, guildPoint, oldGuildPoint = self:lockSetRole( _rid, Enum.Role.guildPoint, _addGuildPoint )
    if not _noSync then
        -- 同步到客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.guildPoint] = guildPoint }, true )
    end

    local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
    -- 记录日志
    LogLogic:currencyChange( {
        rid = _rid, logType = _logType, logType2 = _logExtraType, currencyId = Enum.CurrencyType.individualPoints,
        changeNum = _addGuildPoint, oldNum = oldGuildPoint, newNum = guildPoint, iggid = iggid
    } )

    return guildPoint, oldGuildPoint
end

---@see 检查行动力是否足够
function RoleLogic:checkActionForce( _rid, _checkActionForce )
    assert(_rid and _checkActionForce)
    local actionForce = self:getRole( _rid, Enum.Role.actionForce )
    return actionForce >= _checkActionForce
end

---@see 增加行动力
function RoleLogic:addActionForce( _rid, _addActionForce, _noSync, _logType, _logExtraType )
    local _, actionForce, oldActionForce = self:lockSetRole( _rid, Enum.Role.actionForce, _addActionForce )
    if not _noSync then
        -- 同步到客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.actionForce] = actionForce }, true )
    end

    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.iggid, Enum.Role.online } )
    -- 记录日志
    LogLogic:currencyChange( {
        rid = _rid, logType = _logType, logType2 = _logExtraType, currencyId = Enum.CurrencyType.actionForce,
        changeNum = _addActionForce, oldNum = oldActionForce, newNum = actionForce, iggid = roleInfo.iggid
    } )

    if roleInfo.online then
        -- 检查行动力是否已满
        self:actionForceLimitChange( _rid )
    end
    if _addActionForce < 0 then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.COST_ACTION_POINT, -_addActionForce )
    end
    return actionForce, oldActionForce
end

---@see 检测vip点数还差多少满
function RoleLogic:checkVipFull( _rid, _vipConfig )
    local vipConfig = _vipConfig or CFG.s_Vip:Get()
    local maxPoint = 0
    for _, vipInfo in pairs( vipConfig ) do
        if vipInfo.point > maxPoint then
            maxPoint = vipInfo.point
        end
    end
    local vip = self:getRole( _rid, Enum.Role.vip )
    if vip < maxPoint then
        return maxPoint - vip
    end
    return 0
end

---@see 返回当前vip等级
function RoleLogic:getVipLv( _vipExp, _vipConfig )
    _vipConfig = _vipConfig or CFG.s_Vip:Get()
    local level = 0
    for _, vipInfo in pairs(_vipConfig) do
        if vipInfo.point > 0 and vipInfo.point <= _vipExp then
            if vipInfo.level >= level then
                level = vipInfo.level + 1
            end
        end
    end
    return level
end

---@see 增加vip点数
function RoleLogic:addVip( _rid, _addVip, _noSync, _logType, _logExtraType )
    local vipConfig = CFG.s_Vip:Get()
    local point = self:checkVipFull( _rid, vipConfig )
    if point == 0 then
        return
    elseif _addVip > point then
        _addVip = point
    end
    local _, vip, oldVip = self:lockSetRole( _rid, Enum.Role.vip, _addVip )
    if not _noSync then
        -- 同步到客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.vip] = vip }, true )
    end
    local roleInfo = self:getRole( _rid )
    -- 判断是否有升级
    local level = self:getVipLv( vip, vipConfig )
    local oldLevel = self:getVipLv( oldVip, vipConfig )
    if level > oldLevel then
        local oldRoleInfo = table.copy( roleInfo, true )
        -- 重新计算增益
        RoleCacle:vipAttrChange( roleInfo, level, oldLevel )
        -- 判断是否有未领取的vip专属礼包
        local startLevel = oldLevel
        if roleInfo.vipFreeBox then
            startLevel = startLevel + 1
        end
        if startLevel < level then
            local EmailLogic = require "EmailLogic"
            local ItemLogic = require "ItemLogic"
            for i=startLevel, level - 1 do
                -- 补发邮件
                local config = CFG.s_Vip:Get(i)
                if config.mailID then
                    EmailLogic:sendEmail( _rid, config.mailID, { rewards = ItemLogic:getItemPackage( _rid, config.itemPackage, true ) } )
                end
            end
        end
        self:updateRoleChangeInfo( _rid, oldRoleInfo, roleInfo )
        if roleInfo.vipFreeBox ~= false then
            RoleLogic:setRole( _rid, { [Enum.Role.vipFreeBox] = false } )
            RoleSync:syncSelf( _rid, { [Enum.Role.vipFreeBox] = false }, true )
        end

        -- 检查角色相关属性信息是否变化
        RoleCacle:checkRoleAttrChange( _rid, oldRoleInfo, roleInfo )
    end

    -- 记录日志
    LogLogic:currencyChange( {
        rid = _rid, logType = _logType, logType2 = _logExtraType, currencyId = Enum.CurrencyType.actionForce,
        changeNum = _addVip, oldNum = oldVip, newNum = vip, iggid = roleInfo.iggid
    } )

    return vip, oldVip
end

---@see 检查远征币是否足够
function RoleLogic:checkExpeditionCoin( _rid, _checkExpeditionCoin )
    assert(_rid and _checkExpeditionCoin)
    local denar = self:getRole( _rid, Enum.Role.expeditionCoin )
    return denar >= _checkExpeditionCoin
end

---@see 增加远征币
function RoleLogic:addExpeditionCoin( _rid, _addExpeditionCoin, _noSync, _logType, _logExtraType )
    if _addExpeditionCoin == 0 then return end
    local _, expeditionCoin, oldExpeditionCoin = self:lockSetRole( _rid, Enum.Role.expeditionCoin, _addExpeditionCoin )
    if not _noSync then
        -- 同步到客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.expeditionCoin] = expeditionCoin }, true )
    end

    local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
    -- 记录日志
    LogLogic:currencyChange( { rid = _rid, logType = _logType, logType2 = _logExtraType,
            currencyId = Enum.CurrencyType.expeditionCoin, changeNum = _addExpeditionCoin, oldNum = oldExpeditionCoin, newNum = expeditionCoin, iggid = iggid } )
    return expeditionCoin, oldExpeditionCoin
end

---@see vip连续登陆判断
function RoleLogic:vipLogin( _rid, _lastLoginTime, _isLogin )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.continuousLoginDay, Enum.Role.lastLoginTime } )
    -- 如果第一天登陆，直接算1
    if roleInfo.continuousLoginDay == 0 then
        roleInfo.continuousLoginDay = 1
    elseif _lastLoginTime and Timer.getDiffDays(_lastLoginTime, os.time()) > CFG.s_Config:Get("vipSignDay") then
        roleInfo.continuousLoginDay = 1
    else
        roleInfo.continuousLoginDay = roleInfo.continuousLoginDay + 1
    end

    RoleLogic:setRole( _rid, { [Enum.Role.continuousLoginDay] = roleInfo.continuousLoginDay, [Enum.Role.vipFreeBox] = false, [Enum.Role.vipExpFlag] = false })

    if not _isLogin then
        -- 同步到客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.continuousLoginDay] = roleInfo.continuousLoginDay, [Enum.Role.vipFreeBox] = false, [Enum.Role.vipExpFlag] = false }, true )
    end
end

---@see 检查活跃度是否足够
function RoleLogic:checkActivePoint( _rid, _checkActivePoint )
    assert(_rid and _checkActivePoint)
    local activePoint = self:getRole( _rid, Enum.Role.activePoint )
    return activePoint >= _checkActivePoint
end

---@see 增加活跃度
function RoleLogic:addActivePoint( _rid, _addActivePoint, _noSync )
    local _, activePoint, oldActivePoint = self:lockSetRole( _rid, Enum.Role.activePoint, _addActivePoint )
    if not _noSync then
        -- 同步到客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.activePoint] = activePoint }, true )
    end

    return activePoint, oldActivePoint
end

---@see 判断兵种是否解锁
function RoleLogic:unlockArmy( _rid, _type, _level )
    local armyStudy = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ARMY_STUDY ) or {}
    local technologies = self:getRole( _rid, Enum.Role.technologies )
    if armyStudy[_type][_level].studyId and armyStudy[_type][_level].studyId > 0 then
        local technolog = CFG.s_Study:Get(armyStudy[_type][_level].studyId)
        if technologies[technolog.studyType] and technologies[technolog.studyType].level >= technolog.studyLv then
            return true
        else
            return false
        end
    end
    return true
end

---@see 各兵种解锁最高等级
function RoleLogic:getMaxLevel( _rid )
    local armyType = { Enum.ArmyType.INFANTRY, Enum.ArmyType.CAVALRY, Enum.ArmyType.ARCHER, Enum.ArmyType.SIEGE_UNIT }
    for _, type in pairs(armyType) do
        local maxLevel = 1
        for i=5,2 do
            if self:unlockArmy( _rid, type, i ) then
                maxLevel = i
                break
            end
        end
    end
end

---@see 判断兵种是否充足
function RoleLogic:checkSoldier( _rid, _type, _level, _num )
    local soldiers = self:getRole( _rid, Enum.Role.soldiers ) or {}
    local ArmyTrainLogic = require "ArmyTrainLogic"
    local config = ArmyTrainLogic:getArmsConfig( _rid, _type, _level )
    if not soldiers[config.ID] then return false end
    return soldiers[config.ID].num >= _num
end

---@see 增加建筑版本
function RoleLogic:addVersion( _rid, _noSync )
    local _, version, oldVersion = self:lockSetRole( _rid, Enum.Role.buildVersion, 1 )
    if not _noSync then
        -- 同步到客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.buildVersion] = version }, true )
    end

    return version, oldVersion
end

---@see 初始化角色属性
function RoleLogic:initRoleAttr( _rid )
    local defRoleAttr = RoleDef:getDefaultRoleAttr()
    local rawRoleAttr = self:getRole( _rid, nil, true )
    if not rawRoleAttr then
        LOG_ERROR("initRoleAttr rid(%d) but not found roleAttr", _rid)
        return
    end

    -- 战斗等AttrDef中的属性不能赋值
    local defAttrDef = AttrDef:getDefaultAttr()
    local defBattleAttrDef = AttrDef:getDefaultBattleAttr()
    for name,value in pairs(rawRoleAttr) do
        if not defAttrDef[name] and not defBattleAttrDef[name] then
            defRoleAttr[name] = value
        end
    end
    -- 建筑增加属性
    RoleCacle:cacleBuildAttr( defRoleAttr )
    -- 科技增加属性
    RoleCacle:cacleTechnologyAttr(defRoleAttr)
    -- 城市buff增加属性
    RoleCacle:cacleCityBuffAttr(defRoleAttr)
    -- 联盟官职增加属性
    RoleCacle:cacleGuildOfficerAttr( defRoleAttr )
    -- vip增加属性
    local vipLv = self:getVipLv( defRoleAttr.vip )
    RoleCacle:vipAttrChange( defRoleAttr, vipLv, nil, true )
    -- 联盟科技和升级加成属性
    RoleCacle:cacleGuildAttr( defRoleAttr )
    -- 文明增加属性
    RoleCacle:cacleCivilizationAttr( defRoleAttr )
    -- 斥候速度
    defRoleAttr.scoutSpeed = CFG.s_Config:Get("scoutSpeed") or 0
    -- 计算角色战力
    local power = RoleCacle:cacleRolePower( defRoleAttr )
    if power > defRoleAttr.historyPower then
        defRoleAttr.historyPower = power
    end

    if ( defRoleAttr.combatPower or 0 ) ~= power then
        defRoleAttr.combatPower = power
        local cityIndex = self:getRoleCityIndex( _rid )
        if cityIndex then
            MSM.SceneCityMgr[cityIndex].post.updateCityPower( cityIndex, power )
        end
    end

    -- 不重新set soldiers,避免此时正好在解散部队,覆盖了士兵
    -- 只set角色高级属性、战力、历史战力、斥候速度属性
    local roleUpdateInfo = {}
    local updateFields = { [Enum.Role.combatPower] = true, [Enum.Role.historyPower] = true, [Enum.Role.scoutSpeed] = true }
    for name, value in pairs( defRoleAttr ) do
        if defAttrDef[name] or defBattleAttrDef[name] or updateFields[name] then
            roleUpdateInfo[name] = value
        end
    end

    self:setRole( _rid, roleUpdateInfo )

    return defRoleAttr
end

---@see 立即完成
function RoleLogic:immediatelyComplete( _args )
    local costDenar
    local costFood
    local costWood
    local costStone
    local costGold
    local flag
    -- 建筑立即完成
    if _args.buildingIndex and not _args.type then
        local BuildingLogic = require "BuildingLogic"
        local buildInfo = BuildingLogic:getBuilding( _args.rid, _args.buildingIndex )
        local sBuildingLevelData = CFG.s_BuildingLevelData:Get( buildInfo.type * 100 + buildInfo.level + 1 )
        local buildSpeedMulti = RoleLogic:getRole( _args.rid, Enum.Role.buildSpeedMulti ) or 0
        local buildTime = sBuildingLevelData.buildingTime * ( 1000 - buildSpeedMulti) / 1000 // 1
        flag, costFood, costWood, costStone, costGold, costDenar =
                        self:cancleCost( _args.rid, sBuildingLevelData.food, sBuildingLevelData.wood,
                        sBuildingLevelData.stone, sBuildingLevelData.gold, buildTime )
        local itemFlag
        local overlay
        local ItemLogic = require "ItemLogic"
        if sBuildingLevelData.itemType1 > 0 then
            itemFlag, overlay = ItemLogic:checkItemEnough( _args.rid, sBuildingLevelData.itemType1, sBuildingLevelData.itemCnt )
            if not itemFlag then
                local count = sBuildingLevelData.itemCnt - overlay
                local sItem = CFG.s_Item:Get(sBuildingLevelData.itemType1)
                costDenar = costDenar + sItem.shopPrice * count
                if not RoleLogic:checkDenar( _args.rid, costDenar ) then
                    flag = false
                end
            else
                overlay = sBuildingLevelData.itemCnt
            end
        end
        if not flag then
            LOG_ERROR("rid(%d) immediatelyComplete fail, dener not enough", _args.rid)
            return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
        end
        -- 扣除资源和钻石
        if costFood then
            self:addFood( _args.rid, -costFood, nil, Enum.LogType.IM_BUILD_LEVEL_COST_DENAR )
        end
        if costWood then
            self:addWood( _args.rid, -costWood, nil, Enum.LogType.IM_BUILD_LEVEL_COST_DENAR )
        end
        if costStone then
            self:addStone( _args.rid, -costStone, nil, Enum.LogType.IM_BUILD_LEVEL_COST_DENAR )
        end
        if costGold then
            self:addGold( _args.rid, -costGold, nil, Enum.LogType.IM_BUILD_LEVEL_COST_DENAR )
        end
        if costDenar then
            self:addDenar( _args.rid, -costDenar, nil, Enum.LogType.IM_BUILD_LEVEL_COST_DENAR )
        end
        if overlay and overlay > 0 then
            ItemLogic:delItemById( _args.rid, sBuildingLevelData.itemType1, overlay, nil, Enum.LogType.IM_BUILD_LEVEL_COST_DENAR )
        end

        BuildingLogic:upGradeBuildCallBack( _args.rid, _args.buildingIndex )
        MSM.ActivityRoleMgr[_args.rid].req.setActivitySchedule( _args.rid, Enum.ActivityActionType.BUILE_LEVEL, 1 )
        return { buildingIndex = _args.buildingIndex, immediately = true }
    -- 训练立即完成
    elseif _args.type and _args.level then
        local ArmyTrainLogic = require "ArmyTrainLogic"
        local config
        local maxLv = ArmyTrainLogic:getArmyMaxLv( _args.rid, _args.type )
        if _args.isUpdate == Enum.ArmyUpdate.YES then
            config = ArmyTrainLogic:getArmsConfig( _args.rid, _args.type, maxLv )
        else
            config = ArmyTrainLogic:getArmsConfig( _args.rid, _args.type, _args.level )
        end
        local totalFood
        local totalWood
        local totalStone
        local totalGlod
        if config.needFood then
            totalFood = config.needFood * _args.trainNum
        end
        if config.needWood then
            totalWood = config.needWood * _args.trainNum
        end
        if config.needStone then
            totalStone = config.needStone * _args.trainNum
        end
        if config.needGlod then
            totalGlod = config.needGlod * _args.trainNum
        end
        --添加定时器信息
        local trainSpeedMulti =  self:getRole( _args.rid, Enum.Role.trainSpeedMulti ) or 0
        local finishTime = config.endTime * ( 1- trainSpeedMulti/1000 ) * _args.trainNum // 1
        if _args.isUpdate == Enum.ArmyUpdate.YES then
            config = ArmyTrainLogic:getArmsConfig( _args.rid, _args.type, _args.level )
            if config.needFood then
                totalFood = totalFood - config.needFood * _args.trainNum
            end
            if config.needWood then
                totalWood = totalWood - config.needWood * _args.trainNum
            end
            if config.needStone then
                totalStone = totalStone - config.needStone * _args.trainNum
            end
            if config.needGlod then
                totalGlod = totalGlod - config.needGlod * _args.trainNum
            end
            finishTime = finishTime - config.endTime * ( 1- trainSpeedMulti/1000 ) * _args.trainNum // 1
        end
        flag, costFood, costWood, costStone, costGold, costDenar =
                        self:cancleCost( _args.rid, totalFood, totalWood, totalStone, totalGlod, finishTime)
        if not flag then
            LOG_ERROR("rid(%d) immediatelyComplete fail, dener not enough", _args.rid)
            return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
        end
        local logType = Enum.LogType.IM_TRAIN_SOLDIER_COST_DENAR
        if _args.isUpdate == Enum.ArmyUpdate.YES then
            logType = Enum.LogType.IM_UPGRADE_SOLDIER_COST_DENAR
        end
        -- 扣除资源和钻石
        if costFood then
            self:addFood( _args.rid, -costFood, nil, logType)
        end
        if costWood then
            self:addWood( _args.rid, -costWood, nil, logType )
        end
        if costStone then
            self:addStone( _args.rid, -costStone, nil, logType )
        end
        if costGold then
            self:addGold( _args.rid, -costGold, nil, logType )
        end
        if costDenar then
            self:addDenar( _args.rid, -costDenar, nil, logType )
        end
        -- 如果是晋升扣除对应士兵
        local addLevel = _args.level
        logType = Enum.LogType.TRAIN_ARMY
        local oldActionType
        if _args.isUpdate == Enum.ArmyUpdate.YES then
            ArmyTrainLogic:addSoldiers( _args.rid, _args.type, _args.level, -_args.trainNum, Enum.LogType.ARMY_LEVEL_UP_REDUCE )
            logType = Enum.LogType.ARMY_LEVEL_UP_ADD
            addLevel = maxLv
            if _args.level == 1 then
                oldActionType = Enum.ActivityActionType.TRAIN_LEVEL1_COUNT
            elseif _args.level == 2 then
                oldActionType = Enum.ActivityActionType.TRAIN_LEVEL2_COUNT
            elseif _args.level == 3 then
                oldActionType = Enum.ActivityActionType.TRAIN_LEVEL3_COUNT
            elseif _args.level == 4 then
                oldActionType = Enum.ActivityActionType.TRAIN_LEVEL4_COUNT
            elseif _args.level == 5 then
                oldActionType = Enum.ActivityActionType.TRAIN_LEVEL5_COUNT
            end
        end
        -- local armyQueue = RoleLogic:getRole( _args.rid, Enum.Role.armyQueue )
        -- for _, queue in pairs(armyQueue) do
        --     if queue.type == _args.type then
        --         queue.finishTime = -1
        --         queue.armyType = _args.type
        --         queue.armyNum = _args.trainNum
        --         queue.newArmyLevel = _args.level
        --         RoleLogic:setRole( _args.rid, { [Enum.Role.armyQueue] = armyQueue } )
        --         RoleSync:syncSelf( _args.rid, { [Enum.Role.armyQueue] = { [queue.queueIndex] = queue } }, true )
        --     end
        -- end

        -- 扣除预备部队次数
        local roleInfo = RoleLogic:getRole( _args.rid, { Enum.Role.armyQueue, Enum.Role.trainSpeedMulti,
                                Enum.Role.itemAddTroopsCapacity, Enum.Role.itemAddTroopsCapacityCount } )
        if roleInfo.itemAddTroopsCapacityCount > 0 then
            local roleChangeInfo = {}
            roleChangeInfo.itemAddTroopsCapacityCount = roleInfo.itemAddTroopsCapacityCount - 1
            if roleChangeInfo.itemAddTroopsCapacityCount == 0 then
                roleChangeInfo.itemAddTroopsCapacity = 0
            end
            RoleLogic:setRole( _args.rid, roleChangeInfo )
            RoleSync:syncSelf( _args.rid, roleChangeInfo, true, true )
        end

        ArmyTrainLogic:addSoldiers( _args.rid, _args.type, addLevel, _args.trainNum, logType )
        config = ArmyTrainLogic:getArmsConfig( _args.rid, _args.type, addLevel )
        RoleLogic:reduceTime( _args.rid, config.mysteryStoreCD * _args.trainNum )
        config = ArmyTrainLogic:getArmsConfig( _args.rid, _args.type, addLevel )
        local id = config.ID
        local soldiers = {}
        soldiers[id] = { id = id, type = _args.type, level = addLevel, num = _args.trainNum }
        -- 增加士兵训练累计个数
        local TaskLogic = require "TaskLogic"
        local roleTaskStatistics = {}
        local taskStatisticsSum
        TaskLogic:addTaskStatisticsSum( _args.rid, Enum.TaskType.SOLDIER_TRAIN, _args.type, _args.trainNum, true )
        -- 增加士兵招募累计个数
        taskStatisticsSum = TaskLogic:addTaskStatisticsSum( _args.rid, Enum.TaskType.SOLDIER_SUMMON, _args.type, _args.trainNum, true )
        roleTaskStatistics.taskStatisticsSum = {
            [Enum.TaskType.SOLDIER_TRAIN] = taskStatisticsSum[Enum.TaskType.SOLDIER_TRAIN],
            [Enum.TaskType.SOLDIER_SUMMON] = taskStatisticsSum[Enum.TaskType.SOLDIER_SUMMON],
        }
        -- 通知客户端
        RoleSync:syncSelf( _args.rid, roleTaskStatistics, true )
        -- 更新每日任务进度
        TaskLogic:updateTaskSchedule( _args.rid, { [Enum.TaskType.SOLDIER_SUMMON] = { arg = _args.type, addNum = _args.trainNum } } )
        -- 计算角色最高战力
        local changePower = self:cacleSyncHistoryPower( _args.rid )
        if changePower > 0 then
            MSM.ActivityRoleMgr[_args.rid].req.setActivitySchedule( _args.rid, Enum.ActivityActionType.ARMY_POWER_UP, changePower )
        end
        ArmyTrainLogic:setActivitySchedule( _args.rid, _args.type, addLevel, _args.trainNum, oldActionType )
        return { soldiers = soldiers }
    -- 训练中立即完成
    elseif _args.armyQueueIndex then
        local armyQueue = self:getRole( _args.rid, Enum.Role.armyQueue )
        local queueInfo = armyQueue[_args.armyQueueIndex]
        flag, costFood, costWood, costStone, costGold, costDenar =
                        self:cancleCost( _args.rid, nil, nil, nil, nil, queueInfo.finishTime - os.time() )
        if not flag then
            LOG_ERROR("rid(%d) immediatelyComplete fail, dener not enough", _args.rid)
            return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
        end
        local logType = Enum.LogType.IM_TRAIN_SOLDIER_COST_DENAR
        if queueInfo.oldArmyLevel and queueInfo.oldArmyLevel > 0 then
            logType = Enum.LogType.IM_UPGRADE_SOLDIER_COST_DENAR
        end
        -- 扣除资源和钻石
        if costFood then
            self:addFood( _args.rid, -costFood, nil, logType )
        end
        if costWood then
            self:addWood( _args.rid, -costWood, nil, logType )
        end
        if costStone then
            self:addStone( _args.rid, -costStone, nil, logType )
        end
        if costGold then
            self:addGold( _args.rid, -costGold, nil, logType )
        end
        if costDenar then
            self:addDenar( _args.rid, -costDenar, nil, logType )
        end
        MSM.RoleTimer[_args.rid].req.deleteTrainTimer( _args.rid, queueInfo.timerId )
        local ArmyTrainLogic = require "ArmyTrainLogic"
        return ArmyTrainLogic:awardArmy( _args.rid, queueInfo.armyType )
    -- 科研立即完成
    elseif _args.technologyType then
        local studyConfig = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.STUDY ) or {}
        local technologies = self:getRole( _args.rid, Enum.Role.technologies ) or {}
        local level = 0
        if technologies[_args.technologyType] then
            level = technologies[_args.technologyType].level
        end
        local technologyId = studyConfig[_args.technologyType][level + 1].id
        local config = CFG.s_Study:Get(technologyId)
        local researchSpeedMulti =  RoleLogic:getRole( _args.rid, Enum.Role.researchSpeedMulti ) or 0
        local finishTime = config.costTime / ( 1 + researchSpeedMulti/1000 ) // 1
        flag, costFood, costWood, costStone, costGold, costDenar =
                        self:cancleCost( _args.rid, config.needFood, config.needWood, config.needStone, config.needGold, finishTime )
        if not flag then
            LOG_ERROR("rid(%d) immediatelyComplete fail, dener not enough", _args.rid)
            return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
        end
        -- 扣除资源和钻石
        if costFood then
            self:addFood( _args.rid, -costFood, nil, Enum.LogType.IM_TECH_RESEARCH_COST_DENAR )
        end
        if costWood then
            self:addWood( _args.rid, -costWood, nil, Enum.LogType.IM_TECH_RESEARCH_COST_DENAR )
        end
        if costStone then
            self:addStone( _args.rid, -costStone, nil, Enum.LogType.IM_TECH_RESEARCH_COST_DENAR )
        end
        if costGold then
            self:addGold( _args.rid, -costGold, nil, Enum.LogType.IM_TECH_RESEARCH_COST_DENAR )
        end
        if costDenar then
            self:addDenar( _args.rid, -costDenar, nil, Enum.LogType.IM_TECH_RESEARCH_COST_DENAR )
        end
        local technologyType = _args.technologyType
        if not technologies[technologyType] then
            technologies[technologyType] = { technologyType = technologyType, level = 0 }
        end
        technologies[technologyType].level = level + 1
        self:setRole( _args.rid, { [Enum.Role.technologies] = technologies } )
        RoleSync:syncSelf( _args.rid, { [Enum.Role.technologies] = { [technologyType] = technologies[technologyType] }, }, true )
        MSM.ActivityRoleMgr[_args.rid].req.setActivitySchedule( _args.rid, Enum.ActivityActionType.TECHNOLOGY_RESEARCH, 1 )
        -- 增加开始科技研究累计次数
        local TaskLogic = require "TaskLogic"
        TaskLogic:addTaskStatisticsSum( _args.rid, Enum.TaskType.TECHNOLOGY_NUM, Enum.TaskArgDefault, 1 )
        -- 增加科技完成累计次数
        TaskLogic:addTaskStatisticsSum( _args.rid, Enum.TaskType.TECHNOLOGY_UPGRADE, Enum.TaskArgDefault, 1 )
        -- 更新每日任务进度
        TaskLogic:updateTaskSchedule( _args.rid, { [Enum.TaskType.TECHNOLOGY_UPGRADE] = { arg = 0, addNum = 1 } } )
        -- 重新计算科技属性加成
        local roleInfo = self:getRole( _args.rid )
        local oldRoleInfo = table.copy( roleInfo, true )
        RoleCacle:technologyAttrChange( roleInfo, technologyType, technologies[technologyType].level)
        self:updateRoleChangeInfo( _args.rid, oldRoleInfo, roleInfo )
        -- 计算角色最高战力
        local changePower = self:cacleSyncHistoryPower( _args.rid, roleInfo )
        if changePower > 0 then
            MSM.ActivityRoleMgr[_args.rid].req.setActivitySchedule( _args.rid, Enum.ActivityActionType.TECH_POWER_UP, changePower )
        end
        RoleCacle:checkRoleAttrChange( _args.rid, oldRoleInfo, roleInfo )

        -- 触发限时礼包
        local RechargeLogic = require "RechargeLogic"
        RechargeLogic:triggerLimitPackage( _args.rid, { type = Enum.LimitTimeType.TECH_UNLOCK, id = technologyId } )
        return { result = true, level = technologies[technologyType].level, technologyType = technologyType }
    -- 治疗立即完成
    elseif _args.soldiers then
        local needFood = 0
        local needWood = 0
        local needStone = 0
        local needGold = 0
        local needTime
        local time1 = 0
        local time2 = 0
        local time3 = 0
        local time4 = 0
        local time5 = 0
        local num1 = 0
        local num2 = 0
        local num3 = 0
        local num4 = 0
        local num5 = 0
        local ArmyTrainLogic = require "ArmyTrainLogic"
        for _, v in pairs(_args.soldiers) do
            local config = ArmyTrainLogic:getArmsConfig( _args.rid, v.type, v.level )
            if config.woundedFood then
                needFood = needFood + config.woundedFood * v.num
            end
            if config.woundedWood then
                needWood = needWood + config.woundedWood * v.num
            end
            if config.woundedStone then
                needStone = needStone + config.woundedStone * v.num
            end
            if config.woundedGold then
                needGold = needGold + config.woundedGold * v.num
            end
            if v.level == 1 then
                time1 = time1 + config.woundedTime * v.num
                num1 = num1 + v.num
            elseif v.level == 2 then
                time2 = time2 + config.woundedTime * v.num
                num2 = num2 + v.num
            elseif v.level == 3 then
                time3 = time3 + config.woundedTime * v.num
                num3 = num3 + v.num
            elseif v.level == 4 then
                time4 = time4 + config.woundedTime * v.num
                num4 = num4 + v.num
            elseif v.level == 5 then
                time5 = time5 + config.woundedTime * v.num
                num5 = num5 + v.num
            end
        end
        local minTime = CFG.s_Config:Get("cureMinTime") or 3
        if num1 > 0 then
            time1 = minTime
        end
        if num2 > 0 and time2 < minTime then
            time2 = minTime
        end
        if num3 > 0 and time3 < minTime then
            time3 = minTime
        end
        if num4 > 0 and time4 < minTime then
            time4 = minTime
        end
        if num5 > 0 and time5 < minTime then
            time5 = minTime
        end
        needTime = time1 + time2 + time3 + time4 + time5
        local healSpeedMulti = RoleLogic:getRole( _args.rid, "healSpeedMulti") or 0
        needTime = (needTime/(1 + healSpeedMulti / 1000 ) // 1 )
        flag, costFood, costWood, costStone, costGold, costDenar =
                        self:cancleCost( _args.rid, needFood, needWood, needStone, needGold, needTime )
        if not flag then
            LOG_ERROR("rid(%d) immediatelyComplete fail, dener not enough", _args.rid)
            return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
        end
        -- 扣除资源和钻石
        if costFood then
            self:addFood( _args.rid, -costFood, nil, Enum.LogType.IM_HEAL_SOLDIER_COST_DENAR )
        end
        if costWood then
            self:addWood( _args.rid, -costWood, nil, Enum.LogType.IM_HEAL_SOLDIER_COST_DENAR )
        end
        if costStone then
            self:addStone( _args.rid, -costStone, nil, Enum.LogType.IM_HEAL_SOLDIER_COST_DENAR )
        end
        if costGold then
            self:addGold( _args.rid, -costGold, nil, Enum.LogType.IM_HEAL_SOLDIER_COST_DENAR )
        end
        if costDenar then
            self:addDenar( _args.rid, -costDenar, nil, Enum.LogType.IM_HEAL_SOLDIER_COST_DENAR )
        end

        local TaskLogic = require "TaskLogic"
        local treatmentSum
        local taskType = Enum.TaskType.HEAL_SOLDIER
        local taskArgDefault = Enum.TaskArgDefault
        local addSoldierInfo
        treatmentSum, addSoldierInfo = SoldierLogic:subSeriousInLock( _args.rid, _args.soldiers )
        -- 增加士兵治疗领取累计个数
        local taskStatisticsSum = TaskLogic:addTaskStatisticsSum( _args.rid, taskType, taskArgDefault, treatmentSum or 0, true )
        RoleSync:syncSelf( _args.rid, {
            [Enum.Role.taskStatisticsSum] = { [taskType] = taskStatisticsSum[taskType] }
        }, true, true )
        -- 增加士兵
        SoldierLogic:addSoldier( _args.rid, addSoldierInfo or {}, true )
        -- 更新每日任务进度
        TaskLogic:updateTaskSchedule( _args.rid, { [taskType] = { arg = 0, addNum = treatmentSum } } )
        -- 计算角色最高战力
        self:cacleSyncHistoryPower( _args.rid, nil, nil, true )
        MSM.ActivityRoleMgr[_args.rid].req.setActivitySchedule( _args.rid, Enum.ActivityActionType.TREATMENT_NUM, treatmentSum )
        return { soldiers = _args.soldiers }
    elseif _args.treatmentQueueIndex then
        local treatmentQueue = RoleLogic:getRole( _args.rid, Enum.Role.treatmentQueue ) or {}
        flag, costFood, costWood, costStone, costGold, costDenar =
                        self:cancleCost( _args.rid, nil, nil, nil, nil, treatmentQueue.finishTime - os.time() )
        if not flag then
            LOG_ERROR("rid(%d) immediatelyComplete fail, dener not enough", _args.rid)
            return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
        end
        -- 扣除资源和钻石
        if costFood then
            self:addFood( _args.rid, -costFood, nil, Enum.LogType.IM_HEAL_SOLDIER_COST_DENAR )
        end
        if costWood then
            self:addWood( _args.rid, -costWood, nil, Enum.LogType.IM_HEAL_SOLDIER_COST_DENAR )
        end
        if costStone then
            self:addStone( _args.rid, -costStone, nil, Enum.LogType.IM_HEAL_SOLDIER_COST_DENAR )
        end
        if costGold then
            self:addGold( _args.rid, -costGold, nil, Enum.LogType.IM_HEAL_SOLDIER_COST_DENAR )
        end
        if costDenar then
            self:addDenar( _args.rid, -costDenar, nil, Enum.LogType.IM_HEAL_SOLDIER_COST_DENAR )
        end
        local HospitalLogic = require "HospitalLogic"
        MSM.RoleTimer[_args.rid].req.deleteTreatmentTimer( _args.rid )
        return HospitalLogic:awardTreatment( _args.rid )
    end
end

---@see 立即完成需要材料以及砖石计算
function RoleLogic:cancleCost( _rid, _needFood, _needWood, _needStone, _needGold, _needTime, _needItem )
    local costDenar = 0
    local costFood = _needFood
    local costWood = _needWood
    local costStone = _needStone
    local costGold = _needGold
    -- 判断所需资源
    if _needFood and _needFood > 0 then
        local food = self:getRole( _rid, Enum.Role.food )
        if food < _needFood then
            costFood = math.ceil(food)
            local config = self:findImmediatelyConfig( 100, _needFood - food )
            if config and not table.empty( config ) then
                costDenar = costDenar + ( config.price + ( _needFood - food - config.num ) * config.priceAdd )
            end
        end
    end
    if _needWood and _needWood > 0 then
        local wood = self:getRole( _rid, Enum.Role.wood )
        if wood < _needWood then
            costWood = math.ceil(wood)
            local config = self:findImmediatelyConfig( 200, _needWood - wood )
            if config and not table.empty( config ) then
                costDenar = costDenar + ( config.price + ( _needWood - wood - config.num ) * config.priceAdd )
            end
        end
    end
    if _needStone and _needStone > 0 then
        local stone = self:getRole( _rid, Enum.Role.stone )
        if stone < _needStone then
            costStone =  math.ceil(stone)
            local config = self:findImmediatelyConfig( 300, _needStone - stone )
            if config and not table.empty( config ) then
                costDenar = costDenar + ( config.price + ( _needStone - stone - config.num ) * config.priceAdd )
            end
        end
    end
    if _needGold and _needGold > 0 then
        local gold = self:getRole( _rid, Enum.Role.gold )
        if gold < _needGold then
            costGold =  math.ceil(gold)
            local config = self:findImmediatelyConfig( 400, _needGold - gold )
            if config and not table.empty( config ) then
                costDenar = costDenar + ( config.price + ( _needGold - gold - config.num ) * config.priceAdd )
            end
        end
    end
    if _needTime and _needTime > 0 then
        local config = self:findImmediatelyConfig( 0, _needTime )
        if config and not table.empty( config ) then
            costDenar = costDenar + ( config.price + ( _needTime - config.num ) * config.priceAdd )
        end
    end
    costDenar = math.floor(costDenar)
    return self:checkDenar( _rid, costDenar), costFood, costWood,costStone, costGold, costDenar
end

---@see 立即完成寻找最适合的资源配置
function RoleLogic:findImmediatelyConfig( _type, _num )
    local returnConfig
    local sInstantPrice = CFG.s_instantPrice:Get()
    for _, config in pairs(sInstantPrice) do
        if config.type == _type then
            if config.num <= _num then
                if returnConfig then
                    if config.num > returnConfig.num then
                        returnConfig = config
                    end
                else
                    returnConfig = config
                end
            end
        end
    end
    return returnConfig
end

---@see 增加角色统计次数信息
function RoleLogic:addRoleStatistics( _rid, _type, _addNum, _noSync )
    local roleStatistics = self:getRole( _rid, Enum.Role.roleStatistics ) or {}
    if not roleStatistics[_type] then
        roleStatistics[_type] = { type = _type, num = _addNum }
    else
        roleStatistics[_type].num = roleStatistics[_type].num + _addNum
    end

    -- 更新统计信息
    self:setRole( _rid, { [Enum.Role.roleStatistics] = roleStatistics } )
    -- 通知客户端
    if not _noSync then
        RoleSync:syncSelf( _rid, { [Enum.Role.roleStatistics] = { [_type] = roleStatistics[_type] } }, true )
    end

    return roleStatistics
end

---@see 获取迷雾已探索数量
function RoleLogic:getDiscoverDenseFogCount( _rid )
    local denseFogs = self:getRole( _rid, Enum.Role.denseFog )
    local count = 0
    local denseRule
    for _, denseFogRule in pairs(denseFogs) do
        denseRule = denseFogRule.rule
        while denseRule ~= 0 do
            count = count + 1
            denseRule = denseRule & ( denseRule - 1 )
        end
    end
    return count
end

---@see 计算角色当前战力和历史最高战力
function RoleLogic:cacleSyncHistoryPower( _rid, _roleInfo, _noSync, _noSet, _noAdd, _combatPowerType, _isHospitalLogic, _noUpdateRank )
    local changPower = 0
    local defRoleAttr = _roleInfo
    if not defRoleAttr then
        defRoleAttr = RoleDef:getDefaultRoleAttr()
        local rawRoleAttr = self:getRole( _rid )
        for name,value in pairs( rawRoleAttr ) do
            defRoleAttr[name] = value
        end
    end

    local roleChangeInfo = {}
    local power = RoleCacle:cacleRolePower( defRoleAttr )
    if power > defRoleAttr.historyPower then
        roleChangeInfo.historyPower = power
    end

    -- 角色当前战力变化
    if power ~= ( defRoleAttr.combatPower or 0 ) then
        local cityIndex = RoleLogic:getRoleCityIndex( _rid )
        MSM.SceneCityMgr[cityIndex].post.updateCityPower( cityIndex, power )
        if not _noSet and power > defRoleAttr.combatPower then
            MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.ALL_POWER_UP, power - defRoleAttr.combatPower )
        end
        if not _isHospitalLogic and power > defRoleAttr.combatPower then
            MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.POWER_UP_ACTION, power - defRoleAttr.combatPower )
            MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.POWER_UP, power - defRoleAttr.combatPower )
        end
        if not _noAdd and power < defRoleAttr.combatPower and defRoleAttr.battleNum > 0 then
            roleChangeInfo.battleLostPower = ( defRoleAttr.battleLostPower or 0 ) + (defRoleAttr.combatPower - power)
        end
        roleChangeInfo.combatPower = power
        roleChangeInfo.combatPowerType = _combatPowerType

        -- 更新排行榜
        if not _noUpdateRank then
            local RankLogic = require "RankLogic"
            RankLogic:update( _rid, Enum.RankType.ROLE_POWER, power )
            if defRoleAttr.guildId and defRoleAttr.guildId > 0 then
                -- 更新联盟个人战力排行榜
                RankLogic:update( _rid, Enum.RankType.ALLIACEN_ROLE_POWER, power, defRoleAttr.guildId )
            end
        end
        changPower = power - defRoleAttr.combatPower
    end
    if not table.empty( roleChangeInfo ) then
        self:setRole( _rid, roleChangeInfo )
        if not _noSync then
            roleChangeInfo.battleLostPower = nil
            RoleSync:syncSelf( _rid, roleChangeInfo, true )
        end
    end
    return changPower, roleChangeInfo
end

---@see 获取角色恢复行动力所需时间
function RoleLogic:getActionForceRecoveryTime( _rid )
    local vitalityRecoveryMulti = self:getRole( _rid, Enum.Role.vitalityRecoveryMulti ) or 0
    local vitalityRecoveryTime = CFG.s_Config:Get( "vitalityRecoveryTime" )
    -- 转换为秒数
    local recoveryTime = math.ceil( vitalityRecoveryTime * ( 1000 - vitalityRecoveryMulti ) / 1000 / 1000 )
    if recoveryTime <= 0 then
        return 1
    end

    return recoveryTime
end

---@see 获取角色行动力上限
function RoleLogic:getActionForceLimit( _rid )
    return ( self:getRole( _rid, Enum.Role.maxVitality ) or 0 ) + ( CFG.s_Config:Get( "vitalityLimit" ) or 0 )
end

---@see 登录获取行动力
function RoleLogic:addActionForceTimerOnLogin( _rid )
    local roleInfo = self:getRole( _rid, {
        Enum.Role.lastActionForceTime, Enum.Role.actionForce
    } )
    local nowTime = os.time()
    -- 行动力上限
    local actionForceLimit = self:getActionForceLimit( _rid )
    -- 恢复一点行动力所需要的时间
    local vitalityRecoveryTime = self:getActionForceRecoveryTime( _rid )
    -- 需要新增的行动力
    local costTime = nowTime - ( roleInfo.lastActionForceTime or 0 )
    local addActionForce = math.floor( costTime / vitalityRecoveryTime )
    local actionForce
    if roleInfo.actionForce + addActionForce >= actionForceLimit then
        -- 角色行动力满
        actionForce = actionForceLimit
    else
        actionForce = roleInfo.actionForce + addActionForce
    end

    if roleInfo.actionForce < actionForce then
        if actionForce < actionForceLimit then
            -- 新增定时器
            local interval = ( addActionForce + 1 ) * vitalityRecoveryTime - costTime
            self:setRole( _rid, { [Enum.Role.actionForce] = actionForce, [Enum.Role.lastActionForceTime] = nowTime + interval - vitalityRecoveryTime } )
            MSM.RoleTimer[_rid].req.addActionForceTimer( _rid, interval )
        else
            self:setRole( _rid, { [Enum.Role.actionForce] = actionForce, [Enum.Role.lastActionForceTime] = nowTime } )
        end
    else
        LOG_INFO("rid(%d) addActionForceTimerOnLogin, actionForce(%d) addActionForce(%d) actionForceLimit(%d) vitalityRecoveryTime(%d) lastActionForceTime(%d)",
                _rid, roleInfo.actionForce, addActionForce, actionForceLimit, vitalityRecoveryTime, roleInfo.lastActionForceTime)
    end
end

---@see 行动力上限变化处理
function RoleLogic:actionForceLimitChange( _rid )
    if self:getRole( _rid, Enum.Role.online ) then
        local actionForceLimit = self:getActionForceLimit( _rid )
        if not self:checkActionForce( _rid, actionForceLimit ) then
            -- 行动力未到上限，添加定时器
            MSM.RoleTimer[_rid].req.addActionForceTimer( _rid )
        else
            -- 行动力已到上限，删除定时器
            MSM.RoleTimer[_rid].req.deleteActionForceTimer( _rid )
        end
    end
end

---@see 恢复速度变化处理
function RoleLogic:actionForceRecoverChange( _rid, _noSync )
    local actionForceLimit = self:getActionForceLimit( _rid )
    local roleInfo = self:getRole( _rid, { Enum.Role.lastActionForceTime, Enum.Role.actionForce, Enum.Role.online } )
    if roleInfo.online and not self:checkActionForce( _rid, actionForceLimit ) then
        -- 移除定时器
        MSM.RoleTimer[_rid].req.deleteActionForceTimer( _rid )
        -- 行动力未到上限，此时存在定时器
        local nowTime = os.time()
        local vitalityRecoveryTime = self:getActionForceRecoveryTime( _rid )
        local actionForce = roleInfo.actionForce
        if ( roleInfo.lastActionForceTime or 0 ) + vitalityRecoveryTime <= nowTime then
            -- 速度变化后，直接完成本次新增的行动力
            actionForce = self:addActionForce( _rid, 1, nil, Enum.LogType.RECOVER_GAIN_ACTION )
            -- 重置本次恢复行动力时间
            self:setRole( _rid, { [Enum.Role.lastActionForceTime] = nowTime } )
            -- 通知客户端
            if not _noSync then
                RoleSync:syncSelf( _rid, { [Enum.Role.lastActionForceTime] = nowTime }, true )
            end
        else
            vitalityRecoveryTime = ( roleInfo.lastActionForceTime or 0 ) + vitalityRecoveryTime - nowTime
        end
        -- 重新添加定时器
        if actionForce < actionForceLimit then
            MSM.RoleTimer[_rid].req.addActionForceTimer( _rid, vitalityRecoveryTime )
        end
    end
end

---@see 完成山洞村庄的探索后回调
---@param _resourcePointId integer 地图对象的resourceId(s_MapFixPoint表ID)
function RoleLogic:villageCaveScoutCallBack( _rid, _resourcePointId )
    local villageCaves = self:getRole( _rid, Enum.Role.villageCaves )
    -- 该资源所在索引
    local index = math.ceil( _resourcePointId / 64 )
    -- 该资源所在位索引
    local bitIndex = _resourcePointId % 64
    if not villageCaves[index] then
        villageCaves[index] = { index = index, rule = 0 }
    end

    local EmailLogic = require "EmailLogic"
    local TaskLogic = require "TaskLogic"
    local sMapFixPoint = CFG.s_MapFixPoint:Get( _resourcePointId )
    local sResourceGatherType = CFG.s_ResourceGatherType:Get( sMapFixPoint.type )
    if ( villageCaves[index].rule & ( 1 << bitIndex ) ) == 0 then
        -- 山洞村庄还未探索，完成探索
        villageCaves[index].rule = villageCaves[index].rule ~ ( 1 << bitIndex )
        self:setRole( _rid, Enum.Role.villageCaves, villageCaves )
        -- 通知客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.villageCaves] = { [index] = villageCaves[index] } }, true )

        if sResourceGatherType and not table.empty( sResourceGatherType ) then
            if sResourceGatherType.type == Enum.ResourceType.CAVE then
                -- 探索山洞，发送邮件
                if sResourceGatherType.mail and sResourceGatherType.mail > 0 then
                    local posArg = string.format( "%d,%d", sMapFixPoint.posX, sMapFixPoint.posY )
                    local emailOtherInfo = {
                        discoverReport = {
                            mapFixPointId = _resourcePointId,
                        },
                        subType = Enum.EmailSubType.DISCOVER_CAVE,
                        emailContents = { posArg, posArg },
                    }
                    EmailLogic:sendEmail( _rid, sResourceGatherType.mail, emailOtherInfo )
                end
                -- 增加探索次数
                self:addRoleStatistics( _rid, Enum.RoleStatisticsType.SCOUT, 1 )
                -- 登陆设置活动进度
                MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.CAVE_REWARD, 1 )
                -- 更新山洞调查次数
                TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.SCOUT_CAVE, Enum.TaskArgDefault, 1 )
            elseif sResourceGatherType.type == Enum.ResourceType.VILLAGE then
                -- 探索村庄，直接获取奖励
                local ItemLogic = require "ItemLogic"
                -- 登陆设置活动进度
                MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.VILLAGE_REWARD, 1 )
                -- 更新领取村庄奖励次数
                TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.VILLAGE_REWARD, Enum.TaskArgDefault, 1 )
                return true, ItemLogic:getVillageReward( _rid )
            end
        end
    else
        -- 山洞村庄已经探索
        if sResourceGatherType and not table.empty( sResourceGatherType ) then
            if sResourceGatherType.type == Enum.ResourceType.CAVE then
                -- 探索山洞失败, 发送失败邮件
                local caveMailFail = CFG.s_Config:Get( "caveMailFail" )
                if caveMailFail and caveMailFail > 0 then
                    local posArg = string.format( "%d,%d", sMapFixPoint.posX, sMapFixPoint.posY )
                    local emailOtherInfo = {
                        discoverReport = {
                            mapFixPointId = _resourcePointId,
                        },
                        subType = Enum.EmailSubType.DISCOVER_CAVE,
                        emailContents = { posArg, posArg },
                    }
                    EmailLogic:sendEmail( _rid, caveMailFail, emailOtherInfo )
                end
            elseif sResourceGatherType.type == Enum.ResourceType.VILLAGE then
                -- 探索村庄失败
                return false, ErrorCode.MAP_VILLAGE_ALREADY_SCOUT
            end
        end
    end
end

---@see 检查山洞村庄是否已探索
---@param _resourcePointId integer 地图对象的resourceId(s_MapFixPoint表ID)
---@return boolean true 已探索过
function RoleLogic:checkVillageCave( _rid, _resourcePointId )
    local villageCaves = self:getRole( _rid, Enum.Role.villageCaves )
    -- 该资源所在索引
    local index = math.ceil( _resourcePointId / 64 )
    -- 该资源所在位索引
    local bitIndex = _resourcePointId % 64

    return villageCaves[index] and ( villageCaves[index].rule & ( 1 << bitIndex ) ) ~= 0 or false
end

---@see 增加斥候迷雾探索标识
function RoleLogic:addScoutDenseFogFlag( _rid, _scoutIndex )
    local scoutDenseFogFlag = RoleLogic:getRole( _rid, Enum.Role.scoutDenseFogFlag ) or {}
    if not table.exist( scoutDenseFogFlag, _scoutIndex ) then
        table.insert( scoutDenseFogFlag, _scoutIndex )
        self:setRole( _rid, Enum.Role.scoutDenseFogFlag, scoutDenseFogFlag )
    end
end

---@see 判断引导阶段任务是否完成
function RoleLogic:checkGuideFinish( _noviceGuideStep, _stageId )
    return ( _noviceGuideStep & ( 1 << ( _stageId - 1 ) ) ) >= 1
end

---@see 检测名字是否合法
function RoleLogic:checkBlockName( _name )
    -- 检测名字的屏蔽字
    local allBlockName = CFG.s_Block:Get()
    for _,rule in pairs(allBlockName) do
        if reg.match(_name, rule.ID) then
            return false
        end
    end
    return true
end

---@see 检测内容是否合法
function RoleLogic:checkChatBlock( _content )
    -- 检测名字的屏蔽字
    local sChatBlock = CFG.s_ChatBlock:Get()
    for _, rule in pairs( sChatBlock ) do
        if reg.match( _content, rule.ID ) then
            return false
        end
    end
    return true
end

---@see 角色是否在联盟中
function RoleLogic:checkRoleGuild( _rid )
    local guildId = self:getRole( _rid, Enum.Role.guildId )
    return guildId and guildId > 0
end

---@see 检测名字是否只有数字
function RoleLogic:checkNameOnlyNum( _name )
    local charAscii
    for i = 1, #_name do
        charAscii = string.byte( _name, i )
        if charAscii < 48 or charAscii > 57 then
            return false
        end
    end
    return true
end

---@see 修改角色名字
function RoleLogic:modify( _rid, _name )
    local ItemLogic = require "ItemLogic"
    local ArmyLogic = require "ArmyLogic"

    local sConfig = CFG.s_Config:Get()
    if ItemLogic:checkItemEnough( _rid, sConfig.playerNameCostItem, 1) then
        ItemLogic:delItemById( _rid, sConfig.playerNameCostItem, 1, nil, Enum.LogType.ROLE_MODIFY_NAME_COST_ITEM )
    elseif self:checkDenar( _rid, sConfig.playerNameCostDenar) then
        self:addDenar( _rid, -sConfig.playerNameCostDenar, nil, Enum.LogType.ROLE_MODIFY_NAME_COST_DENAR )
    else
        LOG_ERROR("rid(%d) ModifyName, item(%d) and denar not enough", _rid, sConfig.playerNameCostItem)
        return nil, ErrorCode.ROLE_NAME_ITEM_DENAR_NOT_ENOUGH
    end
    if not SM.GuildNameProxy.req.addRoleName( _name, _rid, Common.getSelfNodeName() ) then
        LOG_ERROR("rid(%d) ModifyName, name(%s) repeat", _rid, _name)
        return nil, ErrorCode.ROLE_NAME_REPEAT
    end
    local roleInfo = self:getRole( _rid, { Enum.Role.name, Enum.Role.guildId, Enum.Role.reinforces } )
    -- 更新统计信息
    self:setRole( _rid, { [Enum.Role.name] = _name } )
    RoleSync:syncSelf( _rid, { [Enum.Role.name] = _name }, true )
    SM.GuildNameProxy.post.delRoleName( roleInfo.name )
    self:updateAoiModifyName(_rid, _name)
    if not roleInfo.guildId or roleInfo.guildId <= 0 then
        -- 入盟邀请推荐角色改名处理
        SM.RoleRecommendMgr.post.roleModifyName( _rid, roleInfo.name, _name )
    end
    -- 角色昵称查询改名处理
    MSM.RoleNameMgr[_rid].post.roleModifyName( _rid, roleInfo.name, _name )
    -- 角色在联盟中更新联盟修改标识
    local targetArg
    if roleInfo.guildId and roleInfo.guildId > 0 then
        MSM.GuildIndexMgr[roleInfo.guildId].post.addMemberIndex( roleInfo.guildId, _rid )
        -- 更新角色求助修改标识
        local GuildLogic = require "GuildLogic"
        GuildLogic:updateRoleRequestIndexs( _rid )
        -- 更新角色集结部队名称
        local RallyLogic = require "RallyLogic"
        RallyLogic:syncRallyRoleInfo( _rid, _name )
        -- 更新联盟书签创建者名称
        MSM.GuildMgr[roleInfo.guildId].post.updateGuildMarkerName( roleInfo.guildId, _rid, _name )
    end
    -- 修改聊天服务器信息
    local RoleChatLogic = require "RoleChatLogic"
    RoleChatLogic:syncRoleInfoToChatServer( _rid )

    -- 更新修改昵称统计数
    local TaskLogic = require "TaskLogic"
    TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.MODIFY_NAME, Enum.TaskArgDefault, 1 )

    -- 增援城市部队名修改
    for reinforceRid, reinforce in pairs( roleInfo.reinforces or {} ) do
        targetArg = ArmyLogic:getArmy( reinforceRid, reinforce.armyIndex, Enum.Army.targetArg ) or {}
        targetArg.targetName = _name
        ArmyLogic:updateArmyInfo( reinforceRid, reinforce.armyIndex, { [Enum.Army.targetArg] = targetArg } )
    end

    return { name = _name }
end

---@see 角色改名更新AOI信息
function RoleLogic:updateAoiModifyName( _rid, _name )
    local ArmyLogic = require "ArmyLogic"
    local GuildBuildLogic = require "GuildBuildLogic"
    local HolyLandLogic = require "HolyLandLogic"

    local objectIndex, targetObjectIndex, targetInfo, reinforces
    local armys = ArmyLogic:getArmy( _rid ) or {}
    for armyIndex, armyInfo in pairs( armys ) do
        objectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, armyIndex )
        targetObjectIndex = armyInfo.targetArg and armyInfo.targetArg.targetObjectIndex or 0
        targetInfo = nil
        if targetObjectIndex > 0 then
            targetInfo = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectInfo( targetObjectIndex )
        end
        if objectIndex then
            -- 部队在地图上
            MSM.SceneArmyMgr[objectIndex].post.syncArmyName( objectIndex, _name )
        else
            if targetInfo then
                if MapObjectLogic:checkIsResourceObject( targetInfo.objectType ) then
                    -- 在资源点中采集
                    MSM.SceneResourceMgr[targetObjectIndex].post.updateResourceInfo( targetObjectIndex, { cityName = _name } )
                end
            end
        end

        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.REINFORCE_MARCH )
            or ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) then
            if MapObjectLogic:checkIsGuildBuildObject( targetInfo.objectType ) then
                -- 在联盟建筑中
                reinforces = GuildBuildLogic:getGuildBuild( targetInfo.guildId, targetInfo.buildIndex, Enum.GuildBuild.reinforces ) or {}
                for index, reinforce in pairs( reinforces ) do
                    if reinforce.rid == _rid and reinforce.armyIndex == armyIndex then
                        GuildBuildLogic:syncGuildBuildArmy( targetObjectIndex, { [index] = { roleName = _name, buildArmyIndex = index } } )
                        break
                    end
                end
            elseif MapObjectLogic:checkIsHolyLandObject( targetInfo.objectType ) then
                -- 在圣地关卡中
                reinforces = HolyLandLogic:getHolyLand( targetInfo.strongHoldId, Enum.HolyLand.reinforces ) or {}
                for index, reinforce in pairs( reinforces ) do
                    if reinforce.rid == _rid and reinforce.armyIndex == armyIndex then
                        HolyLandLogic:syncHolyLandArmy( targetObjectIndex, { [index] = { roleName = _name, buildArmyIndex = index } } )
                        break
                    end
                end
            elseif targetInfo.objectType == Enum.RoleType.CITY and ( armyInfo.reinforceRid or 0 ) > 0 then
                -- 增援城市
                reinforces = RoleLogic:getRole( armyInfo.reinforceRid, Enum.Role.reinforces ) or {}
                if reinforces[_rid] then
                    reinforces[_rid].name = _name
                    -- 更新到角色中
                    RoleLogic:setRole( armyInfo.reinforceRid, Enum.Role.reinforces, reinforces )
                    -- 通知客户端
                    RoleSync:syncSelf( armyInfo.reinforceRid, { [Enum.Role.reinforces] = reinforces }, true )
                end
            end
        end
    end
    -- 角色城市增加联盟简称
    objectIndex = self:getRoleCityIndex( _rid )
    MSM.SceneCityMgr[objectIndex].post.updateCityName( objectIndex, _name )
    -- 斥候增加联盟简称
    local ScoutsLogic = require "ScoutsLogic"
    local scouts = ScoutsLogic:getScouts( _rid ) or {}
    for _, scoutsInfo in pairs( scouts ) do
        if not ArmyLogic:checkArmyStatus( scoutsInfo.scoutsStatus, Enum.ArmyStatus.STANBY ) then
            -- 斥候不处于待命状态
            MSM.SceneScoutsMgr[objectIndex].post.syncArmyName( scoutsInfo.objectIndex or 0, _name )
        end
    end
end

---@see 增加城市buff
function RoleLogic:addCityBuff( _rid, _buffId, _block )
    local cityBuff = self:getRole( _rid, Enum.Role.cityBuff )
    local sCityBuff = CFG.s_CityBuff:Get(_buffId)
    local sCityBuffGroup = CFG.s_CityBuffGroup:Get(sCityBuff.group)
    local sCityBuffSeries = CFG.s_CityBuffSeries:Get(sCityBuffGroup.series)
    local cityBuffConfig
    local cityBuffGroup
    local delBuffId = {}
    -- 判断原来是否有这个buffId
    if cityBuff[_buffId] then
        MSM.RoleTimer[_rid].req.deleteCityBuffTimer( _rid, _buffId )
        table.insert( delBuffId, _buffId )
    else
    -- 如果分组不能共存，处理该分组原有的buff
        if Enum.RoleCityBuffCoexist.NO == sCityBuffGroup.overlay then
            for buffId in pairs(cityBuff) do
                -- 移除对应定时器
                cityBuffConfig = CFG.s_CityBuff:Get(buffId)
                if cityBuffConfig.group == sCityBuff.group then
                    MSM.RoleTimer[_rid].req.deleteCityBuffTimer( _rid, buffId )
                    table.insert( delBuffId, buffId )
                end
            end
        end
        -- 如果分组系列不能共存，处理该分组系列原有的buff
        if sCityBuffSeries and Enum.RoleCityBuffCoexist.NO == sCityBuffSeries.overlay then
            for buffId in pairs(cityBuff) do
                -- 移除对应定时器
                cityBuffConfig = CFG.s_CityBuff:Get(buffId)
                cityBuffGroup = CFG.s_CityBuffGroup:Get(cityBuffConfig.group)
                if cityBuffGroup.series == sCityBuffGroup.series and sCityBuff.group ~= cityBuffGroup.ID then
                    MSM.RoleTimer[_rid].req.deleteCityBuffTimer( _rid, buffId )
                    table.insert( delBuffId, buffId )
                end
            end
        end
    end
    local synCityBuff = {}
    for _, buffId in pairs(delBuffId) do
        cityBuff[buffId] = nil
        synCityBuff[buffId] = { id = buffId, expiredTime = -2 }
        self:reduceCityBuffAttr( _rid, buffId )
    end
    cityBuff[_buffId] = { id = _buffId, expiredTime = os.time() + sCityBuff.duration }
    if sCityBuff.duration == -1 then
        cityBuff[_buffId].expiredTime = -1
    end
    synCityBuff[_buffId] = cityBuff[_buffId]
    self:setRole( _rid, { [Enum.Role.cityBuff] = cityBuff } )
    if cityBuff[_buffId].expiredTime > -1 then
        MSM.RoleTimer[_rid].req.addCityBuffTimer( _rid, _buffId, cityBuff[_buffId].expiredTime )
    end
    RoleSync:syncSelf( _rid, { [Enum.Role.cityBuff] = synCityBuff }, true, _block )
    self:addCityBuffAttr( _rid, _buffId )
    --同步aoi
    local cityIndex = self:getRoleCityIndex( _rid )
    if sCityBuff.effect ~= "" and cityIndex then
        MSM.SceneCityMgr[cityIndex].post.updateCityBuff( cityIndex, cityBuff )
    end
    if sCityBuff.type == Enum.RoleCityBuff.SHIELD then
        -- 开启护盾.判断城市正在被攻击.和被攻击行军
        if cityIndex then
            MSM.SceneCityMgr[cityIndex].post.onCityShieldBuff( cityIndex )
        end
    end
end

---@see 创角增加cityBuff

function RoleLogic:createRoleAddCityBuff( _rid, _buffId, _block )
    local cityBuff = self:getRole( _rid, Enum.Role.cityBuff )
    local sCityBuff = CFG.s_CityBuff:Get(_buffId)
    local sCityBuffGroup = CFG.s_CityBuffGroup:Get(sCityBuff.group)
    local sCityBuffSeries = CFG.s_CityBuffSeries:Get(sCityBuffGroup.series)
    local cityBuffConfig
    local cityBuffGroup
    local delBuffId = {}
    -- 判断原来是否有这个buffId
    if cityBuff[_buffId] then
        MSM.RoleTimer[_rid].req.deleteCityBuffTimer( _rid, _buffId )
        table.insert( delBuffId, _buffId )
    else
    -- 如果分组不能共存，处理该分组原有的buff
        if Enum.RoleCityBuffCoexist.NO == sCityBuffGroup.overlay then
            for buffId in pairs(cityBuff) do
                -- 移除对应定时器
                cityBuffConfig = CFG.s_CityBuff:Get(buffId)
                if cityBuffConfig.group == sCityBuff.group then
                    MSM.RoleTimer[_rid].req.deleteCityBuffTimer( _rid, buffId )
                    table.insert( delBuffId, buffId )
                end
            end
        end
        -- 如果分组系列不能共存，处理该分组系列原有的buff
        if sCityBuffSeries and Enum.RoleCityBuffCoexist.NO == sCityBuffSeries.overlay then
            for buffId in pairs(cityBuff) do
                -- 移除对应定时器
                cityBuffConfig = CFG.s_CityBuff:Get(buffId)
                cityBuffGroup = CFG.s_CityBuffGroup:Get(cityBuffConfig.group)
                if cityBuffGroup.series == sCityBuffGroup.series and sCityBuff.group ~= cityBuffGroup.ID then
                    MSM.RoleTimer[_rid].req.deleteCityBuffTimer( _rid, buffId )
                    table.insert( delBuffId, buffId )
                end
            end
        end
    end
    local synCityBuff = {}
    for _, buffId in pairs(delBuffId) do
        cityBuff[buffId] = nil
        synCityBuff[buffId] = { id = buffId, expiredTime = -2 }
        self:reduceCityBuffAttr( _rid, buffId )
    end
    cityBuff[_buffId] = { id = _buffId, expiredTime = os.time() + sCityBuff.duration }
    if sCityBuff.duration == -1 then
        cityBuff[_buffId].expiredTime = -1
    end
    synCityBuff[_buffId] = cityBuff[_buffId]
    self:setRole( _rid, { [Enum.Role.cityBuff] = cityBuff } )
    if cityBuff[_buffId].expiredTime > -1 then
        MSM.RoleTimer[_rid].req.addCityBuffTimer( _rid, _buffId, cityBuff[_buffId].expiredTime )
    end
    --同步aoi
    local cityIndex = self:getRoleCityIndex( _rid )
    if sCityBuff.effect ~= "" and cityIndex then
        MSM.SceneCityMgr[cityIndex].post.updateCityBuff( cityIndex, cityBuff )
    end
    if sCityBuff.type == Enum.RoleCityBuff.SHIELD then
        -- 开启护盾.判断城市正在被攻击.和被攻击行军
        if cityIndex then
            MSM.SceneCityMgr[cityIndex].post.onCityShieldBuff( cityIndex )
        end
    end
end

---@see 使用道具增加城市buff
function RoleLogic:addRoleCityBuff( _rid, _buffId, _itemId )
    local TaskLogic = require "TaskLogic"

    local sCityBuff = CFG.s_CityBuff:Get(_buffId)
    local itemId = sCityBuff.item
    if itemId == 0 then
        self:addCityBuff( _rid, _buffId )

        return { itemId = sCityBuff.item, itemNum = 1 }
    end
    local ItemLogic = require "ItemLogic"
    local sitem = CFG.s_Item:Get(itemId)
    if _itemId and ItemLogic:checkItemEnough( _rid, itemId, 1 ) then
        ItemLogic:delItemById( _rid, itemId, 1, nil, Enum.LogType.CITY_BUFF_COST_ITEM )
    elseif not _itemId and self:checkDenar( _rid, sitem.shortcutPrice ) then
        self:addDenar( _rid, -sitem.shortcutPrice, nil, Enum.LogType.CITY_BUFF_COST_DENAR )
    else
        return false
    end
    self:addCityBuff( _rid, _buffId )
    TaskLogic:updateItemUseTaskSchedule( _rid, nil, 1, sitem )

    return { itemId = sCityBuff.item, itemNum = 1 }
end

---@see 移除城市buff增益
function RoleLogic:reduceCityBuffAttr( _rid, _buffId )
    local sCityBuff = CFG.s_CityBuff:Get(_buffId)
    local roleInfo = self:getRole( _rid )
    if not table.empty(sCityBuff.attr) then
        local oldRoleInfo = table.copy( roleInfo, true )
        local attr = sCityBuff.attr or {}
        local attrData = sCityBuff.attrData
        for i = 1,table.size(attr) do
            local attrName = attr[i]
            if roleInfo[attrName] then
                roleInfo[attrName] = roleInfo[attrName] - ( attrData[i] or 0 )
                if not attrData[i] then
                    LOG_ERROR("rid(%s) reduceCityBuffAttr error, s_CityBuff buffId(%s) cfg error", tostring(_rid), tostring(_buffId))
                end
            end
        end
        self:updateRoleChangeInfo( _rid, oldRoleInfo, roleInfo )

        -- 检查角色相关属性信息是否变化
        RoleCacle:checkRoleAttrChange( _rid, oldRoleInfo, roleInfo )
    end
    if sCityBuff.effect ~= "" then
        local objectIndex = self:getRoleCityIndex( _rid )
        local synBuff = { [_buffId] = { id = _buffId, expiredTime = -2 } }
        if objectIndex then
            MSM.SceneCityMgr[objectIndex].post.updateCityBuff( objectIndex, synBuff )
        end
    end
end

---@see 增加城市buff
function RoleLogic:addCityBuffAttr( _rid, _buffId, _roleAttr, _noSet )
    local sCityBuff = CFG.s_CityBuff:Get(_buffId)
    local roleInfo = _roleAttr or self:getRole( _rid )
    if sCityBuff and not table.empty( sCityBuff.attr or {} ) then
        local oldRoleInfo = table.copy( roleInfo, true )
        local attr = sCityBuff.attr
        local attrData = sCityBuff.attrData
        for i=1,table.size(attr) do
            local attrName = attr[i]
            roleInfo[attrName] = ( roleInfo[attrName] or 0 ) + ( attrData[i] or 0 )
            if not attrData[i] then
                LOG_ERROR("rid(%s) addCityBuffAttr error, s_CityBuff buffId(%s) cfg error", tostring(_rid), tostring(_buffId))
            end
        end

        if not _noSet then
            self:updateRoleChangeInfo( _rid, oldRoleInfo, roleInfo )
            -- 检查角色相关属性信息是否变化
            RoleCacle:checkRoleAttrChange( _rid, oldRoleInfo, roleInfo )
        end
    end
end

---@see 移除城市buff
function RoleLogic:removeCityBuff( _rid, _buffId, _noSync )
    local cityBuff = self:getRole( _rid, Enum.Role.cityBuff )
    local synCityBuff = {}
    cityBuff[_buffId] = nil
    synCityBuff[_buffId] = { expiredTime = -2, id = _buffId, }
    self:reduceCityBuffAttr( _rid, _buffId )
    self:setRole( _rid, { [Enum.Role.cityBuff] = cityBuff } )
    if not _noSync then
        RoleSync:syncSelf( _rid, { [Enum.Role.cityBuff] = synCityBuff }, true )
    end
end

---@see 判断是否处于战争狂热
function RoleLogic:checkWarCarzy( _rid )
    local cityBuff = self:getRole( _rid, Enum.Role.cityBuff )
    if not cityBuff or table.empty(cityBuff) then
        return false
    end
    for buffId in pairs(cityBuff) do
        local sCityBuff = CFG.s_CityBuff:Get(buffId)
        if sCityBuff.type == Enum.RoleCityBuff.WAR_CARZY then
            return true
        end
    end
    return false
end

---@see 是否处于保护状态
function RoleLogic:checkShield( _rid )
    local cityBuff = self:getRole( _rid, Enum.Role.cityBuff )
    if not cityBuff or table.empty(cityBuff) then
        return false
    end
    for buffId, buffInfo in pairs(cityBuff) do
        local sCityBuff = CFG.s_CityBuff:Get(buffId)
        if sCityBuff and sCityBuff.type == Enum.RoleCityBuff.SHIELD then
            return true, buffInfo
        end
    end
    return false
end

---@see 是否处于反侦察状态
function RoleLogic:checkAntiScout( _rid )
    local cityBuff = self:getRole( _rid, Enum.Role.cityBuff )
    if not cityBuff or table.empty(cityBuff) then
        return false
    end
    for buffId in pairs(cityBuff) do
        local sCityBuff = CFG.s_CityBuff:Get(buffId)
        if sCityBuff.type == Enum.RoleCityBuff.ANTI_SCOUT then
            return true
        end
    end
    return false
end

---@see 是否处于疑兵状态
function RoleLogic:checkSusPect( _rid )
    local cityBuff = self:getRole( _rid, Enum.Role.cityBuff )
    if not cityBuff or table.empty(cityBuff) then
        return false
    end
    for buffId in pairs(cityBuff) do
        local sCityBuff = CFG.s_CityBuff:Get(buffId)
        if sCityBuff.type == Enum.RoleCityBuff.SUSPECT then
            return true
        end
    end
    return false
end

---@see 添加战争狂热状态
function RoleLogic:addWarCrazy( _rid )
    -- 判断是否有战争狂热
    local cityLevel = self:getRole( _rid, Enum.Role.level )
    local sBattleBuff = CFG.s_BattleBuff:Get()
    for _, battleBuffInfo in pairs(sBattleBuff) do
        if battleBuffInfo.minLevel <= cityLevel and battleBuffInfo.maxLevel >= cityLevel then
            -- 添加buff
            self:addCityBuff( _rid, battleBuffInfo.buff )
            return
        end
    end
end

---@see 取消城市护盾状态
function RoleLogic:removeCityShield( _rid )
    local cityBuff = self:getRole( _rid, Enum.Role.cityBuff )
    if not cityBuff or table.empty(cityBuff) then
        return
    end

    local removeBuffIds = {}
    for buffId in pairs(cityBuff) do
        local sCityBuff = CFG.s_CityBuff:Get(buffId)
        if sCityBuff.type == Enum.RoleCityBuff.SHIELD then
            table.insert( removeBuffIds, buffId )
        end
    end

    for _, removeBuffId in pairs(removeBuffIds) do
        self:removeCityBuff( _rid, removeBuffId )
    end
end

---@see 跨天重置角色信息
function RoleLogic:resetRoleAttrDaily( _rid, _isLogin )
    local roleInfo = self:getRole( _rid )
    -- 修改的角色属性
    local roleChangeInfo = {}
    -- 需要同步客户端的角色属性
    local roleSyncInfo = {}

    -- 重置角色今日联盟帮助获得的积分
    if roleInfo.guildHelpPoint > 0 then
        roleChangeInfo[Enum.Role.guildHelpPoint] = 0
        roleSyncInfo[Enum.Role.guildHelpPoint] = 0
    end

    -- 重置今日联盟获得的角色帮助积分
    if roleInfo.roleHelpGuildPoint > 0 then
        roleChangeInfo[Enum.Role.roleHelpGuildPoint] = 0
    end

    -- 重置角色今日联盟建造获得的积分
    if roleInfo.guildBuildPoint > 0 then
        roleChangeInfo[Enum.Role.guildBuildPoint] = 0
    end

    -- 重置角色今日行动力购买次数
    if roleInfo.buyActionForceCount > 0 then
        roleChangeInfo[Enum.Role.buyActionForceCount] = 0
    end

    -- 重置角色代币捐献需求值
    local AllianceGemGiftNum = CFG.s_Config:Get( "AllianceGemGiftNum" )
    if roleInfo.guildDonateCostDenar > AllianceGemGiftNum then
        roleChangeInfo[Enum.Role.guildDonateCostDenar] = AllianceGemGiftNum
        roleSyncInfo[Enum.Role.guildDonateCostDenar] = AllianceGemGiftNum
    end

    -- 修改角色属性值
    self:setRole( _rid, roleChangeInfo )
    -- 同步客户端
    if not _isLogin and not table.empty( roleSyncInfo ) then
        -- 登录时后面会推送所有信息，此处不需要推送
        RoleSync:syncSelf( _rid, roleSyncInfo, true )
    end
end

---@see 解锁玩家头像以及头像框
function RoleLogic:unlockRoleHead( _rid, _itemId )
    local roleInfo = self:getRole( _rid )
    local sitemInfo = CFG.s_Item:Get( _itemId )
    local roleChangeInfo = {}
    if sitemInfo.type ~= Enum.ItemType.HEAD then
        return
    end
    local sItemPlayerHead = CFG.s_ItemPlayerHead:Get(_itemId)
    local sPlayerHead = CFG.s_PlayerHead:Get(sItemPlayerHead.playerHeadID)
    if sPlayerHead.group == Enum.RoleHeadType.HEAD then
        if table.exist(roleInfo.headList, sItemPlayerHead.playerHeadID) then return end
        table.insert(roleInfo.headList, sItemPlayerHead.playerHeadID)
        roleChangeInfo[Enum.Role.headList] = roleInfo.headList
    else
        if table.exist(roleInfo.headFrameList, sItemPlayerHead.playerHeadID) then return end
        table.insert(roleInfo.headFrameList, sItemPlayerHead.playerHeadID)
        roleChangeInfo[Enum.Role.headFrameList] = roleInfo.headFrameList
    end
    self:setRole( _rid, roleChangeInfo)
    RoleSync:syncSelf( _rid, roleChangeInfo, true )
end

---@see 刷新神秘商人商品
function RoleLogic:refreshPostGoods( _rid )
    local BuildingLogic = require "BuildingLogic"
    local level = BuildingLogic:getBuildingLv( _rid, Enum.BuildingType.TOWNHALL)
    local mysteryConfig = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.MYSTERY_STORE ) or {}
    local mysteryStore = {}
    for _, mysteryInfo in pairs(mysteryConfig) do
        local storeRate = {}
        for _, info in pairs(mysteryInfo) do
            if level >= info.level then
                table.insert(storeRate, { id = info.ID, rate = info.prob })
            end
        end
        local goods = Random.GetIds( storeRate, 4 )
        for _, id in pairs(goods) do
            local sMysteryStore = CFG.s_MysteryStore:Get(id)
            -- 判断折扣
            local discounts = CFG.s_MysteryStorePro:Get(sMysteryStore.discount)
            local discountRate = {}
            for _, config in pairs(discounts) do
                table.insert(discountRate, { id = config.add, rate = config.probability })
            end
            local discount = math.tointeger(Random.GetId(discountRate))
            local nums = CFG.s_MysteryStorePro:Get(sMysteryStore.num)
            local numRate = {}
            for _, config in pairs(nums) do
                table.insert(numRate, { id = config.add, rate = config.probability })
            end
            local num = Random.GetId(numRate)
            local price = math.floor( (sMysteryStore.price - sMysteryStore.price * discount / 100 ) * num )
            mysteryStore[id] = { id = id, num = num, discount = discount, isBuy = false, price = price }
        end
    end
    return mysteryStore
end

---@see 刷新神秘商人
function RoleLogic:refreshPost( _rid, _isLogin )
    local BuildingLogic = require "BuildingLogic"
    if table.empty(BuildingLogic:getBuildingInfoByType( _rid, Enum.BuildingType.STATION )) then
        return
    end
    local mysteryStoreGoods = self:refreshPostGoods( _rid )
    local leaveTime = os.time() + CFG.s_Config:Get("mysteryStoreExist")
    local refreshCount = 0
    local mysteryStore = {
        mysteryStoreGoods = mysteryStoreGoods,
        leaveTime = leaveTime,
        refreshCount = refreshCount,
        freeRefresh = false,
    }
    -- 增加商人离开定时器
    MSM.RoleTimer[_rid].req.addMysteryStoreTimer( _rid, mysteryStore.leaveTime, true )
    self:setRole( _rid, { [Enum.Role.mysteryStore] = mysteryStore, [Enum.Role.mysteryRefreshTime] = os.time() } )
    if not _isLogin then
        RoleSync:syncSelf( _rid, { [Enum.Role.mysteryStore] = mysteryStore }, true )
    end
    -- 同步给客户端
    if Common.offOnline( _rid ) then
        self:setRole( _rid, { [Enum.Role.storeNotice] = true } )
    else
        if not _isLogin then
            Common.syncMsg( _rid, "Role_MysteryStore", { refresh = true } )
        end
        self:setRole( _rid, { [Enum.Role.storeNotice] = false } )
    end
end

---@see 神秘商人离开后逻辑处理
function RoleLogic:postLeave( _rid, _isLogin )
    local mysteryRefreshTime = os.time() + CFG.s_Config:Get("mysteryStoreCooling")
    self:setRole( _rid, { [Enum.Role.mysteryStore] = {}, [Enum.Role.mysteryRefreshTime] = mysteryRefreshTime } )
    if not _isLogin then
        RoleSync:syncSelf( _rid, { [Enum.Role.mysteryStore] = {}, [Enum.Role.mysteryRefreshTime] = mysteryRefreshTime }, true )
    end
    -- 增加定时器
    MSM.RoleTimer[_rid].req.addMysteryStoreTimer( _rid, mysteryRefreshTime )
end

---@see 登陆增加神秘商人定时器
function RoleLogic:loginPost( _rid, _isLogin )
    local BuildingLogic = require "BuildingLogic"
    if table.empty(BuildingLogic:getBuildingInfoByType( _rid, Enum.BuildingType.STATION )) then
        return
    end
    local nowTime = os.time()
    local roleInfo = self:getRole( _rid, { Enum.Role.mysteryStore, Enum.Role.mysteryRefreshTime } )
    if table.empty( roleInfo.mysteryStore or {} ) then
        -- 神秘商人已离开
        if roleInfo.mysteryRefreshTime < nowTime then
            -- 神秘商人应该回来了
            self:refreshPost( _rid, _isLogin )
        else
            -- 神秘商人返回时间还未到
            MSM.RoleTimer[_rid].req.addMysteryStoreTimer( _rid, roleInfo.mysteryRefreshTime )
        end
    else
        -- 神秘商人未离开
        if roleInfo.mysteryStore.leaveTime > nowTime then
            -- 神秘商人还未到离开时间
            local mysteryStoreGoods = roleInfo.mysteryStore.mysteryStoreGoods
            local sMysteryStore = CFG.s_MysteryStore:Get()
            for id, good in pairs(mysteryStoreGoods) do
                if not good.price or good.price == 0 then
                    local discount = ( 100 - (good.discount or 0))/ 100
                    local price = math.floor( sMysteryStore[id].price * discount * good.num )
                    good.price = price
                end
            end
            self:setRole( _rid, { [Enum.Role.mysteryStore] = roleInfo.mysteryStore } )
            MSM.RoleTimer[_rid].req.addMysteryStoreTimer( _rid, roleInfo.mysteryStore.leaveTime, true )
        else
            -- 神秘商人已到离开时间
            self:postLeave( _rid, _isLogin )
        end
    end
end

---@see 购买神秘商人道具
function RoleLogic:buyPostGoods( _rid, _id )
    local mysteryStore = self:getRole( _rid, Enum.Role.mysteryStore )
    local sMysteryStore = CFG.s_MysteryStore:Get(_id)
    local itemNum = mysteryStore.mysteryStoreGoods[_id].num
    -- local discount = ( 100 - (mysteryStore.mysteryStoreGoods[_id].discount or 0))/ 100
    local price = mysteryStore.mysteryStoreGoods[_id].price
    if sMysteryStore.type == Enum.CurrencyType.food then
        self:addFood( _rid, -price, nil, Enum.LogType.BUY_POST_COST_CURRENCY )
    elseif sMysteryStore.type == Enum.CurrencyType.wood then
        self:addWood( _rid, -price, nil, Enum.LogType.BUY_POST_COST_CURRENCY )
    elseif sMysteryStore.type == Enum.CurrencyType.stone then
        self:addStone( _rid, -price, nil, Enum.LogType.BUY_POST_COST_CURRENCY )
    elseif sMysteryStore.type == Enum.CurrencyType.gold then
        self:addGold( _rid, -price, nil, Enum.LogType.BUY_POST_COST_CURRENCY )
    elseif sMysteryStore.type == Enum.CurrencyType.denar then
        self:addDenar( _rid, -price, nil, Enum.LogType.BUY_POST_COST_CURRENCY )
    end
    mysteryStore.mysteryStoreGoods[_id].isBuy = true
    self:setRole( _rid, { [Enum.Role.mysteryStore] = mysteryStore } )
    RoleSync:syncSelf( _rid, { [Enum.Role.mysteryStore] = mysteryStore }, true, true )
    local ItemLogic = require "ItemLogic"
    ItemLogic:addItem( { rid = _rid, itemId = sMysteryStore.item, itemNum = itemNum, eventType = Enum.LogType.POST_GAIN_ITEM})
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.POST_BUY_ACTION, 1 )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.POST_BUY_COUNT, 1 )
    -- 更新驿站购买次数
    local TaskLogic = require "TaskLogic"
    TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.MYSTERY_BUY, Enum.TaskArgDefault, 1 )
    TaskLogic:updateTaskSchedule( _rid,{ [Enum.TaskType.MYSTERY_BUY] = { arg = 0, addNum = 1 } } )
end

---@see 减少冷却时间
function RoleLogic:reduceTime( _rid, _sec )
    local BuildingLogic = require "BuildingLogic"
    if table.empty(BuildingLogic:getBuildingInfoByType( _rid, Enum.BuildingType.STATION )) then
        return
    end
    local roleInfo = self:getRole( _rid, { Enum.Role.mysteryStore, Enum.Role.mysteryRefreshTime } ) or {}
    local mysteryRefreshTime = roleInfo.mysteryRefreshTime or 0
    if mysteryRefreshTime < os.time() or not table.empty( roleInfo.mysteryStore or {} ) then
        return
    end
    self:setRole( _rid, { [Enum.Role.mysteryRefreshTime] = mysteryRefreshTime - _sec } )
    MSM.RoleTimer[_rid].req.addMysteryStoreTimer( _rid, mysteryRefreshTime - _sec )
end

---@see 更新角色联盟修改标识
function RoleLogic:updateRoleGuildIndexs( _rid, _attrInfo )
    local guildIndexs = self:getRole( _rid, Enum.Role.guildIndexs ) or {}
    table.mergeEx( guildIndexs, _attrInfo )
    self:setRole( _rid, { [Enum.Role.guildIndexs] = guildIndexs } )
end

---@see 获取角色联盟属性修改标识
function RoleLogic:getRoleGuildIndexs( _rid, _attrName )
    local guildIndexs = self:getRole( _rid, Enum.Role.guildIndexs ) or {}
    return guildIndexs[_attrName] or 0
end

---@see 登陆处理城市buff
function RoleLogic:cityBuffLogin( _rid )
    local cityBuff = self:getRole( _rid, Enum.Role.cityBuff )
    if not cityBuff or table.empty(cityBuff) then
        return
    end
    local removeBuffIds = {}
    for buffId, buffInfo in pairs(cityBuff) do
        if buffInfo.expiredTime > os.time() then
            MSM.RoleTimer[_rid].req.addCityBuffTimer( _rid, buffId, buffInfo.expiredTime )
        elseif buffInfo.expiredTime ~= -1 and buffInfo.expiredTime <= os.time() then
            table.insert( removeBuffIds, buffId )
        end
    end
    for _, buffId in pairs(removeBuffIds) do
        self:removeCityBuff( _rid, buffId, true )
    end
end

---@see 警戒塔升级.修正警戒塔血量
function RoleLogic:guardTowerLevelUpCallback( _rid, _level )
    local sBuildingGuardTower = CFG.s_BuildingGuardTower:Get( _level )
    if _level == 1 then
        -- 设置警戒塔血量
        self:setRole( _rid, Enum.Role.guardTowerHp, sBuildingGuardTower.warningTowerHpMax )
    else
        -- 如果处于战斗状态,不改变警戒塔血量
        local cityIndex = self:getRoleCityIndex( _rid )
        local cityInfo = MSM.SceneCityMgr[cityIndex].req.getCityInfo( cityIndex )
        local ArmyLogic = require "ArmyLogic"
        if not ArmyLogic:checkArmyStatus( cityInfo.status, Enum.ArmyStatus.BATTLEING ) then
            local sOldBuildingGuardTower = CFG.s_BuildingGuardTower:Get( _level - 1 )
            local curGuardTowerHp = self:getRole( _rid, Enum.Role.guardTowerHp )
            local per = curGuardTowerHp / sOldBuildingGuardTower.warningTowerHpMax
            local newGuardTowerHp = math.floor( sBuildingGuardTower.warningTowerHpMax * per )
            self:setRole( _rid, Enum.Role.guardTowerHp, newGuardTowerHp )
            RoleSync:syncSelf( _rid, { [Enum.Role.guardTowerHp] = newGuardTowerHp }, true )
        end
    end
end

---@see 城市退出战斗
function RoleLogic:cityExitBattle( _cityIndex )
    local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _cityIndex )
    if battleIndex then
        local BattleCreate = require "BattleCreate"
        local battleNode = BattleCreate:getBattleServerNode( battleIndex )
        if battleNode then
            Common.rpcMultiSend( battleNode, "BattleLoop", "objectExitBattle", battleIndex, _cityIndex )
        end
    end
end

---@see 购买vip特别尊享
function RoleLogic:buyVipSpecialBox( _rid, _vipLv )
    local roleInfo = self:getRole( _rid, { Enum.Role.vip, Enum.Role.vipSpecialBox, Enum.Role.rechargeFirst } )
    local level = self:getVipLv( roleInfo.vip )
    -- 判断等级是否达到
    if level < _vipLv then
        return Enum.WebError.VIP_NOT_ENOUGH
    end
    -- 判断是否已经买过了
    if table.exist( roleInfo.vipSpecialBox, _vipLv ) then
        return Enum.WebError.VIP_HAVE_BUY
    end
    local sVip = CFG.s_Vip:Get(_vipLv)
    table.insert( roleInfo.vipSpecialBox, _vipLv )

    local ItemLogic = require "ItemLogic"
    local EmailLogic = require "EmailLogic"

    -- 首冲
    if not roleInfo.rechargeFirst then
        local sRechargeFirst = CFG.s_RechargeFirst:Get(1001)
        local rewardInfo = ItemLogic:getItemPackage( _rid, sRechargeFirst.itemPackage, nil, nil, nil, nil, nil, true )
        roleInfo.rechargeFirst = true
        EmailLogic:sendEmail( _rid, sRechargeFirst.mailID, { rewards = rewardInfo, takeEnclosure = true })
    end

    self:setRole( _rid, { [Enum.Role.vipSpecialBox] = roleInfo.vipSpecialBox, [Enum.Role.rechargeFirst] = roleInfo.rechargeFirst } )
    RoleSync:syncSelf( _rid, { [Enum.Role.vipSpecialBox] = roleInfo.vipSpecialBox, [Enum.Role.rechargeFirst] = roleInfo.rechargeFirst }, true )

    EmailLogic:sendEmail( _rid, sVip.specialBoxMail )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.RECHARGE_ACTION, 1 )
    return Enum.WebError.SUCCESS
end

---@see 增加角色战斗数量
function RoleLogic:addBattleNum( _rid )
    local battleNum = self:getRole( _rid, Enum.Role.battleNum )
    battleNum = battleNum + 1
    self:setRole( _rid, { [Enum.Role.battleNum] = battleNum } )
end

---@see 减少角色战斗数量
function RoleLogic:decreaseBattleNum( _rid )
    local roleInfo = self:getRole( _rid, { Enum.Role.battleNum, Enum.Role.battleLostPower } )
    local roleChangeInfo = {}
    roleChangeInfo.battleNum = roleInfo.battleNum -1
    if roleChangeInfo.battleNum < 0 then
        roleChangeInfo.battleNum = 0
    end
    local RechargeLogic = require "RechargeLogic"
    RechargeLogic:triggerLimitPackage( _rid, { type = Enum.LimitTimeType.POWER_LOST, power = roleInfo.battleLostPower } )
    if roleChangeInfo.battleNum <= 0 then
        roleChangeInfo.battleLostPower = 0
    end
    self:setRole( _rid, roleChangeInfo )
end

---@see VIP商店刷新
function RoleLogic:refreshVipShop( _rid, _isLogin )
    local vipStore = self:getRole( _rid, Enum.Role.vipStore )
    local synInfo = {}
    for _, info in pairs(vipStore) do
        synInfo[info.id] = { id = info.id, count = 0 }
    end
    self:setRole( _rid, { [Enum.Role.vipStore] = {}} )
    if not _isLogin then
        RoleSync:syncSelf( _rid, { [Enum.Role.vipStore] = synInfo }, true )
    end
end

---@see 远征商店刷新
function RoleLogic:refreshExpeditionStore()
    local expeditionConfig = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.EXPEDITION_STORE ) or {}
    local expeditionStore = {}
    for _, mysteryInfo in pairs(expeditionConfig) do
        local storeRate = {}
        for _, info in pairs(mysteryInfo) do
            table.insert(storeRate, { id = info.ID, rate = info.weight })
        end
        local good = Random.GetId( storeRate )
        expeditionStore[good] = { itemId = good, buyCount = 0 }
    end
    return expeditionStore
end

---@see 重置远征商店信息
function RoleLogic:resetExpeditionStore( _rid, _isLogin )
    local expedition = self:getRole( _rid, Enum.Role.expedition )
    expedition.refreshCount = 0
    expedition.headCount = 0
    expedition.shopItem = self:refreshExpeditionStore()
    self:setRole( _rid, { [Enum.Role.expedition] = expedition } )
    if not _isLogin then
        RoleSync:syncSelf( _rid, { [Enum.Role.expedition] = expedition }, true )
    end
end

---@see 强制迁城
function RoleLogic:forceMoveCity( _rid )
    local roleInfo = self:getRole( _rid, { Enum.Role.guildId, Enum.Role.pos, Enum.Role.uid } )

    local cityIndex = self:getRoleCityIndex( _rid )
    local cityStatus = MSM.MapObjectTypeMgr[cityIndex].req.getObjectStatus( cityIndex )
    local ArmyLogic = require "ArmyLogic"
    if ArmyLogic:checkArmyStatus( cityStatus, Enum.ArmyStatus.BATTLEING ) then
        -- 退出战斗
        local BattleCreate = require "BattleCreate"
        BattleCreate:exitBattle( cityIndex, true )
    end

    -- 角色部队解散处理
    ArmyLogic:checkArmyOnForceMoveCity( _rid )

    -- 斥候回城处理
    local ScoutsLogic = require "ScoutsLogic"
    ScoutsLogic:checkScoutsOnForceMoveCity( _rid )

    -- 运输队伍回城处理
    local TransportLogic = require "TransportLogic"
    TransportLogic:forceMoveTransport( _rid )

    -- 获取强制迁城后的坐标
    local MapLogic = require "MapLogic"
    local MapProvinceLogic = require "MapProvinceLogic"
    local province = MapProvinceLogic:getPosInProvince( roleInfo.pos )
    local provinceOuterRingIds = CFG.s_Config:Get( "provinceOuterRingIds" ) or {}
    if not table.exist( provinceOuterRingIds, province ) then
        province = nil
    end

    -- 随机该区域内的空闲坐标
    local cityPos = MapLogic:randomCityIdlePos( _rid, roleInfo.uid, province, true ) or roleInfo.pos
    -- 地图城市对象移动
    local cityId = self:getRole( _rid, Enum.Role.cityId )
    MSM.MapObjectMgr[_rid].req.cityMove( _rid, cityId, cityIndex, cityPos )
    -- 向该城市移动的目标回城处理，结束被攻城战斗
    MSM.SceneCityMgr[cityIndex].post.cityMove( cityIndex, cityPos )
    -- 解锁城堡附近迷雾
    local DenseFogLogic = require "DenseFogLogic"
    DenseFogLogic:openDenseFogInPos( _rid, cityPos, 2 * Enum.DesenFogSize )
    -- 角色在联盟中，同步角色位置给联盟成员
    if roleInfo.guildId > 0 then
        local GuildLogic = require "GuildLogic"
        local members = GuildLogic:getAllOnlineMember( roleInfo.guildId ) or {}
        GuildLogic:syncGuildMemberPos( members, { [_rid] = { rid = _rid, pos = cityPos } } )
    end
    -- 角色不在线
    if not SM.OnlineMgr.req.checkOnline( _rid ) then
        self:setRole( _rid, { [Enum.Role.wallHpNotify] = true } )
    else
        -- 发送耐久为0迁城通知
        self:roleNotify( _rid, Enum.RoleNotifyType.WALL_HP_MOVE_CITY, nil, nil, true )
    end

    -- 更新当前城市坐标
    self:setRole( _rid, { [Enum.Role.pos] = cityPos } )
    -- 通知客户端
    RoleSync:syncSelf( _rid, { [Enum.Role.pos] = cityPos }, true )
end

---@see 联盟相关通知
function RoleLogic:roleNotify( _toRids, _op, _numArg, _stringArg, _block )
    Common.syncMsg( _toRids, "Role_RoleNotify", {
        notifyOperate = _op,
        numArg = _numArg,
        stringArg = _stringArg,
    }, _block )
end

---@see 检查是否需要发送城墙耐久为0迁城通知
function RoleLogic:checkWallMoveCityNotify( _rid )
    if self:getRole( _rid, Enum.Role.wallHpNotify ) then
        self:roleNotify( _rid, Enum.RoleNotifyType.WALL_HP_MOVE_CITY, nil, nil, true )
        self:setRole(_rid, { [Enum.Role.wallHpNotify] = false }  )
    end
end

---@see 获取角色联盟中心已增援容量
function RoleLogic:getAllianceCenterReinforceCount( _rid )
    local reinforces = self:getRole( _rid, Enum.Role.reinforces )
    local count = 0
    local ArmyLogic = require "ArmyLogic"
    for _, reinforce in pairs(reinforces) do
        count = count + ArmyLogic:getArmySoldierCount( nil, reinforce.reinforceRid, reinforce.armyIndex )
    end

    return count
end

---@see 获取角色城市地图对象索引
function RoleLogic:getRoleCityIndex( _rid )
    return Common.getSceneMgr(Enum.MapLevel.CITY).req.getRoleCityIndex( _rid ) or 0
end

---@see 检查角色资源是否足够
function RoleLogic:checkRoleCurrency( _rid, _currencyType, _checkNum )
    if _currencyType == Enum.CurrencyType.food then
        return self:checkFood( _rid, _checkNum )
    elseif _currencyType == Enum.CurrencyType.wood then
        return self:checkWood( _rid, _checkNum )
    elseif _currencyType == Enum.CurrencyType.stone then
        return self:checkStone( _rid, _checkNum )
    elseif _currencyType == Enum.CurrencyType.gold then
        return self:checkGold( _rid, _checkNum )
    elseif _currencyType == Enum.CurrencyType.denar then
        return self:checkDenar( _rid, _checkNum )
    end
end

---@see 扣除角色资源
function RoleLogic:addRoleCurrency( _rid, _currencyType, _addNum, _noSync, _logType, _logExtraType )
    if _currencyType == Enum.CurrencyType.food then
        return self:addFood( _rid, _addNum, _noSync, _logType, _logExtraType )
    elseif _currencyType == Enum.CurrencyType.wood then
        return self:addWood( _rid, _addNum, _noSync, _logType, _logExtraType )
    elseif _currencyType == Enum.CurrencyType.stone then
        return self:addStone( _rid, _addNum, _noSync, _logType, _logExtraType )
    elseif _currencyType == Enum.CurrencyType.gold then
        return self:addGold( _rid, _addNum, _noSync, _logType, _logExtraType )
    elseif _currencyType == Enum.CurrencyType.denar then
        return self:addDenar( _rid, _addNum, _noSync, _logType, _logExtraType )
    end
end

---@see 检查角色等级是否满足功能开启
function RoleLogic:checkSystemOpen( _rid, _systemId )
    local openLv = CFG.s_SystemOpen:Get( _systemId, "openLv" ) or 0

    return self:getRole( _rid, Enum.Role.level ) >= openLv
end

---@see 判断某种类型的推送是否开启
function RoleLogic:checkPushOpen( _rid, _type )
    local s_PushMessageData = CFG.s_PushMessageData:Get(_type)
    local pushSetting = self:getRole( _rid, Enum.Role.pushSetting ) or {}
    if pushSetting[s_PushMessageData.group] and pushSetting[s_PushMessageData.group].open == Enum.PushOpen.OPEN then
        return true
    end
    return false
end

---@see 跨服调用查询角色信息
function RoleLogic:getGameRole( _rid, _fields )
    local gameNode = self:getRoleGameNode( _rid )
    if gameNode then
        return Common.rpcMultiCall( gameNode, "d_role", "Get", _rid, _fields )
    end
end

---@see 根据角色ID获取角色所在游服
function RoleLogic:getRoleGameNode( _rid )
    local gameNodeId = math.floor( _rid / 10000000 )
    return string.format( "game%d", gameNodeId )
end

---@see 登录检测推送信息
function RoleLogic:checkPushSetting( _rid )
    local pushSetting = self:getRole( _rid, Enum.Role.pushSetting )
    if not table.empty(pushSetting) then return end
    -- 初始化推送信息
    local sPushMessageGroup = CFG.s_PushMessageGroup:Get()
    pushSetting = {}
    for id, info in pairs(sPushMessageGroup) do
        pushSetting[id] = { id = id, open = info.pushDefault }
    end
    self:setRole( _rid, Enum.Role.pushSetting, pushSetting )
end

---@see 检查角色是否可以迁城到指定坐标
function RoleLogic:checkRoleMoveCity( _rid, _type, _pos, _isMove )
    local DenseFogLogic = require "DenseFogLogic"
    local GuildTerritoryLogic = require "GuildTerritoryLogic"
    local HolyLandLogic = require "HolyLandLogic"
    local ItemLogic = require "ItemLogic"
    local MapLogic = require "MapLogic"

    -- 坐标点是否在迷雾中
    if DenseFogLogic:checkPosInDenseFog( _rid, _pos ) then
        LOG_ERROR("rid(%d) checkRoleMoveCity, pos(%s) in densefog", _rid, tostring(_pos))
        return nil, ErrorCode.MAP_MOVE_CITY_DENSEFOG
    end

    -- 新手迁城和领土迁城不判断沿途关卡, 定点迁城要判断沿途关卡是否是联盟的
    local roleInfo = self:getRole( _rid, { Enum.Role.guildId, Enum.Role.pos } )
    if _type == Enum.MapCityMoveType.FIX_POS and not MSM.CheckPointAStarMgr[_rid].req.findPath( _rid, roleInfo.pos, _pos ) then
        LOG_ERROR("rid(%d) checkRoleMoveCity, can't arrive pos(%s)", _rid, tostring(_pos))
        return nil, ErrorCode.MAP_MOVE_CITY_CANT_ARRIVE
    end

    -- 检测目标位置城堡的独占区域内是否有掩码区域或不可建造区域
    local cityRadiusCollide = CFG.s_Config:Get("cityRadiusCollide") - 1.5
    local cityIndex = self:getRoleCityIndex( _rid )
    if not MapLogic:checkPosIdle( _pos, cityRadiusCollide, false, cityIndex ) then
        LOG_ERROR("rid(%d) checkPosIdle, pos(%s) not idle", _rid, tostring(_pos))
        return nil, ErrorCode.MAP_MOVE_CITY_BUILD_INVALID
    end

    -- 该领地是否为其他联盟的领土
    local guildId = roleInfo.guildId or 0
    local territoryId = GuildTerritoryLogic:getPosTerritoryId( _pos )
    local territoryGuildId = SM.TerritoryMgr.req.getTerritoryGuildId( territoryId ) or 0

    -- 检测目标位置是否在关卡/圣地所属特殊领土内
    if HolyLandLogic:checkInHolyLand( _pos ) then
        LOG_ERROR("rid(%d) checkRoleMoveCity, can't move holyLand territory pos(%s)", _rid, tostring(_pos))
        return nil, ErrorCode.MAP_MOVE_CITY_HOLYLAND_TERRITORY
    end

    local type = _type
    local sConfig = CFG.s_Config:Get()
    if _type == Enum.MapCityMoveType.NOVICE then
        -- 新手迁城
        local MapProvinceLogic = require "MapProvinceLogic"
        local provinceId = MapProvinceLogic:getPosInProvince( _pos )
        if not table.exist( sConfig.provinceOuterRingIds or {}, provinceId ) then
            -- 不是外围区域
            LOG_ERROR("rid(%d) checkRoleMoveCity, can't use novice move city item", _rid)
            return nil, ErrorCode.MAP_MOVE_CITY_NOVICE_ITEM
        end

        -- 道具是否足够
        if sConfig.cityRemoveItem1 > 0 then
            if not ItemLogic:checkItemEnough( _rid, sConfig.cityRemoveItem1, 1 )  then
                LOG_ERROR("rid(%d) checkRoleMoveCity, itemId(%d) not enough", _rid, sConfig.cityRemoveItem1)
                return nil, ErrorCode.MAP_MOVE_CITY_ITEM_NOT_ENOUGH
            end
            if _isMove then
                -- 扣除道具
                ItemLogic:delItemById( _rid, sConfig.cityRemoveItem1, 1, nil, Enum.LogType.MOVE_CITY_COST_CURRENCY )
            end
        end
    elseif type == Enum.MapCityMoveType.TERRITORY then
        -- 领土迁城
        if guildId <= 0 or territoryGuildId ~= guildId then
            -- 是否是角色联盟领土
            LOG_ERROR("rid(%d) checkRoleMoveCity, pos(%s) not role guildId(%d) territory", _rid, tostring(_pos), guildId)
            return nil, ErrorCode.MAP_MOVE_CITY_TERRITORY_SPACE
        end

        -- 角色道具是否足够
        if sConfig.cityRemoveItem3 > 0 then
            if not ItemLogic:checkItemEnough( _rid, sConfig.cityRemoveItem3, 1 )  then
                -- 道具不足，检查货币是否足够
                local shopPrice = CFG.s_Item:Get( sConfig.cityRemoveItem3, "shopPrice" ) or 0
                if shopPrice > 0 then
                    -- 代币不足
                    if not self:checkDenar( _rid, shopPrice ) then
                        LOG_ERROR("rid(%d) checkRoleMoveCity, role denar not enough", _rid)
                        return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
                    end
                    if _isMove then
                        -- 扣除代币
                        self:addDenar( _rid, - shopPrice, nil, Enum.LogType.MOVE_CITY_COST_CURRENCY )
                    end
                end
            else
                if _isMove then
                    -- 扣除道具
                    ItemLogic:delItemById( _rid, sConfig.cityRemoveItem3, 1, nil, Enum.LogType.MOVE_CITY_COST_ITEM )
                end
            end
        end
    elseif type == Enum.MapCityMoveType.FIX_POS then
        -- 定点迁城
        if territoryGuildId > 0 and territoryGuildId ~= guildId then
            LOG_ERROR("rid(%d) checkRoleMoveCity, can't move other guildId(%d) pos(%s) territory", _rid, territoryGuildId, tostring(_pos))
            return nil, ErrorCode.MAP_MOVE_CITY_NO_GUILD_TERRITORY
        end

        -- 角色道具是否足够
        if sConfig.cityRemoveItem2 > 0 then
            if not ItemLogic:checkItemEnough( _rid, sConfig.cityRemoveItem2, 1 )  then
                -- 道具不足，检查货币是否足够
                local shopPrice = CFG.s_Item:Get( sConfig.cityRemoveItem2, "shopPrice" ) or 0
                if shopPrice > 0 then
                    -- 代币不足
                    if not self:checkDenar( _rid, shopPrice ) then
                        LOG_ERROR("rid(%d) checkRoleMoveCity, role denar not enough", _rid)
                        return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
                    end
                    if _isMove then
                        -- 扣除代币
                        self:addDenar( _rid, - shopPrice, nil, Enum.LogType.MOVE_CITY_COST_CURRENCY )
                    end
                end
            else
                if _isMove then
                    -- 扣除道具
                    ItemLogic:delItemById( _rid, sConfig.cityRemoveItem2, 1, nil, Enum.LogType.MOVE_CITY_COST_ITEM )
                end
            end
        end
    end

    return true
end

---@see 获取城市的联盟和名字串
function RoleLogic:getGuildNameAndRoleName( _rid )
    local roleInfo = self:getRole( _rid, { Enum.Role.name, Enum.Role.guildId } )
    local guildName = ""
    if roleInfo.guildId > 0 then
        local GuildLogic = require "GuildLogic"
        guildName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
    end
    return guildName.. "," .. roleInfo.name
end

---@see 神秘商店通知
function RoleLogic:checkStoreNotice( _rid )
    local roleInfo = self:getRole( _rid, { Enum.Role.storeNotice, Enum.Role.mysteryStore } )
    if table.empty(roleInfo.mysteryStore) or not roleInfo.storeNotice then
        return
    end
    Common.syncMsg( _rid, "Role_MysteryStore", { refresh = true } )
    self:setRole( _rid, { [Enum.Role.storeNotice] = false } )
end

---@see 保存角色数据
function RoleLogic:saveRoleData( _rid, _fork )
    if not _fork then
        EntityLoad.saveRole( _rid )
    else
        Timer.runAfter( 100, EntityLoad.saveRole, _rid )
    end
end

---@see 检查新手活动活跃度是否足够
function RoleLogic:checkActivityActivePoint( _rid, _checkActivityActivePoint )
    assert(_rid and _checkActivityActivePoint)
    local activityActivePoint = self:getRole( _rid, Enum.Role.activityActivePoint )
    return activityActivePoint >= _checkActivityActivePoint
end

---@see 增加新手活动活跃度
function RoleLogic:addActivityActivePoint( _rid, _addActivityActivePoint, _noSync, _logType, _logExtraType )
    if _addActivityActivePoint == 0 then return end
    local _, activityActivePoint, oldActivityActivePoint = self:lockSetRole( _rid, Enum.Role.activityActivePoint, _addActivityActivePoint )
    if not _noSync then
        -- 同步到客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.activityActivePoint] = activityActivePoint }, true )
    end
    local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
    -- 记录日志
    LogLogic:currencyChange( { rid = _rid, logType = _logType, logType2 = _logExtraType,
            currencyId = Enum.CurrencyType.activityActivePoint, changeNum = _addActivityActivePoint,
            oldNum = oldActivityActivePoint, newNum = activityActivePoint, iggid = iggid } )
    return activityActivePoint, oldActivityActivePoint
end

---@see 修复异常数据
function RoleLogic:fixEquip( _rid )
    local ItemLogic = require "ItemLogic"
    local itemInfos = ItemLogic:getItem( _rid )
    for itemIndex, itemInfo in pairs(itemInfos) do
        local sitemInfo = CFG.s_Item:Get( itemInfo.itemId )
        if sitemInfo.subType == Enum.ItemSubType.ARMS or sitemInfo.subType == Enum.ItemSubType.HELMET or sitemInfo.subType == Enum.ItemSubType.BREASTPLATE
        or sitemInfo.subType == Enum.ItemSubType.GLOVES or sitemInfo.subType == Enum.ItemSubType.PANTS or sitemInfo.subType == Enum.ItemSubType.ACCESSORIES
        or sitemInfo.subType == Enum.ItemSubType.SHOES then
            if itemInfo.overlay > 1 then
                if itemInfo.heroId > 0 then
                    local equips = {}
                    equips[1] = { subType = Enum.ItemSubType.HELMET, attr = Enum.Hero.head }
                    equips[2] = { subType = Enum.ItemSubType.BREASTPLATE, attr = Enum.Hero.breastPlate }
                    equips[3] = { subType = Enum.ItemSubType.ARMS, attr = Enum.Hero.weapon }
                    equips[4] = { subType = Enum.ItemSubType.GLOVES, attr = Enum.Hero.gloves }
                    equips[5] = { subType = Enum.ItemSubType.PANTS, attr = Enum.Hero.pants }
                    equips[6] = { subType = Enum.ItemSubType.ACCESSORIES, attr = Enum.Hero.accessories1 }
                    equips[7] = { subType = Enum.ItemSubType.ACCESSORIES, attr = Enum.Hero.accessories2 }
                    equips[8] = { subType = Enum.ItemSubType.SHOES, attr = Enum.Hero.shoes }
                    local HeroLogic = require "HeroLogic"
                    local heroInfo = HeroLogic:getHero( _rid, itemInfo.heroId )

                    for _, equipInfo in pairs(equips) do
                        if heroInfo[equipInfo.attr] > 0 and heroInfo[equipInfo.attr] == itemIndex then
                            heroInfo[equipInfo.attr] = 0
                            HeroLogic:setHero( _rid, itemInfo.heroId, heroInfo )
                        end
                    end
                    itemInfo.heroId = 0
                    ItemLogic:setItem( _rid, itemIndex, itemInfo )
                end
                MSM.d_item[_rid].req.Set( _rid, itemIndex, Enum.Item.overlay, 1 )
                ItemLogic:addItem( { rid = _rid, itemId = itemInfo.itemId, itemNum = itemInfo.overlay - 1, noSync = true } )
            end
        end
    end
end

---@see 更新变化属性.主要用于角色高级属性变化更新
function RoleLogic:updateRoleChangeInfo( _rid, _oldRoleInfo, _newRoleInfo )
    local noCheckAttrs = {
        [Enum.Role.food] = true,
        [Enum.Role.wood] = true,
        [Enum.Role.stone] = true,
        [Enum.Role.gold] = true,
        [Enum.Role.denar] = true,
        [Enum.Role.actionForce] = true,
        [Enum.Role.activePoint] = true,
    }

    local roleChangeInfo = {}
    for name, value in pairs( _newRoleInfo ) do
        if not noCheckAttrs[name] and not Common.isTable( value ) and value ~= ( _oldRoleInfo[name] or 0 ) then
            roleChangeInfo[name] = value
        end
    end

    self:setRole( _rid, roleChangeInfo )
end

return RoleLogic