--[[
* @file : GuildMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Wed Apr 08 2020 14:27:09 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟逻辑互斥服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local GuildLogic = require "GuildLogic"
local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local BuildingLogic = require "BuildingLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local ArmyLogic = require "ArmyLogic"
local RankLogic = require "RankLogic"
local GuildTechnologyLogic = require "GuildTechnologyLogic"
local MapObjectLogic = require "MapObjectLogic"
local GuildGiftLogic = require "GuildGiftLogic"
local EmailLogic = require "EmailLogic"
local CommonCacle = require "CommonCacle"
local GuildShopLogic = require "GuildShopLogic"
local HolyLandLogic = require "HolyLandLogic"
local ResourceLogic = require "ResourceLogic"
local MapMarkerLogic = require "MapMarkerLogic"
local Timer = require "Timer"
local LogLogic = require "LogLogic"

local guildLock = {} -- { guildId = { lock = function } }
local guildRequestHelpIndexs = {} -- { guildId = index }
local guildBuildIndexs = {} -- { guildId = index }
local guildBuildArmyIndexs = {} -- { guildId = index }
local guildGiftIndexs = {} -- { guildId = index }

---@see 联盟逻辑互斥锁
local function checkGuildLock( _guildId )
    if not guildLock[_guildId] then
        local queue = require "skynet.queue"
        guildLock[_guildId] = { lock = queue() }
    end
end

---@see 支持跨服调用查询
function init(index)
    local cluster = require "skynet.cluster"
	snax.enablecluster()
	cluster.register(SERVICE_NAME .. index)
end

---@see 初始化guildBuildArmyIndexs
local function initGuildBuildArmyIndex( _guildId, _buildIndex )
    if not guildBuildArmyIndexs[_guildId] then
        guildBuildArmyIndexs[_guildId] = {}
    end

    if not guildBuildArmyIndexs[_guildId][_buildIndex] then
        guildBuildArmyIndexs[_guildId][_buildIndex] = GuildBuildLogic:getBuildArmyMaxIndex( _guildId, _buildIndex ) + 1
    else
        guildBuildArmyIndexs[_guildId][_buildIndex] = guildBuildArmyIndexs[_guildId][_buildIndex] + 1
    end
end

---@see 加入联盟
function response.joinGuild( _guildId, _rid )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return nil, ErrorCode.GUILD_NOT_EXIST end

            return MSM.RoleJoinGuildMgr[_rid].req.roleJoinGuild( _rid, _guildId )
        end
    )
end

---@see 申请加入联盟
function response.applyJoinGuild( _guildId, _rid )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            local guildInfo = GuildLogic:getGuild( _guildId, {
                Enum.Guild.members, Enum.Guild.memberLimit, Enum.Guild.needExamine, Enum.Guild.applys
            } )
            if not guildInfo or table.empty( guildInfo ) then
                LOG_ERROR("rid(%d) applyJoinGuild, guildId(%d) not exist", _rid, _guildId)
                return nil, ErrorCode.GUILD_NOT_EXIST
            end

            -- 联盟成员数是否已满
            if table.size( guildInfo.members ) >= guildInfo.memberLimit then
                LOG_ERROR("rid(%d) applyJoinGuild, guildId(%d) member full", _rid, _guildId)
                return nil, ErrorCode.GUILD_MEMBER_FULL
            end

            local type
            -- 联盟是否需要审核
            if guildInfo.needExamine then
                local allianceApproveNumLimit = CFG.s_Config:Get( "allianceApproveNumLimit" )
                local allianceApproveTimeLimit = CFG.s_Config:Get( "allianceApproveTimeLimit" )
                -- 是否有超时的申请信息
                local nowTime = os.time()
                local newApplys = {}
                local applySize = table.size( guildInfo.applys )
                if allianceApproveNumLimit then
                    for applyRid, applyInfo in pairs( guildInfo.applys ) do
                        if applyInfo.applyTime + allianceApproveTimeLimit > nowTime then
                            newApplys[applyRid] = applyInfo
                        end
                    end
                    local newSize = table.size( newApplys )
                    if newSize ~= applySize then
                        GuildLogic:setGuild( _guildId, { [Enum.Guild.applys] = newApplys } )
                        applySize = newSize
                    end
                end
                -- 申请人数是否已到上限
                if allianceApproveNumLimit and allianceApproveNumLimit <= applySize then
                    LOG_ERROR("rid(%d) applyJoinGuild, guildId(%d) apply full", _rid, _guildId)
                    return nil, ErrorCode.GUILD_APPLY_FULL
                end
                -- 添加申请信息
                GuildLogic:addApply( _guildId, _rid )
                type = Enum.GuildApplyType.APPLY
            else
                -- 加入联盟
                MSM.RoleJoinGuildMgr[_rid].req.roleJoinGuild( _rid, _guildId )
                type = Enum.GuildApplyType.JOIN
            end

            return type
        end
    )
end

---@see 审批入盟申请
function response.examineGuildApply( _guildId, _memberRid, _applyRid, _result )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            local guildInfo = GuildLogic:getGuild( _guildId, {
                Enum.Guild.members, Enum.Guild.memberLimit, Enum.Guild.applys, Enum.Guild.abbreviationName, Enum.Guild.name
            } )
            if not guildInfo or table.empty( guildInfo ) then
                LOG_ERROR("rid(%d) examineGuildApply, guildId(%d) not exist", _memberRid, _guildId)
                return nil, ErrorCode.GUILD_NOT_EXIST
            end

            -- 是否有该申请角色信息
            if not guildInfo.applys or not guildInfo.applys[_applyRid] then
                LOG_ERROR("rid(%d) examineGuildApply, applyRid(%d) not exist", _memberRid, _applyRid)
                return nil, ErrorCode.GUILD_APPLYRID_NOT_EXIST
            end

            -- 删除入盟申请
            GuildLogic:deleteApply( _guildId, _applyRid )

            if _result then
                -- 同意入盟
                -- 联盟人数是否已满
                if table.size( guildInfo.members ) >= guildInfo.memberLimit then
                    LOG_ERROR("rid(%d) examineGuildApply, guildId(%d) member full", _memberRid, _guildId)
                    return nil, ErrorCode.GUILD_MEMBER_FULL
                end

                -- 申请角色是否已经加入其它联盟
                if RoleLogic:checkRoleGuild( _applyRid ) then
                    LOG_ERROR("rid(%d) examineGuildApply, applyRid(%d) join other guild", _memberRid, _applyRid)
                    return nil, ErrorCode.GUILD_APPLYRID_OTHER_GUILD
                end

                -- 加入联盟
                MSM.RoleJoinGuildMgr[_applyRid].req.roleJoinGuild( _applyRid, _guildId )
            else
                -- 拒绝入盟
                -- 申请角色是否已经加入其它联盟
                if RoleLogic:checkRoleGuild( _applyRid ) then
                    LOG_ERROR("rid(%d) examineGuildApply, applyRid(%d) join other guild", _memberRid, _applyRid)
                    return
                end

                -- 给申请角色发送拒绝邮件300002
                local content = string.format( "%s,%s", guildInfo.abbreviationName, guildInfo.name )
                EmailLogic:sendEmail( _applyRid, 300002, {
                    subTitleContents = { content },
                    emailContents = { content },
                } )
            end

            return { applyRid = _applyRid, result = _result }
        end
    )
end

---@see 邀请加入联盟
function response.inviteGuild( _guildId, _rid, _invitedRid )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then
                LOG_ERROR("rid(%d) inviteGuild, guildId not exist", _rid)
                return nil, ErrorCode.GUILD_NOT_EXIST
            end

            -- 是否已发送联盟邀请
            if GuildLogic:checkGuildInvite( _guildId, _invitedRid ) then
                LOG_ERROR("rid(%d) inviteGuild, invitedRid(%d) already invited", _rid, _invitedRid)
                return nil, ErrorCode.GUILD_ROLE_ALREADY_INVITED
            end

            local guildInfo = GuildLogic:getGuild( _guildId, {
                Enum.Guild.signs, Enum.Guild.name, Enum.Guild.abbreviationName, Enum.Guild.invites
            } )
            -- 是否已到联盟邀请上限
            if table.size( guildInfo.invites ) >= CFG.s_Config:Get( "allianceInviteLimit" ) then
                LOG_ERROR("rid(%d) inviteGuild, invite limit", _rid)
                return nil, ErrorCode.GUILD_INVITE_LIMIT
            end

            -- 增加联盟邀请信息
            GuildLogic:addInvite( _guildId, _invitedRid )
            -- 发送联盟邀请邮件
            local roleName = RoleLogic:getRole( _rid, Enum.Role.name )
            local emailArg = string.format( "%s,%s", guildInfo.abbreviationName, guildInfo.name )
            EmailLogic:sendEmail( _invitedRid, Enum.EmailGuildInviteEmailId, {
                subTitleContents = { roleName, emailArg },
                emailContents = { roleName, emailArg },
                guildEmail = { guildId = _guildId, signs = guildInfo.signs, inviteStatus = Enum.EmailGuildInviteStatus.NO_CLICK },
            } )

            return { result = true }
        end
    )
end

---@see 取消入盟申请
function response.cancelGuildApply( _guildId, _rid )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then
                LOG_ERROR("rid(%d) cancelGuildApply, guildId(%d) not exist", _rid, _guildId)
                return nil, ErrorCode.GUILD_NOT_EXIST
            end
            -- 删除入盟申请
            GuildLogic:deleteApply( _guildId, _rid )

            return { guildId = _guildId }
        end
    )
end

---@see 刷新联盟战力
function accept.refreshGuildPower( _guildId )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            local power = 0
            local combatPower, isChange
            local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.memberLimit, Enum.Guild.languageId, Enum.Guild.needExamine } )
            local members = guildInfo.members
            local onlineMembers = GuildLogic:getAllOnlineMember( _guildId, members )
            for memberRid, memberInfo in pairs( members ) do
                if table.exist( onlineMembers, memberRid ) then
                    combatPower = RoleLogic:getRole( memberRid, Enum.Role.combatPower ) or 0
                    -- 成员战力变化
                    if combatPower ~= memberInfo.combatPower then
                        memberInfo.combatPower = combatPower
                        isChange = true
                        -- 更新成员修改标识
                        MSM.GuildIndexMgr[_guildId].post.addMemberIndex( _guildId, memberRid )
                    end
                end

                power = power + memberInfo.combatPower
            end

            if isChange then
                -- 更新联盟信息
                GuildLogic:setGuild( _guildId, { [Enum.Guild.members] = members, [Enum.Guild.power] = power } )
                RankLogic:update( _guildId, Enum.RankType.ALLIANCE_POWER, power )
                MSM.GuildIndexMgr[_guildId].post.addGuildIndex( _guildId )
            end
            if table.size( members ) < guildInfo.memberLimit then
                SM.GuildRecommendMgr.post.addGuildId( _guildId, guildInfo.needExamine, guildInfo.languageId, power )
            end
        end
    )
end

