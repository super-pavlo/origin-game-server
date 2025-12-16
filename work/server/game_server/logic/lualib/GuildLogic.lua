--[[
* @file : GuildLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Tue Apr 07 2020 17:34:46 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟相关逻辑实现
* Copyright(C) 2017 IGG, All rights reserved
]]

local GuildDef = require "GuildDef"
local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local EmailLogic = require "EmailLogic"
local RoleChatLogic = require "RoleChatLogic"
local RoleCacle = require "RoleCacle"
local LogLogic = require "LogLogic"
local Timer = require "Timer"

local GuildLogic = {}

---@see 获取联盟指定数据
function GuildLogic:getGuild( _guildId, _fields )
    return SM.c_guild.req.Get( _guildId, _fields )
end

---@see 更新联盟指定数据
function GuildLogic:setGuild( _guildId, _fields, _data )
    return SM.c_guild.req.Set( _guildId, _fields, _data )
end

---@see 锁定更新联盟数据
function GuildLogic:lockSetGuild( _guildId, _fields, _data )
    return SM.c_guild.req.LockSet( _guildId, _fields, _data )
end

---@see 检查联盟是否存在
function GuildLogic:checkGuild( _guildId )
    local guildInfo = self:getGuild( _guildId, { Enum.Guild.leaderRid, Enum.Guild.disbandFlag } ) or {}
    return guildInfo.leaderRid and guildInfo.leaderRid > 0 and not guildInfo.disbandFlag
end

---@see 检查联盟名称是否被占用
function GuildLogic:checkGuildNameRepeat( _name )
    return SM.GuildNameProxy.req.checkGuildNameRepeat( _name )
end

---@see 检查联盟简称是否被占用
function GuildLogic:checkGuildAbbreviationNameRepeat( _abbreviationName )
    return SM.GuildNameProxy.req.checkGuildAbbNameRepeat( _abbreviationName )
end

---@see 创建联盟
function GuildLogic:createGuild( _rid, _name, _abbreviationName, _notice, _needExamine, _languageId, _signs )
    -- 占用联盟名称简称
    local ret = SM.GuildNameProxy.req.addGuildNameAndAbbName( _name, _abbreviationName )
    if ret ~= Enum.GuildNameRepeat.NO_REPEAT then
        local error
        if ret == Enum.GuildNameRepeat.NAME then
            -- 名称重复
            LOG_ERROR("rid(%d) createGuild, name(%s) repeat", _rid, _name)
            error = ErrorCode.GUILD_NAME_REPEAT
        elseif ret == Enum.GuildNameRepeat.ABB_NAME then
            -- 简称重复
            LOG_ERROR("rid(%d) createGuild, abbreviationName(%s) repeat", _rid, _abbreviationName)
            error = ErrorCode.GUILD_ABBNAME_REPEAT
        end

        return false, error
    end
    -- 联盟信息
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.iggid, Enum.Role.name } )
    local sConfig = CFG.s_Config:Get()
    local guildInfo = GuildDef:getDefaultGuildAttr()
    guildInfo.guildId = SM.c_guild.req.NewId()
    guildInfo.name = _name
    guildInfo.abbreviationName = _abbreviationName
    guildInfo.notice = _notice
    guildInfo.needExamine = _needExamine
    guildInfo.languageId = _languageId
    guildInfo.signs = _signs
    guildInfo.leaderRid = _rid
    guildInfo.createTime = os.time()
    guildInfo.memberLimit = CFG.s_Config:Get( "allianceInitialNum" )
    guildInfo.gameNode = Common.getSelfNodeName()
    guildInfo.territoryLimit = CFG.s_AllianceBuildingType:Get( Enum.GuildBuildType.FLAG, "countDefault" )
    guildInfo.createIggId = roleInfo.iggid
    -- 增加默认初始货币值
    guildInfo.currencies = {}
    guildInfo.currencies[Enum.CurrencyType.leaguePoints] = {
        type = Enum.CurrencyType.leaguePoints, num = 0, limit = 0, produce = 0, lastProduceTime = 0
    }
    guildInfo.currencies[Enum.CurrencyType.allianceFood] = {
        type = Enum.CurrencyType.allianceFood, num = 0, limit = sConfig.allianceFoodLimit, produce = 0, lastProduceTime = 0
    }
    guildInfo.currencies[Enum.CurrencyType.allianceWood] = {
        type = Enum.CurrencyType.allianceWood, num = 0, limit = sConfig.allianceWoodLimit, produce = 0, lastProduceTime = 0
    }
    guildInfo.currencies[Enum.CurrencyType.allianceStone] = {
        type = Enum.CurrencyType.allianceStone, num = 0, limit = sConfig.allianceStoneLimit, produce = 0, lastProduceTime = 0
    }
    guildInfo.currencies[Enum.CurrencyType.allianceGold] = {
        type = Enum.CurrencyType.allianceGold, num = 0, limit = sConfig.allianceGoldLimit, produce = 0, lastProduceTime = 0
    }

    -- 联盟信息插入数据库
    ret = SM.c_guild.req.Add( guildInfo.guildId, guildInfo )
    if not ret then
        -- 联盟信息入库失败
        LOG_ERROR("rid(%d) createGuild, insert guildInfo(%s) failed", _rid, tostring(guildInfo))
        SM.GuildNameProxy.post.delGuildNameAndAbbName( _name, _abbreviationName )
        return false
    end
    -- 盟主加入联盟成员中
    local joinRet, power = MSM.RoleJoinGuildMgr[_rid].req.roleJoinGuild( _rid, guildInfo.guildId, Enum.GuildJob.LEADER )
    if not joinRet then
        LOG_ERROR("rid(%d) createGuild, guild master enter guild failed", _rid)
        SM.c_guild.req.Delete( guildInfo.guildId )
        -- 删除guildNameCenter的名称简称
        SM.GuildNameProxy.post.delGuildNameAndAbbName( _name, _abbreviationName )
        -- 删除guildNameCenter redis的名称简称
        SM.GuildNameProxy.post.delCenterGuildName( guildInfo.guildId, _name, _abbreviationName )
        return false, power
    end

    local allianceEstablishCost = CFG.s_Config:Get( "allianceEstablishCost" )
    if allianceEstablishCost and allianceEstablishCost > 0 then
        -- 扣除宝石
        RoleLogic:addDenar( _rid, - allianceEstablishCost, nil, Enum.LogType.CREATE_GUILD_COST_DENAR )
    end
    -- 联盟频道创建
    RoleChatLogic:newGuildChannel( guildInfo.guildId )
    -- 增加联盟修改标识
    MSM.GuildIndexMgr[guildInfo.guildId].post.addGuildIndex( guildInfo.guildId )
    -- 添加到联盟推荐服务
    SM.GuildRecommendMgr.post.addGuildId( guildInfo.guildId, _needExamine, _languageId, power )
    -- 创建联盟成功更新联盟名称简称到center服
    SM.GuildNameProxy.post.updateCenterGuildName( Common.getSelfNodeName(), guildInfo.guildId, _name, _abbreviationName )
    local RankLogic = require "RankLogic"

    RankLogic:update( guildInfo.guildId, Enum.RankType.ALLIANCE_POWER, power )
    RankLogic:update( guildInfo.guildId, Enum.RankType.ALLIANCE_FLAG, 0 )
    -- 增加联盟属性计算
    MSM.GuildAttrMgr[guildInfo.guildId].req.addGuild( guildInfo.guildId )
    -- 盟主退出隐藏城市检查
    MSM.CityHideMgr[_rid].req.deleteCity( _rid )
    -- 发送跑马灯
    SM.MarqueeMgr.post.sendCreateGuildMarquee( roleInfo.name, _abbreviationName )
    return guildInfo.guildId
end

---@see 加入联盟
function GuildLogic:joinGuild( _guildId, _memberRid, _guildJob )
    -- 加入联盟默认R1等级
    _guildJob = _guildJob or Enum.GuildJob.R1
    -- 联盟人数上限判断
    local guildInfo = self:getGuild( _guildId, {
        Enum.Guild.members, Enum.Guild.leaderRid, Enum.Guild.abbreviationName, Enum.Guild.memberLimit,
        Enum.Guild.name, Enum.Guild.resourcePoints, Enum.Guild.welcomeEmailFlag, Enum.Guild.welcomeEmail,
        Enum.Guild.messageBoardRedDotList, Enum.Guild.needExamine, Enum.Guild.languageId,
    } )
    if table.size( guildInfo.members ) >= guildInfo.memberLimit then
        LOG_ERROR("rid(%d) joinGuild, guildId(%d) member(%d) full", _memberRid, _guildId, table.size( guildInfo.members ))
        return false, ErrorCode.GUILD_MEMBER_FULL
    end

    local oldMemberInfo = RoleLogic:getRole( _memberRid, {
        Enum.Role.lastGuildId, Enum.Role.combatPower, Enum.Role.applyGuildIds, Enum.Role.gameId, Enum.Role.pos, Enum.Role.cityId
    } )

    local nowTime = os.time()
    local resourcePoints = guildInfo.resourcePoints or {}
    local sBuildingType = CFG.s_AllianceBuildingType:Get()
    local resourceTime = CFG.s_Config:Get( "allianceResourcePersonTime" )
    -- 初始化角色可领取的联盟领土收益
    local roleTerritoryGains = {
        [Enum.CurrencyType.food] = {
            type = Enum.CurrencyType.food,
            num = 0,
            territoryTime = nowTime,
            limit = sBuildingType[Enum.GuildBuildType.FOOD].holdPersonSpeed *
                ( resourcePoints[Enum.GuildBuildType.FOOD] and resourcePoints[Enum.GuildBuildType.FOOD].num or 0 ) * resourceTime
        },
        [Enum.CurrencyType.wood] = {
            type = Enum.CurrencyType.wood,
            num = 0,
            territoryTime = nowTime,
            limit = sBuildingType[Enum.GuildBuildType.WOOD].holdPersonSpeed *
                ( resourcePoints[Enum.GuildBuildType.WOOD] and resourcePoints[Enum.GuildBuildType.WOOD].num or 0 ) * resourceTime
        },
        [Enum.CurrencyType.stone] = {
            type = Enum.CurrencyType.stone,
            num = 0,
            territoryTime = nowTime,
            limit = sBuildingType[Enum.GuildBuildType.STONE].holdPersonSpeed *
                ( resourcePoints[Enum.GuildBuildType.STONE] and resourcePoints[Enum.GuildBuildType.STONE].num or 0 ) * resourceTime
        },
        [Enum.CurrencyType.gold] = {
            type = Enum.CurrencyType.gold,
            num = 0,
            territoryTime = nowTime,
            limit = sBuildingType[Enum.GuildBuildType.GOLD].holdPersonSpeed *
                ( resourcePoints[Enum.GuildBuildType.GOLD] and resourcePoints[Enum.GuildBuildType.GOLD].num or 0 ) * resourceTime
        }
    }

    -- 加入联盟开启迷雾
    MSM.GuildMgr[_guildId].post.openDenseFogOnJoinGuild( _guildId, _memberRid )

    -- 联盟信息中增加角色信息
    local guildChangeInfo = {}
    guildChangeInfo.members = guildInfo.members
    guildChangeInfo.members[_memberRid] = {
        rid = _memberRid, combatPower = oldMemberInfo.combatPower, guildJob = _guildJob,
        roleTerritoryGains = roleTerritoryGains, lastTakeGainTime = nowTime,
    }
    -- 联盟战力计算
    local guildPower = 0
    for _, member in pairs( guildChangeInfo.members ) do
        guildPower = guildPower + member.combatPower
    end
    guildChangeInfo.power = guildPower
    guildChangeInfo.messageBoardRedDotList = guildInfo.messageBoardRedDotList or {}
    table.insert( guildChangeInfo.messageBoardRedDotList, _memberRid )
    -- 更新联盟信息
    self:setGuild( _guildId, guildChangeInfo )
    -- 更新联盟标识
    MSM.GuildIndexMgr[_guildId].post.addGuildIndex( _guildId )
    -- 更新角色职位和联盟ID
    RoleLogic:setRole( _memberRid, { [Enum.Role.guildId] = _guildId, [Enum.Role.joinGuildTime] = nowTime, [Enum.Role.lastGuildDonateTime] = nowTime } )
    -- 通知角色加入联盟
    RoleSync:syncSelf( _memberRid, { [Enum.Role.guildId] = _guildId, [Enum.Role.joinGuildTime] = nowTime, [Enum.Role.lastGuildDonateTime] = nowTime }, true )

    -- 加入联盟频道
    RoleChatLogic:memberJoinGuildChannel( _guildId, _memberRid, oldMemberInfo.gameId )
    -- 推送角色信息到聊天服务器
    RoleChatLogic:syncRoleInfoToChatServer( _memberRid )
    -- 首次加入成功，给予奖励
    if not oldMemberInfo.lastGuildId or oldMemberInfo.lastGuildId <= 0 then
        local allianceFirstAward = CFG.s_Config:Get( "allianceFirstAward" )
        if allianceFirstAward and allianceFirstAward > 0 then
            RoleLogic:addDenar( _memberRid, allianceFirstAward, nil, Enum.LogType.JOIN_GUILD_GAIN_DENAR )
        end
    end

    local allRids = self:getAllOnlineMember( _guildId )
    if _guildJob ~= Enum.GuildJob.LEADER then
        -- 发送通知
        self:guildNotify( allRids, Enum.GuildNotify.MEMBER_JOIN, { RoleLogic:getRole( _memberRid, { Enum.Role.name, Enum.Role.rid } ) } )
        -- 通知其他人有新成员加入联盟
        table.removevalue( allRids, _memberRid )
        local member = RoleLogic:getRole( _memberRid, {
            Enum.Role.rid, Enum.Role.headId, Enum.Role.name, Enum.Role.killCount, Enum.Role.headFrameID,
            Enum.Role.online, Enum.Role.isAfk
        } )
        member.combatPower = oldMemberInfo.combatPower
        member.guildJob = _guildJob
        member.cityObjectIndex = RoleLogic:getRoleCityIndex( _memberRid )
        local online = false
        if member.online and not member.isAfk then
            online = true
        end
        member.online = online
        member.isAfk = nil
        self:syncMember( allRids, { [_memberRid] = member } )
        -- 发送欢迎邮件
        if guildInfo.welcomeEmailFlag then
            EmailLogic:sendEmail( _memberRid, 300001, { emailContents = { guildInfo.welcomeEmail } } )
        else
            -- 发送默认欢迎邮件
            EmailLogic:sendEmail( _memberRid, 300000 )
        end
        -- 更新联盟书签创建者名称
        MSM.GuildMgr[_guildId].post.updateGuildMarkerName( _guildId, _memberRid )
    end
    -- 更新aoi联盟简称信息
    self:updateAoiGuildAbbName( _memberRid, guildInfo.abbreviationName, guildInfo.name, _guildId )
    -- 联盟人数是否已满
    if table.size( guildChangeInfo.members ) >= guildInfo.memberLimit then
        SM.GuildRecommendMgr.post.delGuildId( _guildId, guildInfo.languageId )
    else
        SM.GuildRecommendMgr.post.addGuildId( _guildId, guildInfo.needExamine, guildInfo.languageId, guildChangeInfo.power )
    end
    -- 角色入盟，入盟推荐删除角色
    SM.RoleRecommendMgr.post.delRole( _memberRid )
    -- 推送联盟信息
    self:syncGuild( _memberRid, nil, nil, true )
    -- 推送联盟成员信息
    self:pushGuildMembers( _memberRid )
    -- 推送联盟仓库信息
    self:pushGuildDepot( _memberRid )
    -- 推送联盟申请信息
    self:syncApply( _memberRid )
    -- 推送联盟圣地信息
    self:pushHolyLands( _memberRid, _guildId )
    -- 推送联盟求助信息
    self:pushGuildRequestHelps( _memberRid, _guildId )
    -- 推送联盟建筑信息
    local GuildBuildLogic = require "GuildBuildLogic"
    GuildBuildLogic:pushGuildBuilds( _memberRid )
    -- 推送联盟战争信息
    local RallyLogic = require "RallyLogic"
    RallyLogic:pushGuildRallyInfo( _memberRid )
    -- 推送联盟科技信息
    local GuildTechnologyLogic = require "GuildTechnologyLogic"
    GuildTechnologyLogic:pushGuildTechnology( _memberRid, _guildId )
    -- 推送联盟礼物信息
    local GuildGiftLogic = require "GuildGiftLogic"
    GuildGiftLogic:pushGuildGifts( _memberRid )
    -- 推送联盟书签信息
    local MapMarkerLogic = require "MapMarkerLogic"
    MapMarkerLogic:pushGuildMarkers( _memberRid, _guildId )
    -- 更新成员修改标识
    MSM.GuildIndexMgr[_guildId].post.addMemberIndex( _guildId, _memberRid, 1 )
    -- 角色在联盟领地采集速度变化
    local ResourceLogic = require "ResourceLogic"
    ResourceLogic:roleArmyCollectSpeedChange( _memberRid )
    -- 清空其他的联盟申请记录
    for _, applyGuildId in pairs( oldMemberInfo.applyGuildIds or {} ) do
        if applyGuildId ~= _guildId then
            self:deleteApply( applyGuildId, _memberRid )
        end
    end
    RoleLogic:setRole( _memberRid, { [Enum.Role.applyGuildIds] = {} } )
    -- 角色加入联盟角色属性更新
    self:updateRoleAttrChange( _memberRid )
    -- 纪念碑处理
    MSM.MonumentRoleMgr[0].post.setSchedule( _memberRid,
            { type = Enum.MonumentType.SERVER_ALLICNCE_MEMBER_COUNT, guildId = _guildId, count = table.size( guildChangeInfo.members ) } )
    -- 判断自己城市是否正在被同盟攻击
    local cityIndex = RoleLogic:getRoleCityIndex( _memberRid )
    if cityIndex then
        -- 角色被集结信息通知到联盟战争界面
        RallyLogic:checkRoleRallyedOnJoinGuild( _memberRid, _guildId )
        -- 判断是否被同联盟的攻击
        MSM.SceneCityMgr[cityIndex].post.checkSameGuildAttacker( cityIndex )
        -- 判断是否被同联盟的集结
        MSM.SceneCityMgr[cityIndex].post.checkSameGuildRally( cityIndex )
    end
    -- 判断自己的部队是否正在攻击同盟
    local ArmyLogic = require "ArmyLogic"
    ArmyLogic:checkArmyAttackGuildMember( _memberRid )
    -- 更新联盟个人战力排行榜
    local RankLogic = require "RankLogic"
    RankLogic:update( _memberRid, Enum.RankType.ALLIACEN_ROLE_POWER, oldMemberInfo.combatPower, _guildId )
    -- 更新联盟个人击杀排行榜
    RankLogic:update( _memberRid, Enum.RankType.ALLIACEN_ROLE_KILL, nil, _guildId )
    local killCount = RoleLogic:getRole( _memberRid, Enum.Role.killCount )
    local score = 0
    for _, killInfo in pairs( killCount or {} ) do
        score = score + killInfo.count
    end
    RankLogic:update( _guildId, Enum.RankType.ALLIANCE_KILL, score )
    -- 更新联盟个人建造排行榜
    self:updateGuildRoleRank( _guildId, _memberRid, Enum.RankType.ALLIACEN_ROLE_BUILD, 0 )
    -- 更新联盟个人捐献排行榜
    self:updateGuildRoleRank( _guildId, _memberRid, Enum.RankType.ALLIACEN_ROLE_DONATE, 0 )
    -- 更新联盟个人帮助排行榜
    self:updateGuildRoleRank( _guildId, _memberRid, Enum.RankType.ALLIACEN_ROLE_HELP, 0 )
    -- 更新联盟个人资源援助排行榜
    self:updateGuildRoleRank( _guildId, _memberRid, Enum.RankType.ALLIACEN_ROLE_RES_HELP, 0 )
    -- 更新加入联盟任务完成信息
    local TaskLogic = require "TaskLogic"
    TaskLogic:addTaskStatisticsSum( _memberRid, Enum.TaskType.JOIN_GUILD, Enum.TaskArgDefault, 1 )
    -- 更新活动信息
    MSM.ActivityRoleMgr[_memberRid].req.setActivitySchedule( _memberRid, Enum.ActivityActionType.JOIN_ALLIANCE, 1 )
    -- 通知其他角色该角色坐标信息
    if oldMemberInfo.cityId > 0 then
        table.removevalue( allRids, _memberRid )
        self:syncGuildMemberPos( allRids, { [_memberRid] = { rid = _memberRid, pos = oldMemberInfo.pos } } )
    end
    -- 更新数据库
    RoleLogic:saveRoleData( _memberRid, true )

    return true, guildChangeInfo.power
