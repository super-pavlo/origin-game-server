--[[
 * @file : SystemEmailMgr.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2020-05-28 13:58:30
 * @Last Modified time: 2020-05-28 13:58:30
 * @department : Arabic Studio
 * @brief : 系统邮件管理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local Timer = require "Timer"
local snax = require "skynet.snax"
local cluster = require "skynet.cluster"

---@type table<int, systemEmailClass>
local allEmailInfo = {}

function init( index )
    snax.enablecluster()
    cluster.register(SERVICE_NAME .. index)
end

---@see 初始化
function response.Init()
    allEmailInfo = SM.c_systemmail.req.Get()
    local SystemEmailLogic = require "SystemEmailLogic"
    Timer.runEvery( 100, SystemEmailLogic.checkEmailTimeout, SystemEmailLogic, allEmailInfo )
end

---@see 角色登陆.发送系统邮件
function response.onRoleLoginSendMail( _rid, _sync, _emailInfo )
    local RoleLogic = require "RoleLogic"
    local EmailLogic = require "EmailLogic"
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.maxSystemEmailIndex, Enum.Role.language } )
    local newMaxSystemEmailIndex = roleInfo.maxSystemEmailIndex
    local sEmailId = CFG.s_Config:Get("emailOperationTemplate")
    local allSystemEmailInfo = _emailInfo or SM.c_systemmail.req.Get()
    for emailIndex, emailInfo in pairs(allSystemEmailInfo) do
        if emailIndex > roleInfo.maxSystemEmailIndex and emailInfo.expiredTime > os.time() then
            newMaxSystemEmailIndex = emailIndex
            -- 发送邮件
            local content = emailInfo.content.cn
            local title = emailInfo.title.cn
            local subTitle = emailInfo.subTitle.cn
            if roleInfo.language == Enum.LanguageType.ENGLISH then
                content = emailInfo.content.en
                title = emailInfo.title.en
                subTitle = emailInfo.subTitle.en
            elseif roleInfo.language == Enum.LanguageType.ARABIC then
                content = emailInfo.content.arb
                title = emailInfo.title.arb
                subTitle = emailInfo.subTitle.arb
            elseif roleInfo.language == Enum.LanguageType.TURKEY then
                content = emailInfo.content.tr
                title = emailInfo.title.tr
                subTitle = emailInfo.subTitle.tr
            end

            local rewards = { items = emailInfo.items }
            if not emailInfo.items or table.empty( emailInfo.items ) then
                rewards = nil
            end
            EmailLogic:sendEmail( _rid, sEmailId, {
                rewards = rewards,
                takeEnclosure = false,
                emailContents = { content },
                titleContents = { title },
                subTitleContents = { subTitle },
                sendTime = emailInfo.sendTime,
                subType = Enum.EmailSubType.OPERATION
            }, not _sync )
        end
    end

    if newMaxSystemEmailIndex ~= roleInfo.maxSystemEmailIndex then
        RoleLogic:setRole( _rid, Enum.Role.maxSystemEmailIndex, newMaxSystemEmailIndex )
    end
end

---@see 增加一封系统邮件
function accept.addSystemMail( _, _title, _subTitle, _content, _items )
    local emailInfo = {
        title = _title,
        subTitle = _subTitle,
        content = _content,
        items = _items,
        sendTime = os.time(),
        expiredTime = os.time() + CFG.s_Config:Get("emailOperationExpirationDate")
    }
    LOG_INFO("addSystemMail, emailInfo(%s)", tostring(emailInfo))
    local emailIndex = SM.c_systemmail.req.Add( nil, emailInfo )
    if emailIndex then
        allEmailInfo[emailIndex] = emailInfo
    end

    -- 给所有在线的发送一封
    local onlineRids = SM.OnlineMgr.req.getAllOnlineRid() or {}
    LOG_INFO("addSystemMail, onlineRids count(%d)", table.size(onlineRids))
    for _, rid in pairs(onlineRids) do
        MSM.SystemEmailMgr[rid].req.onRoleLoginSendMail( rid, true, { [emailIndex] = emailInfo } )
    end
end

---@see 给指定角色发送邮件
function accept.addSystemMailToRole( _, _rids, _title, _subTitle, _content, _items )
    -- 发送邮件
    local content = _content.cn
    local title = _title.cn
    local subTitle = _subTitle.cn
    local roleInfo
    local sEmailId = CFG.s_Config:Get("emailOperationTemplate")
    local RoleLogic = require "RoleLogic"
    local EmailLogic = require "EmailLogic"
    for _, rid in pairs(_rids) do
        roleInfo = RoleLogic:getRole( rid, { Enum.Role.language }  )
        if roleInfo  and not table.empty( roleInfo ) then
            if roleInfo.language == Enum.LanguageType.ENGLISH then
                content = _content.en
                title = _title.en
                subTitle = _subTitle.en
            elseif roleInfo.language == Enum.LanguageType.ARABIC then
                content = _content.arb
                title = _title.arb
                subTitle = _subTitle.arb
            elseif roleInfo.language == Enum.LanguageType.TURKEY then
                content = _content.tr
                title = _title.tr
                subTitle = _subTitle.tr
            end

            local rewards = { items = _items }
            if not _items or table.empty( _items ) then
                rewards = nil
            end
            EmailLogic:sendEmail( rid, sEmailId, {
                    rewards = rewards,
                    takeEnclosure = false,
                    emailContents = { content },
                    titleContents = { title },
                    subTitleContents = { subTitle },
                    sendTime = os.time(),
                    subType = Enum.EmailSubType.OPERATION
                } )
        end
    end
end