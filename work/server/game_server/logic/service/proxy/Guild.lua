--[[
* @file : Guild.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Thu Apr 09 2020 10:51:12 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟协议服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local GuildLogic = require "GuildLogic"
local RoleLogic = require "RoleLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local EmailLogic = require "EmailLogic"
local ArmyLogic = require "ArmyLogic"

---@see 创建联盟
function response.CreateGuild( msg )
    local rid = msg.rid
    local name = msg.name
    local abbreviationName = msg.abbreviationName
    local notice = msg.notice or ""
    local needExamine = msg.needExamine
    local languageId = msg.languageId
    local signs = msg.signs

    -- 参数检查
    if not name or not abbreviationName or not signs or not languageId then
        LOG_ERROR("rid(%d) CreateGuild, arg error", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否已在联盟中
    if RoleLogic:checkRoleGuild( rid ) then
        LOG_ERROR("rid(%d) CreateGuild, role already in guild", rid)
        return nil, ErrorCode.GUILD_ALREADY_IN_GUILD
    end

    local sConfig = CFG.s_Config:Get()
    -- 简称长度判断
    local strLen = utf8.len( abbreviationName )
    if sConfig.allianceAbbreviationMin > strLen or sConfig.allianceAbbreviationMax < strLen then
        LOG_ERROR("rid(%d) CreateGuild, abbreviationName(%s) length error", rid, abbreviationName)
        return nil, ErrorCode.GUILD_ABBNAME_LENGTH_ERROR
    end

    -- 简称是否只包括数字、字母和特殊符号
    if not GuildLogic:checkGuildAbbName( abbreviationName ) then
        LOG_ERROR("rid(%d) CreateGuild, abbreviationName(%s) char error", rid, abbreviationName)
        return nil, ErrorCode.GUILD_ABBNAME_CHAR_ERROR
    end

    -- 简称是否有效
    if not RoleLogic:checkBlockName( abbreviationName ) then
        LOG_ERROR("rid(%d) CreateGuild, abbreviationName(%s) invalid", rid, abbreviationName)
        return nil, ErrorCode.GUILD_ABBNAME_INVALID
    end

    -- 名称长度判断
    strLen = utf8.len( name )
    if sConfig.allianceNameMin > strLen or sConfig.allianceNameMax < strLen then
        LOG_ERROR("rid(%d) CreateGuild, name(%s) length error", rid, name)
        return nil, ErrorCode.GUILD_NAME_LENGTH_ERROR
    end

    -- 联盟名称是否包含非法字符
    if not GuildLogic:checkGuildName( name ) then
        LOG_ERROR("rid(%d) CreateGuild, name(%s) invalid", rid, name)
        return nil, ErrorCode.GUILD_NAME_INVALID
    end

    -- 名称是否有效
    if not RoleLogic:checkBlockName( name ) then
        LOG_ERROR("rid(%d) CreateGuild, name(%s) invalid", rid, name)
        return nil, ErrorCode.GUILD_NAME_INVALID
    end

    -- 公告是否超长
    if sConfig.allianceNoticeNum < utf8.len( notice ) then
        LOG_ERROR("rid(%d) CreateGuild, notice(%s) too long", rid, notice)
        return nil, ErrorCode.GUILD_NOTICE_LENGTH_ERROR
    end

    -- 公告是否有效
    if not RoleLogic:checkBlockName( notice ) then
        LOG_ERROR("rid(%d) CreateGuild, notice(%s) invalid", rid, notice)
        return nil, ErrorCode.GUILD_NOTICE_INVALID
    end

    -- 宝石是否足够
    if sConfig.allianceEstablishCost and sConfig.allianceEstablishCost > 0
        and not RoleLogic:checkDenar( rid, sConfig.allianceEstablishCost ) then
        LOG_ERROR("rid(%d) CreateGuild, role denar not enough", rid)
        return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
    end

    -- 创建联盟
    local ret, error = GuildLogic:createGuild( rid, name, abbreviationName, notice, needExamine, languageId, signs )
    if not ret then
        LOG_ERROR("rid(%d) CreateGuild, create guild failed", rid)
        return nil, error or ErrorCode.GUILD_CREATE_FAILED
    else
        return { guildId = ret }
    end
end

---@see 申请加入联盟
function response.ApplyJoinGuild( msg )
    local rid = msg.rid
    local guildId = msg.guildId

    -- 参数检查
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) ApplyJoinGuild, guildId arg error", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否已在联盟中
    if RoleLogic:checkRoleGuild( rid ) then
        LOG_ERROR("rid(%d) ApplyJoinGuild, role already in guild", rid)
        return nil, ErrorCode.GUILD_ALREADY_IN_GUILD
    end

    -- 联盟是否存在
    local guildGameNode = SM.GuildNameProxy.req.getGuildGameNode( guildId )
    if not guildGameNode then
        LOG_ERROR("rid(%d) ApplyJoinGuild, guildId(%d) not exist", rid, guildId)
        return nil, ErrorCode.GUILD_NOT_EXIST
    end

    -- 是否为本服联盟
    if guildGameNode ~= Common.getSelfNodeName() then
        LOG_ERROR("rid(%d) ApplyJoinGuild, guildId(%d) is other gameNode(%d)", rid, guildId, guildGameNode)
        return nil, ErrorCode.GUILD_NOT_EXIST
    end

    -- 申请加入联盟
    local ret, error = MSM.GuildMgr[guildId].req.applyJoinGuild( guildId, rid )
    if not ret then
        LOG_ERROR("rid(%d) ApplyJoinGuild, error(%d)", rid, error)
        return nil, error
    else
        return { type = ret, guildId = guildId }
    end
end

---@see 搜索联盟
function response.SearchGuild( msg )
    local rid = msg.rid
    local type = msg.type
    local keyName = msg.keyName

    -- 参数检查
    if not type then
        LOG_ERROR("rid(%d) SearchGuild, no type arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    local guildInfo, leaderInfo, guilds
    local guildList = {}
    local guildFields = {
        Enum.Guild.name, Enum.Guild.abbreviationName, Enum.Guild.notice, Enum.Guild.languageId,
        Enum.Guild.signs, Enum.Guild.leaderRid, Enum.Guild.power, Enum.Guild.members,
        Enum.Guild.memberLimit, Enum.Guild.needExamine, Enum.Guild.guildId,
        Enum.Guild.applys, Enum.Guild.territory, Enum.Guild.giftLevel
    }
    local selfGameNode = Common.getSelfNodeName()
    if type == Enum.GuildSearchType.MAIN_WIN or type == Enum.GuildSearchType.JOIN_WIN then
        -- 主界面、加入联盟 推荐联盟信息
        guilds = SM.GuildRecommendMgr.req.getRecommendGuilds( type, RoleLogic:getRole( rid, Enum.Role.language ) )
    elseif type == Enum.GuildSearchType.SEARCH then
        -- 按照联盟名称简称搜索联盟信息
        guilds = SM.GuildNameProxy.req.searchGuildByKeyName( keyName ) or {}
    end

    local guildIds = {}
    for _, guild in pairs( guilds or {} ) do
        guildInfo = Common.rpcCall( guild.gameNode, "c_guild", "Get", guild.guildId, guildFields )
        if guildInfo and not table.empty( guildInfo ) and not guildIds[guild.guildId] then
            leaderInfo = Common.rpcMultiCall( guild.gameNode, "d_role", "Get", guildInfo.leaderRid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } ) or {}
            table.insert(
                guildList,
                {
                    guildId = guild.guildId,
                    name = guildInfo.name,
                    abbreviationName = guildInfo.abbreviationName,
                    notice = guildInfo.notice,
                    languageId = guildInfo.languageId,
                    signs = guildInfo.signs,
                    leaderRid = guildInfo.leaderRid,
                    power = guildInfo.power,
                    memberNum = table.size( guildInfo.members or {} ),
                    memberLimit = guildInfo.memberLimit,
                    needExamine = guildInfo.needExamine,
                    leaderName = leaderInfo.name,
                    isApply = guildInfo.applys and guildInfo.applys[rid] and true or false,
                    isSameGame = selfGameNode == guild.gameNode,
                    leaderHeadId = leaderInfo.headId,
                    leaderHeadFrameID = leaderInfo.headFrameID,
                    territory = guildInfo.territory,
                    giftLevel = guildInfo.giftLevel,
                }
            )
            guildIds[guild.guildId] = true
        end
    end

    return { guildList = guildList, type = type }
end

---@see 获取联盟信息
function response.GetGuildInfo( msg )
    local rid = msg.rid
    local reqType = msg.reqType

    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.guildId, Enum.Role.guildIndexs } )
    -- 角色是否在联盟中
    if not roleInfo.guildId or roleInfo.guildId <= 0 then
        LOG_ERROR("rid(%d) GetGuildInfo, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    local guildInfo = GuildLogic:getGuild( roleInfo.guildId )
    local guildChangeInfo = {}
    local updateIndexs
    if msg.type or msg.type == Enum.GuildGetType.WELCOME_EMAIL then
        local welcomeEmailIndex = MSM.GuildIndexMgr[roleInfo.guildId].req.getWelcomeEmailIndex( roleInfo.guildId )
        local roleWelcomeEmailIndex = roleInfo.guildIndexs and roleInfo.guildIndexs.welcomeEmailIndex or 0
        -- 联盟欢迎邮件内容有修改
        if welcomeEmailIndex > roleWelcomeEmailIndex then
            guildChangeInfo.welcomeEmailFlag = guildInfo.welcomeEmailFlag
            guildChangeInfo.welcomeEmail = guildInfo.welcomeEmail
            updateIndexs = { welcomeEmailIndex = welcomeEmailIndex }
        end
    else
        -- 联盟基础信息是否需要推送
        local roleGuildIndex = roleInfo.guildIndexs and roleInfo.guildIndexs.guildIndex or 0
        local roleGuildNoticeIndex = roleInfo.guildIndexs and roleInfo.guildIndexs.guildNoticeIndex or 0
        local guildIndex = MSM.GuildIndexMgr[roleInfo.guildId].req.getGuildIndex( roleInfo.guildId ) or 1
        if guildIndex > roleGuildIndex then
            guildChangeInfo.name = guildInfo.name
            guildChangeInfo.abbreviationName = guildInfo.abbreviationName
            guildChangeInfo.power = guildInfo.power
            guildChangeInfo.leaderName = RoleLogic:getRole( guildInfo.leaderRid, Enum.Role.name )
            guildChangeInfo.territory = guildInfo.territory
            guildChangeInfo.giftLevel = guildInfo.giftLevel
            guildChangeInfo.memberNum = table.size( guildInfo.members )
            guildChangeInfo.memberLimit = guildInfo.memberLimit
            guildChangeInfo.signs = guildInfo.signs
            guildChangeInfo.messageBoardRedDot = GuildLogic:checkMessageBoardRedDot( roleInfo.guildId, rid, guildInfo.messageBoardRedDotList )
            guildChangeInfo.territoryBuildFlag = guildInfo.territoryBuildFlag
        end
        -- 联盟公告是否需要推送
        local guildNoticeIndex = MSM.GuildIndexMgr[roleInfo.guildId].req.getGuildNoticeIndex( roleInfo.guildId ) or 1
        if guildNoticeIndex > roleGuildNoticeIndex then
            guildChangeInfo.notice = guildInfo.notice
        end

        updateIndexs = { guildIndex = guildIndex, guildNoticeIndex = guildNoticeIndex }
    end

    if not table.empty( guildChangeInfo ) then
        -- 推送客户端
        GuildLogic:syncGuild( rid, guildChangeInfo, true, true )
        -- 更新角色客户端当前标识
        RoleLogic:updateRoleGuildIndexs( rid, updateIndexs )
    end

    return { type = msg.type, reqType = reqType }
end

---@see 检查联盟简称名称是否被占用
function response.CheckGuildName( msg )
    local rid = msg.rid
    local type = msg.type
    local value = msg.value

    local result, strLen
    local sConfig = CFG.s_Config:Get()
    if type == 1 then
        -- 名称长度判断
        strLen = utf8.len( value )
        if sConfig.allianceNameMin > strLen or sConfig.allianceNameMax < strLen then
            LOG_ERROR("rid(%d) CheckGuildName, name(%s) length error", rid, value)
            return nil, ErrorCode.GUILD_NAME_LENGTH_ERROR
        end

        result = not SM.GuildNameProxy.req.checkGuildNameRepeat( value )
    elseif type == 2 then
        -- 简称长度判断
        strLen = utf8.len( value )
        if sConfig.allianceAbbreviationMin > strLen or sConfig.allianceAbbreviationMax < strLen then
            LOG_ERROR("rid(%d) CheckGuildName, abbreviationName(%s) length error", rid, value)
            return nil, ErrorCode.GUILD_ABBNAME_LENGTH_ERROR
        end

        result = not SM.GuildNameProxy.req.checkGuildAbbNameRepeat( value )
    end

    return { type = type, value = value, result = result }
end

---@see 审批入盟申请
function response.ExamineGuildApply( msg )
    local rid = msg.rid
    local applyRid = msg.applyRid
    local result = msg.result or false

    -- 参数检查
    if not applyRid then
        LOG_ERROR("rid(%d) ExamineGuildApply, no applyRid arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId ) or 0
    if guildId <= 0 then
        LOG_ERROR("rid(%d) GetGuildInfo, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    return MSM.GuildMgr[guildId].req.examineGuildApply( guildId, rid, applyRid, result )
end

---@see 邀请加入联盟
function response.InviteGuild( msg )
    local rid = msg.rid
    local invitedRid = msg.invitedRid

    -- 参数检查
    if not invitedRid then
        LOG_ERROR("rid(%d) InviteGuild, no invitedRid arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否在联盟中
    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.guildId } )
    local guildId = roleInfo.guildId
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) InviteGuild, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 角色是否有入盟邀请权限
    local guildJob = GuildLogic:getRoleGuildJob( guildId, rid )
    if not GuildLogic:checkRoleJurisdiction( rid, Enum.GuildJurisdictionType.INVITE, guildJob ) then
        LOG_ERROR("rid(%d) InviteGuild, role guildJob(%d) no invite join guild jurisdiction", rid, guildJob)
        return nil, ErrorCode.GUILD_NO_JURISDICTION
    end

    -- 被邀请人是否已在联盟中
    if RoleLogic:checkRoleGuild( invitedRid ) then
        LOG_ERROR("rid(%d) InviteGuild, role already in guild", rid)
        return nil, ErrorCode.GUILD_ALREADY_IN_GUILD
    end

    return MSM.GuildMgr[guildId].req.inviteGuild( guildId, rid, invitedRid )
end

---@see 取消入盟申请
function response.CancelGuildApply( msg )
    local rid = msg.rid
    local guildId = msg.guildId

    -- 参数检查
    if not guildId then
        LOG_ERROR("rid(%d) CancelGuildApply, no guildId arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否已在联盟中
    if RoleLogic:checkRoleGuild( rid ) then
        LOG_ERROR("rid(%d) CancelGuildApply, role already in guild", rid)
        return nil, ErrorCode.GUILD_ALREADY_IN_GUILD
    end

    return MSM.GuildMgr[guildId].req.cancelGuildApply( guildId, rid )
end

---@see 获取联盟成员信息
function response.GetGuildMembers( msg )
    local rid = msg.rid

    -- 角色是否在联盟中
    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.guildId, Enum.Role.guildIndexs } )
    if not roleInfo.guildId or roleInfo.guildId <= 0 then
        LOG_ERROR("rid(%d) GetGuildMembers, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 当前客户端是否已为最新联盟成员信息
    local guildMemberIndex = roleInfo.guildIndexs.guildMemberIndex or 0
    local memberGlobalIndex = MSM.GuildIndexMgr[roleInfo.guildId].req.getMemberGlobalIndex( roleInfo.guildId )
    if guildMemberIndex >= memberGlobalIndex then
        return
    end

    local memberInfo, online
    local syncMembers = {}
    local fields = {
        Enum.Role.rid, Enum.Role.headId, Enum.Role.name, Enum.Role.killCount, Enum.Role.online, Enum.Role.isAfk, Enum.Role.headFrameID
    }
    local members = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.members )
    local memberIndexs = MSM.GuildIndexMgr[roleInfo.guildId].req.getMemberIndexs( roleInfo.guildId )
    for memberRid, member in pairs( members ) do
        if memberIndexs[memberRid] and memberIndexs[memberRid] > guildMemberIndex then
            memberInfo = RoleLogic:getRole( memberRid, fields )
            memberInfo.combatPower = member.combatPower
            memberInfo.guildJob = member.guildJob
            memberInfo.cityObjectIndex = RoleLogic:getRoleCityIndex( memberRid )
            online = false
            if memberInfo.online and not memberInfo.isAfk then
                online = true
            end
            memberInfo.online = online
            if memberInfo.guildJob ~= Enum.GuildJob.LEADER then
                memberInfo.killCount = nil
            end
            syncMembers[memberRid] = memberInfo
        end
    end

    -- 推送修改的联盟成员信息
    if not table.empty( syncMembers ) then
        GuildLogic:syncMember( rid, syncMembers )
    end

    -- 更新角色当前的客户端成员标识
    RoleLogic:updateRoleGuildIndexs( rid, { guildMemberIndex = memberGlobalIndex } )