end

---@see 角色加入退出联盟或联盟属性变化更新角色属性
function GuildLogic:updateRoleAttrChange( _memberRid, _oldGuildAttr, _newGuildAttr )
    -- 角色在线
    local roleInfo = RoleLogic:getRole( _memberRid )
    if not roleInfo then
        LOG_ERROR("updateRoleAttrChange membereRid(%s) error", tostring(_memberRid))
        return
    end
    local oldRoleInfo = table.copy( roleInfo, true )
    RoleCacle:cacleGuildAttr( roleInfo, _oldGuildAttr, _newGuildAttr )
    -- 更新变化属性
    RoleLogic:updateRoleChangeInfo( _memberRid, oldRoleInfo, roleInfo )

    -- 检查角色相关属性信息是否变化
    RoleCacle:checkRoleAttrChange( _memberRid, oldRoleInfo, roleInfo )
end

---@see 角色加入或退出联盟或联盟简称修改.更新aoi联盟简称名称信息
function GuildLogic:updateAoiGuildAbbName( _rid, _guildAbbName, _guildName, _guildId )
    local objectIndex
    -- 角色部队增加联盟简称
    local ArmyLogic = require "ArmyLogic"
    local ArmyWalkLogic = require "ArmyWalkLogic"
    local armys = ArmyLogic:getArmy( _rid ) or {}
    for armyIndex, armyInfo in pairs( armys ) do
        local targetObjectIndex = armyInfo.targetArg and armyInfo.targetArg.targetObjectIndex
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
            -- 采集中, 资源点中增加联盟简称
            MSM.SceneResourceMgr[targetObjectIndex].post.updateResourceInfo( targetObjectIndex, { guildAbbName = _guildAbbName, guildId = _guildId } )
        elseif not ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) then
            -- 非驻守状态的部队
            objectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, armyIndex )
            if objectIndex then
                -- 加入了集结的部队可能不会在地图上
                MSM.SceneArmyMgr[objectIndex].post.syncGuildAbbName( objectIndex, _guildAbbName, _guildId )
                -- 部队在行军(非空地行军)
                if targetObjectIndex and targetObjectIndex > 0 and ArmyLogic:checkArmyWalkStatus( armyInfo.status )
                and not ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.SPACE_MARCH ) then
                    -- 修改向目标行军缩略线联盟ID
                    ArmyWalkLogic:updateArmyWalkObjectGuildId( objectIndex, targetObjectIndex, _guildId )
                end
            end
        end
    end
    -- 角色城市增加联盟信息
    objectIndex = RoleLogic:getRoleCityIndex( _rid )
    if objectIndex then
        if _guildId then
            MSM.SceneCityMgr[objectIndex].req.syncGuildId( objectIndex, _guildId )
        else
            MSM.SceneCityMgr[objectIndex].post.syncGuildAbbName( objectIndex, _guildAbbName )
            if _guildName then
                MSM.SceneCityMgr[objectIndex].post.syncGuildFullName( objectIndex, _guildName )
            end
        end
    end

    -- 斥候增加联盟简称
    local ScoutsLogic = require "ScoutsLogic"
    local scouts = ScoutsLogic:getScouts( _rid ) or {}
    for _, scoutsInfo in pairs( scouts ) do
        if not ArmyLogic:checkArmyStatus( scoutsInfo.scoutsStatus, Enum.ArmyStatus.STANBY ) then
            -- 斥候不处于待命状态
            MSM.SceneScoutsMgr[scoutsInfo.objectIndex].post.syncGuildAbbName( scoutsInfo.objectIndex, _guildAbbName )
            if scoutsInfo.scoutsTargetIndex and scoutsInfo.scoutsTargetIndex > 0 then
                -- 修改向目标行军缩略线联盟ID
                ArmyWalkLogic:updateArmyWalkObjectGuildId( scoutsInfo.objectIndex, scoutsInfo.scoutsTargetIndex, _guildId )
            end
        end
    end

    -- 运输车修改联盟信息
    local TransportLogic = require "TransportLogic"
    local transport = TransportLogic:getTransport( _rid ) or {}
    for _, transportInfo in pairs( transport ) do
        if _guildId then
            MSM.SceneTransportMgr[transportInfo.objectIndex].req.syncGuildId( transportInfo.objectIndex, _guildId )
        else
            MSM.SceneTransportMgr[transportInfo.objectIndex].post.syncGuildAbbName( transportInfo.objectIndex, _guildAbbName )
        end

        if transportInfo.targetObjectIndex and transportInfo.targetObjectIndex > 0 then
            -- 修改向目标行军缩略线联盟ID
            ArmyWalkLogic:updateArmyWalkObjectGuildId( transportInfo.objectIndex, transportInfo.targetObjectIndex, _guildId )
        end
    end
end

---@see 检查联盟简称是否只包括数字字母和指定特殊字符
function GuildLogic:checkGuildAbbName( _abbreviationName )
    -- 特殊字符包括: ~、!、@、#、^、&、-、=、:、<、>、/
    local charAscii
    local specialChars = { 126, 33, 64, 35, 94, 38, 45, 61, 58, 60, 62, 47 }
    for i = 1, #_abbreviationName do
        charAscii = string.byte( _abbreviationName, i )
        if not ( ( charAscii >= 48 and charAscii <= 57 )
                or ( charAscii >= 65 and charAscii <= 90 )
                or ( charAscii >= 97 and charAscii <= 122 )
                or table.exist( specialChars, charAscii )
            ) then
            -- 数字、大写字母、小写字母、特殊字符判断
            return false
        end
    end

    return true
end

---@see 检查联盟名称是否满足要求
function GuildLogic:checkGuildName( _name )
    local charAscii
    local specialChars = { 44, 37 }
    for i = 1, #_name do
        charAscii = string.byte( _name, i )
        if table.exist( specialChars, charAscii ) then
            return false
        end
    end

    return true
end

---@see 获取联盟的所有属性
function GuildLogic:getGuildInfo( _guildId, _rid )
    local guildInfo = self:getGuild( _guildId )
    if not guildInfo or table.empty( guildInfo ) then return {} end
    local messageBoardRedDot
    if _rid then
        messageBoardRedDot = self:checkMessageBoardRedDot( _guildId, _rid, guildInfo.messageBoardRedDotList )
    end
    return {
        guildId = _guildId,
        name = guildInfo.name,
        abbreviationName = guildInfo.abbreviationName,
        notice = guildInfo.notice,
        needExamine = guildInfo.needExamine,
        languageId = guildInfo.languageId,
        signs = guildInfo.signs,
        leaderRid = guildInfo.leaderRid,
        leaderName = RoleLogic:getRole( guildInfo.leaderRid, Enum.Role.name ),
        giftLevel = guildInfo.giftLevel,
        memberNum = table.size( guildInfo.members ),
        memberLimit = guildInfo.memberLimit,
        power = guildInfo.power,
        territory = guildInfo.territory,
        messageBoardRedDot = messageBoardRedDot,
        territoryBuildFlag = guildInfo.territoryBuildFlag
    }
end

---@see 推送联盟信息
function GuildLogic:syncGuild( _rid, _field, _haskv, _block, _guildId )
    local guildId = _guildId or RoleLogic:getRole( _rid, Enum.Role.guildId )
    if not guildId or guildId == 0 then return end
    local syncInfo
    if not _haskv then
        -- 读取内存中联盟信息
        local guildInfo
        if _field then
            guildInfo = self:getGuild( guildId, _field )
        else
            guildInfo = self:getGuildInfo( guildId )
        end
        guildInfo.guildId = guildId
        syncInfo = guildInfo
    else
        _field.guildId = guildId
        syncInfo = _field
    end

    -- 推送信息
    Common.syncMsg( _rid, "Guild_GuildInfo",  { guildInfo = syncInfo }, _block )
end