---@see 联盟成员升降级
function response.modifyMemberLevel( _guildId, _rid, _memberRid, _newGuildJob, _isSystemTransfer )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then
                LOG_ERROR("rid(%d) modifyMemberLevel, guildId not exist", _rid)
                return nil, ErrorCode.GUILD_NOT_EXIST
            end

            -- 角色是否在联盟中
            local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
            if not guildId or guildId <= 0 then
                LOG_ERROR("rid(%d) modifyMemberLevel, role not in guild", _rid)
                return nil, ErrorCode.GUILD_NOT_IN_GUILD
            end

            -- 角色是否有权限
            local roleGuildJob = GuildLogic:getRoleGuildJob( guildId, _rid )
            local jurisdictionType = Enum.GuildJurisdictionType.MEMBER_LEVEL
            if not GuildLogic:checkRoleJurisdiction( _rid, jurisdictionType, roleGuildJob ) then
                LOG_ERROR("rid(%d) modifyMemberLevel, role guildJob(%d) no jurisdictionType(%d)",
                            _rid, roleGuildJob, jurisdictionType)
                return nil, ErrorCode.GUILD_NO_JURISDICTION
            end

            -- 成员是否在联盟中
            local memberGuildId = RoleLogic:getRole( _memberRid, Enum.Role.guildId ) or 0
            if memberGuildId ~= _guildId then
                LOG_ERROR("rid(%d) modifyMemberLevel, memberRid(%d) not in guildId", _rid, _memberRid)
                return nil, ErrorCode.GUILD_MEMBER_NOT_IN_GUILD
            end

            local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.guildOfficers } )
            local members = guildInfo.members or {}
            if _newGuildJob == Enum.GuildJob.LEADER then
                -- 盟主转让
                if roleGuildJob ~= Enum.GuildJob.LEADER then
                    LOG_ERROR("rid(%d) modifyMemberLevel, role guildJob(%d) not guild leader", _rid, roleGuildJob)
                    return nil, ErrorCode.GUILD_NO_JURISDICTION
                end

                -- 新的盟主城市是否被回收
                if ( RoleLogic:getRole( _memberRid, Enum.Role.cityId ) or 0 ) <= 0 then
                    LOG_ERROR("rid(%d) modifyMemberLevel, memberRid(%d) city already hide", _rid, _memberRid)
                    return nil, ErrorCode.GUILD_TRANSFER_MEMBER_HIDE
                end

                -- 盟主变为R1, 成员变为盟主
                GuildLogic:transferGuildLeader( _guildId, _rid, _memberRid, _isSystemTransfer )
            else
                -- 提升、降低等级
                -- 该等级人数是否已满
                local guildJobLimit = CFG.s_AllianceMember:Get( _newGuildJob )
                if guildJobLimit > 0 then
                    local guildJobNum = 0
                    for _, memberInfo in pairs( members ) do
                        if memberInfo.guildJob == _newGuildJob then
                            guildJobNum = guildJobNum + 1
                        end
                    end
                    -- 当前等级成员人数已满
                    if guildJobNum >= guildJobLimit then
                        LOG_ERROR("rid(%d) modifyMemberLevel, guildJob(%d) num(%d) limit", _rid, _newGuildJob, guildJobNum)
                        return nil, ErrorCode.GUILD_JOB_NUM_LIMIT
                    end
                end

                -- 成员当前等级不能高于等于角色等级, 新的等级不能高于等于角色等级
                local memberGuildJob = GuildLogic:getRoleGuildJob( guildId, _memberRid )
                if memberGuildJob >= roleGuildJob or _newGuildJob >= roleGuildJob then
                    LOG_ERROR("rid(%d) modifyMemberLevel, member guildJob(%d) newGuildJob(%d) error",
                            _rid, memberGuildJob, _newGuildJob)
                    return nil, ErrorCode.GUILD_MEMBER_LEVEL_ERROR
                end
                -- 更新成员职位和官职
                GuildLogic:modifyMemberLevel( _guildId, _memberRid, _newGuildJob )
            end

            return { newGuildJob = _newGuildJob }
        end
    )
end

---@see 移除联盟成员
function response.kickMember( _guildId, _rid, _memberRid, _reasonId )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then
                LOG_ERROR("rid(%d) kickMember, guildId not exist", _rid)
                return nil, ErrorCode.GUILD_NOT_EXIST
            end

            -- 成员是否在联盟中
            local memberGuildId = RoleLogic:getRole( _memberRid, Enum.Role.guildId )
            if memberGuildId ~= _guildId then
                LOG_ERROR("rid(%d) kickMember, memberRid(%d) not in guild", _rid, _memberRid)
                return nil, ErrorCode.GUILD_MEMBER_NOT_IN_GUILD
            end

            local members = GuildLogic:getGuild( _guildId, Enum.Guild.members )
            local roleGuildJob = members[_rid].guildJob
            -- 角色是否有移除成员权限
            if not GuildLogic:checkRoleJurisdiction( _rid, Enum.GuildJurisdictionType.KICK_MEMBER, roleGuildJob ) then
                LOG_ERROR("rid(%d) kickMember, role guildJob(%d) not kick member", _rid, roleGuildJob)
                return nil, ErrorCode.GUILD_NO_JURISDICTION
            end
            -- 是否可以移除该等级成员
            local memberGuildJob = members[_memberRid].guildJob
            if roleGuildJob ~= Enum.GuildJob.LEADER and roleGuildJob <= memberGuildJob then
                LOG_ERROR("rid(%d) kickMember, role guildJob(%d) not kick member", _rid, roleGuildJob)
                return nil, ErrorCode.GUILD_CANT_KICK_LEVEL_MEMBER
            end
            -- 成员退出联盟
            GuildLogic:exitGuild( _guildId, _memberRid )
            local onlineMembers = GuildLogic:getAllOnlineMember( _guildId )
            -- 发送移除成员通知
            GuildLogic:guildNotify( onlineMembers, Enum.GuildNotify.KICK_MEMBER, { RoleLogic:getRole( _memberRid, { Enum.Role.name } ) } )

            -- 发送邮件
            EmailLogic:sendEmail( _memberRid, 300008, {
                emailContents = { _reasonId, RoleLogic:getRole( _rid, Enum.Role.name ) }
            } )
        end
    )
end

---@see 退出或解散联盟
function response.exitGuild( _guildId, _rid, _type )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then
                LOG_ERROR("rid(%d) exitGuild, guildId not exist", _rid)
                return nil, ErrorCode.GUILD_NOT_EXIST
            end

            if _type == Enum.GuildExitType.EXIT then
                -- 退出联盟
                GuildLogic:exitGuild( _guildId, _rid )
            else
                GuildLogic:setGuild( _guildId, { [Enum.Guild.disbandFlag] = true } )
                -- 解散联盟
                Timer.runAfter( 1, GuildLogic.dispathDisbandGuild, GuildLogic, _guildId )
            end
        end
    )
end

---@see 任命官员
function response.appointOfficer( _guildId, _rid, _memberRid, _officerId )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then
                LOG_ERROR("rid(%d) appointOfficer, guildId not exist", _rid)
                return nil, ErrorCode.GUILD_NOT_EXIST
            end

            -- 角色是否有任命权限
            local jurisdictionType = Enum.GuildJurisdictionType.APPOINT_OFFICER
            local roleGuildJob = GuildLogic:getRoleGuildJob( _guildId, _rid )
            if not GuildLogic:checkRoleJurisdiction( _rid, jurisdictionType, roleGuildJob ) then
                LOG_ERROR("rid(%d) appointOfficer, role no appoint officer jurisdiction", _rid)
                return nil, ErrorCode.GUILD_NO_JURISDICTION
            end

            -- 官员任命是否还在冷却时间内
            local nowTime = os.time()
            local allianceOfficerCD = CFG.s_Config:Get( "allianceOfficerCD" ) or 0
            local guildOfficers = GuildLogic:getGuild( _guildId, Enum.Guild.guildOfficers ) or {}
            if allianceOfficerCD > 0 and guildOfficers[_officerId]
                and guildOfficers[_officerId].appointTime + allianceOfficerCD > nowTime then
                LOG_ERROR("rid(%d) appointOfficer, officerId(%d) appointTime(%d) cd time limit",
                            _rid, _officerId, guildOfficers[_officerId].appointTime)
                return nil, ErrorCode.GUILD_APPOINT_CDTIME_LIMIT
            end

            -- 成员是否在联盟中
            local memberGuildId = RoleLogic:getRole( _memberRid, Enum.Role.guildId )
            if not memberGuildId or memberGuildId ~= _guildId  then
                LOG_ERROR("rid(%d) appointOfficer, memberRid(%d) not in guild", _rid, _memberRid)
                return nil, ErrorCode.GUILD_NOT_IN_GUILD
            end

            -- 成员是否是R4
            local memberGuildJob = GuildLogic:getRoleGuildJob( _guildId, _memberRid )
            if memberGuildJob ~= Enum.GuildJob.R4 then
                LOG_ERROR("rid(%d) appointOfficer, memberRid(%d) guildJob(%d) not R4", _rid, _memberRid, memberGuildJob)
                return nil, ErrorCode.GUILD_MEMBER_NOT_R4_APPOINTED
            end

            -- 任命官员
            GuildLogic:appointOfficer( _guildId, _memberRid, _officerId )

            return { officerId = _officerId }
        end
    )
end

---@see 增加联盟货币
function accept.addGuildCurrency( _guildId, _currencyType, _addNum )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            return GuildLogic:addGuildCurrency( _guildId, _currencyType, _addNum )
        end
    )
end