end

---@see 联盟成员升降级
function response.ModifyMemberLevel( msg )
    local rid = msg.rid
    local memberRid = msg.memberRid
    local newGuildJob = msg.newGuildJob

    -- 参数检查
    if not memberRid or not newGuildJob or newGuildJob > Enum.GuildJob.LEADER then
        LOG_ERROR("rid(%d) ModifyMemberLevel, no memberRid or newGuildJob arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) ModifyMemberLevel, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    return MSM.GuildMgr[guildId].req.modifyMemberLevel( guildId, rid, memberRid, newGuildJob )
end

---@see 移除联盟成员
function response.KickMember( msg )
    local rid = msg.rid
    local memberRid = msg.memberRid
    local reasonId = msg.reasonId

    -- 参数检查
    if not memberRid or memberRid == rid or not reasonId or reasonId <= 0 then
        LOG_ERROR("rid(%d) ModifyMemberLevel, no memberRid or reasonId arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) KickMember, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    return MSM.GuildMgr[guildId].req.kickMember( guildId, rid, memberRid, reasonId )
end

---@see 退出联盟
function response.ExitGuild( msg )
    local rid = msg.rid
    local type = msg.type

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) ExitGuild, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    local guildJob = GuildLogic:getRoleGuildJob( guildId, rid )
    if type == Enum.GuildExitType.EXIT then
        -- 退出联盟
        -- 角色是否有退出联盟权限
        if not GuildLogic:checkRoleJurisdiction( rid, Enum.GuildJurisdictionType.EXIT, guildJob ) then
            LOG_ERROR("rid(%d) ExitGuild, role no exit guild jurisdiction", rid)
            return nil, ErrorCode.GUILD_NO_JURISDICTION
        end
    elseif type == Enum.GuildExitType.DISBAND then
        -- 解散联盟
        -- 角色是否有解散联盟权限
        if not GuildLogic:checkRoleJurisdiction( rid, Enum.GuildJurisdictionType.DISBAND, guildJob ) then
            LOG_ERROR("rid(%d) ExitGuild, role no disband guild jurisdiction", rid)
            return nil, ErrorCode.GUILD_NO_JURISDICTION
        end
    else
        LOG_ERROR("rid(%d) ExitGuild, type(%d) arg error", rid, type)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 退出或解散联盟处理
    return MSM.GuildMgr[guildId].req.exitGuild( guildId, rid, type )
end

---@see 任命官员
function response.AppointOfficer( msg )
    local rid = msg.rid
    local memberRid = msg.memberRid
    local officerId = msg.officerId

    -- 参数检查
    if not memberRid or not officerId or officerId <= 0 then
        LOG_ERROR("rid(%d) AppointOfficer, no memberRid or officerId arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) AppointOfficer, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 任命官员
    return MSM.GuildMgr[guildId].req.appointOfficer( guildId, rid, memberRid, officerId )
end

---@see 获取联盟仓库信息
function response.GetGuildDepot( msg )
    local rid = msg.rid

    -- 角色是否在联盟中
    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.guildId, Enum.Role.guildIndexs } )
    if not roleInfo.guildId or roleInfo.guildId <= 0 then
        LOG_ERROR("rid(%d) GetGuildDepot, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    local guildDepotRecordIndex = roleInfo.guildIndexs and roleInfo.guildIndexs.guildDepotRecordIndex or 0
    local guildInfo = GuildLogic:getGuild( roleInfo.guildId, { Enum.Guild.consumeRecords } )
    local guildDepotRecordGlobalIndex = MSM.GuildIndexMgr[roleInfo.guildId].req.getGuildDepotRecordIndex( roleInfo.guildId )
    if guildDepotRecordGlobalIndex > guildDepotRecordIndex then
        GuildLogic:syncGuildDepot( rid, nil, guildInfo.consumeRecords )
        -- 更新客户端当前的仓库记录修改标识
        RoleLogic:updateRoleGuildIndexs( rid, { guildDepotRecordIndex = guildDepotRecordGlobalIndex } )
    end
end

---@see 获取联盟求助信息
function response.GetGuildRequestHelps( msg )
    local rid = msg.rid

    -- 角色是否在联盟中
    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.guildId, Enum.Role.guildIndexs } )
    if not roleInfo.guildId or roleInfo.guildId <= 0 then
        LOG_ERROR("rid(%d) GetGuildRequestHelps, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    local guildRequestHelpIndex = roleInfo.guildIndexs and roleInfo.guildIndexs.guildRequestHelpIndex or 0
    -- 当前客户端是否已为最新联盟求助信息
    local requestHelpGlobalIndex = MSM.GuildIndexMgr[roleInfo.guildId].req.getRequestHelpGlobalIndex( roleInfo.guildId )
    if guildRequestHelpIndex >= requestHelpGlobalIndex then
        return
    end

    local syncRequestHelps = {}
    local deleteHelpIndexs = {}
    local requestHelps = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.requestHelps ) or {}
    local requestIndexs = MSM.GuildIndexMgr[roleInfo.guildId].req.getRequestHelpIndexs( roleInfo.guildId )
    for index, requestInfo in pairs( requestHelps ) do
        if not requestInfo.helps[rid] and guildRequestHelpIndex < ( requestIndexs[index] or 0 ) then
            -- 1. 角色已经帮助过的不推送
            -- 2. 求助信息有更新的要推送
            if requestInfo.rid == rid then
                -- 自己的求助信息更新要推送
                syncRequestHelps[index] = {
                    index = index,
                    rid = requestInfo.rid,
                    type = requestInfo.type,
                    args = requestInfo.args,
                    helpNum = requestInfo.helpNum,
                    helpLimit = requestInfo.helpLimit,
                    reduceTime = requestInfo.reduceTime,
                }
            else
                if requestInfo.helpNum >= requestInfo.helpLimit then
                    -- 帮助到上限的求助要删除
                    table.insert( deleteHelpIndexs, index )
                else
                    -- 帮助不到上限的求助要推送
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
        end
    end

    -- 推送修改的联盟求助信息
    if not table.empty( syncRequestHelps ) then
        if table.empty( deleteHelpIndexs ) then
            deleteHelpIndexs = nil
        end
        GuildLogic:syncGuildRequestHelps( rid, syncRequestHelps, deleteHelpIndexs )
    end

    -- 更新角色当前的客户端联盟求助信息标识
    RoleLogic:updateRoleGuildIndexs( rid, { guildRequestHelpIndex = requestHelpGlobalIndex } )