---@see 增加入盟申请记录
function GuildLogic:addApply( _guildId, _applyRid )
    -- 申请者信息
    local roleInfo = RoleLogic:getRole( _applyRid, {
        Enum.Role.name, Enum.Role.headId, Enum.Role.combatPower, Enum.Role.killCount, Enum.Role.headFrameID, Enum.Role.applyGuildIds
    } )
    local applyInfo = {
        rid = _applyRid, name = roleInfo.name, headId = roleInfo.headId, combatPower = roleInfo.combatPower,
        killCount = 0, applyTime = os.time(), headFrameID = roleInfo.headFrameID
    }
    for _, countInfo in pairs( roleInfo.killCount or {} ) do
        applyInfo.killCount = applyInfo.killCount + countInfo.count
    end

    -- 联盟已有的申请信息
    local guildInfo = self:getGuild( _guildId, { Enum.Guild.applys, Enum.Guild.members } ) or {}
    local applys = guildInfo.applys or {}
    applys[_applyRid] = applyInfo
    -- 更新入盟申请信息
    self:setGuild( _guildId, { applys = applys } )
    -- 通知联盟成员
    local memberRids = table.indexs( guildInfo.members )
    self:syncApply( memberRids, _applyRid, applyInfo, true )
    -- MSM.GuildIndexMgr[_guildId].req.addApplyIndex( _guildId, _applyRid )
    -- 增加角色申请过的联盟列表
    local applyGuildIds = roleInfo.applyGuildIds or {}
    table.insert( applyGuildIds, _guildId )
    RoleLogic:setRole( _applyRid, { [Enum.Role.applyGuildIds] = applyGuildIds } )
end

---@see 删除入盟申请记录
function GuildLogic:deleteApply( _guildId, _applyRid, _noSync )
    local applys = self:getGuild( _guildId, Enum.Guild.applys ) or {}
    if not applys[_applyRid] then return true end

    applys[_applyRid] = nil
    self:setGuild( _guildId, { applys = applys } )

    if not _noSync then
        -- 通知所有联盟成员，删除入盟申请记录
        local members = self:getGuild( _guildId, Enum.Guild.members )

        -- 推送
        Common.syncMsg( table.indexs( members ), "Guild_GuildApplys", { deleteRid = _applyRid } )
    end

    local applyGuildIds = RoleLogic:getRole( _applyRid, Enum.Role.applyGuildIds ) or {}
    table.removevalue( applyGuildIds, _guildId )
    RoleLogic:setRole( _applyRid, { [Enum.Role.applyGuildIds] = applyGuildIds } )

    return true
end

---@see 入盟申请信息通知
function GuildLogic:syncApply( _rid, _applyRid, _field, _haskv )
    local guildApplys = {}

    if _haskv then
        if _applyRid then
            guildApplys[_applyRid] = _field
            guildApplys[_applyRid].rid = _applyRid
        else
            guildApplys = _field
        end
    else
        local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
        if not guildId or guildId == 0 then
            return
        end
        guildApplys = self:getGuild( guildId, Enum.Guild.applys )
    end

    if not guildApplys or table.empty(guildApplys) then return end

    -- 推送
    Common.syncMsg( _rid, "Guild_GuildApplys", { guildApplys = guildApplys } )
end

---@see 登录推送联盟信息
function GuildLogic:pushGuild( _rid )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    if not guildId or guildId == 0 then return end

    local guildInfo = self:getGuildInfo( guildId, _rid )

    -- 推送信息
    Common.syncMsg( _rid, "Guild_GuildInfo",  { guildInfo = guildInfo } )
    RoleLogic:updateRoleGuildIndexs( _rid, {
        guildIndex = MSM.GuildIndexMgr[guildId].req.getGuildIndex( guildId ),
        guildNoticeIndex = MSM.GuildIndexMgr[guildId].req.getGuildNoticeIndex( guildId )
    } )
end

---@see 联盟相关通知
function GuildLogic:guildNotify( _toRids, _op, _roleInfos, _numArg, _stringArg )
    Common.syncMsg( _toRids, "Guild_GuildNotify", {
        notifyOperate = _op,
        roleInfos = _roleInfos,
        numArg = _numArg,
        stringArg = _stringArg
    } )
end

---@see 增加联盟邀请
function GuildLogic:addInvite( _guildId, _invitedRid )
    local invites = self:getGuild( _guildId, Enum.Guild.invites ) or {}
    invites[_invitedRid] = { rid = _invitedRid, inviteTime = os.time() }

    self:setGuild( _guildId, { [Enum.Guild.invites] = invites } )
end

---@see 删除联盟邀请
function GuildLogic:delInvite( _guildId, _invitedRid )
    -- 联盟邀请邮件同意、拒绝时删除、删除联盟邀请邮件时删除
    local invites = self:getGuild( _guildId, Enum.Guild.invites ) or {}
    if invites[_invitedRid] then
        invites[_invitedRid] = nil
        self:setGuild( _guildId, { [Enum.Guild.invites] = invites } )
    end
end

---@see 检查联盟是否有指定角色的邀请信息
function GuildLogic:checkGuildInvite( _guildId, _invitedRid )
    local invites = self:getGuild( _guildId, Enum.Guild.invites ) or {}
    return invites[_invitedRid] and true or false
end

---@see 登录或者加入联盟时推送联盟成员信息
function GuildLogic:pushGuildMembers( _rid )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then return end
    -- 先推送盟主和自己的信息
    local roleInfo
    local syncMember = {}
    local memberPos = {}
    local fields = {
        Enum.Role.rid, Enum.Role.headId, Enum.Role.name, Enum.Role.killCount,
        Enum.Role.online, Enum.Role.isAfk, Enum.Role.headFrameID, Enum.Role.pos,
        Enum.Role.cityId
    }
    local members = GuildLogic:getGuild( guildId, Enum.Guild.members ) or {}
    for memberRid, memberInfo in pairs( members ) do
        if memberInfo.guildJob == Enum.GuildJob.LEADER or memberRid == _rid then
            roleInfo = RoleLogic:getRole( memberRid, fields )
            -- 战力不取角色当前最新，按照联盟记录的角色战力推送
            roleInfo.combatPower = memberInfo.combatPower
            roleInfo.guildJob = memberInfo.guildJob
            roleInfo.cityObjectIndex = RoleLogic:getRoleCityIndex( memberRid )
            local online = false
            if roleInfo.online and not roleInfo.isAfk then
                online = true
            end
            roleInfo.online = online
            -- 盟主有击杀数量
            if memberInfo.guildJob ~= Enum.GuildJob.LEADER then
                roleInfo.killCount = nil
            end
            syncMember[memberRid] = roleInfo
            -- 盟主坐标
            if roleInfo.cityId > 0 then
                memberPos[memberRid] = {
                    rid = memberRid,
                    pos = roleInfo.pos,
                }
            end
        end
    end

    -- 推送联盟成员信息
    Common.syncMsg( _rid, "Guild_GuildMemberInfo",  { guildMembers = syncMember } )
    -- 推送联盟成员坐标信息
    Common.syncMsg( _rid, "Guild_GuildMemberPos", { memberPos = memberPos } )

    MSM.GuildMgr[guildId].post.pushGuildMembers( guildId, _rid )
end

---@see 定时刷新联盟战力
function GuildLogic:refreshGuildPower()
    local centerNode = Common.getCenterNode()
    -- 本服所有联盟ID
    local guildIds = Common.rpcCall( centerNode, "GuildProxy", "getGuildIds", Common.getSelfNodeName() ) or {}
    for guildId in pairs( guildIds ) do
        MSM.GuildMgr[guildId].post.refreshGuildPower( guildId )
    end
end

---@see 推送联盟成员信息
function GuildLogic:syncMember( _toRids, _members, _deleteRid, _guildOfficers, _block )
    -- 推送信息
    Common.syncMsg( _toRids, "Guild_GuildMemberInfo",  { guildMembers = _members, deleteRid = _deleteRid, guildOfficers = _guildOfficers }, _block )
end

---@see 获取联盟所有在线成员
function GuildLogic:getAllOnlineMember( _guildId, _members )
    local members = _members or self:getGuild( _guildId, Enum.Guild.members ) or {}

    return SM.OnlineMgr.req.getOnlineRoles( members )
end

---@see 获取联盟不在线成员
function GuildLogic:getAllNotOnlineMember( _guildId, _members )
    local members = _members or self:getGuild( _guildId, Enum.Guild.members ) or {}
    return SM.OnlineMgr.req.getOfflineRoles( members )
end

---@see 获取角色联盟职位
function GuildLogic:getRoleGuildJob( _guildId, _rid )
    _guildId = _guildId or RoleLogic:getRole( _rid, Enum.Role.guildId )
    local members = self:getGuild( _guildId, Enum.Guild.members ) or {}
    if members[_rid] then
        return members[_rid].guildJob
    end
end

---@see 角色是否有指定权限
function GuildLogic:checkRoleJurisdiction( _rid, _jurisdictionType, _guildJob )
    _guildJob = _guildJob or self:getRoleGuildJob( nil, _rid )
    local sJurisdiction = CFG.s_AllianceMemberJurisdiction:Get( _jurisdictionType )
    return sJurisdiction and sJurisdiction[_guildJob] and sJurisdiction[_guildJob] == Enum.GuildMemberJurisdiction.YES
end

---@see 角色退出联盟
function GuildLogic:exitGuild( _guildId, _memberRid )
    local guildInfo = self:getGuild( _guildId, {
        Enum.Guild.members, Enum.Guild.guildOfficers, Enum.Guild.memberLimit,
        Enum.Guild.needExamine, Enum.Guild.languageId, Enum.Guild.messageBoardRedDotList
    } )
    local members = guildInfo.members or {}
    if not members[_memberRid] then return end
    -- 移除成员
    members[_memberRid] = nil

    local power = 0
    local allRids = {}
    for memRid, memberInfo in pairs( members ) do
        table.insert( allRids, memRid )
        power = power + memberInfo.combatPower
    end
    -- 联盟官员信息
    local syncGuildOfficers
    local guildOfficers = guildInfo.guildOfficers or {}
    for officerId, officerInfo in pairs( guildOfficers ) do
        if officerInfo.rid == _memberRid then
            -- 移除角色的官员增加属性
            self:cacleRoleOfficerAttr( _memberRid, officerId )
            officerInfo.rid = 0
            syncGuildOfficers = {}
            syncGuildOfficers[officerId] = officerInfo
            break
        end
    end
    local messageBoardRedDotList = guildInfo.messageBoardRedDotList or {}
    table.removevalue( messageBoardRedDotList, _memberRid )
    -- 更新联盟成员信息和当前战力
    self:setGuild( _guildId, {
        [Enum.Guild.members] = members,
        [Enum.Guild.power] = power,
        [Enum.Guild.guildOfficers] = guildOfficers,
        [Enum.Guild.messageBoardRedDotList] = messageBoardRedDotList,
    } )
    local roleChangeInfo = {
        [Enum.Role.guildId] = 0,
        [Enum.Role.lastGuildId] = _guildId,
        [Enum.Role.guildIndexs] = {},
    }

    local memberInfo = RoleLogic:getRole( _memberRid, {
        Enum.Role.technologyQueue, Enum.Role.treatmentQueue, Enum.Role.focusBuildObject, Enum.Role.name
    } )
    -- 重置角色建筑队列联盟求助索引
    MSM.RoleBuildQueueMgr[_memberRid].post.cleanBuildRequestIndexsOnExitGuild( _memberRid )
    -- 重置角色建筑队列联盟求助索引
    if memberInfo.technologyQueue then
        roleChangeInfo.technologyQueue = memberInfo.technologyQueue
        roleChangeInfo.technologyQueue.requestHelpIndex = nil
    end
    -- 重置角色建筑队列联盟求助索引
    if memberInfo.treatmentQueue then
        roleChangeInfo.treatmentQueue = memberInfo.treatmentQueue
        roleChangeInfo.treatmentQueue.requestHelpIndex = nil
    end

    -- 更新角色信息中的联盟ID
    RoleLogic:setRole( _memberRid, roleChangeInfo )
    -- 通知客户端
    RoleSync:syncSelf( _memberRid, { [Enum.Role.guildId] = 0 }, true )
    -- 联盟战力变化更新联盟信息修改标识
    MSM.GuildIndexMgr[_guildId].post.addGuildIndex( _guildId )
    -- 角色退盟，入盟推荐增加角色
    SM.RoleRecommendMgr.post.addRole( _memberRid, memberInfo.name )
    -- 联盟人数未满, 添加到联盟推荐服务
    if table.size( members ) < guildInfo.memberLimit then
        SM.GuildRecommendMgr.post.addGuildId( _guildId, guildInfo.needExamine, guildInfo.languageId, power )
    end
    -- 清除该角色的求助信息
    self:deleteRequestHelpsOnExitGuild( _guildId, _memberRid )
    -- 获取联盟在线成员
    local onlineMembers = GuildLogic:getAllOnlineMember( _guildId )
    -- 通知客户端移除成员
    self:syncMember( onlineMembers, nil, _memberRid, syncGuildOfficers )
    -- 通知客户端移除联盟成员坐标信息
    self:syncGuildMemberPos( onlineMembers, nil, _memberRid )
    -- aoi更新联盟简称信息
    self:updateAoiGuildAbbName( _memberRid, "", "", 0 )
    -- 退出联盟频道
    RoleChatLogic:memberLeaveGuildChannel( _guildId, _memberRid )
    -- 角色退出联盟，更新聊天信息
    RoleChatLogic:syncRoleInfoToChatServer( _memberRid )
    -- 在联盟建筑和盟友建筑中的部队自动召回
    local ArmyLogic = require "ArmyLogic"
    ArmyLogic:checkArmyOnExitGuild( _memberRid )

    -- 更新角色属性
    local guildAttr = MSM.GuildAttrMgr[_guildId].req.getGuildAttr( _guildId )
    self:updateRoleAttrChange( _memberRid, guildAttr )

    -- 纪念碑处理
    MSM.MonumentRoleMgr[0].post.setSchedule( _memberRid,
            { type = Enum.MonumentType.SERVER_ALLICNCE_MEMBER_COUNT, guildId = _guildId, count = table.size( members ) })

    local cityIndex = RoleLogic:getRoleCityIndex( _memberRid )
    if cityIndex then
        -- 被集结切换
        SM.RallyTargetMgr.req.switchTargetGuild( cityIndex, _guildId, 0 )
    end
    -- 通知集结模块,角色退出联盟
    MSM.RallyMgr[_guildId].post.exitGuildDispatchRally( _guildId, _memberRid )
    -- 通知增援模块,角色退出联盟
    MSM.CityReinforceMgr[_memberRid].post.roleExitGuildDisbanReinforce( _memberRid )
    -- 删除联盟中该角色的被集结信息
    local RallyLogic = require "RallyLogic"
    RallyLogic:checkRoleRallyedOnExitGuild( _memberRid, _guildId )
    -- 删除联盟个人战力排行
    local RankLogic = require "RankLogic"
    RankLogic:delete( _memberRid, Enum.RankType.ALLIACEN_ROLE_POWER, _guildId )
    -- 删除联盟个人击杀排行
    RankLogic:delete( _memberRid, Enum.RankType.ALLIACEN_ROLE_KILL, _guildId )
    -- 更新联盟击杀排行
    local killCount = RoleLogic:getRole( _memberRid, Enum.Role.killCount )
    local score = 0
    for _, killInfo in pairs( killCount or {} ) do
        score = score + killInfo.count
    end
    RankLogic:update( _guildId, Enum.RankType.ALLIANCE_KILL, -score )
    -- 退出联盟关闭迷雾
    --local DenseFogLogic = require "DenseFogLogic"
    --DenseFogLogic:onRoleExitGuild( _guildId, _memberRid )
    -- 移除角色关心的建筑
    for objectIndex, type in pairs( memberInfo.focusBuildObject or {} ) do
        if type == Enum.RoleBuildFocusType.GUILD_BUILD then
            MSM.SceneGuildBuildMgr[objectIndex].post.deleteFocusRid( objectIndex, _memberRid, true )
        elseif type == Enum.RoleBuildFocusType.HOLY_LAND then
            MSM.SceneHolyLandMgr[objectIndex].post.deleteFocusRid( objectIndex, _memberRid, true )
        end
    end
    RoleLogic:setRole( _memberRid, { [Enum.Role.focusBuildObject] = {} } )
    -- 更新数据库
    RoleLogic:saveRoleData( _memberRid, true )

    return true