---@see 发送联盟求助
function response.sendRequestHelp( _guildId, _rid, _requestType, _queueIndex )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then
                LOG_ERROR("rid(%d) sendRequestHelp, guildId not exist", _rid)
                return nil, ErrorCode.GUILD_NOT_EXIST
            end

            local nowTime = os.time()
            -- 获取联盟求助索引
            if not guildRequestHelpIndexs[_guildId] then
                guildRequestHelpIndexs[_guildId] = GuildLogic:getRequestHelpMaxIndex( _guildId ) + 1
            else
                guildRequestHelpIndexs[_guildId] = guildRequestHelpIndexs[_guildId] + 1
            end

            -- 求助信息
            local requestHelpInfo = {
                rid = _rid, type = _requestType, helpNum = 0, reduceTime = 0, helps = {},
                index = guildRequestHelpIndexs[_guildId], queueIndex = _queueIndex
            }
            local roleInfo = RoleLogic:getRole( _rid, {
                Enum.Role.guildId, Enum.Role.technologyQueue, Enum.Role.treatmentQueue, Enum.Role.technologies
            } )
            if _requestType == Enum.GuildRequestHelpType.BUILD then
                -- 建筑建造升级
                local ret, error = MSM.RoleBuildQueueMgr[_rid].req.guildHelpUpdateBuildQueueInfo( _rid, _queueIndex, requestHelpInfo.index )
                if not ret then
                    LOG_ERROR("rid(%d) sendRequestHelp, update build queue failed", _rid)
                    return nil, error
                end
                -- 获取建筑信息
                local buildInfo = BuildingLogic:getBuilding( _rid, ret.buildingIndex )
                if buildInfo then
                    requestHelpInfo.args = { buildInfo.type, buildInfo.level + 1 }
                end
                -- 该建筑需要总时间
                requestHelpInfo.needTime = ret.firstFinishTime - ret.beginTime
            elseif _requestType == Enum.GuildRequestHelpType.HEAL then
                -- 医院治疗
                if not roleInfo.treatmentQueue or not roleInfo.treatmentQueue.finishTime
                    or roleInfo.treatmentQueue.finishTime <= nowTime then
                    LOG_ERROR("rid(%d) sendRequestHelp, treatmentQueue already finish", _rid)
                    return nil, ErrorCode.GUILD_HELP_QUEUE_NOT_EXIST
                end

                -- 是否已发送过联盟求助
                if roleInfo.treatmentQueue.requestGuildHelp then
                    LOG_ERROR("rid(%d) sendRequestHelp, treatmentQueue already send guild help", _rid)
                    return nil, ErrorCode.GUILD_ALREADY_SEND_GUILD_HELP
                end

                -- 更新联盟求助信息
                roleInfo.treatmentQueue.requestGuildHelp = true
                roleInfo.treatmentQueue.requestHelpIndex = requestHelpInfo.index
                RoleLogic:setRole( _rid, { [Enum.Role.treatmentQueue] = roleInfo.treatmentQueue } )
                -- 通知客户端
                RoleSync:syncSelf( _rid, { [Enum.Role.treatmentQueue] = roleInfo.treatmentQueue }, true )
                -- 该治疗需要总时间
                requestHelpInfo.needTime = roleInfo.treatmentQueue.firstFinishTime - roleInfo.treatmentQueue.beginTime
            elseif _requestType == Enum.GuildRequestHelpType.TECHNOLOGY then
                -- 科技升级
                if not roleInfo.technologyQueue or not roleInfo.technologyQueue.finishTime
                    or roleInfo.technologyQueue.finishTime <= nowTime then
                    LOG_ERROR("rid(%d) sendRequestHelp, technologyQueue already finish", _rid)
                    return nil, ErrorCode.GUILD_HELP_QUEUE_NOT_EXIST
                end

                -- 是否已发送过联盟求助
                if roleInfo.technologyQueue.requestGuildHelp then
                    LOG_ERROR("rid(%d) sendRequestHelp, technologyQueue already send guild help", _rid)
                    return nil, ErrorCode.GUILD_ALREADY_SEND_GUILD_HELP
                end

                -- 更新联盟求助信息
                roleInfo.technologyQueue.requestGuildHelp = true
                roleInfo.technologyQueue.requestHelpIndex = requestHelpInfo.index
                RoleLogic:setRole( _rid, { [Enum.Role.technologyQueue] = roleInfo.technologyQueue } )
                -- 通知客户端
                RoleSync:syncSelf( _rid, { [Enum.Role.technologyQueue] = roleInfo.technologyQueue }, true )
                -- 增加求助科技参数
                local technologyType = roleInfo.technologyQueue.technologyType
                local level = ( roleInfo.technologies[technologyType] and roleInfo.technologies[technologyType].level or 0 ) + 1
                -- 科技求助参数
                requestHelpInfo.args = { technologyType, level }
                -- 该治疗需要总时间
                requestHelpInfo.needTime = roleInfo.technologyQueue.firstFinishTime - roleInfo.technologyQueue.beginTime
            elseif _requestType == Enum.GuildRequestHelpType.BATTLELOSE then
                -- 战损补偿,帮助索引通知到战损服务
                MSM.BattleLosePowerMgr[_rid].req.setGuildMemberHelpIndex( _rid, requestHelpInfo.index )
                requestHelpInfo.needTime = 0
            else
                LOG_ERROR("rid(%d) SendRequestHelp, requestType(%d) arg error", _rid, _requestType)
                return nil, ErrorCode.GUILD_ARG_ERROR
            end

            -- 获取求助时可被帮助次数
            local centerLevel = BuildingLogic:getBuildingLv( _rid, Enum.BuildingType.ALLIANCE_CENTER )
            if centerLevel > 0 then
                requestHelpInfo.helpLimit = CFG.s_BuildingAllianceCenter:Get( centerLevel, "helpCnt" )
            else
                requestHelpInfo.helpLimit = CFG.s_Config:Get( "alliancehelpedTimes" )
            end

            -- 战损补偿
            if _requestType == Enum.GuildRequestHelpType.BATTLELOSE then
                requestHelpInfo.helpLimit = CFG.s_Config:Get("battleDamMaxNum")
            end

            -- 更新联盟求助信息
            local requestHelps = GuildLogic:getGuild( _guildId, Enum.Guild.requestHelps ) or {}
            requestHelps[requestHelpInfo.index] = requestHelpInfo
            GuildLogic:setGuild( _guildId, { [Enum.Guild.requestHelps] = requestHelps } )
            -- 通知联盟在线人员
            GuildLogic:syncGuildRequestHelps( GuildLogic:getAllOnlineMember( _guildId ), { [requestHelpInfo.index] = requestHelpInfo } )
            -- 更新求助信息修改标识
            -- MSM.GuildIndexMgr[_guildId].post.addRequestHelpIndex( _guildId, requestHelpInfo.index )
        end
    )
end

---@see 帮助联盟成员
function accept.helpGuildMembers( _guildId, _rid )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            GuildLogic:helpGuildMembers( _guildId, _rid )
        end
    )
end

---@see 角色建筑建造治疗和科技研究完成回调
function accept.roleQueueFinishCallBack( _guildId, _requestHelpIndex, _isLogin )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end
            -- 角色建筑建造治疗和科技研究完成回调
            GuildLogic:roleQueueFinishCallBack( _guildId, _requestHelpIndex, _isLogin )
        end
    )
end

---@see 创建联盟建筑
function response.createGuildBuild( _guildId, _rid, _type, _pos, _noCheck )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return nil, ErrorCode.GUILD_NOT_EXIST end

            if not _noCheck then
                -- 检查联盟建筑建筑条件
                local ret, error = GuildBuildLogic:checkGuildBuildCreate( _rid, _guildId, _type, _pos )
                if not ret then
                    LOG_ERROR("rid(%d) createGuildBuild, check create guild build failed error(%d)", _rid, error)
                    return nil, error
                end

                -- 占用联盟建筑附近地块
                local radiusCollide = CFG.s_AllianceBuildingType:Get( _type, "radiusCollide" )
                local MapLogic = require "MapLogic"
                if radiusCollide and radiusCollide > 0 and not MapLogic:checkPosIdle( _pos, radiusCollide ) then
                    LOG_ERROR("rid(%d) createGuildBuild, pos(%s) around already occupy", _rid, tostring(_pos))
                    return nil, ErrorCode.GUILD_BUILD_NOT_OPEN_SPACE
                end
            end

            -- 更新最新建筑索引
            guildBuildIndexs[_guildId] = ( guildBuildIndexs[_guildId] or GuildBuildLogic:getGuildBuildIndex( _guildId ) ) + 1
            -- 创建建筑
            return GuildBuildLogic:createGuildBuild( _guildId, _rid, guildBuildIndexs[_guildId], _type, _pos )
        end
    )
end

---@see 增援联盟建筑
function response.reinforceGuildBuild( _guildId, _rid, _reinforceObjectIndex, _reinforceArmys )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return nil, ErrorCode.GUILD_NOT_EXIST end

            -- 联盟建筑信息
            local guildBuildInfo = MSM.SceneGuildBuildMgr[_reinforceObjectIndex].req.getGuildBuildInfo( _reinforceObjectIndex )
            local buildIndex = guildBuildInfo.buildIndex
            local buildInfo = GuildBuildLogic:getGuildBuild( _guildId, buildIndex, {
                Enum.GuildBuild.reinforces, Enum.GuildBuild.type, Enum.GuildBuild.status, Enum.GuildBuild.pos
            } )
            local sAllianceBuildingType = CFG.s_AllianceBuildingType:Get( buildInfo.type )
            local checkArmyCount, checkSoldierCount, collectResource
            local targetType = Enum.MapMarchTargetType.REINFORCE
            if MapObjectLogic:checkIsGuildResourceCenterBuild( buildInfo.type ) then
                -- 角色等级是否满足联盟资源中心建造采集条件
                local roleLevel = RoleLogic:getRole( _rid, Enum.Role.level )
                if roleLevel < CFG.s_Config:Get( "allianceResourcePointReqLevel" ) then
                    LOG_ERROR("rid(%d) reinforceGuildBuild error, role level not enough", _rid)
                    return nil, ErrorCode.GUILD_CREATE_BUILD_LEVEL_ERROR
                end

                if buildInfo.status ~= Enum.GuildBuildStatus.BUILDING then
                    -- 资源中心已经建造完成
                    collectResource = true
                    targetType = Enum.MapMarchTargetType.COLLECT
                    local reinforceArmyInfo = table.first( _reinforceArmys ).value
                    local armyInfo = reinforceArmyInfo and reinforceArmyInfo.armyInfo or {}
                    -- 角色负载是否已满
                    local leftLoad = ResourceLogic:getArmyLoad( _rid, armyInfo.armyIndex, armyInfo ) - ResourceLogic:getArmyUseLoad( _rid, armyInfo.armyIndex, armyInfo )
                    local resourceType = GuildBuildLogic:resourceBuildTypeToResourceType( buildInfo.type )
                    if ResourceLogic:loadToResourceCount( resourceType, leftLoad ) < 1 then
                        LOG_ERROR("rid(%d) reinforceGuildBuild error, role army load full", _rid)
                        return nil, ErrorCode.ROLE_ARMY_LOAD_FULL
                    end
                end

                checkArmyCount = true
            end

            checkSoldierCount = true

            local roleTechnology
            -- 建造中建筑要检测部队数和士兵上限
            if buildInfo.status == Enum.GuildBuildStatus.BUILDING then
                checkArmyCount = true
                roleTechnology = true
                -- 更新联盟建筑索引
                MSM.GuildIndexMgr[_guildId].post.addBuildIndex( _guildId, buildIndex )
            elseif MapObjectLogic:checkIsGuildResourceCenterBuild( buildInfo.type ) then
                -- 建造完成的联盟资源中心无上限
                checkSoldierCount = false
                roleTechnology = true
            end

            if roleTechnology then
                local scienceReq = sAllianceBuildingType.scienceReq
                local technologies = RoleLogic:getRole( _rid, Enum.Role.technologies ) or {}
                -- 所需科技是否学习
                if scienceReq and scienceReq > 0 and not technologies[scienceReq] then
                    LOG_ERROR("rid(%d) reinforceGuildBuild error, not study technology(%d)", _rid, scienceReq)
                    return nil, ErrorCode.ROLE_RESOURCE_NO_TECHNOLOGY
                end
            end

            local reinforces = buildInfo.reinforces or {}
            if checkArmyCount then
                -- 建造中的联盟建筑只能派遣一支部队
                for _, reinforce in pairs( reinforces ) do
                    if reinforce.rid == _rid and reinforce.armyIndex ~= table.first( _reinforceArmys ).key then
                        LOG_ERROR("rid(%d) reinforceGuildBuild, role already reinforce guild build", _rid)
                        if collectResource then
                            return nil, ErrorCode.GUILD_CENTER_ALREADY_ARMY_COLLECT
                        else
                            return nil, ErrorCode.MAP_ALREADY_REINFORCE_GUILD
                        end
                    end
                end
            end

            if checkSoldierCount then
                -- 是否超过增援部队总量
                local armyCount = 0
                for _, reinforceArmy in pairs( _reinforceArmys ) do
                    armyCount = armyCount + ArmyLogic:getArmySoldierCount( reinforceArmy.armyInfo and reinforceArmy.armyInfo.soldiers or {} )
                end

                -- 增加联盟建筑中已有部队
                for _, reinforce in pairs( reinforces ) do
                    if reinforce.rid ~= _rid or not _reinforceArmys[reinforce.armyIndex] then
                        -- 本次增援部队可能
                        armyCount = armyCount + ArmyLogic:getArmySoldierCount( nil, reinforce.rid, reinforce.armyIndex )
                    end
                end

                -- 是否已超过容量上限
                local armyCntLimit = sAllianceBuildingType.armyCntLimit or 0
                if armyCount > armyCntLimit then
                    LOG_ERROR("rid(%d) reinforceGuildBuild error, buildIndex(%d) armyCount(%d) armyCntLimit(%d) error",
                            _rid, buildIndex, armyCount, armyCntLimit)
                    return nil, ErrorCode.MAP_GUILD_BUILD_ARMY_LIMIT
                end
            end

            local alreadyReinforce = {}
            for index, reinforce in pairs( reinforces ) do
                if reinforce.rid == _rid then
                    alreadyReinforce[reinforce.armyIndex] = index
                end
            end

            -- 增援部队处理
            local armyList = {}
            local nowTime = os.time()
            local reinforceIndex, arrivalTime
            -- 推送联盟建筑部队信息到关注角色中
            local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } ) or {}
            for armyIndex, reinfroceArmyInfo in pairs( _reinforceArmys ) do
                if not alreadyReinforce[armyIndex] then
                    initGuildBuildArmyIndex( _guildId, buildIndex )
                    reinforceIndex = guildBuildArmyIndexs[_guildId][buildIndex]
                else
                    reinforceIndex = alreadyReinforce[armyIndex]
                end
                arrivalTime = GuildBuildLogic:reinforceGuildBuildCallBack( _rid, armyIndex, reinfroceArmyInfo.armyInfo,
                        reinfroceArmyInfo.fromType, targetType, _reinforceObjectIndex, reinforceIndex, guildBuildInfo )
                reinforces[reinforceIndex] = {
                    reinforceIndex = reinforceIndex,
                    rid = _rid,
                    armyIndex = armyIndex,
                    startTime = nowTime,
                }
                armyList[reinforceIndex] = {
                    buildArmyIndex = reinforceIndex,
                    rid = _rid,
                    armyIndex = reinfroceArmyInfo.armyInfo.armyIndex,
                    mainHeroId = reinfroceArmyInfo.armyInfo.mainHeroId,
                    deputyHeroId = reinfroceArmyInfo.armyInfo.deputyHeroId,
                    soldiers = reinfroceArmyInfo.armyInfo.soldiers,
                    status = reinfroceArmyInfo.armyInfo.status,
                    startTime = os.time(),
                    mainHeroLevel = reinfroceArmyInfo.armyInfo.mainHeroLevel,
                    deputyHeroLevel = reinfroceArmyInfo.armyInfo.deputyHeroLevel,
                    arrivalTime = arrivalTime,
                    roleName = roleInfo.name,
                    roleHeadId = roleInfo.headId,
                    roleHeadFrameId = roleInfo.headFrameID,
                }
            end

            -- 更新联盟建筑增援信息
            GuildBuildLogic:setGuildBuild( _guildId, buildIndex, { [Enum.GuildBuild.reinforces] = reinforces } )
            -- 通知客户端建筑中的部队信息
            GuildBuildLogic:syncGuildBuildArmy( _reinforceObjectIndex, armyList )

            return true
        end
    )
