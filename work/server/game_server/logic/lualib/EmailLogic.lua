--[[
* @file : EmailLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Tue Jan 07 2020 16:30:13 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 邮件相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]


local EmailLogic = {}

---@see 获取邮件信息
function EmailLogic:getEmail( _rid, _emailIndex, _fields )
    return MSM.d_email[_rid].req.Get( _rid, _emailIndex, _fields )
    -- local emails = MSM.d_email[_rid].req.Get( _rid, _emailIndex ) or {}
    -- if _emailIndex then
    --     if emails.contentId then
    --         return SM.c_email_content.req.Get( emails.contentId, _fields )
    --     end
    -- else
    --     local allEmails = {}
    --     for _, email in pairs( emails ) do
    --         allEmails[email.emailIndex] = SM.c_email_content.req.Get( email.contentId )
    --     end

    --     return allEmails
    -- end
end

---@see 设置邮件信息
function EmailLogic:setEmail( _rid, _emailIndex, _field, _value )
    return MSM.d_email[_rid].req.Set( _rid, _emailIndex, _field, _value )
    -- _contentId = _contentId or MSM.d_email[_rid].req.Get( _rid, _emailIndex, "contentId" )
    -- MSM.EmailMgr[_rid].post.setEmail( _contentId, _field, _value )
end

---@see 增加邮件
function EmailLogic:addEmail( _rid, _emailIndex, _emailInfo )
    MSM.EmailMgr[_rid].post.addEmail( _rid, _emailIndex, _emailInfo )
end

---@see 同步邮件
function EmailLogic:syncEmail( _rid, _emailIndex, _fields, _haskv, _block, _sendNow )
    local syncEmail = {}
    if _haskv then
        if not _emailIndex then
            syncEmail = _fields
        else
            _fields.emailIndex = _emailIndex
            syncEmail[_emailIndex] = _fields
        end
    elseif _emailIndex then
        if not Common.isTable( _emailIndex ) then _emailIndex = { _emailIndex } end
        local emailInfo
        for _, emailIndex in pairs( _emailIndex ) do
            emailInfo = self:getEmail( _rid, emailIndex, _fields )
            emailInfo.emailIndex = emailIndex
            syncEmail[emailIndex] = emailInfo
        end
    else -- 推送所有邮件
        syncEmail = self:getEmail( _rid ) or {}
    end

    Common.syncMsg( _rid, "Email_EmailList",  { emailInfo = syncEmail }, _block, _sendNow )
end

---@see 删除邮件
function EmailLogic:deleteEmail( _rid, _emailIndex, _noSync, _block )
    local battleReportEx = self:getEmail( _rid, _emailIndex, "battleReportEx" )
    if battleReportEx and battleReportEx ~= "" then
        -- 删除文件
        MSM.BattleReportUploadMgr[_rid].post.deleteEmail( _rid, battleReportEx )
    end
    -- 删除邮件
    MSM.d_email[_rid].req.Delete( _rid, _emailIndex )
    -- 通知客户端
    if not _noSync then
        self:syncEmail( _rid, _emailIndex, { emailIndex = _emailIndex, emailId = -1 }, true, _block )
    end
end

---@see 检查是否是联盟邀请邮件
function EmailLogic:checkDeleteGuildInviteEmail( _rid, _emailInfo )
    if _emailInfo and _emailInfo.emailId == Enum.EmailGuildInviteEmailId then
        if _emailInfo.guildEmail.inviteStatus == Enum.EmailGuildInviteStatus.NO_CLICK then
            local GuildLogic = require "GuildLogic"
            GuildLogic:delInvite( _emailInfo.guildEmail.guildId, _rid )
        end
    end
end

---@see 检查邮件是否存在
function EmailLogic:checkEmail( _rid, _emailIndex, _emailInfo )
    _emailInfo = _emailInfo or self:getEmail( _rid, _emailIndex ) or {}
    return _emailInfo.sendTime ~= nil
end

---@see 检查邮件是否是采集邮件
function EmailLogic:checkCollectEmail( _rid, _emailIndex, _emailInfo )
    _emailInfo = _emailInfo or self:getEmail( _rid, _emailIndex )

    return _emailInfo.subType and _emailInfo.subType == Enum.EmailSubType.RESOURCE_COLLECT
end

---@see 检查邮件是否是探索发现邮件
function EmailLogic:checkDiscoverEmail( _rid, _emailIndex, _emailInfo )
    _emailInfo = _emailInfo or self:getEmail( _rid, _emailIndex )

    return _emailInfo.subType and _emailInfo.subType == Enum.EmailSubType.DISCOVER_REPORT
end

---@see 检查邮件是否是资源援助成功邮件
function EmailLogic:checkResourceHelpEmail( _rid, _emailIndex, _emailInfo )
    _emailInfo = _emailInfo or self:getEmail( _rid, _emailIndex )

    return _emailInfo.subType and _emailInfo.subType == Enum.EmailSubType.RSS_HELP
end

---@see 检查邮件是否是被侦查邮件
function EmailLogic:checkScoutedEmail( _rid, _emailIndex, _emailInfo )
    _emailInfo = _emailInfo or self:getEmail( _rid, _emailIndex )

    return _emailInfo.subType and _emailInfo.subType == Enum.EmailSubType.SCOUTED
end

---@see 检查邮件是否是留言回复邮件
function EmailLogic:checkMessageReplyEmail( _rid, _emailIndex, _emailInfo )
    _emailInfo = _emailInfo or self:getEmail( _rid, _emailIndex )

    return _emailInfo.subType and _emailInfo.subType == Enum.EmailSubType.MESSAGE_REPLY
end

---@see 获取邮件索引
function EmailLogic:getFreeEmailIndex( _rid, _emailType, _emailSubType )
    return MSM.EmailMgr[_rid].req.getFreeEmailIndex( _rid, _emailType, _emailSubType )
end

---@see 发送采集报告邮件
function EmailLogic:sendResourceCollectEmail( _rid, _sEmailId, _resourceTypeId, _pos, _resource, _extraResource, _noSync, _resourceReportType )
    local emailIndex = self:getFreeEmailIndex( _rid, Enum.EmailType.REPORT, Enum.EmailSubType.RESOURCE_COLLECT )
    local emailInfo = {
        emailIndex = emailIndex,
        emailId = _sEmailId,
        sendTime = os.time(),
        status = Enum.EmailStatus.NO,
        isCollect = false,
        subType = Enum.EmailSubType.RESOURCE_COLLECT,
        resourceCollectReport = {
            resourceTypeId = _resourceTypeId,
            pos = _pos,
            resource = _resource,
            extraResource = _extraResource,
            type = _resourceReportType,
        }
    }

    -- 邮件附件
    local sEmail = CFG.s_Mail:Get( _sEmailId )
    if sEmail.enclosure and sEmail.enclosure > 0 then
        local ItemLogic = require "ItemLogic"
        if sEmail.receiveAuto and sEmail.receiveAuto == Enum.EmailReceiveAuto.YES then
            emailInfo.rewards = ItemLogic:getItemPackage( _rid, sEmail.enclosure, nil, _noSync )
            emailInfo.takeEnclosure = true
        else
            emailInfo.rewards = ItemLogic:getItemPackage( _rid, sEmail.enclosure, true, _noSync )
        end
    end

    -- 添加邮件
    -- MSM.d_email[_rid].req.Add( _rid, emailIndex, emailInfo )
    self:addEmail( _rid, emailIndex, emailInfo )

    -- 通知客户端
    if not _noSync then
        self:syncEmail( _rid, emailIndex, emailInfo, true )
    end
    -- 更新邮件版本号
    self:updateEmailVersion( _rid, _noSync )
end

---@see 发送战斗报告
function EmailLogic:sendBattleReportEmail( _rid, _sEmailId, _reportSubTile, _battleReportEx, _mainHeroId, _noSync )
    local emailIndex = self:getFreeEmailIndex( _rid, Enum.EmailType.REPORT )
    local emailInfo = {
        emailIndex = emailIndex,
        emailId = _sEmailId,
        sendTime = os.time(),
        status = Enum.EmailStatus.NO,
        isCollect = false,
        subType = Enum.EmailSubType.BATTLE_REPORT,
        reportSubTile = _reportSubTile,
        mainHeroId = _mainHeroId,

        -- 先直接存本地
        --battleReportExContent = _battleReportEx,
        --reportStatus = 2,
    }

    -- 邮件附件
    local sEmail = CFG.s_Mail:Get( _sEmailId )
    if sEmail.enclosure and sEmail.enclosure > 0 then
        local ItemLogic = require "ItemLogic"
        if sEmail.receiveAuto and sEmail.receiveAuto == Enum.EmailReceiveAuto.YES then
            emailInfo.rewards = ItemLogic:getItemPackage( _rid, sEmail.enclosure, nil, _noSync )
            emailInfo.takeEnclosure = true
        else
            emailInfo.rewards = ItemLogic:getItemPackage( _rid, sEmail.enclosure, true, _noSync )
        end
    end

    -- 添加邮件
    -- MSM.d_email[_rid].req.Add( _rid, emailIndex, emailInfo )
    self:addEmail( _rid, emailIndex, emailInfo )

    -- 通知客户端
    if not _noSync then
        self:syncEmail( _rid, emailIndex, emailInfo, true )
    end

    -- 更新邮件版本号
    self:updateEmailVersion( _rid, _noSync )

    -- 上传邮件额外信息
    MSM.BattleReportUploadMgr[_rid].post.uploadEmail( _rid, emailIndex, _battleReportEx )
end

---@see 发送邮件
---@param _otherInfo table 邮件的其他信息无则为nil
function EmailLogic:sendEmail( _rid, _sEmailId, _otherInfo, _noSync )
    local sMail = CFG.s_Mail:Get( _sEmailId )
    if not sMail or table.empty( sMail ) then
        LOG_ERROR("rid(%d) sendEmail, s_Mail not sEmailId(%d) cfg", _rid, _sEmailId)
        return false
    end

    local emailIndex = self:getFreeEmailIndex( _rid, sMail.type, _otherInfo and _otherInfo.subType )
    local emailInfo = {
        emailIndex = emailIndex,
        emailId = _sEmailId,
        sendTime = os.time(),
        status = Enum.EmailStatus.NO,
        isCollect = false,
    }
    table.mergeEx( emailInfo, _otherInfo or {} )

    -- 邮件附件
    local sEmail = CFG.s_Mail:Get( _sEmailId )
    if sEmail.enclosure and sEmail.enclosure > 0 then
        local ItemLogic = require "ItemLogic"
        if sEmail.receiveAuto and sEmail.receiveAuto == Enum.EmailReceiveAuto.YES then
            emailInfo.rewards = ItemLogic:getItemPackage( _rid, sEmail.enclosure, nil, _noSync )
            emailInfo.takeEnclosure = true
        else
            emailInfo.rewards = ItemLogic:getItemPackage( _rid, sEmail.enclosure, true, _noSync )
        end
    end

    -- 添加邮件
    -- MSM.d_email[_rid].req.Add( _rid, emailIndex, emailInfo )
    self:addEmail( _rid, emailIndex, emailInfo )

    -- 通知客户端
    if not _noSync then
        self:syncEmail( _rid, emailIndex, emailInfo, true )
    end

    -- 更新邮件版本号
    self:updateEmailVersion( _rid, _noSync )

    if sMail.type == Enum.EmailType.ROLE then
        SM.PushMgr.post.sendPush( { pushRid = _rid, pushType = Enum.PushType.PERSON_MAIL, args = { arg1 = _otherInfo.senderInfo.name, arg2 = _otherInfo.emailContents[1] } })
    end

    return true
end

---@see 新增邮件
function EmailLogic:addSystemEmail( _rid, _sEmailId, _noSync )
    local emailType = Enum.EmailType.SYSTEM
    local sMail = CFG.s_Mail:Get( _sEmailId )
    if sMail.type ~= emailType then
        LOG_ERROR("rid(%d) addSystemEmail, sEmailId(%d) not system email", _rid, _sEmailId)
        return false
    end
    local emailIndex = self:getFreeEmailIndex( _rid, emailType )
    local emailInfo = {
        emailIndex = emailIndex,
        emailId = _sEmailId,
        sendTime = os.time(),
        status = Enum.EmailStatus.NO,
        isCollect = false,
    }

    -- 邮件附件
    local sEmail = CFG.s_Mail:Get( _sEmailId )
    if sEmail.enclosure and sEmail.enclosure > 0 then
        local ItemLogic = require "ItemLogic"
        if sEmail.receiveAuto and sEmail.receiveAuto == Enum.EmailReceiveAuto.YES then
            emailInfo.rewards = ItemLogic:getItemPackage( _rid, sEmail.enclosure, nil, _noSync )
            emailInfo.takeEnclosure = true
        else
            emailInfo.rewards = ItemLogic:getItemPackage( _rid, sEmail.enclosure, true, _noSync )
        end
    end

    -- 添加邮件
    -- MSM.d_email[_rid].req.Add( _rid, emailIndex, emailInfo )
    self:addEmail( _rid, emailIndex, emailInfo )

    -- 通知客户端
    if not _noSync then
        self:syncEmail( _rid, emailIndex, emailInfo, true )
    end

    -- 更新邮件版本号
    self:updateEmailVersion( _rid, _noSync )

    return true
end

---@see 更新邮件版本
function EmailLogic:updateEmailVersion( _rid, _noSync )
    local RoleLogic = require "RoleLogic"
    local RoleSync = require "RoleSync"

    local _, emailVersion = RoleLogic:lockSetRole( _rid, Enum.Role.emailVersion, 1 )
    if not _noSync then
        RoleSync:syncSelf( _rid, { [Enum.Role.emailVersion] = emailVersion }, true )
    end
end

return EmailLogic