end

---@see 解散联盟成员信息处理
function GuildLogic:kickMemberOnDisbandGuild( _memberRid, _roleChangeInfo, _roleSyncInfo, _guildAttr )
    local memberInfo = RoleLogic:getRole( _memberRid, {
        Enum.Role.technologyQueue, Enum.Role.treatmentQueue, Enum.Role.name
    } )
    -- 重置角色建筑队列联盟求助索引
    MSM.RoleBuildQueueMgr[_memberRid].post.cleanBuildRequestIndexsOnExitGuild( _memberRid )

    -- 重置角色建筑队列联盟求助索引
    if memberInfo.technologyQueue then
        _roleChangeInfo.technologyQueue = memberInfo.technologyQueue
        _roleChangeInfo.technologyQueue.requestHelpIndex = nil
    else
        _roleChangeInfo.buildQutechnologyQueueeue = nil
    end
    -- 重置角色建筑队列联盟求助索引
    if memberInfo.treatmentQueue then
        _roleChangeInfo.treatmentQueue = memberInfo.treatmentQueue
        _roleChangeInfo.treatmentQueue.requestHelpIndex = nil
    else
        _roleChangeInfo.treatmentQueue = nil
    end
    -- 更新角色信息
    RoleLogic:setRole( _memberRid, _roleChangeInfo )
    -- 通知客户端
    RoleSync:syncSelf( _memberRid, _roleSyncInfo, true )
    -- 发送邮件
    -- aoi更新联盟简称信息
    self:updateAoiGuildAbbName( _memberRid, "", "", 0 )
    -- 角色退盟，入盟推荐增加角色
    SM.RoleRecommendMgr.post.addRole( _memberRid, memberInfo.name )
    -- 在联盟建筑和盟友建筑中的部队自动召回
    local ArmyLogic = require "ArmyLogic"
    ArmyLogic:checkArmyOnExitGuild( _memberRid )
    -- 角色退出联盟，更新聊天信息
    RoleChatLogic:syncRoleInfoToChatServer( _memberRid )
    -- 更新角色属性
    self:updateRoleAttrChange( _memberRid, _guildAttr )
    -- 发送解散邮件
    EmailLogic:sendEmail( _memberRid, 300009 )
    -- 更新数据库
    RoleLogic:saveRoleData( _memberRid, true )
end

---@see 角色解散联盟
function GuildLogic:disbandGuild( _guildId )
    local guildInfo = self:getGuild( _guildId )
    local roleChangeInfo = {
        [Enum.Role.guildId] = 0,
        [Enum.Role.lastGuildId] = _guildId,
        [Enum.Role.guildIndexs] = {},
    }
    local roleSyncInfo = {
        [Enum.Role.guildId] = 0,
    }
    local members = guildInfo.members or {}
    -- 发送联盟解散通知
    local onlineMembers = self:getAllOnlineMember( _guildId, members )
    local guildAttr = MSM.GuildAttrMgr[_guildId].req.getGuildAttr( _guildId )
    -- 先退出盟主
    self:kickMemberOnDisbandGuild( guildInfo.leaderRid, roleChangeInfo, roleSyncInfo, guildAttr )
    -- 再退出其他在线成员
    for memberRid in pairs( members ) do
        if memberRid ~= guildInfo.leaderRid and table.exist( onlineMembers, memberRid ) then
            self:kickMemberOnDisbandGuild( memberRid, roleChangeInfo, roleSyncInfo, guildAttr )
        end
    end
    -- 退出其他不在线成员
    for memberRid in pairs( members ) do
        if memberRid ~= guildInfo.leaderRid and not table.exist( onlineMembers, memberRid ) then
            self:kickMemberOnDisbandGuild( memberRid, roleChangeInfo, roleSyncInfo, guildAttr )
        end
    end

    -- 移除联盟官员属性
    local guildOfficers = guildInfo.guildOfficers or {}
    for officerId, officerInfo in pairs( guildOfficers ) do
        if officerInfo.rid and officerInfo.rid > 0 then
            -- 移除角色的官员增加属性
            self:cacleRoleOfficerAttr( officerInfo.rid, officerId )
        end
    end

    self:guildNotify( onlineMembers, Enum.GuildNotify.DISBAND )
    local allMembers = self:getGuild( _guildId, Enum.Guild.members ) or {}
    -- 解散关闭迷雾
    --local DenseFogLogic = require "DenseFogLogic"
    --DenseFogLogic:onRoleExitGuild( _guildId, onlineMembers, true )
    -- 通知集结模块,联盟解散
    MSM.RallyMgr[_guildId].req.disbanGuildDispatchRally( _guildId )
    -- 通知增援模块,角色退出联盟
    MSM.CityReinforceMgr[_guildId].post.disGuildDisbanReinforce( allMembers )
    -- 删除联盟信息
    SM.c_guild.req.Delete( _guildId )
    -- 删除guildNameCenter的名称简称
    SM.GuildNameProxy.post.delGuildNameAndAbbName( guildInfo.name, guildInfo.abbreviationName )
    -- 删除guildNameCenter redis的名称简称
    SM.GuildNameProxy.post.delCenterGuildName( _guildId, guildInfo.name, guildInfo.abbreviationName )
    -- 删除联盟推荐中的联盟信息
    SM.GuildRecommendMgr.post.delGuildId( _guildId, guildInfo.languageId )
    -- 移除联盟地块状态寻路地图
    MSM.AStarMgr[_guildId].post.freeSearchMap( _guildId )
    -- 移除联盟属性信息
    MSM.GuildAttrMgr[_guildId].post.delGuild( _guildId )
    -- 解散联盟移除联盟所有建筑
    local GuildBuildLogic = require "GuildBuildLogic"
    GuildBuildLogic:removeAllGuildBuilds( _guildId )
    -- 移除联盟领土属性
    MSM.GuildTerritoryMgr[_guildId].post.cleanGuildTerritory( _guildId )

    -- 删除联盟频道
    RoleChatLogic:delGuildChannel( _guildId )
    -- 移除联盟占有的圣地
    MSM.GuildHolyLandMgr[_guildId].post.deleteHolyLandsOnDisbandGuild( _guildId )

    local RankLogic = require "RankLogic"
    RankLogic:delete( _guildId, Enum.RankType.ALLIANCE_POWER )
    RankLogic:delete( _guildId, Enum.RankType.ALLIANCE_KILL )
    RankLogic:delete( _guildId, Enum.RankType.ALLIANCE_FLAG )

    -- 删除联盟个人战力排行榜
    local key = RankLogic:getKey( Enum.RankType.ALLIACEN_ROLE_POWER )
    MSM.RankMgr[_guildId].post.deleteKey( key, nil, _guildId )
    -- 删除联盟个人击杀排行榜
    key = RankLogic:getKey( Enum.RankType.ALLIACEN_ROLE_KILL )
    MSM.RankMgr[_guildId].post.deleteKey( key, nil, _guildId )
    -- 删除联盟个人捐献排行榜
    key = RankLogic:getKey( Enum.RankType.ALLIACEN_ROLE_DONATE )
    MSM.RankMgr[_guildId].post.deleteKey( key, nil, _guildId )
    -- 删除联盟个人建造排行榜
    key = RankLogic:getKey( Enum.RankType.ALLIACEN_ROLE_BUILD )
    MSM.RankMgr[_guildId].post.deleteKey( key, nil, _guildId )
    -- 删除联盟帮助排行榜
    key = RankLogic:getKey( Enum.RankType.ALLIACEN_ROLE_HELP )
    MSM.RankMgr[_guildId].post.deleteKey( key, nil, _guildId )
    -- 删除联盟资源援助排行榜
    key = RankLogic:getKey( Enum.RankType.ALLIACEN_ROLE_RES_HELP )
    MSM.RankMgr[_guildId].post.deleteKey( key, nil, _guildId )
    -- 删除活动联盟排行版
    key = RankLogic:getKey( Enum.RankType.TRIBE_KING )
    MSM.RankMgr[_guildId].post.deleteRecord( key, _guildId )
    -- 删除联盟资源援助排行榜
    key = RankLogic:getKey( Enum.RankType.FIGHT_HORN_ALLIANCE )
    MSM.RankMgr[_guildId].post.deleteRecord( key,_guildId )
end

---@see 解散联盟入口
function GuildLogic:dispathDisbandGuild( _guildId )
    SM.ServiceBusyCheckMgr.post.addBusyService( Enum.ServiceBusyType.GUILD )
    local ret, err = xpcall( GuildLogic.disbandGuild, debug.traceback, GuildLogic, _guildId )
    if not ret then
        LOG_ERROR("GuildLogic.disbandGuild err:%s", err)
    end
    SM.ServiceBusyCheckMgr.post.subBusyService( Enum.ServiceBusyType.GUILD )
end

---@see 任命官员
function GuildLogic:appointOfficer( _guildId, _memberRid, _officerId )
    -- 更新官员信息
    local guildInfo = self:getGuild( _guildId, { Enum.Guild.guildOfficers, Enum.Guild.members, Enum.Guild.leaderRid } )
    local guildOfficers = guildInfo.guildOfficers or {}
    local oldOfficerId
    local syncOfficers = {}
    for officerId, officerInfo in pairs( guildOfficers ) do
        if officerInfo.rid == _memberRid then
            oldOfficerId = officerId
            officerInfo.rid = 0
            syncOfficers[officerId] = officerInfo
        end
    end
    local oldOfficerMemRid = guildOfficers[_officerId] and guildOfficers[_officerId].rid
    guildOfficers[_officerId] = {
        officerId = _officerId, rid = _memberRid, appointTime = os.time()
    }
    syncOfficers[_officerId] = guildOfficers[_officerId]

    self:setGuild( _guildId, { [Enum.Guild.guildOfficers] = guildOfficers } )
    -- 通知客户端
    local onlineMembers = self:getAllOnlineMember( _guildId, guildInfo.members )
    self:syncMember( onlineMembers, nil, nil, syncOfficers )
    -- 发送任命通知
    local memberInfo = RoleLogic:getRole( _memberRid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } )
    self:guildNotify( onlineMembers, Enum.GuildNotify.APPOINT_OFFICER, { { name = memberInfo.name } }, { _officerId } )
    -- 发送任命邮件
    local leaderName = RoleLogic:getRole( guildInfo.leaderRid, Enum.Role.name )
    local emailOtherInfo = {
        subTitleContents = { memberInfo.name, _officerId },
        emailContents = { memberInfo.name, leaderName, _officerId, _officerId, _officerId, _officerId, _officerId },
        guildEmail = {
            roleRid = _memberRid,
            roleName = memberInfo.name,
            roleHeadId = memberInfo.headId,
            roleHeadFrameId = memberInfo.headFrameID
        }
    }
    MSM.GuildMgr[_guildId].post.sendGuildEmail( _guildId, guildInfo.members, 300006, emailOtherInfo )

    -- 成员之前是否有官员加成属性
    self:cacleRoleOfficerAttr( _memberRid, oldOfficerId, _officerId )

    -- 新官职之前是否有任命给其他人
    if oldOfficerMemRid and oldOfficerMemRid > 0 then
        self:cacleRoleOfficerAttr( oldOfficerMemRid, _officerId )
    end
end

---@see 盟主转让
function GuildLogic:transferGuildLeader( _guildId, _oldLeaderRid, _newLeaderRid, _isSystemTransfer )
    local newLeaderInfo = RoleLogic:getRole( _newLeaderRid, {
        Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.killCount
    } )
    local guildInfo = self:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.guildOfficers } )
    local members = guildInfo.members or {}
    -- 盟主变为R1, 成员变为盟主
    members[_oldLeaderRid].guildJob = Enum.GuildJob.R1
    members[_newLeaderRid].guildJob = Enum.GuildJob.LEADER
    local syncMembers = {}
    syncMembers[_oldLeaderRid] = { rid = _oldLeaderRid, guildJob = Enum.GuildJob.R1 }
    syncMembers[_newLeaderRid] = { rid = _newLeaderRid, guildJob = Enum.GuildJob.LEADER, killCount = newLeaderInfo.killCount }
    -- 官员信息修改
    local syncGuildOfficers, oldOfficerId
    for officerId, officerInfo in pairs( guildInfo.guildOfficers or {} ) do
        if officerInfo.rid == _newLeaderRid then
            officerInfo.rid = 0
            syncGuildOfficers = {}
            syncGuildOfficers[officerId] = officerInfo
            oldOfficerId = officerId
            break
        end
    end
    -- 更新联盟信息
    self:setGuild( _guildId, {
        [Enum.Guild.members] = members,
        [Enum.Guild.leaderRid] = _newLeaderRid,
        [Enum.Guild.guildOfficers] = guildInfo.guildOfficers
    } )
    -- 旧的盟主加入隐藏城市检查
    MSM.CityHideMgr[_oldLeaderRid].post.addCity( _oldLeaderRid )
    -- 新的盟主退出隐藏城市检查
    MSM.CityHideMgr[_newLeaderRid].req.deleteCity( _newLeaderRid )
    -- 更新联盟信息修改标识
    MSM.GuildIndexMgr[_guildId].post.addGuildIndex( _guildId )
    -- 通知客户端
    self:syncMember( self:getAllOnlineMember( _guildId, members ), syncMembers, nil, syncGuildOfficers )
    local oldLeaderName = RoleLogic:getRole( _oldLeaderRid, Enum.Role.name )
    local emailOtherInfo = {
        subTitleContents = { newLeaderInfo.name },
        emailContents = { oldLeaderName, newLeaderInfo.name, newLeaderInfo.name },
        guildEmail = {
            roleRid = _newLeaderRid,
            roleName = newLeaderInfo.name,
            roleHeadId = newLeaderInfo.headId,
            roleHeadFrameId = newLeaderInfo.headFrameID,
        }
    }
    if not _isSystemTransfer then
        -- 发送邮件
        MSM.GuildMgr[_guildId].post.sendGuildEmail( _guildId, members, 300005, emailOtherInfo )
    else
        -- 系统强制转让
        MSM.GuildMgr[_guildId].post.sendGuildEmail( _guildId, members, 300021, emailOtherInfo )
    end

    -- 新盟主之前是否有官员加成属性
    if oldOfficerId then
        self:cacleRoleOfficerAttr( _newLeaderRid, oldOfficerId )
    end