end

---@see 部队到达联盟建筑回调
function response.arriveGuildBuild( _guildId, _buildIndex, _rid, _armyIndex, _objectIndex, _targetObjectIndex )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then
                return false
            end
            -- 判断部队是否还处于联盟中
            if RoleLogic:getRole( _rid, Enum.Role.guildId ) ~= _guildId then
                return false
            end
            local buildInfo = GuildBuildLogic:getGuildBuild( _guildId, _buildIndex )
            local buildArmyIndex
            for index, reinforce in pairs( buildInfo.reinforces or {} ) do
                if reinforce.rid == _rid and reinforce.armyIndex == _armyIndex then
                    buildArmyIndex = index
                    break
                end
            end
            if buildArmyIndex then
                -- 根据建筑状态不同，做不同处理
                local armyStatus = Enum.ArmyStatus.GARRISONING
                -- local targetArg = ArmyLogic:getArmy( _rid, _armyIndex, Enum.Army.targetArg ) or {}
                local armyInfo = ArmyLogic:getArmy( _rid, _armyIndex ) or {}
                if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING ) then
                    local BattleCreate = require "BattleCreate"
                    BattleCreate:exitBattle( _objectIndex, true )
                end
                local targetArg = armyInfo.targetArg or {}
                targetArg.pos = buildInfo.pos
                if buildInfo.status == Enum.GuildBuildStatus.NORMAL and MapObjectLogic:checkIsGuildResourceCenterBuild( buildInfo.type ) then
                    -- 联盟资源中心采集
                    armyStatus = Enum.ArmyStatus.COLLECTING
                end
                -- 更新部队状态
                ArmyLogic:setArmy( _rid, _armyIndex, { [Enum.Army.targetArg] = targetArg, [Enum.Army.status] = armyStatus } )
                ArmyLogic:syncArmy( _rid, _armyIndex, { [Enum.Army.targetArg] = targetArg, [Enum.Army.status] = armyStatus }, true )
                if buildInfo.status == Enum.GuildBuildStatus.BUILDING then
                    -- 更新到达时间，计算建造获得的个人联盟积分使用
                    buildInfo.reinforces[buildArmyIndex] = {
                        reinforceIndex = buildArmyIndex,
                        rid = _rid,
                        armyIndex = _armyIndex,
                        startTime = os.time(),
                    }
                    GuildBuildLogic:setGuildBuild( _guildId, _buildIndex, { [Enum.GuildBuild.reinforces] = buildInfo.reinforces }, true )
                    -- 建造中的联盟建筑
                    MSM.GuildTimerMgr[_guildId].req.resetGuildBuildTimer( _guildId, _buildIndex )
                    -- 部队加入建造中的联盟建筑
                    local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
                    LogLogic:guildBuildTroops( {
                        logType = Enum.LogType.ARMY_JOIN_GUILD_BUILD, iggid = iggid, guildId = _guildId,
                        buildIndex = _buildIndex, buildType = buildInfo.type, rid = _rid, mainHeroId = armyInfo.mainHeroId,
                        deputyHeroId = armyInfo.deputyHeroId, buildTime = 0, soldiers = armyInfo.soldiers
                    } )
                else
                    if MapObjectLogic:checkIsGuildResourceCenterBuild( buildInfo.type ) then
                        -- 角色进入联盟资源中心采集，更新联盟资源中心定时器信息
                        MSM.GuildTimerMgr[_guildId].req.resetResourceCenterTimer( _guildId, _buildIndex, nil, Enum.GuildResourceCenterReset.MEMBER_JOIN, _rid )
                    end
                end
                -- 非联盟资源中心的建筑需要驻守
                if not MapObjectLogic:checkIsGuildResourceCenterBuild( buildInfo.type ) then
                    -- 联盟建筑,驻守建筑
                    MSM.SceneGuildBuildMgr[_targetObjectIndex].post.addGarrisonArmy( _targetObjectIndex, _rid, _armyIndex, buildArmyIndex )
                end
                -- 推送联盟建筑部队信息到关注角色中
                local armyList = {
                    [buildArmyIndex] = {
                        buildArmyIndex = buildArmyIndex,
                        status = armyStatus
                    }
                }
                GuildBuildLogic:syncGuildBuildArmy( _targetObjectIndex, armyList )

                -- 删除地图上的对象
                MSM.AoiMgr[Enum.MapLevel.ARMY].req.armyLeave( Enum.MapLevel.ARMY, _objectIndex, { x = -1, y = -1 } )
                -- 移除军队索引信息
                MSM.RoleArmyMgr[_rid].post.deleteRoleArmyIndex( _rid, _armyIndex )
            end

            return true
        end
    )
end

---@see 联盟建筑中的部队行军
function accept.guildBuildArmyMarch( _guildId, _buildIndex, _rid, _armyIndex, _marchArgs, _oldObjectIndex, _disbandArmy, _targetInfo )
    --- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            local buildInfo = GuildBuildLogic:getGuildBuild( _guildId, _buildIndex )
            local reinforceIndex
            for index, reinforce in pairs( buildInfo.reinforces or {} ) do
                if reinforce.rid == _rid and reinforce.armyIndex == _armyIndex then
                    reinforceIndex = index
                    break
                end
            end
            if reinforceIndex then
                local armyObjectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, _armyIndex )
                if armyObjectIndex then
                    -- 删除该部队在联盟建筑中的增援信息
                    buildInfo.reinforces[reinforceIndex] = nil
                    GuildBuildLogic:setGuildBuild( _guildId, _buildIndex, { [Enum.GuildBuild.reinforces] = buildInfo.reinforces } )
                    if not _disbandArmy then
                        -- 军队移动
                        MSM.MapMarchMgr[armyObjectIndex].req.armyMove( armyObjectIndex, _marchArgs.targetObjectIndex, _marchArgs.targetPos, _marchArgs.armyStatus )
                    end
                    -- 推送联盟建筑部队信息到关注角色中
                    GuildBuildLogic:syncGuildBuildArmy( _oldObjectIndex, nil, nil, { reinforceIndex } )
                else
                    if buildInfo.status == Enum.GuildBuildStatus.NORMAL and MapObjectLogic:checkIsGuildResourceCenterBuild( buildInfo.type ) then
                        -- 部队离开采集中的联盟资源中心, 重置定时器
                        MSM.GuildTimerMgr[_guildId].req.resetResourceCenterTimer( _guildId, _buildIndex, nil, Enum.GuildResourceCenterReset.MEMBER_LEAVE, _rid, _marchArgs, _disbandArmy )
                    else
                        -- 联盟建筑,从建筑退出,不再驻守
                        MSM.SceneGuildBuildMgr[_oldObjectIndex].post.delGarrisonArmy( _oldObjectIndex, _rid, _armyIndex )
                        -- 部队行军
                        local fromType = GuildBuildLogic:buildTypeToObjectType( buildInfo.type )
                        local armyInfo = ArmyLogic:getArmy( _rid, _armyIndex ) or {}
                        if not _disbandArmy then
                            local toType = _targetInfo and _targetInfo.objectType or nil
                            local armyRadius = CommonCacle:getArmyRadius( armyInfo.soldiers )
                            local targetInfo = _targetInfo
                            if ( not targetInfo or not targetInfo.armyRadius ) and _marchArgs.targetObjectIndex and _marchArgs.targetObjectIndex > 0 then
                                targetInfo = MSM.MapObjectTypeMgr[_marchArgs.targetObjectIndex].req.getObjectInfo( _marchArgs.targetObjectIndex )
                            end
                            ArmyLogic:armyEnterMap( _rid, _armyIndex, armyInfo, fromType, toType, buildInfo.pos, _marchArgs.targetPos,
                                                _marchArgs.targetObjectIndex, _marchArgs.targetType, armyRadius, targetInfo and targetInfo.armyRadius )
                        end
                        -- 更新当前的联盟建筑增援角色信息
                        local nowTime = os.time()
                        local startTime = buildInfo.reinforces[reinforceIndex].startTime
                        buildInfo.reinforces[reinforceIndex] = nil
                        GuildBuildLogic:setGuildBuild( _guildId, _buildIndex, { [Enum.GuildBuild.reinforces] = buildInfo.reinforces } )
                        if buildInfo.status == Enum.GuildBuildStatus.BUILDING then
                            -- 更新角色获得的联盟个人积分
                            local armyChangeInfo = {}
                            local allianceCoinReward = CFG.s_AllianceBuildingType:Get( buildInfo.type, "allianceCoinReward" )
                            if allianceCoinReward > 0 then
                                local addGuildBuildPoint = math.floor( allianceCoinReward / 3600 * ( nowTime - startTime ) )
                                if addGuildBuildPoint > 0 then
                                    armyChangeInfo.guildBuildPoint = ( armyInfo.guildBuildPoint or 0 ) + addGuildBuildPoint
                                end
                            end
                            -- 增加参与建造时间
                            armyChangeInfo.guildBuildTime = ( armyInfo.guildBuildTime or 0 ) + ( nowTime - startTime )
                            MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.BUILD_ALLIANCE_TIME,
                                nil, nil, nil, nil, nil, nil, nowTime - startTime )
                            ArmyLogic:setArmy( _rid, _armyIndex, armyChangeInfo )
                            -- 建造中的联盟建筑, 刷新联盟建筑定时器
                            MSM.GuildTimerMgr[_guildId].req.resetGuildBuildTimer( _guildId, _buildIndex )
                            -- 部队离开建造中的联盟建筑
                            local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
                            LogLogic:guildBuildTroops( {
                                logType = Enum.LogType.ARMY_LEAVE_GUILD_BUILD, iggid = iggid, guildId = _guildId,
                                buildIndex = _buildIndex, buildType = buildInfo.type, rid = _rid, mainHeroId = armyInfo.mainHeroId,
                                deputyHeroId = armyInfo.deputyHeroId, buildTime = nowTime - startTime, soldiers = armyInfo.soldiers
                            } )
                        end
                        -- 推送联盟建筑部队信息到关注角色中
                        GuildBuildLogic:syncGuildBuildArmy( _oldObjectIndex, nil, nil, { reinforceIndex } )
                    end
                end
                if buildInfo.status == Enum.GuildBuildStatus.BUILDING then
                    -- 更新联盟建筑索引
                    MSM.GuildIndexMgr[_guildId].post.addBuildIndex( _guildId, _buildIndex )
                end
            end
        end
    )