end

---@see 发送联盟求助
function response.SendRequestHelp( msg )
    local rid = msg.rid
    local requestType = msg.requestType
    local queueIndex = msg.queueIndex

    -- 参数检查
    if not requestType or not queueIndex then
        LOG_ERROR("rid(%d) SendRequestHelp, no requestType or no queueIndex arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) SendRequestHelp, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    return MSM.GuildMgr[guildId].req.sendRequestHelp( guildId, rid, requestType, queueIndex )
end

---@see 帮助联盟成员
function response.HelpGuildMembers( msg )
    local rid = msg.rid

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) SendRequestHelp, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 帮助联盟成员
    MSM.GuildMgr[guildId].post.helpGuildMembers( guildId, rid )

    return { result = true }
end

---@see 创建联盟建筑
function response.CreateGuildBuild( msg )
    local rid = msg.rid
    local type = msg.type
    local pos = msg.pos

    -- 参数检查
    if not type or not pos then
        LOG_ERROR("rid(%d) CreateGuildBuild, no type or no pos arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) CreateGuildBuild, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 创建联盟
    local ret, error = MSM.GuildMgr[guildId].req.createGuildBuild( guildId, rid, type, pos )
    if ret then
        return { objectIndex = ret, pos = pos }
    else
        return nil, error
    end
end

---@see 拆除联盟建筑
function response.RemoveGuildBuild( msg )
    local rid = msg.rid
    local targetIndex = msg.targetIndex

    -- 参数检查
    if not targetIndex or targetIndex <= 0 then
        LOG_ERROR("rid(%d) RemoveGuildBuild, no targetIndex arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) RemoveGuildBuild, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 角色是否有拆除建筑权限
    local guildJob = GuildLogic:getRoleGuildJob( guildId, rid )
    if not GuildLogic:checkRoleJurisdiction( rid, Enum.GuildJurisdictionType.REMOVE_BUILDING, guildJob ) then
        LOG_ERROR("rid(%d) RemoveGuildBuild, role no remove guild build jurisdiction", rid)
        return nil, ErrorCode.GUILD_NO_JURISDICTION
    end

    -- 建筑是否存在
    local guildBuildInfo = MSM.SceneGuildBuildMgr[targetIndex].req.getGuildBuildInfo( targetIndex )
    if not guildBuildInfo or table.empty( guildBuildInfo ) then
        LOG_ERROR("rid(%d) RemoveGuildBuild, objectIndex(%d) not exist", rid, targetIndex)
        return nil, ErrorCode.GUILD_BUILD_NOT_EXIST
    end

    -- 是否为本联盟的建筑
    if guildBuildInfo.guildId ~= guildId then
        LOG_ERROR("rid(%d) RemoveGuildBuild, can't remove other guild(%d) build", rid, guildBuildInfo.guildId)
        return nil, ErrorCode.GUILD_CANT_REMOVE_OTHER_GUILD
    end

    -- 移除联盟建筑
    MSM.GuildMgr[guildId].post.removeGuildBuild( guildId, guildBuildInfo.buildIndex, rid )
end

---@see 维修联盟建筑
function response.RepairGuildBuild( msg )
    local rid = msg.rid
    local targetIndex = msg.targetIndex
    local type = msg.type

    -- 参数检查
    if not targetIndex or targetIndex <= 0 or not type then
        LOG_ERROR("rid(%d) RepairGuildBuild, no targetIndex or no type arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) RepairGuildBuild, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 建筑是否存在
    local guildBuildInfo = MSM.SceneGuildBuildMgr[targetIndex].req.getGuildBuildInfo( targetIndex )
    if not guildBuildInfo or table.empty( guildBuildInfo ) then
        LOG_ERROR("rid(%d) RepairGuildBuild, objectIndex(%d) not exist", rid, targetIndex)
        return nil, ErrorCode.GUILD_BUILD_NOT_EXIST
    end

    -- 是否为本联盟的建筑
    if guildBuildInfo.guildId ~= guildId then
        LOG_ERROR("rid(%d) RepairGuildBuild, can't repair other guild(%d) build", rid, guildId, guildBuildInfo.guildId)
        return nil, ErrorCode.GUILD_CANT_REPAIR_OTHER_GUILD
    end

    if type == Enum.GuildRepairType.DENAR or type == Enum.GuildRepairType.GUILD_POINT then
        -- 使用代币、联盟积分灭火
        return MSM.GuildMgr[guildId].req.repairGuildBuild( guildId, guildBuildInfo.buildIndex, rid, type )
    else
        LOG_ERROR("rid(%d) RepairGuildBuild, type(%d) arg error", rid, type)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end
end

---@see 修改联盟信息
function response.ModifyGuildInfo( msg )
    local rid = msg.rid
    local type = msg.type
    local newValue = msg.newValue

    -- 参数检查
    if not type or ( type ~= Enum.GuildModifyType.SIGNS and type ~= Enum.GuildModifyType.MESSAGE_BOARD and not newValue ) then
        LOG_ERROR("rid(%d) ModifyGuildInfo, arg error", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) ModifyGuildInfo, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 角色是否有设置联盟属性权限
    local guildJob = GuildLogic:getRoleGuildJob( guildId, rid )
    if type ~= Enum.GuildModifyType.MESSAGE_BOARD then
        if not GuildLogic:checkRoleJurisdiction( rid, Enum.GuildJurisdictionType.EDIT_GUILD_INFO, guildJob ) then
            LOG_ERROR("rid(%d) ModifyGuildInfo, role guildJob(%d) no edit guild info jurisdiction", rid, guildJob)
            return nil, ErrorCode.GUILD_NO_JURISDICTION
        end
    else
        -- 开启关闭留言板只有R4官员和盟主有权限
        if guildJob < Enum.GuildJob.R4 or ( guildJob == Enum.GuildJob.R4 and not GuildLogic:checkRoleOfficer( guildId, rid ) ) then
            LOG_ERROR("rid(%d) ModifyGuildInfo, role guildJob(%d) no edit message board jurisdiction", rid, guildJob)
            return nil, ErrorCode.GUILD_NO_JURISDICTION
        end
    end

    local sConfig = CFG.s_Config:Get()
    local guildChangeInfo, noSync, messageBoardStatus
    if type == Enum.GuildModifyType.ABB_NAME then
        -- 修改联盟简称
        local guildAbbName = GuildLogic:getGuild( guildId, Enum.Guild.abbreviationName )
        -- 简称是否有修改
        if guildAbbName == newValue then
            LOG_ERROR("rid(%d) ModifyGuildInfo, abbreviationName(%s) not modify", rid, newValue)
            return nil, ErrorCode.GUILD_ABBNAME_NOT_MODIFY
        end

        -- 简称长度判断
        local strLen = utf8.len( newValue )
        if sConfig.allianceAbbreviationMin > strLen or sConfig.allianceAbbreviationMax < strLen then
            LOG_ERROR("rid(%d) ModifyGuildInfo, abbreviationName(%s) length error", rid, newValue)
            return nil, ErrorCode.GUILD_ABBNAME_LENGTH_ERROR
        end

        -- 简称是否只包括数字、字母和特殊符号
        if not GuildLogic:checkGuildAbbName( newValue ) then
            LOG_ERROR("rid(%d) ModifyGuildInfo, abbreviationName(%s) char error", rid, newValue)
            return nil, ErrorCode.GUILD_ABBNAME_CHAR_ERROR
        end

        -- 简称是否有效
        if not RoleLogic:checkBlockName( newValue ) then
            LOG_ERROR("rid(%d) ModifyGuildInfo, abbreviationName(%s) invalid", rid, newValue)
            return nil, ErrorCode.GUILD_ABBNAME_INVALID
        end

        -- 角色代币是否足够
        local allianceAbbreviationAmend = sConfig.allianceAbbreviationAmend or 0
        if allianceAbbreviationAmend > 0 and not RoleLogic:checkDenar( rid, allianceAbbreviationAmend ) then
            LOG_ERROR("rid(%d) ModifyGuildInfo, role denar not enough", rid, newValue)
            return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
        end

        -- 占用联盟简称
        local guildNode = Common.getSelfNodeName()
        if SM.GuildNameProxy.req.modifyGuildAbbName( guildNode, guildId, newValue, guildAbbName ) ~= Enum.GuildNameRepeat.NO_REPEAT then
            LOG_ERROR("rid(%d) ModifyGuildInfo, abbreviationName(%s) repeat", rid, newValue)
            return nil, ErrorCode.GUILD_ABBNAME_REPEAT
        end

        if allianceAbbreviationAmend > 0 then
            -- 扣除代币
            RoleLogic:addDenar( rid, - allianceAbbreviationAmend, nil, Enum.LogType.MODIFY_GUILD_COST_CURRENCY )
        end

        guildChangeInfo = { [Enum.Guild.abbreviationName] = newValue }
    elseif type == Enum.GuildModifyType.NAME then
        -- 修改联盟名称
        local guildName = GuildLogic:getGuild( guildId, Enum.Guild.name )
        -- 名称是否有修改
        if guildName == newValue then
            LOG_ERROR("rid(%d) ModifyGuildInfo, name(%s) not modify", rid, newValue)
            return nil, ErrorCode.GUILD_NAME_NOT_MODIFY
        end

        -- 联盟名称是否包含非法字符
        if not GuildLogic:checkGuildName( newValue ) then
            LOG_ERROR("rid(%d) CreateGuild, name(%s) invalid", rid, newValue)
            return nil, ErrorCode.GUILD_NAME_INVALID
        end

        -- 联盟名称长度错误
        local strLen = utf8.len( newValue )
        if sConfig.allianceNameMin > strLen or sConfig.allianceNameMax < strLen then
            LOG_ERROR("rid(%d) ModifyGuildInfo, name(%s) length error", rid, newValue)
            return nil, ErrorCode.GUILD_NAME_LENGTH_ERROR
        end

        -- 名称是否有效
        if not RoleLogic:checkBlockName( newValue ) then
            LOG_ERROR("rid(%d) ModifyGuildInfo, name(%s) invalid", rid, newValue)
            return nil, ErrorCode.GUILD_NAME_INVALID
        end

        -- 角色代币是否足够
        local allianceNameAmend = sConfig.allianceNameAmend or 0
        if allianceNameAmend > 0 and not RoleLogic:checkDenar( rid, allianceNameAmend ) then
            LOG_ERROR("rid(%d) ModifyGuildInfo, role denar not enough", rid, newValue)
            return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
        end

        -- 占用联盟简称
        local guildNode = Common.getSelfNodeName()
        if SM.GuildNameProxy.req.modifyGuildName( guildNode, guildId, newValue, guildName ) ~= Enum.GuildNameRepeat.NO_REPEAT then
            LOG_ERROR("rid(%d) ModifyGuildInfo, abbreviationName(%s) repeat", rid, newValue)
            return nil, ErrorCode.GUILD_NAME_REPEAT
        end

        if allianceNameAmend > 0 then
            -- 扣除代币
            RoleLogic:addDenar( rid, - allianceNameAmend, nil, Enum.LogType.MODIFY_GUILD_COST_CURRENCY )
        end

        guildChangeInfo = { [Enum.Guild.name] = newValue }
    elseif type == Enum.GuildModifyType.WELCOME_EMAIL then
        -- 修改欢迎邮件
        -- 邮件长度判断
        if utf8.len( newValue ) > CFG.s_Config:Get( "emailContentLimit" ) then
            LOG_ERROR("rid(%d) ModifyGuildInfo, welcomeEmail(%s) length limit", rid, newValue)
            return nil, ErrorCode.GUILD_WELCOM_EMAIL_LEN_LIMIT
        end

        -- 邮件内容是否有效判断
        if not RoleLogic:checkBlockName( newValue ) then
            LOG_ERROR("rid(%d) ModifyGuildInfo, welcomeEmail(%s) invalid", rid, newValue)
            return nil, ErrorCode.GUILD_WELCOME_EMAIL_INVALID
        end

        guildChangeInfo = { [Enum.Guild.welcomeEmail] = newValue, [Enum.Guild.welcomeEmailFlag] = true }
    elseif type == Enum.GuildModifyType.NOTICE then
        -- 修改联盟公告、入盟要求和语言
        -- 公告是否超长
        if sConfig.allianceNoticeNum < utf8.len( newValue ) then
            LOG_ERROR("rid(%d) ModifyGuildInfo, notice(%s) too long", rid, newValue)
            return nil, ErrorCode.GUILD_NOTICE_LENGTH_ERROR
        end

        -- 公告是否有效
        if not RoleLogic:checkBlockName( newValue ) then
            LOG_ERROR("rid(%d) ModifyGuildInfo, notice(%s) invalid", rid, newValue)
            return nil, ErrorCode.GUILD_NOTICE_INVALID
        end

        if not msg.languageId or msg.languageId < 0 then
            LOG_ERROR("rid(%d) ModifyGuildInfo, languageId arg error", rid)
            return nil, ErrorCode.GUILD_ARG_ERROR
        end

        guildChangeInfo = {
            [Enum.Guild.notice] = newValue,
            [Enum.Guild.needExamine] = msg.needExamine or false,
            [Enum.Guild.languageId] = msg.languageId,
        }
    elseif type == Enum.GuildModifyType.SIGNS then
        local newSigns = msg.newSigns
        -- 修改联盟标识
        if not newSigns or #newSigns <= 0 then
            LOG_ERROR("rid(%d) ModifyGuildInfo, newSigns arg error", rid)
            return nil, ErrorCode.GUILD_ARG_ERROR
        end

        -- 联盟标识是否修改
        local guildSigns = GuildLogic:getGuild( guildId, Enum.Guild.signs ) or {}
        if #guildSigns == #newSigns then
            local modify
            for _, signId in pairs( newSigns ) do
                if not table.exist( guildSigns, signId ) then
                    modify = true
                    break
                end
            end
            -- 联盟标识是否修改
            if not modify then
                LOG_ERROR("rid(%d) ModifyGuildInfo, signs(%s) not modify", rid, tostring(newSigns))
                return nil, ErrorCode.GUILD_SIGN_NOT_MODIFY
            end
        end

        -- 角色代币是否足够
        if sConfig.alliancSignAmend and sConfig.alliancSignAmend > 0 then
            if not RoleLogic:checkDenar( rid, sConfig.alliancSignAmend ) then
                LOG_ERROR("rid(%d) ModifyGuildInfo, role denar not enough", rid, newValue)
                return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
            end

            -- 扣除代币
            RoleLogic:addDenar( rid, - sConfig.alliancSignAmend, nil, Enum.LogType.MODIFY_GUILD_COST_CURRENCY )
        end

        guildChangeInfo = { [Enum.Guild.signs] = msg.newSigns }
    elseif type == Enum.GuildModifyType.MESSAGE_BOARD then
        messageBoardStatus = not GuildLogic:getGuild( guildId, Enum.Guild.messageBoardStatus )
        guildChangeInfo = { [Enum.Guild.messageBoardStatus] = messageBoardStatus }
        noSync = true
    else
        -- 参数错误
        LOG_ERROR("rid(%d) modifyGuildInfo, type(%d) arg error", rid, type)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 更新联盟信息
    MSM.GuildMgr[guildId].post.modifyGuildInfo( guildId, rid, type, guildChangeInfo, noSync )

    return { type = type, messageBoardStatus = messageBoardStatus }
end

---@see 检查建筑是否可以创建到指定坐标点
function response.CheckGuildBuildCreate( msg )
    local rid = msg.rid
    local type = msg.type
    local pos = msg.pos

    -- 参数检查
    if not type or not pos then
        LOG_ERROR("rid(%d) CheckGuildBuildCreate, no type or no pos arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    local ret, error = GuildBuildLogic:checkGuildBuildCreate( rid, nil, type, pos )
    if not ret then
        LOG_ERROR("rid(%d) CheckGuildBuildCreate, check create guild build failed error(%d)", rid, error)
        return nil, error
    else
        return { type = type, pos = pos, result = true }
    end
end

---@see 领取联盟领土收益
function response.TakeGuildTerritoryGain( msg )
    local rid = msg.rid

    -- 角色是否在联盟中
    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.guildId, Enum.Role.level } )
    if not roleInfo.guildId or roleInfo.guildId <= 0 then
        LOG_ERROR("rid(%d) TakeGuildTerritoryGain, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 市政厅等级是否满足
    local allianceResourcePersonRequestLv = CFG.s_Config:Get( "allianceResourcePersonRequestLv" ) or 0
    if roleInfo.level < allianceResourcePersonRequestLv then
        LOG_ERROR("rid(%d) TakeGuildTerritoryGain, role level(%d) not enough", rid, roleInfo.level)
        return nil, ErrorCode.GUILD_TERRITORY_GAIN_LEVEL_ERROR
    end
    -- 领取收益
    MSM.GuildMgr[roleInfo.guildId].post.takeGuildTerritoryGain( roleInfo.guildId, rid )
end

---@see 获取联盟建筑信息
function response.GetGuildBuilds( msg )
    local rid = msg.rid
    local reqType = msg.reqType

    -- 角色是否在联盟中
    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.guildId, Enum.Role.guildIndexs } )
    local guildId = roleInfo.guildId or 0
    if guildId <= 0 then
        LOG_ERROR("rid(%d) GetGuildBuilds, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 联盟建筑信息是否有变化
    local guildFortresses = {}
    local guildResourceCenter = {}
    local guildFlags = {}
    local battleStatus = Enum.ArmyStatus.BATTLEING
    local guildBuildGlobalIndex = MSM.GuildIndexMgr[guildId].req.getBuildGlobalIndex( guildId )
    local roleBuildIndex = roleInfo.guildIndexs and roleInfo.guildIndexs.guildBuildIndex or 0
    if roleBuildIndex < guildBuildGlobalIndex then
        local guildBuildIndexs = MSM.GuildIndexMgr[guildId].req.getBuildIndexs( guildId )
        local objectIndexs = MSM.GuildBuildIndexMgr[guildId].req.getGuildBuildIndexs( guildId ) or {}
        local guildBuilds = GuildBuildLogic:getGuildBuild( guildId ) or {}
        local buildRateInfo, buildBurnInfo, buildInfo, buildObjectIndex, guildBuildStatus, isBattle
        for buildIndex, modifyIndex in pairs( guildBuildIndexs ) do
            if modifyIndex > roleBuildIndex then
                buildInfo = guildBuilds[buildIndex]
                buildBurnInfo = guildBuilds[buildIndex].buildBurnInfo
                buildRateInfo = guildBuilds[buildIndex].buildRateInfo
                buildObjectIndex = objectIndexs[buildIndex] or 0
                if buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS
                    or buildInfo.type == Enum.GuildBuildType.FORTRESS_FIRST
                    or buildInfo.type == Enum.GuildBuildType.FORTRESS_SECOND then
                    -- 联盟要塞信息
                    guildFortresses[buildIndex] = {
                        buildIndex = buildIndex,
                        type = buildInfo.type,
                        pos = buildInfo.pos,
                        status = buildInfo.status,
                        objectIndex = buildObjectIndex,
                    }
                    if buildInfo.status == Enum.GuildBuildStatus.BUILDING then
                        -- 建造中显示建造进度
                        guildFortresses[buildIndex].buildProgress = buildRateInfo.buildRate
                        guildFortresses[buildIndex].buildProgressTime = buildRateInfo.lastRateTime
                        guildFortresses[buildIndex].buildFinishTime = buildRateInfo.finishTime
                        guildFortresses[buildIndex].isReinforce = GuildBuildLogic:checkIsReinforce( nil, nil, buildInfo.reinforces, rid )
                    else
                        -- 其他状态显示耐久度
                        guildFortresses[buildIndex].durable = buildInfo.durable
                        guildFortresses[buildIndex].durableLimit = buildInfo.durableLimit
                        guildFortresses[buildIndex].isReinforce = true
                        if buildInfo.status == Enum.GuildBuildStatus.BURNING then
                            guildFortresses[buildIndex].burnSpeed = buildBurnInfo.burnSpeed
                            guildFortresses[buildIndex].burnTime = buildBurnInfo.burnTime
                        elseif buildInfo.status == Enum.GuildBuildStatus.REPAIR then
                            guildFortresses[buildIndex].durableRecoverTime = buildBurnInfo.lastDurableTime
                        end
                    end
                    guildBuildStatus = MSM.SceneGuildBuildMgr[buildObjectIndex].req.getGuildBuildStatus( buildObjectIndex )
                    guildFortresses[buildIndex].isBattle = ArmyLogic:checkArmyStatus( guildBuildStatus, battleStatus )
                elseif buildInfo.type >= Enum.GuildBuildType.FOOD_CENTER and buildInfo.type <= Enum.GuildBuildType.GOLD_CENTER then
                    -- 联盟资源中心信息
                    guildResourceCenter = {
                        resourceCenter = {
                            buildIndex = buildIndex,
                            type = buildInfo.type,
                            pos = buildInfo.pos,
                            status = buildInfo.status,
                            objectIndex = objectIndexs[buildIndex],
                        }
                    }
                    if buildInfo.status == Enum.GuildBuildStatus.BUILDING then
                        -- 建造中显示建造进度
                        guildResourceCenter.resourceCenter.buildProgress = buildRateInfo.buildRate
                        guildResourceCenter.resourceCenter.buildProgressTime = buildRateInfo.lastRateTime
                        guildResourceCenter.resourceCenter.buildFinishTime = buildRateInfo.finishTime
                        guildResourceCenter.resourceCenter.isReinforce = GuildBuildLogic:checkIsReinforce( nil, nil, buildInfo.reinforces, rid )
                    else
                        guildResourceCenter.resource = buildInfo.resourceCenter.resourceNum
                        guildResourceCenter.collectTime = buildInfo.resourceCenter.lastCollectTime
                        guildResourceCenter.collectSpeed = buildInfo.resourceCenter.collectSpeed
                        guildResourceCenter.resourceCenter.isReinforce = true
                    end
                elseif buildInfo.type == Enum.GuildBuildType.FLAG then
                    if not guildFlags.flags then guildFlags.flags = {} end
                    -- 联盟旗帜信息
                    guildBuildStatus = MSM.SceneGuildBuildMgr[buildObjectIndex].req.getGuildBuildStatus( buildObjectIndex )
                    isBattle = ArmyLogic:checkArmyStatus( guildBuildStatus, battleStatus )
                    if buildInfo.status == Enum.GuildBuildStatus.BUILDING then
                        -- 建造中
                        guildFlags.flags[buildIndex] = {
                            buildIndex = buildIndex,
                            type = buildInfo.type,
                            pos = buildInfo.pos,
                            status = buildInfo.status,
                            objectIndex = buildObjectIndex,
                            isBattle = isBattle,
                        }
                        -- 建造中显示建造进度
                        guildFlags.flags[buildIndex].buildProgress = buildRateInfo.buildRate
                        guildFlags.flags[buildIndex].buildProgressTime = buildRateInfo.lastRateTime
                        guildFlags.flags[buildIndex].buildFinishTime = buildRateInfo.finishTime
                        guildFlags.flags[buildIndex].isReinforce = GuildBuildLogic:checkIsReinforce( nil, nil, buildInfo.reinforces, rid )
                    elseif buildInfo.status ~= Enum.GuildBuildStatus.NORMAL or isBattle then
                        -- 非正常状态的旗帜
                        guildFlags.flags[buildIndex] = {
                            buildIndex = buildIndex,
                            type = buildInfo.type,
                            pos = buildInfo.pos,
                            status = buildInfo.status,
                            isReinforce = true,
                            objectIndex = buildObjectIndex,
                            durable = buildInfo.durable,
                            durableLimit = buildInfo.durableLimit,
                            isBattle = isBattle,
                        }
                        if buildInfo.status == Enum.GuildBuildStatus.BURNING then
                            guildFlags.flags[buildIndex].burnSpeed = buildBurnInfo.burnSpeed
                            guildFlags.flags[buildIndex].burnTime = buildBurnInfo.burnTime
                        elseif buildInfo.status == Enum.GuildBuildStatus.REPAIR then
                            guildFlags.flags[buildIndex].durableRecoverTime = buildBurnInfo.lastDurableTime
                        end
                    end
                end
            end
        end
    end

    -- 联盟资源点信息
    local guildInfo = GuildLogic:getGuild( guildId, {
        Enum.Guild.resourcePoints, Enum.Guild.members, Enum.Guild.territory, Enum.Guild.territoryLimit
    } )
    local guildResourcePointIndex = MSM.GuildIndexMgr[guildId].req.getResourcePointIndex( guildId )
    local guildResourcePoint, roleTerritoryGains, lastTakeGainTime
    local roleResourcePointIndex = roleInfo.guildIndexs and roleInfo.guildIndexs.guildResourcePointIndex or 0
    if roleResourcePointIndex < guildResourcePointIndex then
        -- 联盟资源点信息变化
        local resourcePoints = guildInfo.resourcePoints or {}
        guildResourcePoint = {
            foodPoint = resourcePoints[Enum.GuildBuildType.FOOD] and resourcePoints[Enum.GuildBuildType.FOOD].num or 0,
            woodPoint = resourcePoints[Enum.GuildBuildType.WOOD] and resourcePoints[Enum.GuildBuildType.WOOD].num or 0,
            stonePoint = resourcePoints[Enum.GuildBuildType.STONE] and resourcePoints[Enum.GuildBuildType.STONE].num or 0,
            goldPoint = resourcePoints[Enum.GuildBuildType.GOLD] and resourcePoints[Enum.GuildBuildType.GOLD].num or 0,
        }
        -- 个人联盟资源点收益信息变化
        roleTerritoryGains = guildInfo.members[rid].roleTerritoryGains
        lastTakeGainTime = guildInfo.members[rid].lastTakeGainTime
    end

    guildFlags.flagNum = guildInfo.territory
    guildFlags.flagLimit = guildInfo.territoryLimit

    -- 推送到客户端
    GuildBuildLogic:synGuildBuild( rid, guildFortresses, guildResourceCenter, guildFlags, guildResourcePoint, roleTerritoryGains, lastTakeGainTime, nil, reqType )
    -- 更新角色相关联盟修改标识
    RoleLogic:updateRoleGuildIndexs( rid, { guildBuildIndex = guildBuildGlobalIndex, guildResourcePointIndex = guildResourcePointIndex } )
end

---@see 获取联盟科技捐献点信息
function response.GetTechnologyDonate( msg )
    local rid = msg.rid
    local technologyType = msg.technologyType

    -- 参数检查
    if not technologyType then
        LOG_ERROR("rid(%d) GetTechnologyDonate, no technologyType arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) GetTechnologyDonate, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    local technologies = GuildLogic:getGuild( guildId, Enum.Guild.technologies ) or {}
    return {
        technologyType = technologyType,
        exp = technologies[technologyType] and technologies[technologyType].exp or 0,
    }
end

---@see 联盟科技捐献
function response.DonateTechnology( msg )
    local rid = msg.rid
    local technologyType = msg.technologyType
    local donateType = msg.donateType

    -- 参数检查
    if not technologyType or not donateType then
        LOG_ERROR("rid(%d) DonateTechnology, no technologyType or donateType arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) DonateTechnology, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    return MSM.GuildMgr[guildId].req.donateTechnology( guildId, rid, donateType, technologyType )
end

---@see 设置联盟推荐科技
function response.RecommendTechnology( msg )
    local rid = msg.rid
    local technologyType = msg.technologyType

    -- 参数检查
    if not technologyType then
        LOG_ERROR("rid(%d) RecommendTechnology, no technologyType arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) RecommendTechnology, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 角色是否有权限
    local guildJob = GuildLogic:getRoleGuildJob( guildId, rid )
    if guildJob < Enum.GuildJob.R4 then
        LOG_ERROR("rid(%d) RecommendTechnology, role guildJob(%d) no recommend technology jurisdiction", rid, guildJob)
        return nil, ErrorCode.GUILD_NO_RECOMMEND_TECHNOLOGY
    end

    -- 设置联盟推荐科技
    MSM.GuildMgr[guildId].post.recommendTechnology( guildId, technologyType )
end

---@see 研究联盟科技
function response.ResearchTechnology( msg )
    local rid = msg.rid
    local technologyType = msg.technologyType

    -- 参数检查
    if not technologyType then
        LOG_ERROR("rid(%d) ResearchTechnology, no technologyType arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) ResearchTechnology, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 角色是否有权限
    local guildJob = GuildLogic:getRoleGuildJob( guildId, rid )
    if guildJob < Enum.GuildJob.R4 then
        LOG_ERROR("rid(%d) ResearchTechnology, role guildJob(%d) no research technology jurisdiction", rid, guildJob)
        return nil, ErrorCode.GUILD_NO_RESEARCH_TECHNOLOGY
    end
    -- 研究联盟科技
    MSM.GuildMgr[guildId].post.researchTechnology( guildId, rid, technologyType )
end

---@see 获取其他联盟属性
function response.GetOtherGuildInfo( msg )
    local rid = msg.rid
    local guildId = msg.guildId or 0

    -- 参数检查
    if guildId <= 0 then
        LOG_ERROR("rid(%d) GetOtherGuildInfo, no guildId arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 联盟是否存在
    local guildGameNode = SM.GuildNameProxy.req.getGuildGameNode( guildId )
    if not guildGameNode then
        LOG_ERROR("rid(%d) GetOtherGuildInfo, guildId(%d) not exist", rid, guildId)
        return nil, ErrorCode.GUILD_NOT_EXIST
    end

    local guildInfo = {}
    local guildFields = {
        Enum.Guild.name, Enum.Guild.abbreviationName, Enum.Guild.notice, Enum.Guild.signs,
        Enum.Guild.leaderRid, Enum.Guild.power, Enum.Guild.members, Enum.Guild.territory,
        Enum.Guild.memberLimit, Enum.Guild.guildId, Enum.Guild.giftLevel
    }
    local guild = Common.rpcCall( guildGameNode, "c_guild", "Get", guildId, guildFields )
    if guild and not table.empty( guild ) then
        guildInfo = {
            guildId = guild.guildId,
            name = guild.name,
            abbreviationName = guild.abbreviationName,
            notice = guild.notice,
            signs = guild.signs,
            power = guild.power,
            territory = guild.territory,
            giftLevel = guild.giftLevel,
            memberNum = table.size( guild.members or {} ),
            memberLimit = guild.memberLimit,
            leaderRid = guild.leaderRid,
            leaderName = Common.rpcMultiCall( guildGameNode, "d_role", "Get", guild.leaderRid, Enum.Role.name ),
        }
    end

    return {
        guildId = guildId, guildInfo = guildInfo
    }
end

---@see 获取其他联盟成员信息
function response.GetOtherGuildMembers( msg )
    local rid = msg.rid
    local guildId = msg.guildId or 0

    -- 参数检查
    if guildId <= 0 then
        LOG_ERROR("rid(%d) GetOtherGuildMembers, no guildId arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 联盟是否存在
    local guildGameNode = SM.GuildNameProxy.req.getGuildGameNode( guildId )
    if not guildGameNode then
        LOG_ERROR("rid(%d) GetOtherGuildMembers, guildId(%d) not exist", rid, guildId)
        return nil, ErrorCode.GUILD_NOT_EXIST
    end

    local memberInfo
    local guildMembers = {}
    local guildOfficers = {}
    local guildFields = { Enum.Guild.members, Enum.Guild.guildOfficers }
    local roleFields = {
        Enum.Role.rid, Enum.Role.headId, Enum.Role.name, Enum.Role.killCount, Enum.Role.headFrameID
    }
    -- 获取联盟属性
    local guildInfo = Common.rpcCall( guildGameNode, "c_guild", "Get", guildId, guildFields )
    if guildInfo and not table.empty( guildInfo ) then
        for memberRid, member in pairs( guildInfo.members or {} ) do
            -- 获取联盟成员信息
            memberInfo = Common.rpcMultiCall( guildGameNode, "d_role", "Get", memberRid, roleFields )
            if memberInfo then
                guildMembers[memberRid] = {
                    rid = memberRid,
                    headId = memberInfo.headId,
                    name = memberInfo.name,
                    killCount = memberInfo.killCount,
                    headFrameID = memberInfo.headFrameID,
                    guildJob = member.guildJob,
                    combatPower = member.combatPower,
                }
            end
        end

        for officerId, officer in pairs( guildInfo.guildOfficers or {} ) do
            if officer.rid > 0 then
                guildOfficers[officerId] = officer
            end
        end
    end

    return { guildId = guildId, guildMembers = guildMembers, guildOfficers = guildOfficers }
end

---@see 获取联盟留言板信息
function response.GetGuildMessageBoard( msg )
    local rid = msg.rid
    local guildId = msg.guildId
    local messageIndex = msg.messageIndex
    local type = msg.type

    -- 参数检查
    if not guildId or not type then
        LOG_ERROR("rid(%d) GetGuildMessageBoard, no guildId or no type arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 联盟是否存在
    local guildGameNode = SM.GuildNameProxy.req.getGuildGameNode( guildId )
    if not guildGameNode then
        LOG_ERROR("rid(%d) GetGuildMessageBoard, guildId(%d) not exist", rid, guildId)
        return nil, ErrorCode.GUILD_NOT_EXIST
    end

    local ret = Common.rpcMultiCall( guildGameNode, "GuildMessageBoardMgr", "getMessageBoard", guildId, type, messageIndex, rid )
    if ret then
        return {
            messages = ret.messages,
            messageBoardStatus = ret.messageBoardStatus
        }
    end

    return {}
end

---@see 发布联盟留言板消息
function response.SendBoardMessage( msg )
    local rid = msg.rid
    local guildId = msg.guildId
    local replyMessageIndex = msg.replyMessageIndex
    local content = msg.content

    -- 参数检查
    if not guildId or not content and #content <= 0 then
        LOG_ERROR("rid(%d) SendBoardMessage, no guildId or no content arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 检查角色等级是否满足发送留言板消息
    if not RoleLogic:checkSystemOpen( rid, Enum.SystemId.GUILD_MESSAGE_BOARD ) then
        LOG_ERROR("rid(%d) SendBoardMessage, system not open", rid)
        return nil, ErrorCode.GUILD_NO_OPEN_MESSAGE_BOARD
    end

    -- 是否已超过长度上限
    local allianceMessageCharacterLimit = CFG.s_Config:Get( "allianceMessageCharacterLimit" )
    if utf8.len( content ) > allianceMessageCharacterLimit then
        LOG_ERROR("rid(%d) SendBoardMessage, no guildId or no content arg", rid)
        return nil, ErrorCode.GUILD_MESSAGE_BOARD_LENGTH_LIMIT
    end

    -- 是否包含敏感字符
    if not RoleLogic:checkBlockName( content ) then
        LOG_ERROR("rid(%d) SendBoardMessage, content(%s) invalid", rid, content)
        return nil, ErrorCode.GUILD_MESSAGE_BOARD_INVALID
    end

    -- 联盟是否存在
    local guildGameNode = SM.GuildNameProxy.req.getGuildGameNode( guildId )
    if not guildGameNode then
        LOG_ERROR("rid(%d) SendBoardMessage, guildId(%d) not exist", rid, guildId)
        return nil, ErrorCode.GUILD_NOT_EXIST
    end

    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.rid, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.guildId } )
    local roleAttr = {
        rid = rid,
        name = roleInfo.name,
        headId = roleInfo.headId,
        headFrameID = roleInfo.headFrameID,
    }
    if roleInfo.guildId and roleInfo.guildId > 0 then
        roleAttr.guildAbbName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
    end
    local ret = Common.rpcMultiCall( guildGameNode, "GuildMgr", "sendBoardMessage", guildId, replyMessageIndex, content, roleAttr )
    if ret then
        if ret.error then
            LOG_ERROR("rid(%d) SendBoardMessage, error(%d)", rid, ret.error)
            return nil, ret.error
        else
            return { message = ret.messageInfo }
        end
    else
        return nil, ErrorCode.GUILD_SEND_MESSAGE_FAILED
    end
end

---@see 删除联盟留言板消息
function response.DeleteBoardMessage( msg )
    local rid = msg.rid
    local guildId = msg.guildId
    local messageIndex = msg.messageIndex

    -- 参数检查
    if not guildId or not messageIndex and messageIndex <= 0 then
        LOG_ERROR("rid(%d) DeleteBoardMessage, no guildId or no messageIndex arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 联盟是否存在
    local guildGameNode = SM.GuildNameProxy.req.getGuildGameNode( guildId )
    if not guildGameNode then
        LOG_ERROR("rid(%d) DeleteBoardMessage, guildId(%d) not exist", rid, guildId)
        return nil, ErrorCode.GUILD_NOT_EXIST
    end

    local ret = Common.rpcMultiCall( guildGameNode, "GuildMgr", "deleteBoardMessage", guildId, messageIndex, rid )
    if ret then
        if ret.error then
            LOG_ERROR("rid(%d) DeleteBoardMessage, error(%d)", rid, ret.error)
            return nil, ret.error
        else
            return { messageIndex = messageIndex }
        end
    else
        return nil, ErrorCode.GUILD_DELETE_MESSAGE_FAILED
    end
end

---@see 领取联盟礼物
function response.TakeGuildGift( msg )
    local rid = msg.rid
    local type = msg.type
    local giftIndex = msg.giftIndex

    -- 参数检查
    if not type then
        LOG_ERROR("rid(%d) TakeGuildGift, no type arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) TakeGuildGift, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 领取礼物
    return MSM.GuildMgr[guildId].req.takeGuildGift( guildId, rid, type, giftIndex )
end

---@see 清除联盟过期和已领取的礼物信息
function response.CleanGiftRecord( msg )
    local rid = msg.rid

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) CleanGiftRecord, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 领取礼物
    MSM.GuildMgr[guildId].post.cleanGiftRecord( guildId, rid )
end

---@see 联盟商店进货
function response.ShopStock( msg )
    local rid = msg.rid

    local roleBrief = RoleLogic:getRoleBrief(rid)
    if not roleBrief or roleBrief.guildId <= 0 then
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    local guildId = roleBrief.guildId

    -- 角色是否有权限
    local guildJob = GuildLogic:getRoleGuildJob( guildId, rid )
    if guildJob < Enum.GuildJob.R4 then
        return nil, ErrorCode.GUILD_NO_JURISDICTION
    end

    return MSM.GuildMgr[guildId].req.ShopStock(guildId, msg.idItemType, msg.nCount, rid, roleBrief.name)
end

---@see 联盟商店购买
function response.ShopBuy( msg )
    local roleBrief = RoleLogic:getRoleBrief(msg.rid)
    if not roleBrief or roleBrief.guildId <= 0 then
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    local guildId = roleBrief.guildId
    return MSM.GuildMgr[guildId].req.ShopBuy(guildId, msg.idItemType, msg.nCount, msg.rid, roleBrief.name)
end

---@see 联盟商店商品查询
function response.ShopQuery( msg )
    local roleBrief = RoleLogic:getRoleBrief(msg.rid)
    if not roleBrief or roleBrief.guildId <= 0 then
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    local guildId = roleBrief.guildId
    return MSM.GuildMgr[guildId].req.ShopQuery(guildId, msg.rid)
end

---@see 联盟邀请邮件回复
function response.ReplyGuildInvite( msg )
    local rid = msg.rid
    local emailIndex = msg.emailIndex
    local result = msg.result

    -- 参数检查
    if not emailIndex then
        LOG_ERROR("rid(%d) ReplyGuildInvite, no emailIndex arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 邮件是否存在
    local emailInfo = EmailLogic:getEmail( rid, emailIndex )
    if not emailInfo or table.empty( emailInfo ) then
        LOG_ERROR("rid(%d) ReplyGuildInvite, emailIndex(%d) not exist", rid, emailIndex)
        return nil, ErrorCode.EMAIL_NOT_EXIST
    end

    -- 是否已回复该邮件
    if emailInfo.emailId ~= Enum.EmailGuildInviteEmailId or emailInfo.guildEmail.inviteStatus ~= Enum.EmailGuildInviteStatus.NO_CLICK then
        LOG_ERROR("rid(%d) ReplyGuildInvite, emailIndex(%d) already reply", rid, emailIndex)
        return nil, ErrorCode.GUILD_INVITE_EMAIL_REPLY
    end

    -- 更新联盟邀请邮件标识
    if result then
        emailInfo.guildEmail.inviteStatus = Enum.EmailGuildInviteStatus.YES
    else
        emailInfo.guildEmail.inviteStatus = Enum.EmailGuildInviteStatus.NO
    end
    EmailLogic:setEmail( rid, emailIndex, { guildEmail = emailInfo.guildEmail } )
    -- 通知客户端
    EmailLogic:syncEmail( rid, emailIndex, { guildEmail = emailInfo.guildEmail }, true, true )

    local guildId = emailInfo.guildEmail.guildId

    -- 删除联盟邀请信息
    GuildLogic:delInvite( guildId, rid )

    if result then
        -- 联盟是否存在
        if not GuildLogic:checkGuild( guildId ) then
            LOG_ERROR("rid(%d) ReplyGuildInvite, guildId(%d) not exist", rid, guildId)
            return nil, ErrorCode.GUILD_NOT_EXIST
        end

        -- 角色是否已在联盟中
        local roleGuildId = RoleLogic:getRole( rid, Enum.Role.guildId )
        if roleGuildId > 0 then
            LOG_ERROR("rid(%d) ReplyGuildInvite, role already in guildId(%d)", rid, roleGuildId)
            if roleGuildId ~= guildId then
                return nil, ErrorCode.GUILD_ALREADY_IN_OTHER_GUILD
            else
                return nil, ErrorCode.GUILD_IN_THIS_GUILD
            end
        end

        -- 加入联盟
        local ret, error = MSM.GuildMgr[guildId].req.joinGuild( guildId, rid )
        if not ret then
            return nil, error
        end
    end

    return { emailIndex = emailIndex, result = result }
end

---@see 检查联盟留言信息是否存在
function response.CheckBoardMessage( msg )
    local rid = msg.rid
    local guildId = msg.guildId
    local messageIndex = msg.messageIndex

    -- 参数检查
    if not guildId or not messageIndex then
        LOG_ERROR("rid(%d) CheckBoardMessage, no guildId or no messageIndex arg", rid)
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    -- 联盟是否存在
    local guildGameNode = SM.GuildNameProxy.req.getGuildGameNode( guildId )
    if not guildGameNode then
        LOG_ERROR("rid(%d) CheckBoardMessage, guildId(%d) not exist", rid, guildId)
        return nil, ErrorCode.GUILD_NOT_EXIST
    end

    local ret = Common.rpcMultiCall( guildGameNode, "GuildMessageBoardMgr", "checkBoardMessage", guildId, messageIndex )
    if not ret then
        return {
            guildId = guildId, messageIndex = messageIndex, result = false
        }
    else
        return {
            guildId = guildId, messageIndex = messageIndex, result = true
        }
    end
end