end

---@see 成员升降级
function GuildLogic:modifyMemberLevel( _guildId, _memberRid, _newGuildJob )
    local guildInfo = self:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.guildOfficers } )
    local members = guildInfo.members or {}

    local emailId
    if members[_memberRid].guildJob > _newGuildJob then
        -- 降级邮件
        emailId = 300004
    else
        -- 升级邮件
        emailId = 300003
    end
    -- 更新成员职位和官职
    members[_memberRid].guildJob = _newGuildJob
    -- 官员信息修改
    local syncGuildOfficers, oldOfficerId
    for officerId, officerInfo in pairs( guildInfo.guildOfficers or {} ) do
        if officerInfo.rid == _memberRid then
            officerInfo.rid = 0
            syncGuildOfficers = {}
            syncGuildOfficers[officerId] = officerInfo
            oldOfficerId = officerId
            break
        end
    end
    -- 更新联盟信息
    self:setGuild( _guildId, {
        [Enum.Guild.members] = members,
        [Enum.Guild.guildOfficers] = guildInfo.guildOfficers
    } )
    -- 通知客户端
    self:syncMember( table.indexs( members ), { [_memberRid] = { rid = _memberRid, guildJob = _newGuildJob } }, nil, syncGuildOfficers )
    -- 发送邮件
    local strNewGuildJob = tostring( _newGuildJob )
    EmailLogic:sendEmail( _memberRid, emailId, { subTitleContents = { strNewGuildJob }, emailContents = { strNewGuildJob }, } )

    -- 成员之前是否有官员加成属性
    if oldOfficerId then
        self:cacleRoleOfficerAttr( _memberRid, oldOfficerId )
    end
end

---@see 联盟官职变化更新角色高级属性
function GuildLogic:cacleRoleOfficerAttr( _rid, _oldOfficerId, _newOfficerId )
    local roleInfo = RoleLogic:getRole( _rid )
    local oldRoleInfo = table.copy( roleInfo, true )
    -- 扣除之前官职增加属性
    RoleCacle:cacleGuildOfficerAttr( roleInfo, _oldOfficerId, _newOfficerId )
    -- 更新角色最新属性
    RoleLogic:updateRoleChangeInfo( _rid, oldRoleInfo, roleInfo )

    -- 检查角色相关属性信息是否变化
    RoleCacle:checkRoleAttrChange( _rid, oldRoleInfo, roleInfo )
end

---@see 登录或加入推送联盟仓库信息
function GuildLogic:pushGuildDepot( _rid )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then return end

    local guildInfo = self:getGuild( guildId, { Enum.Guild.currencies, Enum.Guild.consumeRecords } )
    if not guildInfo then
        return
    end
    -- 推送联盟仓库信息
    Common.syncMsg( _rid, "Guild_GuildDepotInfo",  {
        guildDepot = { [Enum.Guild.currencies] = guildInfo.currencies, [Enum.Guild.consumeRecords] = guildInfo.consumeRecords }
    } )

    -- 更新客户端当前的仓库记录修改标识
    RoleLogic:updateRoleGuildIndexs( _rid, { guildDepotRecordIndex = MSM.GuildIndexMgr[guildId].req.getGuildDepotRecordIndex( guildId ) } )
end

---@see 推送联盟仓库信息
function GuildLogic:syncGuildDepot( _toRids, _currencies, _consumeRecords )
    -- 推送联盟仓库信息
    Common.syncMsg( _toRids, "Guild_GuildDepotInfo",  {
        guildDepot = { [Enum.Guild.currencies] = _currencies, [Enum.Guild.consumeRecords] = _consumeRecords }
    } )
end

---@see 检查联盟指定类型货币是否足够
function GuildLogic:checkGuildCurrency( _guildId, _currencyType, _checkNum, _currencies )
    local num = 0
    local currencies = _currencies or self:getGuild( _guildId, Enum.Guild.currencies ) or {}
    if currencies[_currencyType] then
        num = currencies[_currencyType].num
    end
    if not ( currencies[_currencyType].limit and currencies[_currencyType].limit > 0 and num > currencies[_currencyType].limit ) then
        -- 增加联盟资源点产量
        num = num + math.floor( ( currencies[_currencyType].produce or 0 ) / 3600 * ( os.time() - ( currencies[_currencyType].lastProduceTime or 0 ) ) )

        if currencies[_currencyType].limit and currencies[_currencyType].limit > 0
            and currencies[_currencyType].limit < num then
            num = currencies[_currencyType].limit
        end
    end

    return num >= _checkNum
end

---@see 增加联盟货币
function GuildLogic:addGuildCurrency( _guildId, _currencyType, _addNum, _buildType, _noSync )
    local guildInfo = self:getGuild( _guildId, { Enum.Guild.currencies, Enum.Guild.resourcePoints } ) or {}
    local currencies = guildInfo.currencies or {}
    currencies[_currencyType] = currencies[_currencyType] or {}
    local nowTime = os.time()
    local limit = currencies[_currencyType].limit
    if not limit then
        local sConfig = CFG.s_Config:Get()
        if _currencyType == Enum.CurrencyType.allianceFood then
            limit = sConfig.allianceFoodLimit
        elseif _currencyType == Enum.CurrencyType.allianceWood then
            limit = sConfig.allianceWoodLimit
        elseif _currencyType == Enum.CurrencyType.allianceStone then
            limit = sConfig.allianceStoneLimit
        elseif _currencyType == Enum.CurrencyType.allianceGold then
            limit = sConfig.allianceGoldLimit
        end
    end

    local num = currencies[_currencyType].num or 0
    if _addNum > 0 then
        num = num + _addNum
        num = num + math.floor( ( currencies[_currencyType].produce or 0 ) / 3600 * ( nowTime - ( currencies[_currencyType].lastProduceTime or nowTime ) ) )
        if limit and limit > 0 and num > limit then
            num = limit
        end
    else
        num = num + math.floor( ( currencies[_currencyType].produce or 0 ) / 3600 * ( nowTime - ( currencies[_currencyType].lastProduceTime or nowTime ) ) )
        if limit and limit > 0 and num > limit then
            num = limit
        end
        num = num + _addNum
        if num < 0 then
            num = 0
        end
    end

    local produce = currencies[_currencyType].produce or 0
    if _buildType then
        local holdAllianceSpeed = CFG.s_AllianceBuildingType:Get( _buildType, "holdAllianceSpeed" )
        if holdAllianceSpeed and guildInfo.resourcePoints and guildInfo.resourcePoints[_buildType] then
            produce = holdAllianceSpeed * guildInfo.resourcePoints[_buildType].num
        end
    end

    currencies[_currencyType] = {
        type = _currencyType, num = num, produce = produce,
        lastProduceTime = nowTime, limit = limit or 0,
    }
    -- 更新货币信息
    self:setGuild( _guildId, { [Enum.Guild.currencies] = currencies } )

    if not _noSync then
        local allMemberRids = self:getAllOnlineMember( _guildId )
        if #allMemberRids > 0 then
            self:syncGuildDepot( allMemberRids, currencies )
        end
    end

    return currencies
end

---@see 增加消费联盟货币记录信息
function GuildLogic:addConsumeRecord( _guildId, _memberRid, _type, _args, _consumeCurrencies )
    local consumeRecords = self:getGuild( _guildId, Enum.Guild.consumeRecords ) or {}
    local memberInfo = RoleLogic:getRole( _memberRid, { Enum.Role.headId, Enum.Role.name, Enum.Role.headFrameID } )
    table.insert(
        consumeRecords,
        {
            roleHeadId = memberInfo.headId,
            roleName = memberInfo.name,
            consumeType = _type,
            consumeArgs = _args,
            consumeCurrencies = _consumeCurrencies,
            consumeTime = os.time(),
            roleHeadFrameID = memberInfo.headFrameID,
        }
    )
    -- 是否超出上限
    local recordLimit = CFG.s_Config:Get( "allianceConsumeRecordCnt" )
    if recordLimit > 0 and #consumeRecords > recordLimit then
        for _ = 1, #consumeRecords - recordLimit do
            table.remove( consumeRecords, 1 )
        end
    end
    -- 更新联盟信息
    self:setGuild( _guildId, { [Enum.Guild.consumeRecords] = consumeRecords } )
    -- 更新联盟仓库消费记录修改标识
    MSM.GuildIndexMgr[_guildId].post.addGuildDepotRecordIndex( _guildId )
end