end

---@see 移除联盟建筑
function accept.removeGuildBuild( _guildId, _buildIndex, _rid )
    --- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            -- 移除建筑定时器
            MSM.GuildTimerMgr[_guildId].req.removeGuildBuildTimer( _guildId, _buildIndex )
            local buildInfo = GuildBuildLogic:getGuildBuild( _guildId, _buildIndex )
            -- 拆除建筑
            local emailId = CFG.s_AllianceBuildingType:Get( buildInfo.type, "buildRemoveMail" ) or 0
            if GuildBuildLogic:removeGuildBuild( _guildId, _buildIndex, buildInfo, nil, nil, true ) and emailId > 0 then
                -- 发送联盟建筑被拆除邮件
                local members = GuildLogic:getGuild( _guildId, Enum.Guild.members ) or {}
                local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } )
                local guildEmail = {
                    roleName = roleInfo.name,
                    roleHeadId = roleInfo.headId,
                    roleHeadFrameId = roleInfo.headFrameID,
                }

                local posArg = string.format( "%d,%d", buildInfo.pos.x, buildInfo.pos.y )
                local emailOtherInfo = {
                    subTitleContents = { buildInfo.type },
                    emailContents = { buildInfo.type, posArg, posArg },
                    guildEmail = guildEmail
                }
                -- 发送联盟邮件
                snax.self().post.sendGuildEmail( _guildId, members, emailId, emailOtherInfo )
                -- 玩家主动拆除联盟建筑事件
                local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
                LogLogic:guildBuild( {
                    logType = Enum.LogType.ROLE_REMOVE_GUILD_BUILD, iggid = iggid,
                    guildId = _guildId, buildIndex = _buildIndex, buildType = buildInfo.type,
                    buildNum = GuildBuildLogic:getBuildNum( _guildId, buildInfo.type ),
                } )
            end
        end
    )
end

---@see 联盟建筑维修
function response.repairGuildBuild( _guildId, _buildIndex, _rid, _type )
    --- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            local buildInfo = GuildBuildLogic:getGuildBuild( _guildId, _buildIndex )

            local nowTime = os.time()
            local sBuildingType = CFG.s_AllianceBuildingType:Get( buildInfo.type )
            -- 是否在燃烧状态
            if buildInfo.status ~= Enum.GuildBuildStatus.BURNING then
                LOG_ERROR("rid(%d) repairGuildBuild, buildIndex(%d) not burning status", _rid, _buildIndex)
                return nil, ErrorCode.GUILD_BUILD_NOT_BURNING
            end

            -- 是否还在冷却时间内
            local lastRepairTime = buildInfo.buildBurnInfo and buildInfo.buildBurnInfo.lastRepairTime or 0
            if lastRepairTime + sBuildingType.outFireCD > nowTime then
                LOG_ERROR("rid(%d) repairGuildBuild, buildIndex(%d) repair cdtime", _rid, _buildIndex)
                return nil, ErrorCode.GUILD_REPAIR_CDTIME_LIMIT
            end

            if _type == Enum.GuildRepairType.DENAR then
                -- 代币灭火
                if sBuildingType.fixGem > 0 then
                    -- 角色代币是否足够
                    if not RoleLogic:checkDenar( _rid, sBuildingType.fixGem ) then
                        LOG_ERROR("rid(%d) repairGuildBuild, role denar not enough", _rid, _buildIndex)
                        return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
                    end
                    -- 扣除角色代币
                    RoleLogic:addDenar( _rid, - sBuildingType.fixGem, nil, Enum.LogType.REPAIR_GUILD_BUILD_COST_DENAR )
                end
            elseif _type == Enum.GuildRepairType.GUILD_POINT then
                local guildJob = GuildLogic:getRoleGuildJob( _guildId, _rid )
                if not GuildLogic:checkRoleJurisdiction( _rid, Enum.GuildJurisdictionType.BUILDING_EXTINGUISH, guildJob ) then
                    return nil, ErrorCode.GUILD_NO_JURISDICTION
                end

                -- 联盟积分灭火
                if sBuildingType.fixFund > 0 then
                    if not GuildLogic:checkGuildCurrency( _guildId, Enum.CurrencyType.leaguePoints, sBuildingType.fixFund ) then
                        LOG_ERROR("rid(%d) repairGuildBuild, guildId(%d) point not enough", _rid, _guildId)
                        return nil, ErrorCode.GUILD_POINT_NOT_ENOUGH
                    end

                    -- 扣除联盟积分
                    GuildLogic:addGuildCurrency( _guildId, Enum.CurrencyType.leaguePoints, - sBuildingType.fixFund )
                end
            end
            -- 联盟建筑维修灭火
            GuildBuildLogic:repairGuildBuild( _guildId, _buildIndex, buildInfo )
        end
    )
end

---@see 燃烧联盟建筑
function accept.burnGuildBuild( _guildId, _buildIndex, _armyRid )
    --- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end
            -- 联盟建筑燃烧
            GuildBuildLogic:burnGuildBuild( _guildId, _buildIndex, nil, _armyRid )
        end
    )
end

---@see 编辑联盟属性
function accept.modifyGuildInfo( _guildId, _rid, _type, _guildChangeInfo, _noSync )
    --- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            local oldColor = GuildLogic:getTerritoryColor( _guildId )
            local oldGuildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.needExamine, Enum.Guild.languageId } )
            -- 更新联盟信息
            GuildLogic:setGuild( _guildId, _guildChangeInfo )
            if not _noSync then
                -- 通知修改角色客户端
                GuildLogic:syncGuild( _rid, _guildChangeInfo, true )
            end
            -- 更新联盟信息修改标识
            if _type == Enum.GuildModifyType.WELCOME_EMAIL then
                local welcomeEmailIndex = MSM.GuildIndexMgr[_guildId].req.addWelcomeEmailIndex( _guildId )
                -- 更新角色欢迎邮件修改标识
                RoleLogic:updateRoleGuildIndexs( _rid, { welcomeEmailIndex = welcomeEmailIndex } )
            else
                -- 更新联盟修改标识
                local guildIndex = MSM.GuildIndexMgr[_guildId].req.addGuildIndex( _guildId )
                -- 更新角色联盟信息修改标识
                RoleLogic:updateRoleGuildIndexs( _rid, { guildIndex = guildIndex } )

                if _type == Enum.GuildModifyType.NAME then
                    -- 联盟名称修改
                    GuildLogic:modifyGuildNameCallBack( _guildId )
                elseif _type == Enum.GuildModifyType.ABB_NAME then
                    -- 联盟简称修改
                    GuildLogic:modifyGuildAbbNameCallBack( _guildId )
                elseif _type == Enum.GuildModifyType.NOTICE then
                    -- 修改语言和是否需要审批
                    local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.memberLimit, Enum.Guild.power } )
                    if guildInfo and table.size( guildInfo.members ) < guildInfo.memberLimit then
                        local newGuildInfo = {
                            languageId = _guildChangeInfo.languageId or oldGuildInfo.languageId,
                            needExamine = _guildChangeInfo.needExamine, power = guildInfo.power
                        }
                        SM.GuildRecommendMgr.post.modifyGuildInfo( _guildId, oldGuildInfo, newGuildInfo )
                    end
                    MSM.GuildIndexMgr[_guildId].post.addGuildNoticeIndex( _guildId )
                elseif _type == Enum.GuildModifyType.SIGNS then
                    -- 修改联盟旗帜标识, 更新地图aoi
                    local updateMapBuildInfo = { guildFlagSigns = _guildChangeInfo.signs }
                    local objectIndexs = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndexs( _guildId ) or {}
                    local noUpdateObjectType = {
                        Enum.RoleType.GUILD_FOOD, Enum.RoleType.GUILD_WOOD, Enum.RoleType.GUILD_STONE, Enum.RoleType.GUILD_GOLD
                    }
                    for _, objectIndex in pairs( objectIndexs ) do
                        -- 更新地图建筑旗帜信息
                        MSM.SceneGuildBuildMgr[objectIndex].post.updateGuildBuildInfo( objectIndex, updateMapBuildInfo, noUpdateObjectType )
                    end
                    -- 更新领地颜色
                    local newColor = GuildLogic:getTerritoryColor( _guildId, _guildChangeInfo.signs )
                    if oldColor ~= newColor then
                        MSM.GuildTerritoryMgr[_guildId].post.modifyGuildTerritoryColor( _guildId, newColor )
                    end

                    -- 更新集结部队的联盟旗帜标识
                    local guildRallyTeams = MSM.RallyMgr[_guildId].req.getGuildRallyInfo( _guildId ) or {}
                    for _, rallyTeam in pairs( guildRallyTeams ) do
                        if rallyTeam.rallyObjectIndex and rallyTeam.rallyObjectIndex > 0 then
                            MSM.SceneArmyMgr[rallyTeam.rallyObjectIndex].post.syncArmyGuildFlagSigns( rallyTeam.rallyObjectIndex, _guildChangeInfo.signs )
                        end
                    end
                    -- 更新联盟所占圣地关卡旗帜信息
                    MSM.GuildHolyLandMgr[_guildId].post.updateGuildFlagSigns( _guildId, _guildChangeInfo.signs )
                end
            end
        end
    )
end

---@see 联盟资源点变化
function accept.guildResourcePointChange( _guildId, _type, _addNum )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            GuildLogic:guildResourcePointChange( _guildId, _type, _addNum )
        end
    )
end

---@see 领取联盟领土收益
function accept.takeGuildTerritoryGain( _guildId, _rid )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end
            -- 领取联盟领土收益
            GuildLogic:takeGuildTerritoryGain( _guildId, _rid )
        end
    )
end

---@see 在联盟资源中心采集的角色采集速度变化
function accept.roleArmyCollectSpeedChange( _guildId, _buildIndex, _memberRid )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end
            -- 更新联盟成员采集速度, 重置定时器
            MSM.GuildTimerMgr[_guildId].req.resetResourceCenterTimer( _guildId, _buildIndex, nil, Enum.GuildResourceCenterReset.SPEED_CHANGE, _memberRid )
        end
    )
end

