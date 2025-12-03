--[[
* @file : Email.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Tue Jan 07 2020 16:43:50 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 邮件相关协议代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local EmailLogic = require "EmailLogic"
local ItemLogic = require "ItemLogic"
local RoleLogic = require "RoleLogic"
local GuildLogic = require "GuildLogic"
local RoleSync = require "RoleSync"

---@see 领取邮件附件奖励
function response.TakeEnclosure( msg )
    local rid = msg.rid
    local type = msg.type
    local data = msg.data

    -- 参数检查
    if not type or not data then
        LOG_ERROR("rid(%d) TakeEnclosure, no type or no data arg", rid)
        return nil, ErrorCode.EMAIL_ARG_ERROR
    end

    local reward
    local emailVersion
    if type == 1 then
        -- 领取指定索引邮件附件
        local emailInfo = EmailLogic:getEmail( rid, data )
        if not emailInfo or table.empty( emailInfo ) then
            LOG_ERROR("rid(%d) TakeEnclosure, emailIndex(%d) not exist", rid, data)
            return nil, ErrorCode.EMAIL_NOT_EXIST
        end

        local sMail = CFG.s_Mail:Get( emailInfo.emailId )
        -- 邮件无附件奖励
        if not emailInfo.rewards or table.empty( emailInfo.rewards ) then
            LOG_ERROR("rid(%d) TakeEnclosure, emailIndex(%d) emailId(%d) not have enclosure", rid, data, emailInfo.emailId)
            return nil, ErrorCode.EMAIL_NOT_ENCLOSURE
        end

        -- 附件奖励是否已领取
        if emailInfo.takeEnclosure then
            LOG_ERROR("rid(%d) TakeEnclosure, already take emailIndex(%d) enclosure", rid, data, emailInfo.emailId)
            return nil, ErrorCode.EMAIL_ALREADY_TAKE_ENCLOSURE
        end

        if sMail.deleteAuto and sMail.deleteAuto == 1 then
            -- 领取附件后要自动删除
            EmailLogic:deleteEmail( rid, data )
        else
            -- 更新邮件附件领取状态
            EmailLogic:setEmail( rid, data, { takeEnclosure = true } )
            -- 通知客户端邮件领取状态
            EmailLogic:syncEmail( rid, data, { takeEnclosure = true }, true )
        end
        -- 领取附件奖励
        ItemLogic:giveReward( rid, emailInfo.rewards, emailInfo.rewards.groupId )
        emailVersion = true
    elseif type == 2 then
        -- 领取指定类型邮件附件
        local emails = EmailLogic:getEmail( rid )
        local sMail = CFG.s_Mail:Get()

        local mail, roleChange, itemChange
        local syncEmails = {}
        local roleChangeInfo = {}
        local itemChangeInfo = {}
        for emailIndex, emailInfo in pairs( emails ) do
            mail = sMail[emailInfo.emailId]
            if mail and mail.type == data then
                if not emailInfo.takeEnclosure and emailInfo.emailId and mail and ( ( mail.enclosure and mail.enclosure > 0 )
                    or ( emailInfo.rewards and not table.empty( emailInfo.rewards ) ) ) then
                    -- 是否要删除邮件
                    if mail.deleteAuto and mail.deleteAuto == 1 then
                        -- 删除邮件
                        EmailLogic:deleteEmail( rid, emailIndex, true )
                        syncEmails[emailIndex] = { emailIndex = emailIndex, emailId = -1 }
                    else
                        -- 更新邮件附件领取状态
                        EmailLogic:setEmail( rid, emailIndex, { takeEnclosure = true, status = Enum.EmailStatus.YES } )
                        syncEmails[emailIndex] = { emailIndex = emailIndex, takeEnclosure = true, status = Enum.EmailStatus.YES }
                    end
                    -- 领取附件奖励
                    roleChange, itemChange = ItemLogic:giveReward( rid, emailInfo.rewards, emailInfo.rewards.groupId, true )
                    table.mergeEx( roleChangeInfo, roleChange or {} )
                    if not table.empty( itemChange or {} ) then
                        for itemIndex, item in pairs(itemChange) do
                            if itemChangeInfo[itemIndex] then
                                itemChangeInfo[itemIndex].overlay = item.overlay
                            else
                                itemChangeInfo[itemIndex] = item
                            end
                        end
                    end
                    if not reward then reward = {} end
                    reward = ItemLogic:mergeReward( reward, emailInfo.rewards )
                    emailVersion = true
                elseif emailInfo.status ~= Enum.EmailStatus.YES then
                    -- 更新邮件附件读取状态
                    EmailLogic:setEmail( rid, emailIndex, { status = Enum.EmailStatus.YES } )
                    syncEmails[emailIndex] = { emailIndex = emailIndex, status = Enum.EmailStatus.YES }
                    emailVersion = true
                end
            end
        end

        if not table.empty( syncEmails ) then
            -- 通知客户端
            EmailLogic:syncEmail( rid, nil, syncEmails, true, true )
        end
        -- 角色变化信息合并推送
        if not table.empty( roleChangeInfo ) then
            RoleSync:syncSelf( rid, roleChangeInfo, true )
        end
        -- 道具变化信息合并推送
        if not table.empty( itemChangeInfo ) then
            ItemLogic:syncItem( rid, nil, itemChangeInfo, true )
        end
    else
        LOG_ERROR("rid(%d) TakeEnclosure, type(%d) arg error", rid, type)
        return nil, ErrorCode.EMAIL_ARG_ERROR
    end

    -- 更新邮件版本号
    if emailVersion then
        EmailLogic:updateEmailVersion( rid )
    end

    return { type = type, data = data, reward = reward }
end

---@see 删除邮件
function response.DeleteEmail( msg )
    local rid = msg.rid
    local type = msg.type
    local data = msg.data

    -- 参数检查
    if not type or not data then
        LOG_ERROR("rid(%d) DeleteEmail, no type or no data arg", rid)
        return nil, ErrorCode.EMAIL_ARG_ERROR
    end

    local emailVersion
    local syncEmails = {}
    if type == 1 then
        -- 删除指定索引邮件
        local emailInfo = EmailLogic:getEmail( rid, data )
        if not emailInfo or table.empty( emailInfo ) then
            EmailLogic:syncEmail( rid, nil, { [data] = { emailIndex = data, emailId = -1 } }, true, true )
            LOG_ERROR("rid(%d) DeleteEmail, emailIndex(%d) not exist", rid, data)
            return nil, ErrorCode.EMAIL_NOT_EXIST
        end

        if not emailInfo.takeEnclosure and not table.empty( emailInfo.rewards ) then
            LOG_ERROR("rid(%d) DeleteEmail, emailIndex(%d) rewards not award", rid, data)
            return nil, ErrorCode.EMAIL_REWARD_NOT_AWARD
        end

        local collectEmailSubType = Enum.EmailSubType.RESOURCE_COLLECT
        local discoverEmailSubType = Enum.EmailSubType.DISCOVER_REPORT
        local resourceHelpEmailSubType = Enum.EmailSubType.RSS_HELP
        local scoutedEmailSubType = Enum.EmailSubType.SCOUTED
        local messageReplySubType = Enum.EmailSubType.MESSAGE_REPLY
        if emailInfo.subType then
            if emailInfo.subType == collectEmailSubType then
                local emails = EmailLogic:getEmail( rid )
                for emailIndex, email in pairs( emails ) do
                    if email.subType and email.subType == collectEmailSubType then
                        -- 删除资源采集邮件
                        EmailLogic:deleteEmail( rid, emailIndex, true )
                        syncEmails[emailIndex] = { emailIndex = emailIndex, emailId = -1 }
                    end
                end
            elseif emailInfo.subType == discoverEmailSubType then
                local emails = EmailLogic:getEmail( rid )
                for emailIndex, email in pairs( emails ) do
                    if email.subType and email.subType == discoverEmailSubType then
                        -- 删除探索发现邮件
                        EmailLogic:deleteEmail( rid, emailIndex, true )
                        syncEmails[emailIndex] = { emailIndex = emailIndex, emailId = -1 }
                    end
                end
            elseif emailInfo.subType == resourceHelpEmailSubType then
                -- 资源援助邮件
                local emails = EmailLogic:getEmail( rid )
                for emailIndex, email in pairs( emails ) do
                    if email.subType and email.subType == resourceHelpEmailSubType then
                        -- 删除资源援助邮件
                        EmailLogic:deleteEmail( rid, emailIndex, true )
                        syncEmails[emailIndex] = { emailIndex = emailIndex, emailId = -1 }
                    end
                end
            elseif emailInfo.subType == scoutedEmailSubType then
                -- 被侦查邮件
                local emails = EmailLogic:getEmail( rid )
                for emailIndex, email in pairs( emails ) do
                    if email.subType and email.subType == scoutedEmailSubType then
                        EmailLogic:deleteEmail( rid, emailIndex, true )
                        syncEmails[emailIndex] = { emailIndex = emailIndex, emailId = -1 }
                    end
                end
            elseif emailInfo.subType == messageReplySubType then
                -- 留言回复邮件
                local emails = EmailLogic:getEmail( rid )
                for emailIndex, email in pairs( emails ) do
                    if email.subType and email.subType == messageReplySubType then
                        EmailLogic:deleteEmail( rid, emailIndex, true )
                        syncEmails[emailIndex] = { emailIndex = emailIndex, emailId = -1 }
                    end
                end
            else
                -- 删除邮件
                EmailLogic:deleteEmail( rid, data, nil, true )
                EmailLogic:checkDeleteGuildInviteEmail( rid, emailInfo )
            end
        else
            -- 删除邮件
            EmailLogic:deleteEmail( rid, data, nil, true )
            EmailLogic:checkDeleteGuildInviteEmail( rid, emailInfo )
        end
    elseif type == 2 then
        -- 删除指定类型已读邮件
        local mail
        local emails = EmailLogic:getEmail( rid )
        local sMail = CFG.s_Mail:Get()

        local noDeleteCollect, noDeleteDiscover, noDeleteResourceHelp, noDeleteScouted, noDeleteMessageReply
        if data == Enum.EmailType.REPORT then
            -- 采集邮件存在未读，全部都不删除
            for _, emailInfo in pairs( emails ) do
                if EmailLogic:checkCollectEmail( nil, nil, emailInfo ) and emailInfo.status == Enum.EmailStatus.NO then
                    noDeleteCollect = true
                elseif EmailLogic:checkDiscoverEmail( nil, nil, emailInfo ) and ( emailInfo.status == Enum.EmailStatus.NO
                    or ( emailInfo.discoverReport.mapFixPointId and emailInfo.discoverReport.mapFixPointId > 0
                        and not RoleLogic:checkVillageCave( rid, emailInfo.discoverReport.mapFixPointId ) ) ) then
                    -- 探索邮件未读或者未探索，全部都不删除
                    noDeleteDiscover = true
                elseif EmailLogic:checkCollectEmail( nil, nil, emailInfo ) and emailInfo.status == Enum.EmailStatus.NO then
                    -- 被侦查邮件
                    noDeleteScouted = true
                elseif EmailLogic:checkMessageReplyEmail( nil, nil, emailInfo ) and emailInfo.status == Enum.EmailStatus.NO then
                    -- 留言回复邮件
                    noDeleteMessageReply = true
                end
                if noDeleteCollect and noDeleteDiscover and noDeleteScouted then
                    break
                end
            end
        elseif data == Enum.EmailType.GUILD then
            -- 资源援助邮件存在未读，全部都不删除
            for _, emailInfo in pairs( emails ) do
                if EmailLogic:checkResourceHelpEmail( nil, nil, emailInfo ) and emailInfo.status == Enum.EmailStatus.NO then
                    noDeleteResourceHelp = true
                    if noDeleteResourceHelp then
                        break
                    end
                end
            end
        end

        for emailIndex, emailInfo in pairs( emails ) do
            repeat

            mail = sMail[emailInfo.emailId]
            if not mail then
                break
            end

            -- 未读邮件不能删除
            if emailInfo.status ~= Enum.EmailStatus.YES then
                break
            end

            if data == Enum.EmailType.COLLECT then
                -- 收藏邮件
                if emailInfo.isCollect then
                    -- 删除邮件
                    EmailLogic:deleteEmail( rid, emailIndex, true )
                    EmailLogic:checkDeleteGuildInviteEmail( rid, emailInfo )
                    syncEmails[emailIndex] = { emailIndex = emailIndex, emailId = -1 }
                    emailVersion = true
                end
            elseif data == Enum.EmailType.ROLE or data == Enum.EmailType.SEND then
                if mail.type ~= data then
                    break
                end

                EmailLogic:deleteEmail( rid, emailIndex, true )
                syncEmails[emailIndex] = { emailIndex = emailIndex, emailId = -1 }
                emailVersion = true
            else
                -- 无附件奖励或者已领取附件奖励、采集邮件和探索邮件判断
                if mail.type == data and ( emailInfo.takeEnclosure or ( table.empty( emailInfo.rewards or {} ) ) )
                    and ( data ~= Enum.EmailType.REPORT or (( not EmailLogic:checkCollectEmail( nil, nil, emailInfo ) or not noDeleteCollect )
                        or ( not EmailLogic:checkDiscoverEmail( nil, nil, emailInfo ) or not noDeleteDiscover )
                        or ( not EmailLogic:checkScoutedEmail( nil, nil, emailInfo ) or not noDeleteScouted
                        or ( not EmailLogic:checkMessageReplyEmail( nil, nil, emailInfo ) or not noDeleteMessageReply ) ) ) )
                    and ( data ~= Enum.EmailType.GUILD or ( not EmailLogic:checkResourceHelpEmail( nil, nil, emailInfo ) or not noDeleteResourceHelp ) ) then
                    -- 删除邮件
                    EmailLogic:deleteEmail( rid, emailIndex, true )
                    EmailLogic:checkDeleteGuildInviteEmail( rid, emailInfo )
                    syncEmails[emailIndex] = { emailIndex = emailIndex, emailId = -1 }
                    emailVersion = true
                end
            end

            until true
        end
    else
        LOG_ERROR("rid(%d) DeleteEmail, type(%d) arg error", rid, type)
        return nil, ErrorCode.EMAIL_ARG_ERROR
    end

    if not table.empty( syncEmails ) then
        -- 通知客户端
        EmailLogic:syncEmail( rid, nil, syncEmails, true, true )
    end

    -- 更新邮件版本号
    if emailVersion then
        EmailLogic:updateEmailVersion( rid )
    end

    return { type = type, data = data }
end

---@see 更新邮件状态为已读取
function response.UpdateEmailStatus( msg )
    local rid = msg.rid
    local emailIndexs = msg.emailIndexs

    -- 参数检查
    if not emailIndexs or table.empty( emailIndexs ) then
        LOG_ERROR("rid(%d) UpdateEmailStatus, no emailIndexs arg", rid)
        return nil, ErrorCode.EMAIL_ARG_ERROR
    end

    local collectResource, emailInfo, emailVersion, discoverEmail, resourceHelpEmail, scoutedEmail, messageReplyEmail
    local syncEmails = {}
    for _, emailIndex in pairs( emailIndexs ) do
        emailInfo = EmailLogic:getEmail( rid, emailIndex )
        if emailInfo and EmailLogic:checkEmail( nil, nil, emailInfo ) then
            -- 更新邮件读取状态
            EmailLogic:setEmail( rid, emailIndex, { status = Enum.EmailStatus.YES } )
            syncEmails[emailIndex] = { emailIndex = emailIndex, status = Enum.EmailStatus.YES }
            if EmailLogic:checkCollectEmail( nil, nil, emailInfo ) then
                collectResource = true
            elseif EmailLogic:checkDiscoverEmail( nil, nil, emailInfo ) then
                discoverEmail = true
            elseif EmailLogic:checkResourceHelpEmail( nil, nil, emailInfo ) then
                resourceHelpEmail = true
            elseif EmailLogic:checkScoutedEmail( nil, nil, emailInfo ) then
                scoutedEmail = true
            elseif EmailLogic:checkMessageReplyEmail( nil, nil, emailInfo ) then
                messageReplyEmail = true
            end
            emailVersion = true
        end
    end

    -- 更新所有采集邮件的状态
    if collectResource then
        local emails = EmailLogic:getEmail( rid )
        for index, email in pairs( emails ) do
            if EmailLogic:checkCollectEmail( nil, nil, email ) and email.status == Enum.EmailStatus.NO then
                -- 更新邮件读取状态
                EmailLogic:setEmail( rid, index, { status = Enum.EmailStatus.YES } )
                syncEmails[index] = { emailIndex = index, status = Enum.EmailStatus.YES }
                emailVersion = true
            end
        end
    elseif discoverEmail then
        -- 更新所有探索发现邮件的状态
        local emails = EmailLogic:getEmail( rid )
        for index, email in pairs( emails ) do
            if EmailLogic:checkDiscoverEmail( nil, nil, email ) and email.status == Enum.EmailStatus.NO then
                -- 更新邮件读取状态
                EmailLogic:setEmail( rid, index, { status = Enum.EmailStatus.YES } )
                syncEmails[index] = { emailIndex = index, status = Enum.EmailStatus.YES }
                emailVersion = true
            end
        end
    elseif resourceHelpEmail then
        -- 更新所有资源援助邮件的状态
        local emails = EmailLogic:getEmail( rid )
        for index, email in pairs( emails ) do
            if EmailLogic:checkResourceHelpEmail( nil, nil, email ) and email.status == Enum.EmailStatus.NO then
                -- 更新邮件读取状态
                EmailLogic:setEmail( rid, index, { status = Enum.EmailStatus.YES } )
                syncEmails[index] = { emailIndex = index, status = Enum.EmailStatus.YES }
                emailVersion = true
            end
        end
    elseif scoutedEmail then
        local emails = EmailLogic:getEmail( rid )
        for index, email in pairs( emails ) do
            if EmailLogic:checkScoutedEmail( nil, nil, email ) and email.status == Enum.EmailStatus.NO then
                -- 更新邮件读取状态
                EmailLogic:setEmail( rid, index, { status = Enum.EmailStatus.YES } )
                syncEmails[index] = { emailIndex = index, status = Enum.EmailStatus.YES }
                emailVersion = true
            end
        end
    elseif messageReplyEmail then
        local emails = EmailLogic:getEmail( rid )
        for index, email in pairs( emails ) do
            if EmailLogic:checkMessageReplyEmail( nil, nil, email ) and email.status == Enum.EmailStatus.NO then
                -- 更新邮件读取状态
                EmailLogic:setEmail( rid, index, { status = Enum.EmailStatus.YES } )
                syncEmails[index] = { emailIndex = index, status = Enum.EmailStatus.YES }
                emailVersion = true
            end
        end
    end

    -- 通知客户端
    if not table.empty( syncEmails ) then
        EmailLogic:syncEmail( rid, nil, syncEmails, true )
    end

    -- 更新邮件版本号
    if emailVersion then
        EmailLogic:updateEmailVersion( rid )
    end
end

---@see 获取邮件信息
function response.GetEmails( msg )
    local rid = msg.rid

    local emailSize = 0
    local syncEmails = {}
    local emails = EmailLogic:getEmail( rid ) or {}
    for emailIndex, emailInfo in pairs( emails ) do
        syncEmails[emailIndex] = {
            emailIndex = emailIndex,
            emailId = emailInfo.emailId,
            status = emailInfo.status,
            sendTime = emailInfo.sendTime,
            takeEnclosure = emailInfo.takeEnclosure,
            isCollect = emailInfo.isCollect,
            subType = emailInfo.subType,
            acitonForceReturn = emailInfo.acitonForceReturn,
            resourceCollectReport = emailInfo.resourceCollectReport,
            discoverReport = emailInfo.discoverReport,
            emailContents = emailInfo.emailContents,
            titleContents = emailInfo.titleContents,
            subTitleContents = emailInfo.subTitleContents,
            guildEmail = emailInfo.guildEmail,
            senderInfo = emailInfo.senderInfo,
            scoutReport = emailInfo.scoutReport,
            reportSubTile = emailInfo.reportSubTile,
            rewards = emailInfo.rewards,
        }
        -- 私聊邮件等待客户端请求返回内容信息
        if emailInfo.subType and emailInfo.subType == Enum.EmailSubType.PRIVATE then
            syncEmails[emailIndex].emailContents = nil
        end
        emailSize = emailSize + 1
        if emailSize >= 50 then
            EmailLogic:syncEmail( rid, nil, syncEmails, true, true, true )
            emailSize = 0
            syncEmails = {}
        end
    end

    -- 通知客户端
    if not table.empty( syncEmails ) then
        EmailLogic:syncEmail( rid, nil, syncEmails, true, true, true )
    end

    return { sendFinish = true }
end

---@see 收藏邮件
function response.CollectEmail( msg )
    local rid = msg.rid
    local emailIndex = msg.emailIndex

    -- 参数检查
    if not emailIndex then
        LOG_ERROR("rid(%d) CollectEmail, no emailIndex arg", rid)
        return nil, ErrorCode.EMAIL_ARG_ERROR
    end

    local emailInfo = EmailLogic:getEmail( rid, emailIndex )
    if not emailInfo or table.empty( emailInfo ) then
        LOG_ERROR("rid(%d) CollectEmail, emailIndex(%d) not exist", rid, emailIndex)
        return nil, ErrorCode.EMAIL_NOT_EXIST
    end

    local sMail = CFG.s_Mail:Get( emailInfo.emailId )
    -- 邮件有附件奖励且未领取的不能收藏
    if not emailInfo.takeEnclosure and sMail and sMail.enclosure and sMail.enclosure > 0  then
        LOG_ERROR("rid(%d) CollectEmail, emailIndex(%d) not take enclosure", rid, emailIndex)
        return nil, ErrorCode.EMAIL_NOT_TAKE_ENCLOSURE
    end

    -- 更新邮件收藏状态
    EmailLogic:setEmail( rid, emailIndex, { isCollect = true } )
    -- 通知客户端
    EmailLogic:syncEmail( rid, emailIndex, { isCollect = true }, true )

    -- 更新邮件版本号
    EmailLogic:updateEmailVersion( rid )

    return { emailIndex = emailIndex }
end

---@see 获取邮件具体信息
function response.GetEmailInfo( msg )
    local rid = msg.rid
    local emailIndexs = msg.emailIndexs

    -- 参数检查
    if not emailIndexs or table.empty( emailIndexs ) then
        LOG_ERROR("rid(%d) GetEmailInfo, no emailIndexs arg", rid)
        return nil, ErrorCode.EMAIL_ARG_ERROR
    end

    local emailInfo
    local syncEmails = {}
    for _, emailIndex in pairs( emailIndexs ) do
        emailInfo = EmailLogic:getEmail( rid, emailIndex )
        if emailInfo then
            syncEmails[emailIndex] = {
                emailIndex = emailIndex,
                battleReport = emailInfo.battleReport,
                battleReportEx = emailInfo.battleReportEx,
                reportStatus = emailInfo.reportStatus,
                battleReportExContent = emailInfo.battleReportExContent,
                rewards = emailInfo.rewards,
                senderInfo = emailInfo.senderInfo,
                emailContents = emailInfo.emailContents,
                roleList = emailInfo.roleList,
            }
        end
    end

    -- 通知客户端
    if not table.empty( syncEmails ) then
        EmailLogic:syncEmail( rid, nil, syncEmails, true, true )
    end

    return { emailIndexs = emailIndexs }
end

function response.MsgSendPrivateEmail(msg)
    local isGuildReply = msg.isGuildReply
    local rid = msg.rid
    local title = msg.title or ""
    local content = msg.content or ""

    if not msg.lst or table.empty(msg.lst) then
        LOG_ERROR("rid(%d) MsgSendPrivateEmail error, no lst arg", rid)
        return nil, ErrorCode.CHAT_ARG_ERROR
    end

    local roleInfo = RoleLogic:getRole( rid, {
        Enum.Role.rid, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID,
        Enum.Role.level, Enum.Role.guildId, Enum.Role.lastEmailSendTime
    } )

    -- 是否在发送时间间隔限制内
    local emailTimeInterval = CFG.s_Config:Get( "emailTimeInterval" ) or 10
    if ( roleInfo.lastEmailSendTime or 0 ) + emailTimeInterval > os.time() then
        LOG_ERROR("rid(%d) MsgSendPrivateEmail error, send email too often", rid)
        return nil, ErrorCode.EMAIL_SEND_TOO_OFTEN
    end

    local length = utf8.len( title )
    if length > 0 then
        -- 副标题超长
        if length > CFG.s_Config:Get( "emailTitleLimit" ) then
            LOG_ERROR("rid(%d) MsgSendPrivateEmail error, title length(%d) limit", rid, length)
            return nil, ErrorCode.EMAIL_SUBTITLE_LEN_LIMIT
        end

        -- 副标题存在非法字符
        if not RoleLogic:checkChatBlock( title )  then
            LOG_ERROR("rid(%d) MsgSendPrivateEmail error, title(%s) invalid", rid, title)
            return nil, ErrorCode.EMAIL_SUBTITLE_INVALID
        end
    end

    length = utf8.len( content )
    if length > 0 then
        -- 内容超长
        if length > CFG.s_Config:Get( "emailContentLimit" ) then
            LOG_ERROR("rid(%d) MsgSendPrivateEmail error, content length(%d) limit", rid, length)
            return nil, ErrorCode.EMAIL_CONTENT_LEN_LIMIT
        end
        -- 内容存在非法字符
        if not RoleLogic:checkChatBlock( content )  then
            LOG_ERROR("rid(%d) MsgSendPrivateEmail error, content(%s) invalid", rid, content)
            return nil, ErrorCode.EMAIL_CONTENT_INVALID
        end
    end

    local sMailLevelLimit = CFG.s_MailLevelLimit:Get( roleInfo.level )
    if not sMailLevelLimit then
        LOG_ERROR("rid(%d) MsgSendPrivateEmail error, s_MailLevelLimit not level(%d) cfg", rid, roleInfo.level)
        return nil, ErrorCode.CFG_ERROR
    end

    local nReceiverCnt = table.size(msg.lst)

    -- 市政厅每小时邮件限制判定
    if sMailLevelLimit.mailNum ~= -1 then
        -- 检查当前小时内已发送的邮件次数
        local nCurCnt = MSM.EmailCountMgr[rid].req.getSendEmails( rid ) or 0
        if nCurCnt + nReceiverCnt > sMailLevelLimit.mailNum then
            LOG_ERROR("rid(%d) MsgSendPrivateEmail error, role level(%d) receiver num(%d) limit", rid, roleInfo.level, nCurCnt + nReceiverCnt)
            return nil, ErrorCode.CHAT_HOUR_SEND_LMT
        end

        MSM.EmailCountMgr[rid].post.addSendEmails( rid, nReceiverCnt )

        RoleSync:syncSelf( rid, { [Enum.Role.emailSendCntPerHour] = nCurCnt + nReceiverCnt }, true )
    end

    local idRecvMailType = 400000  -- 收件人邮件类型
    local idSendMailType = 400002  -- 发件人邮件类型
    if (nReceiverCnt > 1) then
        idSendMailType = 400003    -- 多人邮件
    end

    if msg.isReply then
        idRecvMailType = 400001     -- 回复邮件
    end

    -- 联盟群发邮件回复ID
    if isGuildReply then
        idRecvMailType = 400007
        idSendMailType = 400005
    end

    -- 获取发件人的公会简称
    local guildAbbr
    if roleInfo.guildId and roleInfo.guildId > 0 then
        guildAbbr = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
    end

    local senderInfo = {
        rid = roleInfo.rid,
        name = roleInfo.name,
        headId = roleInfo.headId,
        headFrameID = roleInfo.headFrameID,
        guildId = roleInfo.guildId,
        guildAbbr = guildAbbr
    }

    local info = {
        titleContents = { msg.receiverInfo },
        emailContents = { msg.content },
        subTitleContents = { msg.title },
        senderInfo = senderInfo,
        subType = Enum.EmailSubType.PRIVATE,
    }

    -- 支持跨服发送邮件
    local tReceiver = {}
    for i = 1, nReceiverCnt do
        table.insert(tReceiver, msg.lst[i].rid)
    end

    MSM.EmailProxy[rid].post.sendEmail( tReceiver, idRecvMailType, info )

    -- 保存至发件箱
    info.status = 1 -- 发件置为已读
    EmailLogic:sendEmail(rid, idSendMailType, info)
    -- 更新邮件上次发送时间
    RoleLogic:setRole( rid, { [Enum.Role.lastEmailSendTime] = os.time() } )

    return { result = true }
end

---@see 联盟群发邮件
function response.SendGuildEmail( msg )
    local rid = msg.rid
    local subTitle = msg.subTitle or ""
    local emailContent = msg.emailContent or ""
    local receiverInfo = msg.receiverInfo or ""

    local titleLen = utf8.len( subTitle )
    if titleLen > 0 then
        -- 副标题超长
        if titleLen > CFG.s_Config:Get( "emailTitleLimit" ) then
            LOG_ERROR("rid(%d) SendGuildEmail error, subTitle(%s) length limit", rid, subTitle)
            return nil, ErrorCode.EMAIL_SUBTITLE_LEN_LIMIT
        end
        -- 副标题存在非法字符
        if not RoleLogic:checkChatBlock( subTitle )  then
            LOG_ERROR("rid(%d) SendGuildEmail error, subTitle(%s) invalid", rid, subTitle)
            return nil, ErrorCode.EMAIL_SUBTITLE_INVALID
        end
    end

    local contentLen = utf8.len( emailContent )
    if contentLen > 0 then
        -- 内容超长
        if contentLen > CFG.s_Config:Get( "emailContentLimit" ) then
            LOG_ERROR("rid(%d) SendGuildEmail error, emailContent(%s) length limit", rid, emailContent)
            return nil, ErrorCode.EMAIL_CONTENT_LEN_LIMIT
        end
        -- 内容存在非法字符
        if not RoleLogic:checkChatBlock( emailContent )  then
            LOG_ERROR("rid(%d) SendGuildEmail error, emailContent(%s) invalid", rid, emailContent)
            return nil, ErrorCode.EMAIL_CONTENT_INVALID
        end
    end

    local roleInfo = RoleLogic:getRole( rid, {
        Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.guildId, Enum.Role.lastEmailSendTime, Enum.Role.level
    } )
    local emailTimeInterval = CFG.s_Config:Get( "emailTimeInterval" ) or 10
    if ( roleInfo.lastEmailSendTime or 0 ) + emailTimeInterval > os.time() then
        LOG_ERROR("rid(%d) SendGuildEmail error, send email too often", rid)
        return nil, ErrorCode.EMAIL_SEND_TOO_OFTEN
    end

    -- 角色是否在联盟中
    local guildId = roleInfo.guildId or 0
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) SendGuildEmail error, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 角色是否有权限
    local guildJob = GuildLogic:getRoleGuildJob( guildId, rid )
    if not GuildLogic:checkRoleJurisdiction( rid, Enum.GuildJurisdictionType.SEND_EMAIL, guildJob ) then
        LOG_ERROR("rid(%d) SendGuildEmail error, role guildJob(%d) no send email jurisdiction", rid, guildJob)
        return nil, ErrorCode.EMAIL_NO_GUILD_JURISDICTION
    end

    local sMailLevelLimit = CFG.s_MailLevelLimit:Get( roleInfo.level )
    if not sMailLevelLimit then
        LOG_ERROR("rid(%d) SendGuildEmail error, s_MailLevelLimit not level(%d) cfg", rid, roleInfo.level)
        return nil, ErrorCode.CFG_ERROR
    end

    if sMailLevelLimit.mailNum > -1 then
        -- 联盟邮件发送次数
        if MSM.EmailCountMgr[rid].req.getSendTimes( rid ) >= sMailLevelLimit.mailNum then
            LOG_ERROR("rid(%d) SendGuildEmail error, send guild email times limit", rid)
            return nil, ErrorCode.EMAIL_GUILD_TIMES_LIMIT
        end
        -- 更新本小时联盟邮件群发次数
        MSM.EmailCountMgr[rid].post.addSendTimes( rid )
    end

    local guildInfo = GuildLogic:getGuild( guildId, { Enum.Guild.members, Enum.Guild.abbreviationName } )
    local senderInfo = {
        rid = rid,
        name = roleInfo.name,
        headId = roleInfo.headId,
        headFrameID = roleInfo.headFrameID,
        guildAbbr = guildInfo.abbreviationName,
    }
    local emailId = 400006
    local emailOtherInfo = {
        titleContents = { receiverInfo },
        subTitleContents = { subTitle },
        emailContents = { emailContent },
        senderInfo = senderInfo,
        subType = Enum.EmailSubType.PRIVATE,
    }
    -- 给收件人发送邮件
    MSM.GuildMgr[guildId].post.sendGuildEmail( guildId, guildInfo.members, emailId, emailOtherInfo )

    -- 给发件人发送邮件
    -- 邮件置为已读状态
    emailOtherInfo.status = Enum.EmailStatus.YES
    EmailLogic:sendEmail( rid, 400004, emailOtherInfo )

    -- 更新邮件上次发送时间
    RoleLogic:setRole( rid, { [Enum.Role.lastEmailSendTime] = os.time() } )

    return { result = true }
end