---@see 登录或加入联盟推送联盟求助信息
function GuildLogic:pushGuildRequestHelps( _rid, _guildId )
    local guildId = _guildId or RoleLogic:getRole( _rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then return end

    local syncRequestHelps = {}
    local requestHelps = self:getGuild( guildId, Enum.Guild.requestHelps ) or {}
    for index, requestInfo in pairs( requestHelps ) do
        if requestInfo.rid == _rid or ( not requestInfo.helps[_rid] and requestInfo.helpNum < requestInfo.helpLimit ) then
            -- 1. 角色自己的求助要推送
            -- 2. 角色未帮助且帮助未满的求助要推送
            syncRequestHelps[index] = {
                index = index,
                rid = requestInfo.rid,
                type = requestInfo.type,
                args = requestInfo.args,
                helpNum = requestInfo.helpNum,
                helpLimit = requestInfo.helpLimit,
                reduceTime = requestInfo.reduceTime,
            }
        end
    end

    -- 推送联盟仓库信息
    Common.syncMsg( _rid, "Guild_GuildRequestHelps",  { guildRequestHelps = syncRequestHelps } )

    -- 记录角色当前的客户端联盟求助信息最大标识
    -- RoleLogic:updateRoleGuildIndexs( _rid, { guildRequestHelpIndex = MSM.GuildIndexMgr[guildId].req.getRequestHelpGlobalIndex( guildId ) } )
end

---@see 角色退出移除联盟求助信息
function GuildLogic:deleteRequestHelpsOnExitGuild( _guildId, _memberRid )
    local newRequestInfo = {}
    -- local helpIndex
    -- local memberRequestHelpIndex = {}
    local guildInfo = self:getGuild( _guildId, { Enum.Guild.requestHelps } ) or {}
    local requestHelps = guildInfo.requestHelps or {}
    local deleteIndexRids = {}
    -- for index, requestInfo in pairs( requestHelps ) do
    --     if requestInfo.rid == _memberRid then
    --         deleteIndexRids[index] = {}
    --         -- 获取所有角色已请求到此求助信息的角色ID
    --         helpIndex = MSM.GuildIndexMgr[_guildId].req.getRequestHelpIndex( _guildId, index )
    --         if helpIndex and helpIndex > 0 then
    --             for memberRid in pairs( guildInfo.members ) do
    --                 if not memberRequestHelpIndex[memberRid] then
    --                     memberRequestHelpIndex[memberRid] = RoleLogic:getRoleGuildIndexs( memberRid, "guildRequestHelpIndex" )
    --                 end
    --                 -- 该角色请求过此求助信息
    --                 if helpIndex <= memberRequestHelpIndex[memberRid] then
    --                     table.insert( deleteIndexRids[index], memberRid )
    --                 end
    --             end
    --         end
    --     else
    --         newRequestInfo[index] = requestInfo
    --     end
    -- end
    local allOnlineMembers = self:getAllOnlineMember( _guildId )
    for index, requestInfo in pairs( requestHelps ) do
        if requestInfo.rid == _memberRid then
            for _, memberRid in pairs( allOnlineMembers ) do
                if not requestInfo.helps[memberRid] then
                    if not deleteIndexRids[memberRid] then
                        deleteIndexRids[memberRid] = { index }
                    else
                        table.insert( deleteIndexRids[memberRid], index )
                    end
                end
            end
        else
            newRequestInfo[index] = requestInfo
        end
    end

    -- 更新联盟求助信息
    self:setGuild( _guildId, { [Enum.Guild.requestHelps] = newRequestInfo } )
    -- 通知角色删除求助
    for memberRid, deleteIndexs in pairs( deleteIndexRids ) do
        self:syncGuildRequestHelps( memberRid, nil, deleteIndexs )
    end
    -- 通知角色删除此求助信息
    -- for index, toRids in pairs( deleteIndexRids ) do
    --     if not table.empty( toRids ) then
    --         self:syncGuildRequestHelps( toRids, nil, { index } )
    --     end
    -- end

end

---@see 推送联盟求助信息
function GuildLogic:syncGuildRequestHelps( _rid, _guildRequestHelps, _deleteHelpIndexs, _block )
    -- 推送联盟求助信息
    Common.syncMsg( _rid, "Guild_GuildRequestHelps",  { guildRequestHelps = _guildRequestHelps, deleteHelpIndexs = _deleteHelpIndexs }, _block )
end

---@see 获取联盟求助最大索引
function GuildLogic:getRequestHelpMaxIndex( _guildId )
    local requestHelps = self:getGuild( _guildId, Enum.Guild.requestHelps ) or {}
    local maxIndex = 0
    for index in pairs( requestHelps ) do
        if maxIndex < index then
            maxIndex = index
        end
    end

    return maxIndex
end

---@see 角色建筑建造治疗和科技研究完成回调
function GuildLogic:roleQueueFinishCallBack( _guildId, _requestHelpIndex, _isLogin )
    if not _requestHelpIndex or _requestHelpIndex <= 0 then return end

    local allRids = {}
    local guildInfo = self:getGuild( _guildId, { Enum.Guild.requestHelps } )
    if guildInfo.requestHelps[_requestHelpIndex] then
        -- 通知联盟获取过此求助信息的角色删除此求助
        -- local helpIndex = MSM.GuildIndexMgr[_guildId].req.getRequestHelpIndex( _guildId, _requestHelpIndex )
        -- if helpIndex and helpIndex > 0 then
        --     for memberRid in pairs( guildInfo.members ) do
        --         if helpIndex <= RoleLogic:getRoleGuildIndexs( memberRid, "guildRequestHelpIndex" ) then
        --             table.insert( allRids, helpIndex )
        --         end
        --     end
        --     -- 加上通知求助角色自己
        --     if not table.exist( allRids, guildInfo.requestHelps[_requestHelpIndex].rid ) then
        --         table.insert( allRids, guildInfo.requestHelps[_requestHelpIndex].rid )
        --     end
        -- end
        -- 获取所有未帮助过此请求的角色
        local allOnlineMembers = self:getAllOnlineMember( _guildId )
        for _, memberRid in pairs( allOnlineMembers ) do
            if not guildInfo.requestHelps[_requestHelpIndex].helps[memberRid] then
                table.insert( allRids, memberRid )
            end
        end

        if not _isLogin then
            -- 通知求助者自己
            table.insert( allRids, guildInfo.requestHelps[_requestHelpIndex].rid )
        end

        -- 更新联盟求助信息
        guildInfo.requestHelps[_requestHelpIndex] = nil
        self:setGuild( _guildId, { [Enum.Guild.requestHelps] = guildInfo.requestHelps } )

        if #allRids > 0 then
            self:syncGuildRequestHelps( allRids, nil, { _requestHelpIndex } )
        end
    end
end

---@see 帮助联盟成员
function GuildLogic:helpGuildMembers( _guildId, _rid )
    local helpCount = 0
    local requestHelps = self:getGuild( _guildId, Enum.Guild.requestHelps ) or {}
    local allOnlineMembers = self:getAllOnlineMember( _guildId )
    -- local helpIndexs = {}
    local finishIndexs = {}
    local helpNotifys = {}
    local updateHelpRids = {}
    local reduceTime, queueFinish
    local deleteHelpIndexs = {}
    local sConfig = CFG.s_Config:Get()
    local roleInfo = RoleLogic:getRole( _rid, {
        Enum.Role.guildHelpPoint, Enum.Role.allianceHelpTime, Enum.Role.name, Enum.Role.roleHelpGuildPoint
    } )
    -- 最少时间等于helpMinAddTime+联盟增加时间
    local helpMinAddTime = sConfig.helpMinAddTime + ( roleInfo.allianceHelpTime or 0 )
    for index, requestInfo in pairs( requestHelps ) do
        repeat
            if requestInfo.rid ~= _rid and requestInfo.helpNum < requestInfo.helpLimit and not requestInfo.helps[_rid] then
                -- 1. 不是自己的求助信息
                -- 2. 求助次数未到上限
                -- 3. 还未帮助过此求助
                requestInfo.helpNum = requestInfo.helpNum + 1
                -- 帮助成功次数
                helpCount = helpCount + 1
                requestInfo.helps[_rid] = { rid = _rid }
                -- 计算本次帮助扣除时间
                reduceTime = math.max(
                                math.floor( requestInfo.needTime * sConfig.helpAddProportion / 1000 ) + ( roleInfo.allianceHelpTime or 0 ),
                                helpMinAddTime
                            )
                queueFinish = 1
                if requestInfo.type == Enum.GuildRequestHelpType.BUILD then
                    -- 建造扣除时间
                    queueFinish = MSM.RoleQueueMgr[requestInfo.rid].req.buildSpeedUp( requestInfo.rid, requestInfo.queueIndex, reduceTime, true )
                elseif requestInfo.type == Enum.GuildRequestHelpType.HEAL then
                    -- 治疗扣除时间
                    queueFinish = MSM.RoleQueueMgr[requestInfo.rid].req.hospitalSpeedUp( requestInfo.rid, reduceTime, true )
                elseif requestInfo.type == Enum.GuildRequestHelpType.TECHNOLOGY then
                    -- 科技升级扣除时间
                    queueFinish = MSM.RoleQueueMgr[requestInfo.rid].req.technologySpeedUp( requestInfo.rid, reduceTime, true )
                elseif requestInfo.type == Enum.GuildRequestHelpType.BATTLELOSE then
                    -- 战损补偿
                    MSM.BattleLosePowerMgr[requestInfo.rid].post.guildMemberHelp( requestInfo.rid, _rid )
                end
                -- 被帮助角色的求助类型
                if not helpNotifys[requestInfo.rid] then
                    helpNotifys[requestInfo.rid] = {}
                end
                helpNotifys[requestInfo.rid][requestInfo.type] = true
                requestInfo.reduceTime = requestInfo.reduceTime + reduceTime
                -- 通知客户端相关信息
                if queueFinish == 0 then
                    table.insert( finishIndexs, index )
                else
                    for _, memberRid in pairs( allOnlineMembers ) do
                        if not requestInfo.helps[memberRid] then
                            if not updateHelpRids[memberRid] then
                                updateHelpRids[memberRid] = {}
                            end
                            if requestInfo.rid == memberRid then
                                updateHelpRids[memberRid][index] = {
                                    index = index, helpNum = requestInfo.helpNum, reduceTime = requestInfo.reduceTime
                                }
                            else
                                updateHelpRids[memberRid][index] = {
                                    index = index, helpNum = requestInfo.helpNum
                                }
                            end
                        end
                    end
                end
                table.insert( deleteHelpIndexs, index )
            end
        until true
    end

    if helpCount > 0 then
        -- 更新求助信息
        self:setGuild( _guildId, { [Enum.Guild.requestHelps] = requestHelps } )
        -- 本次帮助队列完成，删除求助信息, 通知相应客户端
        for _, index in pairs( finishIndexs ) do
            self:roleQueueFinishCallBack( _guildId, index )
        end
        -- 更新帮助次数通知客户端
        for memberRid, requestInfo in pairs( updateHelpRids ) do
            self:syncGuildRequestHelps( memberRid, requestInfo )
        end
        if #deleteHelpIndexs > 0 then
            self:syncGuildRequestHelps( _rid, nil, deleteHelpIndexs )
        end
        -- 更新求助标识
        -- MSM.GuildIndexMgr[_guildId].post.updateRequestHelpIndexs( _guildId, helpIndexs )
        if roleInfo.guildHelpPoint < sConfig.individualPointsLimit then
            local addHelpPoint = helpCount * ( sConfig.individualPointsAward or 0 )
            if roleInfo.guildHelpPoint + addHelpPoint > sConfig.individualPointsLimit then
                -- 是否超出今日获得上限
                addHelpPoint = sConfig.individualPointsLimit - roleInfo.guildHelpPoint
            end
            -- 增加联盟个人积分
            RoleLogic:addGuildPoint( _rid, addHelpPoint, nil, Enum.LogType.GUILD_HELP_GAIN_POINT )
            -- 增加今日帮助获取联盟积分
            RoleLogic:setRole( _rid, { [Enum.Role.guildHelpPoint] = roleInfo.guildHelpPoint + addHelpPoint } )
            -- 通知客户端今日帮助获取联盟个人积分信息
            RoleSync:syncSelf( _rid, { [Enum.Role.guildHelpPoint] = roleInfo.guildHelpPoint + addHelpPoint }, true )
        end
        -- 获得联盟积分
        if roleInfo.roleHelpGuildPoint < sConfig.alliancePointsLimit then
            local addGuildPoint = helpCount * ( sConfig.alliancePointsAward or 0 )
            if roleInfo.roleHelpGuildPoint + addGuildPoint > sConfig.alliancePointsLimit then
                -- 是否超出今日获得上限
                addGuildPoint = sConfig.alliancePointsLimit - roleInfo.roleHelpGuildPoint
            end
            -- 增加联盟积分
            self:addGuildCurrency( _guildId, Enum.CurrencyType.leaguePoints, addGuildPoint )
            -- 刷新角色帮助联盟获取积分
            RoleLogic:setRole( _rid, { [Enum.Role.roleHelpGuildPoint] = roleInfo.roleHelpGuildPoint + addGuildPoint } )
        end
        -- 发送联盟帮助通知
        local helpNameInfo = { [Enum.Role.name] = roleInfo.name }
        for toRid, types in pairs( helpNotifys ) do
            self:guildNotify( toRid, Enum.GuildNotify.HELP, { helpNameInfo }, table.indexs( types ) )
        end
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.ALLIANCE_HELP_COUNT, helpCount )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.ALLIANCE_HELP_ACTION, helpCount )
        -- 更新联盟帮助次数排行榜
        self:updateGuildRoleRank( _guildId, _rid, Enum.RankType.ALLIACEN_ROLE_HELP, helpCount )
        -- 更新角色帮助次数
        local TaskLogic = require "TaskLogic"
        TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.HELP_GUILD_MEMBER, Enum.TaskArgDefault, helpCount )
        TaskLogic:updateTaskSchedule( _rid, { [Enum.TaskType.HELP_GUILD_MEMBER] = { arg = 0, addNum = helpCount } } )
        RoleLogic:addRoleStatistics( _rid, Enum.RoleStatisticsType.GUILD_HELP, helpCount )
    end
end

---@see 角色改名改头像等更新联盟求助索引
function GuildLogic:updateRoleRequestIndexs( _rid )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.buildQueue, Enum.Role.technologyQueue, Enum.Role.treatmentQueue, Enum.Role.guildId } )
    if not roleInfo.guildId or roleInfo.guildId <= 0 then return end
    local indexs = {}
    for _, queueInfo in pairs( roleInfo.buildQueue or {} ) do
        if queueInfo.requestHelpIndex and queueInfo.requestHelpIndex > 0 then
            table.insert( indexs, queueInfo.requestHelpIndex )
        end
    end
    if roleInfo.treatmentQueue and roleInfo.treatmentQueue.requestHelpIndex and roleInfo.treatmentQueue.requestHelpIndex > 0 then
        table.insert( indexs, roleInfo.treatmentQueue.requestHelpIndex )
    end
    if roleInfo.technologyQueue and roleInfo.technologyQueue.requestHelpIndex and roleInfo.technologyQueue.requestHelpIndex > 0 then
        table.insert( indexs, roleInfo.technologyQueue.requestHelpIndex )
    end
    -- 更新求助修改标识
    -- MSM.GuildIndexMgr[roleInfo.guildId].post.updateRequestHelpIndexs( roleInfo.guildId, indexs )
end

---@see 获取联盟领土颜色
function GuildLogic:getTerritoryColor( _guildId, _signs )
    local sAllianceSign = CFG.s_AllianceSign:Get()
    local signs = _signs or self:getGuild( _guildId, Enum.Guild.signs ) or {}
    for _, signId in pairs( signs ) do
        if sAllianceSign[signId] and sAllianceSign[signId].type == Enum.GuildSignType.TERRITORY_COLOR then
            return signId
        end
    end
end

---@see 联盟名称修改更新aoi信息
function GuildLogic:modifyGuildNameCallBack( _guildId )
    local guildInfo = self:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.name } )
    -- 更新联盟建筑的联盟名称
    local GuildBuildLogic = require "GuildBuildLogic"
    local guildBuilds = GuildBuildLogic:getGuildBuild( _guildId ) or {}
    local objectIndexs = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndexs( _guildId )
    local changInfo = { guildFullName = guildInfo.name }
    local noUpdateObjectType = {
        Enum.RoleType.GUILD_FOOD, Enum.RoleType.GUILD_WOOD, Enum.RoleType.GUILD_STONE, Enum.RoleType.GUILD_GOLD
    }
    for buildIndex in pairs( guildBuilds ) do
        if objectIndexs[buildIndex] then
            MSM.SceneGuildBuildMgr[objectIndexs[buildIndex]].post.updateGuildBuildInfo( objectIndexs[buildIndex], changInfo, noUpdateObjectType )
        end
    end

    -- 更新联盟城市的联盟名称
    local objectIndex
    for membereRid in pairs( guildInfo.members or {} ) do
        objectIndex = RoleLogic:getRoleCityIndex( membereRid )
        if objectIndex then
            MSM.SceneCityMgr[objectIndex].post.syncGuildFullName( objectIndex, guildInfo.name )
        end
    end
end

---@see 联盟简称修改更新aoi信息
function GuildLogic:modifyGuildAbbNameCallBack( _guildId )
    local guildInfo = self:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.abbreviationName } )
    -- 更新联盟建筑的联盟简称
    local GuildBuildLogic = require "GuildBuildLogic"
    local guildBuilds = GuildBuildLogic:getGuildBuild( _guildId ) or {}
    local objectIndexs = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndexs( _guildId )
    local changeInfo = { guildAbbName = guildInfo.abbreviationName }
    for buildIndex in pairs( guildBuilds ) do
        if objectIndexs[buildIndex] then
            MSM.SceneGuildBuildMgr[objectIndexs[buildIndex]].post.updateGuildBuildInfo( objectIndexs[buildIndex], changeInfo )
        end
    end
    -- 更新联盟资源点简称信息
    objectIndexs = MSM.GuildResourcePointIndexMgr[_guildId].req.getGuildResourcePointIndexs( _guildId ) or {}
    for objectIndex in pairs( objectIndexs ) do
        MSM.SceneGuildResourcePointMgr[objectIndex].post.updateGuildAbbName( objectIndex, guildInfo.abbreviationName )
    end

    -- 更新角色涉及联盟简称相关
    local ArmyLogic = require "ArmyLogic"
    local reinforces, targetArg
    for memberRid in pairs( guildInfo.members or {} ) do
        self:updateAoiGuildAbbName( memberRid, guildInfo.abbreviationName )
        -- 角色退出联盟，更新聊天信息
        RoleChatLogic:syncRoleInfoToChatServer( memberRid )
        -- 更新增援部队的联盟简称
        reinforces = RoleLogic:getRole( memberRid, Enum.Role.reinforces ) or {}
        for reinforceRid, reinforce in pairs( reinforces ) do
            targetArg = ArmyLogic:getArmy( reinforceRid, reinforce.armyIndex, Enum.Army.targetArg ) or {}
            targetArg.targetGuildName = guildInfo.abbreviationName
            ArmyLogic:updateArmyInfo( reinforceRid, reinforce.armyIndex, { [Enum.Army.targetArg] = targetArg } )
        end
    end

    -- 更新资源点所属联盟
    local guildTerritories = MSM.GuildTerritoryMgr[_guildId].req.getGuildTerritories( _guildId ) or {}
    if guildTerritories.validTerritoryIds then
        local ResourceLogic = require "ResourceLogic"
        ResourceLogic:resourceGuildAbbNameChange( guildTerritories.validTerritoryIds, guildInfo.abbreviationName )
    end

    -- 更新联盟所占的奇观信息
    MSM.GuildHolyLandMgr[_guildId].post.updateGuildAbbName( _guildId, guildInfo.abbreviationName )

    -- 更新联盟战争联盟简称信息
    local RallyLogic = require "RallyLogic"
    RallyLogic:syncRallyGuildAbbName( _guildId, guildInfo.abbreviationName )