---@see 捐献联盟科技
function response.donateTechnology( _guildId, _rid, _donateType, _technologyType )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return nil, ErrorCode.GUILD_NOT_EXIST end

            local donateNum
            local nowTime = os.time()
            local sConfig = CFG.s_Config:Get()
            local roleInfo = RoleLogic:getRole( _rid, {
                Enum.Role.lastGuildDonateTime, Enum.Role.guildDonateCostDenar, Enum.Role.joinGuildTime
            } )
            local lastGuildDonateTime = roleInfo.lastGuildDonateTime
            local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.technologies, Enum.Guild.dailyDonates, Enum.Guild.weekDonates } ) or {}
            local technologies = guildInfo.technologies or {}
            local technologyId = _technologyType * 100 + ( technologies[_technologyType] and technologies[_technologyType].level or 0 ) + 1
            local sAllianceStudy = CFG.s_AllianceStudy:Get( technologyId )

            -- 是否有该配置
            if not sAllianceStudy or table.empty( sAllianceStudy ) then
                LOG_ERROR("rid(%d) donateTechnology, technologyType(%d) not cfg", _rid, _technologyType)
                return nil, ErrorCode.CFG_ERROR
            end

            -- 联盟前置科技是否已满足
            if not technologies[_technologyType] then
                if ( sAllianceStudy.preconditionStudy1 > 0 and ( not technologies[sAllianceStudy.preconditionStudy1]
                        or technologies[sAllianceStudy.preconditionStudy1].level < sAllianceStudy.preconditionLv1 ) )
                    or ( sAllianceStudy.preconditionStudy2 > 0 and ( not technologies[sAllianceStudy.preconditionStudy2]
                        or technologies[sAllianceStudy.preconditionStudy2].level < sAllianceStudy.preconditionLv2 ) )
                    or ( sAllianceStudy.preconditionStudy3 > 0 and ( not technologies[sAllianceStudy.preconditionStudy3]
                        or technologies[sAllianceStudy.preconditionStudy3].level < sAllianceStudy.preconditionLv3 ) )
                    or ( sAllianceStudy.preconditionStudy4 > 0 and ( not technologies[sAllianceStudy.preconditionStudy4]
                        or technologies[sAllianceStudy.preconditionStudy4].level < sAllianceStudy.preconditionLv4 ) ) then
                    LOG_ERROR("rid(%d) donateTechnology, precondition technology not finish", _rid)
                    return nil, ErrorCode.GUILD_DONATE_PRE_NOT_FINISH
                end
            end

            if _donateType == Enum.GuildDonateType.RESOURCE then
                -- 使用资源捐献
                -- 是否有捐献次数
                donateNum = math.floor( ( nowTime - lastGuildDonateTime ) / sConfig.AllianceStudyGiftCD )
                if donateNum <= 0 then
                    LOG_ERROR("rid(%d) donateTechnology, role not have donate times", _rid)
                    return nil, ErrorCode.GUILD_TECHNOLOGY_DONATE_NO_TIMES
                end

                -- 资源是否足够
                if sAllianceStudy.currencyType == Enum.CurrencyType.food then
                    -- 粮食
                    if not RoleLogic:checkFood( _rid, sAllianceStudy.currencyNum ) then
                        LOG_ERROR("rid(%d) donateTechnology, role food not enough", _rid)
                        return nil, ErrorCode.GUILD_DONATE_FOOD_NOT_ENOUGH
                    end
                    -- 扣除粮食
                    RoleLogic:addFood( _rid, - sAllianceStudy.currencyNum, nil, Enum.LogType.GUILD_DONATE_COST_CURRENCY )
                elseif sAllianceStudy.currencyType == Enum.CurrencyType.wood then
                    -- 木材
                    if not RoleLogic:checkWood( _rid, sAllianceStudy.currencyNum ) then
                        LOG_ERROR("rid(%d) donateTechnology, role wood not enough", _rid)
                        return nil, ErrorCode.GUILD_DONATE_WOOD_NOT_ENOUGH
                    end
                    -- 扣除粮食
                    RoleLogic:addWood( _rid, - sAllianceStudy.currencyNum, nil, Enum.LogType.GUILD_DONATE_COST_CURRENCY )
                elseif sAllianceStudy.currencyType == Enum.CurrencyType.stone then
                    -- 石料
                    if not RoleLogic:checkStone( _rid, sAllianceStudy.currencyNum ) then
                        LOG_ERROR("rid(%d) donateTechnology, role food not enough", _rid)
                        return nil, ErrorCode.GUILD_DONATE_STONE_NOT_ENOUGH
                    end
                    -- 扣除粮食
                    RoleLogic:addStone( _rid, - sAllianceStudy.currencyNum, nil, Enum.LogType.GUILD_DONATE_COST_CURRENCY )
                elseif sAllianceStudy.currencyType == Enum.CurrencyType.gold then
                    -- 金币
                    if not RoleLogic:checkGold( _rid, sAllianceStudy.currencyNum ) then
                        LOG_ERROR("rid(%d) donateTechnology, role food not enough", _rid)
                        return nil, ErrorCode.GUILD_DONATE_GOLD_NOT_ENOUGH
                    end
                    -- 扣除粮食
                    RoleLogic:addGold( _rid, - sAllianceStudy.currencyNum, nil, Enum.LogType.GUILD_DONATE_COST_CURRENCY )
                end

                -- 更新角色上次捐献时间
                if donateNum >= sConfig.AllianceStudyGiftTime then
                    lastGuildDonateTime = nowTime - ( sConfig.AllianceStudyGiftTime - 1 ) * sConfig.AllianceStudyGiftCD
                else
                    lastGuildDonateTime = lastGuildDonateTime + sConfig.AllianceStudyGiftCD
                end
                -- 更新上次捐献时间
                RoleLogic:setRole( _rid, { [Enum.Role.lastGuildDonateTime] = lastGuildDonateTime } )
                -- 通知客户端
                RoleSync:syncSelf( _rid, { [Enum.Role.lastGuildDonateTime] = lastGuildDonateTime }, true )
            elseif _donateType == Enum.GuildDonateType.DENAR then
                -- 使用代币捐献
                -- 加入联盟时间是否超过24小时
                if roleInfo.joinGuildTime + sConfig.AllianceGemGiftCD > nowTime then
                    LOG_ERROR("rid(%d) donateTechnology, role join guild time not enough", _rid)
                    return nil, ErrorCode.GUILD_JOIN_TIME_NOT_ENOUGH
                end

                -- 角色代币是否足够
                local guildDonateCostDenar = roleInfo.guildDonateCostDenar
                if not RoleLogic:checkDenar( _rid, guildDonateCostDenar ) then
                    LOG_ERROR("rid(%d) donateTechnology, role denar not enough", _rid)
                    return nil, ErrorCode.GUILD_DONATE_DENAR_NOT_ENOUGH
                end

                -- 扣除代币
                RoleLogic:addDenar( _rid, - guildDonateCostDenar, nil, Enum.LogType.GUILD_DONATE_COST_CURRENCY )
                if guildDonateCostDenar < sConfig.AllianceCostGemUpperLimit then
                    guildDonateCostDenar = guildDonateCostDenar + sConfig.AllianceGemGiftIncrease
                    if guildDonateCostDenar > sConfig.AllianceCostGemUpperLimit then
                        guildDonateCostDenar = sConfig.AllianceCostGemUpperLimit
                    end
                    -- 更新角色使用宝石捐献需要的宝石数量
                    RoleLogic:setRole( _rid, { [Enum.Role.guildDonateCostDenar] = guildDonateCostDenar } )
                    -- 通知客户端
                    RoleSync:syncSelf( _rid, { [Enum.Role.guildDonateCostDenar] = guildDonateCostDenar }, true )
                end
            else
                LOG_ERROR("rid(%d) donateTechnology, donateType(%d) arg error", _rid, _donateType)
                return nil, ErrorCode.GUILD_ARG_ERROR
            end

            -- 获得捐献奖励
            local critRate = {
                { id = 1, rate = sConfig.AllianceStudyCrit_1 },
                { id = 2, rate = sConfig.AllianceStudyCrit_2 },
                { id = 5, rate = sConfig.AllianceStudyCrit_5 },
                { id = 10, rate = sConfig.AllianceStudyCrit_10 },
            }

            local Random = require "Random"
            critRate = Random.GetId( critRate )
            local addDonateNum = sConfig.AllianceAcquireStudyDot * critRate
            -- 更新联盟科技的科技点
            if not technologies[_technologyType] then
                technologies[_technologyType] = {
                    type = _technologyType,
                    level = 0,
                    exp = addDonateNum
                }
            else
                technologies[_technologyType].exp = technologies[_technologyType].exp + addDonateNum
            end
            if technologies[_technologyType].exp > sAllianceStudy.progress then
                technologies[_technologyType].exp = sAllianceStudy.progress
            end
            -- 角色增加每日和每周的捐献值
            local dailyDonates = guildInfo.dailyDonates or {}
            if not dailyDonates[_rid] then
                dailyDonates[_rid] = {
                    rid = _rid,
                    donateNum = addDonateNum,
                    donateTime = nowTime
                }
            else
                dailyDonates[_rid].donateNum = dailyDonates[_rid].donateNum + addDonateNum
                dailyDonates[_rid].donateTime = nowTime
            end
            local weekDonates = guildInfo.weekDonates or {}
            if not weekDonates[_rid] then
                weekDonates[_rid] = {
                    rid = _rid,
                    donateNum = addDonateNum,
                    donateTime = nowTime
                }
            else
                weekDonates[_rid].donateNum = weekDonates[_rid].donateNum + addDonateNum
                weekDonates[_rid].donateTime = nowTime
            end
            -- 更新联盟科技点信息
            GuildLogic:setGuild( _guildId, {
                [Enum.Guild.technologies] = technologies,
                [Enum.Guild.dailyDonates] = dailyDonates,
                [Enum.Guild.weekDonates] = weekDonates
            } )
            -- 通知角色当天的联盟捐献值
            GuildTechnologyLogic:syncGuildTechnology( _rid, nil, nil, nil, nil, dailyDonates[_rid].donateNum )

            -- 增加个人积分
            RoleLogic:addGuildPoint( _rid, sConfig.AllianceAcquireSoloFund * critRate, nil, Enum.LogType.GUILD_DONATE_GAIN_CURRENCY )
            -- 增加联盟积分
            GuildLogic:addGuildCurrency( _guildId, Enum.CurrencyType.leaguePoints, sConfig.AllianceAcquireFund * critRate )

            -- 增加活动进度相关
            MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.ALLIANCE_TECH_DONATE, 1 )
            -- 更新联盟科技捐献排行榜
            Timer.runAfter( 1, RankLogic.update, RankLogic, _rid, Enum.RankType.ALLIACEN_ROLE_DONATE, weekDonates[_rid].donateNum, _guildId )

            return { technologyType = _technologyType, critNum = critRate, exp = technologies[_technologyType].exp }
        end
    )
end

---@see 设置推荐联盟科技
function accept.recommendTechnology( _guildId, _technologyType )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            local recommendTechnologyType = GuildLogic:getGuild( _guildId, Enum.Guild.recommendTechnologyType ) or 0
            if recommendTechnologyType == _technologyType then
                return
            end
            -- 更新推荐联盟科技子类型
            GuildLogic:setGuild( _guildId, { [Enum.Guild.recommendTechnologyType] = _technologyType } )
            -- 通知在线联盟成员
            GuildTechnologyLogic:syncGuildTechnology( GuildLogic:getAllOnlineMember( _guildId ), nil, _technologyType )
        end
    )
end

---@see 研究联盟科技
function accept.researchTechnology( _guildId, _rid, _technologyType )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            local nowTime = os.time()
            -- 是否正在研究其他联盟科技
            local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.technologies, Enum.Guild.researchTechnologyType, Enum.Guild.researchTime } )
            if guildInfo.researchTechnologyType and guildInfo.researchTechnologyType > 0 then
                LOG_ERROR("rid(%d) researchTechnology, research other technologyType(%d)", _rid, guildInfo.researchTechnologyType)
                return nil, ErrorCode.GUILD_RESEARCH_OTHER_TECHNOLOGY
            end
            -- 联盟资源是否足够
            local technologyLevel = guildInfo.technologies[_technologyType] and guildInfo.technologies[_technologyType].level or 0
            local technologyId = _technologyType * 100 + technologyLevel + 1
            local sAllianceStudy = CFG.s_AllianceStudy:Get( technologyId )
            if ( sAllianceStudy.needFood > 0 and not GuildLogic:checkGuildCurrency( _guildId, Enum.CurrencyType.allianceFood, sAllianceStudy.needFood ) )
                or ( sAllianceStudy.needWood > 0 and not GuildLogic:checkGuildCurrency( _guildId, Enum.CurrencyType.allianceWood, sAllianceStudy.needWood ) )
                or ( sAllianceStudy.needStone > 0 and not GuildLogic:checkGuildCurrency( _guildId, Enum.CurrencyType.allianceStone, sAllianceStudy.needStone ) )
                or ( sAllianceStudy.needGold > 0 and not GuildLogic:checkGuildCurrency( _guildId, Enum.CurrencyType.allianceGold, sAllianceStudy.needGold ) )
                or ( sAllianceStudy.needLeaguePoints > 0 and not GuildLogic:checkGuildCurrency( _guildId, Enum.CurrencyType.leaguePoints, sAllianceStudy.needLeaguePoints ) ) then
                LOG_ERROR("rid(%d) researchTechnology, guild resource not enough", _rid)
                return nil, ErrorCode.GUILD_RESEARCH_RESOURCE_NOT_ENOUGH
            end
            local consumeCurrencies = {}
            -- 扣除资源
            local currencies
            if sAllianceStudy.needFood > 0 then
                currencies = GuildLogic:addGuildCurrency( _guildId, Enum.CurrencyType.allianceFood, - sAllianceStudy.needFood, nil, true )
                consumeCurrencies[Enum.CurrencyType.allianceFood] = { type = Enum.CurrencyType.allianceFood, num = - sAllianceStudy.needFood }
            end
            if sAllianceStudy.needWood > 0 then
                currencies = GuildLogic:addGuildCurrency( _guildId, Enum.CurrencyType.allianceWood, - sAllianceStudy.needWood, nil, true )
                consumeCurrencies[Enum.CurrencyType.allianceWood] = { type = Enum.CurrencyType.allianceWood, num = - sAllianceStudy.needWood }
            end
            if sAllianceStudy.needStone > 0 then
                currencies = GuildLogic:addGuildCurrency( _guildId, Enum.CurrencyType.allianceStone, - sAllianceStudy.needStone, nil, true )
                consumeCurrencies[Enum.CurrencyType.allianceStone] = { type = Enum.CurrencyType.allianceStone, num = - sAllianceStudy.needStone }
            end
            if sAllianceStudy.needGold > 0 then
                currencies = GuildLogic:addGuildCurrency( _guildId, Enum.CurrencyType.allianceGold, - sAllianceStudy.needGold, nil, true )
                consumeCurrencies[Enum.CurrencyType.allianceGold] = { type = Enum.CurrencyType.allianceGold, num = - sAllianceStudy.needGold }
            end
            if sAllianceStudy.needLeaguePoints > 0 then
                currencies = GuildLogic:addGuildCurrency( _guildId, Enum.CurrencyType.leaguePoints, - sAllianceStudy.needLeaguePoints, nil, true )
                consumeCurrencies[Enum.CurrencyType.leaguePoints] = { type = Enum.CurrencyType.leaguePoints, num = - sAllianceStudy.needLeaguePoints }
            end
            -- 更新联盟正在研究的科技
            GuildLogic:setGuild( _guildId, { [Enum.Guild.researchTechnologyType] = _technologyType, [Enum.Guild.researchTime] = nowTime } )
            -- 增加定时器
            MSM.GuildTimerMgr[_guildId].req.addTechnologyResearchTimer( _guildId )
            -- 通知联盟成员
            GuildTechnologyLogic:syncGuildTechnology( GuildLogic:getAllOnlineMember( _guildId ), nil, nil, _technologyType, nowTime )
            -- 添加联盟资源消费记录
            GuildLogic:addConsumeRecord( _guildId, _rid, Enum.GuildConsumeType.TECHNOLOGY, { _technologyType, technologyLevel + 1 }, consumeCurrencies )
            -- 更新联盟货币信息
            local allMemberRids = GuildLogic:getAllOnlineMember( _guildId )
            if #allMemberRids > 0 then
                GuildLogic:syncGuildDepot( allMemberRids, currencies )
            end
        end
    )
end

---@see 联盟科技研究完成处理
function response.guildTechnologyResearchFinish( _guildId )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            local guildInfo = GuildLogic:getGuild( _guildId, {
                Enum.Guild.technologies, Enum.Guild.researchTechnologyType, Enum.Guild.researchTime, Enum.Guild.members
            } )
            local technologyInfo = guildInfo.technologies[guildInfo.researchTechnologyType] or {
                type = guildInfo.researchTechnologyType,
                level = 0,
                exp = 0
            }

            -- 更新研究完成的科技信息
            technologyInfo.level = technologyInfo.level + 1
            technologyInfo.exp = 0
            guildInfo.technologies[guildInfo.researchTechnologyType] = technologyInfo
            local technologyId = technologyInfo.type * 100 + technologyInfo.level
            -- 更新联盟信息
            GuildLogic:setGuild( _guildId, {
                [Enum.Guild.technologies] = guildInfo.technologies,
                [Enum.Guild.researchTechnologyType] = 0,
                [Enum.Guild.researchTime] = 0
            } )
            -- 通知所有在线成员
            GuildTechnologyLogic:syncGuildTechnology(
                GuildLogic:getAllOnlineMember( _guildId ),
                { [guildInfo.researchTechnologyType] = technologyInfo }, nil, 0, 0
            )
            -- 发送科技研究完成邮件
            local sAllianceStudy = CFG.s_AllianceStudy:Get( technologyId )
            local emailOtherInfo = {
                guildEmail = {
                    technologyId = sAllianceStudy.ID,
                },
                emailContents = { technologyInfo.level, sAllianceStudy.ID }
            }
            -- 发送联盟邮件
            snax.self().post.sendGuildEmail( _guildId, guildInfo.members, 300017, emailOtherInfo )
            -- 计算联盟属性和角色属性
            MSM.GuildAttrMgr[_guildId].req.researchTechnologyFinish( _guildId, guildInfo.researchTechnologyType )
        end
    )
end

---@see 每日联盟科技贡献处理
function accept.resetGuildDailyDonate( _guildId )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end
            -- 发放成员每日捐献奖励
            GuildTechnologyLogic:resetMemberDailyDonates( _guildId )
        end
    )
end

---@see 每周联盟科技贡献处理
function accept.resetGuildWeekDonate( _guildId )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end
            -- 发放成员每周捐献奖励
            GuildTechnologyLogic:resetMemberWeekDonates( _guildId )
        end
    )
end

---@see 发布联盟留言板消息
function response.sendBoardMessage( _guildId, _replyMessageIndex, _content, _roleInfo )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return { error = ErrorCode.GUILD_NOT_EXIST } end

            -- 发布联盟留言板消息
            return MSM.GuildMessageBoardMgr[_guildId].req.sendBoardMessage( _guildId, _replyMessageIndex, _content, _roleInfo )
        end
    )
end

---@see 删除联盟留言板消息
function response.deleteBoardMessage( _guildId, _messageIndex, _rid )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return { error = ErrorCode.GUILD_NOT_EXIST } end

            -- 发布联盟留言板消息
            return MSM.GuildMessageBoardMgr[_guildId].req.deleteBoardMessage( _guildId, _messageIndex, _rid )
        end
    )
end

---@see 发放礼物
function accept.sendGuildGift( _guildId, _giftType, _buyRid, _isHideName, _packageNameId, _sendType, _giftArgs )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            -- 获取空闲索引
            guildGiftIndexs[_guildId] = ( guildGiftIndexs[_guildId] or GuildGiftLogic:getGiftMaxIndex( _guildId ) ) + 1
            -- 发放礼物
            GuildGiftLogic:sendGuildGift( _guildId, guildGiftIndexs[_guildId], _giftType, _buyRid, _isHideName, _packageNameId, _sendType, _giftArgs )
        end
    )
end

---@see 领取联盟礼物
function response.takeGuildGift( _guildId, _rid, _type, _giftIndex )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return nil, ErrorCode.GUILD_NOT_EXIST end

            local rewards, treasureNum
            guildGiftIndexs[_guildId] = ( guildGiftIndexs[_guildId] or GuildGiftLogic:getGiftMaxIndex( _guildId ) )
            if _type == Enum.GuildGiftTakeType.TREASURE then
                -- 领取珍藏
                rewards = GuildGiftLogic:takeTreasure( _guildId, _rid )
            elseif _type == Enum.GuildGiftTakeType.ALL_NORMAL_GIFT then
                -- 一键领取普通礼物
                rewards, treasureNum = GuildGiftLogic:takeNormalGifts( _guildId, _rid, guildGiftIndexs[_guildId] )
            elseif _type == Enum.GuildGiftTakeType.GIFT then
                -- 领取指定礼物
                rewards, treasureNum = GuildGiftLogic:takeGift( _guildId, _rid, _giftIndex, guildGiftIndexs[_guildId] )
            else
                LOG_ERROR("rid(%d) takeGuildGift, type(%d) error", _rid, _type)
                return nil, ErrorCode.GUILD_ARG_ERROR
            end

            guildGiftIndexs[_guildId] = guildGiftIndexs[_guildId] + ( treasureNum or 0 )

            return { rewards = rewards and not table.empty( rewards ) and rewards or nil, type = _type }
        end
    )
end

---@see 清除联盟过期和已领取的礼物信息
function accept.cleanGiftRecord( _guildId, _rid )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end
            -- 发放礼物
            GuildGiftLogic:cleanGiftRecord( _guildId, _rid )
        end
    )
end

---@see 跨周处理联盟排行榜信息
function accept.resetGuildRoleRanks( _guildId )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end
            -- 重置联盟角色排行信息
            GuildLogic:resetGuildRoleRanks( _guildId )
        end
    )
end

---@see 更新联盟角色排行榜
function accept.updateGuildRank( _guildId, _rid, _type, _addNum )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end
            -- 更新联盟角色排行榜
            GuildLogic:updateGuildRoleRank( _guildId, _rid, _type, _addNum )
        end
    )
end

function response.ShopStock( _guildId, idItemType, nCount, rid, name )
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            return GuildShopLogic:shopStock(_guildId, idItemType, nCount, rid, name)
        end
    )
end

function response.ShopBuy( _guildId, idItemType, nCount, rid, name )
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            return GuildShopLogic:shopBuy(_guildId, idItemType, nCount, rid, name)
        end
    )
end

function response.ShopQuery( _guildId, _rid )
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            return GuildShopLogic:shopQuery(_guildId, _rid)
        end
    )
end

---@see 联盟建筑耐久度上限变化
function accept.buildDurableLimitChange( _guildId )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            MSM.GuildTimerMgr[_guildId].req.buildDurableLimitChange( _guildId )
        end
    )
end

---@see 联盟建筑建造速度变化
function accept.buildSpeedChange( _guildId, _onlyFlag, _buildIndex )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            local guildBuilds
            if _buildIndex then
                guildBuilds = {}
                guildBuilds[_buildIndex] = GuildBuildLogic:getGuildBuild( _guildId, _buildIndex ) or {}
            else
                guildBuilds = GuildBuildLogic:getGuildBuild( _guildId ) or {}
            end
            for buildIndex, buildInfo in pairs( guildBuilds ) do
                if buildInfo.status == Enum.GuildBuildStatus.BUILDING and ( not _onlyFlag or buildInfo.type == Enum.GuildBuildType.FLAG ) then
                    MSM.GuildTimerMgr[_guildId].req.resetGuildBuildTimer( _guildId, buildIndex )
                end
            end
        end
    )
end

---@see 增援联盟圣地关卡
function response.reinforceHolyLand( _guildId, _rid, _reinforceObjectIndex, _reinforceArmys )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return nil, ErrorCode.GUILD_NOT_EXIST end

            -- 增援联盟圣地关卡
            return MSM.GuildHolyLandMgr[_guildId].req.reinforceHolyLand( _guildId, _rid, _reinforceObjectIndex, _reinforceArmys )
        end
    )
end