end

---@see 推送联盟成员坐标信息
function GuildLogic:pushGuildMemberPos( _rid, _guildId )
    _guildId = _guildId or RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
    if _guildId <= 0 then return end

    MSM.GuildMgr[_guildId].post.pushGuildMemberPos( _guildId, _rid )
end

---@see 通知联盟成员坐标信息
function GuildLogic:syncGuildMemberPos( _toRids, _memberPos, _deleteRid )
    Common.syncMsg( _toRids, "Guild_GuildMemberPos", { memberPos = _memberPos, deleteRid = _deleteRid } )
end

---@see 增加联盟领土
function GuildLogic:addGuildTerritory( _guildId, _addNum )
    local territory = ( self:getGuild( _guildId, Enum.Guild.territory ) or 0 ) + _addNum
    if territory < 0 then
        territory = 0
    end

    self:setGuild( _guildId, { [Enum.Guild.territory] = territory } )

    MSM.GuildIndexMgr[_guildId].req.addGuildIndex( _guildId )
    -- 联盟旗帜排行
    local RankLogic = require "RankLogic"
    RankLogic:update( _guildId, Enum.RankType.ALLIANCE_FLAG, territory )
end

---@see 增加联盟资源点数量
function GuildLogic:addGuildResourcePoint( _guildId, _type, _addNum )
    local resourcePoints = self:getGuild( _guildId, Enum.Guild.resourcePoints ) or {}
    local oldValue
    if not resourcePoints[_type] then
        oldValue = 0
        resourcePoints[_type] = { type = _type, num = _addNum }
    else
        oldValue = resourcePoints[_type].num
        resourcePoints[_type].num = resourcePoints[_type].num + _addNum
    end

    if resourcePoints[_type].num < 0 then
        resourcePoints[_type].num = 0
    end
    self:setGuild( _guildId, { [Enum.Guild.resourcePoints] = resourcePoints } )
    -- 刷新当前联盟该货币数量
    local GuildBuildLogic = require "GuildBuildLogic"
    self:addGuildCurrency( _guildId, GuildBuildLogic:resourceBuildTypeToGuildCurrency( _type ), 0, _type )

    -- 更新联盟资源点标识
    MSM.GuildIndexMgr[_guildId].post.addResourcePointIndex( _guildId )

    return resourcePoints[_type].num, oldValue
end

---@see 增加联盟资源点数量
---@param _type integer 联盟资源点建筑类型
function GuildLogic:guildResourcePointChange( _guildId, _type, _addNum )
    local GuildBuildLogic = require "GuildBuildLogic"
    local members = self:getGuild( _guildId, Enum.Guild.members )

    local nowTime = os.time()
    local resourceTime = CFG.s_Config:Get( "allianceResourcePersonTime" )
    local sBuildingType = CFG.s_AllianceBuildingType:Get( _type )
    local roleCurrencyType = GuildBuildLogic:resourceBuildTypeToRoleCurrency( _type )
    -- 当前资源点数量和之前的资源点数量
    local newResourcePoint, oldResourcePoint = self:addGuildResourcePoint( _guildId, _type, _addNum )
    local roleTerritoryGains, addNum
    if _addNum < 0 then
        -- 联盟资源点减少
        for _, memberInfo in pairs( members ) do
            roleTerritoryGains = memberInfo.roleTerritoryGains
            if roleTerritoryGains[roleCurrencyType].num < roleTerritoryGains[roleCurrencyType].limit then
                -- 角色该类型资源获取还未达上限
                addNum = math.floor( ( nowTime - roleTerritoryGains[roleCurrencyType].territoryTime ) * oldResourcePoint * sBuildingType.holdPersonSpeed / 3600 )
                roleTerritoryGains[roleCurrencyType].num = roleTerritoryGains[roleCurrencyType].num + addNum
                if roleTerritoryGains[roleCurrencyType].num > roleTerritoryGains[roleCurrencyType].limit then
                    -- 角色增加这段时间获得的收益后超过上限
                    roleTerritoryGains[roleCurrencyType].num = roleTerritoryGains[roleCurrencyType].limit
                end
            end
            -- 重置收益刷新时间
            roleTerritoryGains[roleCurrencyType].territoryTime = nowTime
            -- 上限变更
            roleTerritoryGains[roleCurrencyType].limit = newResourcePoint * sBuildingType.holdPersonSpeed * resourceTime
            memberInfo.roleTerritoryGains = roleTerritoryGains
        end
    else
        -- 联盟资源点增多
        -- 角色可获取的联盟领地资源收益变大
        for _, memberInfo in pairs( members ) do
            roleTerritoryGains = memberInfo.roleTerritoryGains
            -- 这段时间增加的联盟收益
            addNum = math.floor( ( nowTime - roleTerritoryGains[roleCurrencyType].territoryTime ) * oldResourcePoint * sBuildingType.holdPersonSpeed / 3600 )
            -- 之前收益不满
            if roleTerritoryGains[roleCurrencyType].num < roleTerritoryGains[roleCurrencyType].limit then
                -- 之前收益未满，加上这段时间的增量
                roleTerritoryGains[roleCurrencyType].num = roleTerritoryGains[roleCurrencyType].num + addNum
                if roleTerritoryGains[roleCurrencyType].num > roleTerritoryGains[roleCurrencyType].limit then
                    -- 当前收益超过收益上限
                    roleTerritoryGains[roleCurrencyType].num = roleTerritoryGains[roleCurrencyType].limit
                end
            end
            -- 重置收益刷新时间
            roleTerritoryGains[roleCurrencyType].territoryTime = nowTime
            -- 上限变更
            roleTerritoryGains[roleCurrencyType].limit = newResourcePoint * sBuildingType.holdPersonSpeed * resourceTime
            memberInfo.roleTerritoryGains = roleTerritoryGains
        end
    end
    -- 更新成员联盟领土收益信息
    self:setGuild( _guildId, { [Enum.Guild.members] = members } )
end

---@see 领取联盟收益
function GuildLogic:takeGuildTerritoryGain( _guildId, _rid )
    local GuildBuildLogic = require "GuildBuildLogic"
    local guildInfo = self:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.resourcePoints } ) or {}
    local members = guildInfo.members or {}
    local resourcePoints = guildInfo.resourcePoints or {}
    if members[_rid] then
        local addNum, buildType, resourePointNum, holdPersonSpeed
        local nowTime = os.time()
        local sBuildingType = CFG.s_AllianceBuildingType:Get()
        for currencyType, territoryGain in pairs( members[_rid].roleTerritoryGains ) do
            buildType = GuildBuildLogic:resourceRoleCurrencyToBuildType( currencyType )
            addNum = territoryGain.num
            -- 当前收益大于上限，是因为建筑移除导致资源点数量变小导致
            if addNum < territoryGain.limit then
                -- 当前收益小于上限
                resourePointNum = resourcePoints[buildType] and resourcePoints[buildType].num or 0
                holdPersonSpeed = sBuildingType[buildType].holdPersonSpeed or 0
                addNum = addNum + math.floor( ( nowTime - territoryGain.territoryTime ) * holdPersonSpeed * resourePointNum / 3600 )
                if addNum > territoryGain.limit then
                    addNum = territoryGain.limit
                end
            end

            if addNum > 0 then
                -- 角色获得领土收益
                if currencyType == Enum.CurrencyType.food then
                    -- 增加粮食
                    RoleLogic:addFood( _rid, addNum, nil, Enum.LogType.TERRITORY_GAIN_CURRENCY )
                elseif currencyType == Enum.CurrencyType.wood then
                    -- 增加木材
                    RoleLogic:addWood( _rid, addNum, nil, Enum.LogType.TERRITORY_GAIN_CURRENCY )
                elseif currencyType == Enum.CurrencyType.stone then
                    -- 增加石料
                    RoleLogic:addStone( _rid, addNum, nil, Enum.LogType.TERRITORY_GAIN_CURRENCY )
                elseif currencyType == Enum.CurrencyType.gold then
                    -- 增加金币
                    RoleLogic:addGold( _rid, addNum, nil, Enum.LogType.TERRITORY_GAIN_CURRENCY )
                end
            end
            -- 更新角色可领取的收益信息
            territoryGain.num = 0
            territoryGain.territoryTime = nowTime
        end

        members[_rid].lastTakeGainTime = nowTime
        -- 更新领取信息
        self:setGuild( _guildId, { [Enum.Guild.members] = members } )
        -- 通知客户端
        GuildBuildLogic:synGuildBuild( _rid, nil, nil, nil, nil, members[_rid].roleTerritoryGains, nowTime )
    end
end

---@see 推送联盟圣地信息
function GuildLogic:pushHolyLands( _rid, _guildId )
    local guildId = _guildId or RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
    if guildId <= 0 then return end

    local guildHolyLands = MSM.GuildHolyLandMgr[guildId].req.getGuildHolyLand( guildId ) or {}

    if not table.empty( guildHolyLands ) then
        local syncHolyLands = {}

        for holyLandId, holyLandInfo in pairs( guildHolyLands ) do
            syncHolyLands[holyLandId] = {
                strongHoldId = holyLandInfo.strongHoldId,
                status = Enum.GuildHolyLandStatus.NORMAL,
                pos = holyLandInfo.pos,
            }
        end

        Common.syncMsg( _rid, "Guild_GuildHolyLands", { guildHolyLands = syncHolyLands } )
    end
end

---@see 更新联盟圣地信息
function GuildLogic:syncGuildHolyLands( _toRids, _guildHolyLands, _deleteStrongHoldId )
    Common.syncMsg( _toRids, "Guild_GuildHolyLands", { guildHolyLands = _guildHolyLands, deleteStrongHoldId = _deleteStrongHoldId } )
end

---@see 跨周处理联盟排行榜信息
function GuildLogic:resetGuildRoleRankInfo()
    local centerNode = Common.getCenterNode()
    -- 本服所有联盟ID
    local guildIds = Common.rpcCall( centerNode, "GuildProxy", "getGuildIds", Common.getSelfNodeName() ) or {}
    for guildId in pairs( guildIds ) do
        MSM.GuildMgr[guildId].post.resetGuildRoleRanks( guildId )
    end
end

---@see 重置联盟排行榜信息
function GuildLogic:resetGuildRoleRanks( _guildId )
    local RankLogic = require "RankLogic"

    local guildInfo = self:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.guildRanks } )
    local members = guildInfo.members or {}
    for type, rankInfo in pairs( guildInfo.guildRanks or {} ) do
        for memberRid in pairs( rankInfo.roleRanks or {} ) do
            if members[memberRid] then
                -- 角色还在联盟中
                RankLogic:update( memberRid, type, 0, _guildId )
            else
                -- 角色不在联盟中，删除角色排行榜信息
                RankLogic:delete( memberRid, type, _guildId )
            end
        end
    end

    -- 更新排行信息
    self:setGuild( _guildId, { [Enum.Guild.guildRanks] = {} } )
end

---@see 更新联盟角色排行榜
function GuildLogic:updateGuildRoleRank( _guildId, _rid, _type, _addNum )
    local guildRanks = self:getGuild( _guildId, Enum.Guild.guildRanks ) or {}
    if not guildRanks[_type] then
        guildRanks[_type] = {
            type = _type,
            roleRanks = {}
        }
    end

    if not guildRanks[_type].roleRanks[_rid] then
        guildRanks[_type].roleRanks[_rid] = {
            rid = _rid,
            score = _addNum
        }
    else
        guildRanks[_type].roleRanks[_rid].score = guildRanks[_type].roleRanks[_rid].score + _addNum
    end

    self:setGuild( _guildId, { [Enum.Guild.guildRanks] = guildRanks } )
    -- 更新联盟角色排行榜
    local RankLogic = require "RankLogic"
    RankLogic:update( _rid, _type, guildRanks[_type].roleRanks[_rid].score, _guildId )
end

---@see 获取联盟属性值
function GuildLogic:getGuildAttr( _guildId, _attrNames )
    return MSM.GuildAttrMgr[_guildId].req.getGuildAttr( _guildId, _attrNames )
end

---@see 更新联盟成员人数上限
function GuildLogic:updateGuildMemberLimit( _guildId )
    local GuildBuildLogic = require "GuildBuildLogic"

    local guildInfo = self:getGuild( _guildId, {
        Enum.Guild.memberLimit, Enum.Guild.members, Enum.Guild.needExamine, Enum.Guild.languageId, Enum.Guild.power
    } )
    local sConfig = CFG.s_Config:Get()
    local guildBuilds = GuildBuildLogic:getGuildBuild( _guildId ) or {}
    local fortressNum = 0
    local flagNum = 0
    for _, buildInfo in pairs( guildBuilds ) do
        if buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS
            or buildInfo.type == Enum.GuildBuildType.FORTRESS_FIRST
            or buildInfo.type == Enum.GuildBuildType.FORTRESS_SECOND then
            fortressNum = fortressNum + 1
        elseif buildInfo.type == Enum.GuildBuildType.FLAG then
            flagNum = flagNum + 1
        end
    end

    local allianceMemberNum = self:getGuildAttr( _guildId, Enum.Guild.allianceMemberNum ) or 0

    local newMemberLimit = sConfig.allianceInitialNum + allianceMemberNum
                        + fortressNum * sConfig.allianceFortressMemberNum
                        + math.floor( flagNum / sConfig.allianceMemberNumFlag )
    if newMemberLimit ~= guildInfo.memberLimit then
        self:setGuild( _guildId, { [Enum.Guild.memberLimit] = newMemberLimit } )
        MSM.GuildIndexMgr[_guildId].post.addGuildIndex( _guildId )
        if guildInfo.memberLimit > table.size( guildInfo.members ) then
            SM.GuildRecommendMgr.post.addGuildId( _guildId, guildInfo.needExamine, guildInfo.languageId, guildInfo.power )
        else
            SM.GuildRecommendMgr.post.delGuildId( _guildId, guildInfo.languageId )
        end
    end