---@see 占领联盟圣地
function response.occupyHolyLand( _guildId, _holyLandId )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return nil, ErrorCode.GUILD_NOT_EXIST end

            -- 占领圣地关卡
            SM.HolyLandMgr.req.occupyHolyLand( _holyLandId, _guildId )
        end
    )
end

---@see 到达联盟圣地关卡
function response.arriveHolyLand( _guildId, _rid, _armyIndex, _objectIndex, _targetObjectIndex )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return nil, ErrorCode.GUILD_NOT_EXIST end

            -- 增援联盟圣地关卡
            return HolyLandLogic:arriveHolyLand( _guildId, _rid, _armyIndex, _objectIndex, _targetObjectIndex )
        end
    )
end

---@see 删除向联盟圣地的增援
function accept.deleteHolyLandArmy( _guildId, _rid, _armyIndex, _objectIndex )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            local mapHolyLandInfo = MSM.SceneHolyLandMgr[_objectIndex].req.getHolyLandInfo( _objectIndex )
            local reinforces = HolyLandLogic:getHolyLand( mapHolyLandInfo.strongHoldId, Enum.HolyLand.reinforces ) or {}

            local buildArmyIndex
            for index, reinforce in pairs( reinforces ) do
                if reinforce.rid == _rid and reinforce.armyIndex == _armyIndex then
                    buildArmyIndex = index
                    reinforces[index] = nil
                    break
                end
            end
            HolyLandLogic:setHolyLand( mapHolyLandInfo.strongHoldId, { [Enum.HolyLand.reinforces] = reinforces } )

            if buildArmyIndex then
                HolyLandLogic:syncHolyLandArmy( _objectIndex, nil, nil, { buildArmyIndex } )
            end
        end
    )
end

---@see 圣地关卡中的部队行军
function response.holyLandArmyMarch( _guildId, _objectIndex, _rid, _armyIndex, _marchArgs, _targetInfo )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            HolyLandLogic:holyLandArmyMarch( _objectIndex, _rid, _armyIndex, _marchArgs, _targetInfo )
        end
    )
end

---@see 加入联盟开启迷雾
function accept.openDenseFogOnJoinGuild( _guildId, _memberRid )
    local DenseFogLogic = require "DenseFogLogic"
    -- 加入联盟开启迷雾
    DenseFogLogic:onRoleJoinGuild( _guildId, _memberRid )
end

---@see 增加联盟书签
function response.addGuildMarker( _guildId, _rid, _markerId, _description, _gameNode, _pos, _oldMarkerId )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return nil, ErrorCode.GUILD_NOT_EXIST end
            -- 添加联盟书签
            MapMarkerLogic:addGuildMarker( _guildId, _rid, _markerId, _description, _gameNode, _pos, _oldMarkerId )

            return true
        end
    )
end

---@see 删除联盟书签
function response.deleteGuildMarker( _guildId, _rid, _markerId )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return nil, ErrorCode.GUILD_NOT_EXIST end
            -- 添加联盟书签
            MapMarkerLogic:deleteGuildMarker( _guildId, _rid, _markerId )

            return true
        end
    )
end

---@see 更新联盟书签状态
function accept.updateGuildMarkerStatus( _guildId, _rid )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end
            -- 更新联盟书签状态
            MapMarkerLogic:updateGuildMarkerStatus( _guildId, _rid )
        end
    )
end

---@see 更新联盟书签创建者名称
function accept.updateGuildMarkerName( _guildId, _rid, _name )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end
            -- 添加联盟书签
            MapMarkerLogic:updateGuildMarkerName( _guildId, _rid, _name )
        end
    )
end

---@see 发送联盟邮件
function accept.sendGuildEmail( _guildId, _members, _emailId, _emailOtherInfo )
    SM.ServiceBusyCheckMgr.post.addBusyService( Enum.ServiceBusyType.GUILD )
    _members = _members or GuildLogic:getGuild( _guildId, Enum.Guild.members ) or {}

    for memberRid in pairs( _members ) do
        pcall( EmailLogic.sendEmail, EmailLogic, memberRid, _emailId, _emailOtherInfo )
    end
    SM.ServiceBusyCheckMgr.post.subBusyService( Enum.ServiceBusyType.GUILD )
end

---@see 推送联盟盟友信息
function accept.pushGuildMembers( _guildId, _memberRid )
    local roleInfo
    local syncMember = {}
    local memberPos = {}
    local fields = {
        Enum.Role.rid, Enum.Role.headId, Enum.Role.name, Enum.Role.killCount,
        Enum.Role.headFrameID, Enum.Role.pos, Enum.Role.cityId
    }
    local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.guildOfficers } )
    if not guildInfo then
        return
    end

    local onlineMembers = GuildLogic:getAllOnlineMember( _guildId, guildInfo.members or {} )
    for memberRid, memberInfo in pairs( guildInfo.members or {} ) do
        roleInfo = RoleLogic:getRole( memberRid, fields )
        -- 战力不取角色当前最新，按照联盟记录的角色战力推送
        roleInfo.combatPower = memberInfo.combatPower
        roleInfo.guildJob = memberInfo.guildJob
        roleInfo.cityObjectIndex = RoleLogic:getRoleCityIndex( memberRid )

        roleInfo.online = table.exist( onlineMembers, memberRid ) or false
        -- 盟主有击杀数量
        if roleInfo.guildJob ~= Enum.GuildJob.LEADER then
            roleInfo.killCount = nil
        end
        syncMember[memberRid] = roleInfo

        if roleInfo.cityId > 0 then
            memberPos[memberRid] = {
                rid = memberRid,
                pos = roleInfo.pos,
            }
        end
    end

    -- 推送联盟成员信息
    Common.syncMsg( _memberRid, "Guild_GuildMemberInfo",  { guildMembers = syncMember, guildOfficers = guildInfo.guildOfficers } )
    if not table.empty( memberPos ) then
        Common.syncMsg( _memberRid, "Guild_GuildMemberPos", { memberPos = memberPos } )
    end

    -- 更新客户端当前最大的成员修改标识
    RoleLogic:updateRoleGuildIndexs( _memberRid, { guildMemberIndex = MSM.GuildIndexMgr[_guildId].req.getMemberGlobalIndex( _guildId ) } )
end

---@see 刷新角色在联盟中的战力
function accept.refreshGuildRolePower( _guildId, _memberRid )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            local guildInfo = GuildLogic:getGuild( _guildId, {
                Enum.Guild.members, Enum.Guild.memberLimit, Enum.Guild.languageId, Enum.Guild.needExamine, Enum.Guild.power
            } )
            local combatPower = RoleLogic:getRole( _memberRid, Enum.Role.combatPower ) or 0
            local power = guildInfo.power
            local members = guildInfo.members
            if members[_memberRid] and ( members[_memberRid].combatPower or 0 ) ~= combatPower then
                power = power - ( members[_memberRid].combatPower or 0 ) + combatPower
                members[_memberRid].combatPower = combatPower
                -- 更新联盟信息
                GuildLogic:setGuild( _guildId, { [Enum.Guild.members] = members, [Enum.Guild.power] = power } )
                RankLogic:update( _guildId, Enum.RankType.ALLIANCE_POWER, power )
                MSM.GuildIndexMgr[_guildId].post.addGuildIndex( _guildId )
            end
            -- 更新联盟推荐中的战力信息
            if table.size( members ) < guildInfo.memberLimit then
                SM.GuildRecommendMgr.post.addGuildId( _guildId, guildInfo.needExamine, guildInfo.languageId, power )
            end
        end
    )
end

---@see 战斗过程通知联盟建筑或圣地关卡部队士兵信息
function accept.syncBuildArmySoldiers( _guildId, _objectIndex, _buildArmyIndex, _armyInfo )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end

            local mapBuildInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex ) or {}
            if not table.empty( mapBuildInfo ) then
                if MapObjectLogic:checkIsAttackGuildBuildObject( mapBuildInfo.objectType ) then
                    -- 联盟建筑
                    if mapBuildInfo.buildIndex and mapBuildInfo.buildIndex > 0 then
                        local reinforces = GuildBuildLogic:getGuildBuild( _guildId, mapBuildInfo.buildIndex, Enum.GuildBuild.reinforces ) or {}
                        -- 检查此时部队是否还在联盟建筑中
                        if Common.isTable( _buildArmyIndex) then
                            -- 批量推送
                            local syncBuildArmyInfo = {}
                            for syncBuildArmyIndex, syncArmyInfo in pairs(_buildArmyIndex) do
                                if reinforces[syncBuildArmyIndex] then
                                    syncBuildArmyInfo[syncBuildArmyIndex] = syncArmyInfo
                                end
                            end
                            GuildBuildLogic:syncGuildBuildArmy( _objectIndex, syncBuildArmyInfo )
                        else
                            if reinforces[_buildArmyIndex] then
                                GuildBuildLogic:syncGuildBuildArmy( _objectIndex, { [_buildArmyIndex] = _armyInfo } )
                            end
                        end
                    end
                elseif MapObjectLogic:checkIsHolyLandObject( mapBuildInfo.objectType ) then
                    -- 圣地关卡
                    if mapBuildInfo.strongHoldId and mapBuildInfo.strongHoldId > 0 then
                        local reinforces = HolyLandLogic:getHolyLand( mapBuildInfo.strongHoldId, Enum.HolyLand.reinforces ) or {}
                        -- 检查此时部队是否还在圣地关卡中
                        if Common.isTable( _buildArmyIndex) then
                            -- 批量推送
                            local syncBuildArmyInfo = {}
                            for syncBuildArmyIndex, syncArmyInfo in pairs(_buildArmyIndex) do
                                if reinforces[syncBuildArmyIndex] then
                                    syncBuildArmyInfo[syncBuildArmyIndex] = syncArmyInfo
                                end
                            end
                            HolyLandLogic:syncHolyLandArmy( _objectIndex, syncBuildArmyInfo )
                        else
                            if reinforces[_buildArmyIndex] then
                                HolyLandLogic:syncHolyLandArmy( _objectIndex, { [_buildArmyIndex] = _armyInfo } )
                            end
                        end
                    end
                end
            end
        end
    )
end

---@see 清空超时的联盟礼物
function accept.cleanTimeOutGuildGifts( _guildId )
    -- 检查互斥锁
    checkGuildLock( _guildId )

    return guildLock[_guildId].lock(
        function ()
            -- 检查联盟是否存在
            if not GuildLogic:checkGuild( _guildId ) then return end
            -- 清空超时联盟礼物
            GuildGiftLogic:cleanTimeOutGuildGifts( _guildId )
        end
    )
end

---@see PMLogic调用更新联盟建筑buildArmyIndex
function response.getFreeBuildArmyIndex( _guildId, _buildIndex )
    initGuildBuildArmyIndex( _guildId, _buildIndex )
    return guildBuildArmyIndexs[_guildId][_buildIndex]
end

---@see 一键领取普通礼物更新联盟礼物表信息
function accept.updateGuildGift( _guildId, _giftIndex, _giftInfo )
    -- 避免维护导致联盟礼物信息更新失败
    SM.ServiceBusyCheckMgr.post.addBusyService( Enum.ServiceBusyType.GUILD )

    pcall( GuildGiftLogic.setGuildGift, GuildGiftLogic, _guildId, _giftIndex, _giftInfo )

    SM.ServiceBusyCheckMgr.post.subBusyService( Enum.ServiceBusyType.GUILD )
end

---@see 一键领取普通礼物发放奖励信息
function accept.giveAllRewards( _rid, _rewards )
    -- 避免维护导致发放奖励失败
    SM.ServiceBusyCheckMgr.post.addBusyService( Enum.ServiceBusyType.GUILD )

    pcall( GuildGiftLogic.giveAllRewards, GuildGiftLogic, _rid, _rewards )

    SM.ServiceBusyCheckMgr.post.subBusyService( Enum.ServiceBusyType.GUILD )
end