end

---@see 更新联盟仓库上限
function GuildLogic:updateGuildDepotLimit( _guildId )
    local num
    local nowTime = os.time()
    local sConfig = CFG.s_Config:Get()
    local allianceDepotMulti = self:getGuildAttr( _guildId, Enum.Guild.allianceDepotMulti ) or 0
    local currencies = self:getGuild( _guildId, Enum.Guild.currencies ) or {}
    for type, currencyInfo in pairs( currencies ) do
        if type ~= Enum.CurrencyType.leaguePoints then
            if currencyInfo.num < currencyInfo.limit then
                num = currencyInfo.num + math.floor( ( currencyInfo.produce or 0 ) / 3600 * ( nowTime - ( currencyInfo.lastProduceTime or nowTime ) ) )
                if num > currencyInfo.limit then
                    currencyInfo.num = currencyInfo.limit
                else
                    currencyInfo.num = num
                end
                currencyInfo.lastProduceTime = nowTime
            end
            if type == Enum.CurrencyType.allianceFood then
                currencyInfo.limit = math.floor( sConfig.allianceFoodLimit * ( 1000 + allianceDepotMulti ) / 1000 )
            elseif type == Enum.CurrencyType.allianceWood then
                currencyInfo.limit = math.floor( sConfig.allianceWoodLimit * ( 1000 + allianceDepotMulti ) / 1000 )
            elseif type == Enum.CurrencyType.allianceStone then
                currencyInfo.limit = math.floor( sConfig.allianceStoneLimit * ( 1000 + allianceDepotMulti ) / 1000 )
            elseif type == Enum.CurrencyType.allianceGold then
                currencyInfo.limit = math.floor( sConfig.allianceGoldLimit * ( 1000 + allianceDepotMulti ) / 1000 )
            end
        end
    end

    -- 更新仓库信息
    self:setGuild( _guildId, { [Enum.Guild.currencies] = currencies } )
    -- 通知联盟成员
    local allMemberRids = self:getAllOnlineMember( _guildId )
    if #allMemberRids > 0 then
        self:syncGuildDepot( allMemberRids, currencies )
    end
end

---@see 更新联盟旗帜上限
function GuildLogic:updateGuildFlagLimit( _guildId )
    local territoryLimit = CFG.s_AllianceBuildingType:Get( Enum.GuildBuildType.FLAG, "countDefault" )
    territoryLimit = territoryLimit + ( self:getGuildAttr( _guildId, Enum.Guild.allianceFlagNum ) or 0 )

    self:setGuild( _guildId, { [Enum.Guild.territoryLimit] = territoryLimit } )
end

---@see 联盟属性变化
function GuildLogic:guildAttrChangeCallBack( _guildId, _attrNames )
    -- 联盟成员上限变化
    if _attrNames.allianceMemberNum then
        self:updateGuildMemberLimit( _guildId )
    end

    -- 联盟仓库的存储容量加成
    if _attrNames.allianceDepotMulti then
        self:updateGuildDepotLimit( _guildId )
    end

    -- 联盟旗帜上限加值
    if _attrNames.allianceFlagNum then
        self:updateGuildFlagLimit( _guildId )
    end

    -- 联盟建筑耐久度加成
    if _attrNames.allianceBuildingDurableMulti then
        MSM.GuildMgr[_guildId].post.buildDurableLimitChange( _guildId )
    end

    -- 联盟建筑建造速度加成
    if _attrNames.allianceBuildingSpeedMulti then
        MSM.GuildMgr[_guildId].post.buildSpeedChange( _guildId )
    end

    -- 联盟旗帜建造速度加成
    if _attrNames.allianceFlagSpeedMulti then
        MSM.GuildMgr[_guildId].post.buildSpeedChange( _guildId, true )
    end
end

---@see 检查角色是否是官员
function GuildLogic:checkRoleOfficer( _guildId, _rid )
    _guildId = _guildId or RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
    if _guildId > 0 then
        local guildOfficers = self:getGuild( _guildId, Enum.Guild.guildOfficers ) or {}
        for officerId, officerInfo in pairs( guildOfficers ) do
            if officerInfo.rid == _rid then
                return true, officerId
            end
        end
    end
end

---@see 检查是否有留言板红点提示
function GuildLogic:checkMessageBoardRedDot( _guildId, _rid, _messageBoardRedDotList )
    local messages = SM.c_guild_message_board.req.Get( _guildId ) or {}
    if #messages > 0 and not table.exist( _messageBoardRedDotList or {}, _rid ) then
        return true
    end
end

---@see 检查联盟信息是否有角色数据
function GuildLogic:checkRoleGuildOnRoleLogin( _rid )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
    if guildId > 0 then
        local members = self:getGuild( guildId, Enum.Guild.members )
        if not members or not members[_rid] then
            RoleLogic:setRole( _rid, { [Enum.Role.guildId] = 0 } )
        end
    end
end

---@see 记录联盟日志
function GuildLogic:guildLog()
    local GuildBuildLogic = require "GuildBuildLogic"
    local centerNode = Common.getCenterNode()
    -- 本服所有联盟ID
    local args, buildNum
    local fields = {
        Enum.Guild.createIggId, Enum.Guild.createTime, Enum.Guild.leaderRid, Enum.Guild.name,
        Enum.Guild.abbreviationName, Enum.Guild.giftLevel, Enum.Guild.currencies, Enum.Guild.territory,
        Enum.Guild.members, Enum.Guild.memberLimit
    }
    local guildIds = Common.rpcCall( centerNode, "GuildProxy", "getGuildIds", Common.getSelfNodeName() ) or {}
    for guildId in pairs( guildIds ) do
        args = self:getGuild( guildId, fields )
        if args then
            buildNum = GuildBuildLogic:getBuildNum( guildId, Enum.GuildBuildType.CENTER_FORTRESS )
            args.fortressFlag = buildNum > 0 and 1 or 0
            args.guildId = guildId
            args.iggid = RoleLogic:getRole( args.leaderRid, Enum.Role.iggid )
            LogLogic:roleGuild( args )
        end
    end
end

---@see 刷新角色在联盟中的战力
function GuildLogic:refreshGuildRolePower( _rid )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
    if guildId and guildId > 0 then
        MSM.GuildMgr[guildId].post.refreshGuildRolePower( guildId, _rid )
    end
end

---@see 检查服务是否忙碌
function GuildLogic:checkServiceBusy()
    local skynet = require "skynet"
    while SM.ServiceBusyCheckMgr.req.checkServiceBusy() do
        skynet.sleep(100)
    end
end

---@see 发送联盟不活跃邮件
function GuildLogic:sendInactiveMembersEmail( _rid )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.guildId, Enum.Role.lastInactiveEmailTime } ) or {}
    local guildId = roleInfo.guildId or 0
    if guildId > 0 and Timer.isDiffDay( roleInfo.lastInactiveEmailTime or 0 ) then
        local guildInfo = self:getGuild( guildId, { Enum.Guild.members, Enum.Guild.leaderRid } ) or {}
        if guildInfo.leaderRid and guildInfo.leaderRid == _rid then
            -- 盟主才会收到不活跃邮件
            local notOnlineMembers = self:getAllNotOnlineMember( guildId, guildInfo.members or {} ) or {}
            table.removevalue( notOnlineMembers, _rid )
            if table.size( notOnlineMembers ) > 0 then
                local memberInfo
                local nowTime = os.time()
                local inactiveMembers = {}
                local intervalTime = ( CFG.s_Config:Get( "allianceInactivityDefine" ) or 3 ) * 24 * 3600
                local fields = { Enum.Role.rid, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.lastLogoutTime }
                for _, memberRid in pairs( notOnlineMembers ) do
                    memberInfo = RoleLogic:getRole( memberRid, fields ) or {}
                    memberInfo.lastLogoutTime = memberInfo.lastLogoutTime or 0
                    if memberInfo and not table.empty( memberInfo ) and ( nowTime - memberInfo.lastLogoutTime ) >= intervalTime then
                        table.insert( inactiveMembers, memberInfo )
                    end
                end

                if table.size( inactiveMembers ) > 0 then
                    table.sort( inactiveMembers, function ( a, b ) return a.lastLogoutTime < b.lastLogoutTime end )
                    -- 发送不活跃邮件
                    EmailLogic:sendEmail( _rid, 300020, { guildEmail = { inactiveMembers = inactiveMembers } } )
                    RoleLogic:setRole( _rid, { [Enum.Role.lastInactiveEmailTime] = os.time() } )
                end
            end
        end
    end
end

---@see 从联盟成员中找到满足转让邀请的联盟成员
function GuildLogic:getPreTransferLeadRid( _guildId )
    local memberInfo
    local memberList = {}
    local guildInfo = self:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.leaderRid, Enum.Guild.weekDonates } ) or {}
    local weekDonates = guildInfo.weekDonates or {}
    local fields = { Enum.Role.cityId, Enum.Role.combatPower, Enum.Role.level }
    local onlineMembers = self:getAllOnlineMember( _guildId, guildInfo.members or {} ) or {}
    for memberRid, guildMemberInfo in pairs( guildInfo.members or {} ) do
        if table.exist( onlineMembers, memberRid ) and memberRid ~= ( guildInfo.leaderRid or 0 ) then
            memberInfo = RoleLogic:getRole( memberRid, fields ) or {}
            if not table.empty( memberInfo ) and ( memberInfo.cityId or 0 ) > 0 then
                -- 离线时间未超过指定时间
                table.insert( memberList, {
                    rid = memberRid,
                    donateNum = weekDonates[memberRid] and weekDonates[memberRid].donateNum or 0,
                    guildJob = guildMemberInfo.guildJob or Enum.GuildJob.R1,
                    combatPower = memberInfo.combatPower or 0,
                    level = memberInfo.level
                } )
            end
        end
    end

    if #memberList > 0 then
        table.sort( memberList, function ( a, b )
            -- 城市未被回收 > 离线时长小于指定值 > 本周贡献度 > 联盟职位（R4、R3、R2、R1） > 角色战力 > 市政厅等级
            if a.donateNum == b.donateNum then
                if a.guildJob == b.guildJob then
                    if a.combatPower == b.combatPower then
                        return a.level > b.level
                    else
                        return a.combatPower > b.combatPower
                    end
                else
                    return a.guildJob > b.guildJob
                end
            else
                return a.donateNum > b.donateNum
            end
        end )

        return memberList[1].rid
    end
end

---@see 检查联盟盟主转让时间是否已到达
function GuildLogic:checkGuildLeaderLogoutTime()
    local centerNode = Common.getCenterNode()
    -- 本服所有联盟ID
    local nowTime = os.time()
    local leaderRid, lastLogoutTime, newLeaderRid
    local leaderGuildJob = Enum.GuildJob.LEADER
    local allianceLeaderTransferTime = ( CFG.s_Config:Get( "allianceLeaderTransferTime" ) or 72 ) * 3600
    local guildIds = Common.rpcCall( centerNode, "GuildProxy", "getGuildIds", Common.getSelfNodeName() ) or {}
    for guildId in pairs( guildIds ) do
        leaderRid = self:getGuild( guildId, Enum.Guild.leaderRid ) or 0
        -- 盟主不在线
        if leaderRid and leaderRid > 0 and not SM.OnlineMgr.req.checkOnline( leaderRid ) then
            -- 盟主离线时间是否到达指定值
            lastLogoutTime = RoleLogic:getRole( leaderRid, Enum.Role.lastLogoutTime ) or 0
            if nowTime - lastLogoutTime >= allianceLeaderTransferTime then
                -- 找到满足转让要求的联盟成员
                newLeaderRid = self:getPreTransferLeadRid( guildId ) or 0
                if newLeaderRid > 0 then
                    -- 转让盟主
                    MSM.GuildMgr[guildId].req.modifyMemberLevel( guildId, leaderRid, newLeaderRid, leaderGuildJob, true )
                end
            end
        end
    end
end

---@see 服务器启动检查联盟求助信息是否正常
function GuildLogic:checkGuildRequestOnReboot( _guildId )
    local nowTime = os.time()
    local newRequestHelps = {}
    local noDeleteRequest, queueInfo
    local requestHelps = self:getGuild( _guildId, Enum.Guild.requestHelps ) or {}
    for index, requestInfo in pairs( requestHelps ) do
        noDeleteRequest = false
        if requestInfo.rid and requestInfo.rid > 0 then
            if requestInfo.type == Enum.GuildRequestHelpType.BUILD then
                -- 升级建筑
                if requestInfo.queueIndex and requestInfo.queueIndex > 0 then
                    queueInfo = RoleLogic:getRole( requestInfo.rid, Enum.Role.buildQueue ) or {}
                    -- 建筑队列是否已经完成升级
                    if queueInfo[requestInfo.queueIndex] and queueInfo[requestInfo.queueIndex].finishTime
                        and queueInfo[requestInfo.queueIndex].finishTime > nowTime then
                        noDeleteRequest = true
                    end
                end
            elseif requestInfo.type == Enum.GuildRequestHelpType.HEAL then
                -- 治疗
                queueInfo = RoleLogic:getRole( requestInfo.rid, Enum.Role.treatmentQueue ) or {}
                -- 治疗队列是否已经完成
                if queueInfo.finishTime and queueInfo.finishTime > nowTime then
                    noDeleteRequest = true
                end
            elseif requestInfo.type == Enum.GuildRequestHelpType.TECHNOLOGY then
                -- 科技升级
                queueInfo = RoleLogic:getRole( requestInfo.rid, Enum.Role.technologyQueue ) or {}
                -- 科技升级是否已经完成
                if queueInfo.finishTime and queueInfo.finishTime > nowTime then
                    noDeleteRequest = true
                end
            elseif requestInfo.type == Enum.GuildRequestHelpType.BATTLELOSE then
                -- 战损补偿
                noDeleteRequest = false
            else
                noDeleteRequest = true
            end
        end

        if noDeleteRequest then
            newRequestHelps[index] = requestInfo
        end
    end

    -- 更新联盟求助信息
    if table.size( newRequestHelps ) ~= table.size( requestHelps ) then
        self:setGuild( _guildId, { [Enum.Guild.requestHelps] = newRequestHelps } )
    end
end

return GuildLogic