--[[
* @file : EmailMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Wed Jan 08 2020 10:09:12 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 邮件相关逻辑服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local queue = require "skynet.queue"
local EmailLogic = require "EmailLogic"
local RoleLogic = require "RoleLogic"

local emailLocks = {}
local emailIndexs = {}

---@see 增加lock
local function checkLock( _rid )
    if not emailLocks[_rid] then
        emailLocks[_rid] = {}
    end

    if not emailLocks[_rid].lock then
        emailLocks[_rid].lock = queue()
    end
end

---@see 获取邮件唯一索引
function response.getFreeEmailIndex( _rid, _emailType, _emailSubType )
    checkLock( _rid )

    return emailLocks[_rid].lock(
        function ()
            local sMail = CFG.s_Mail:Get()
            local emails = EmailLogic:getEmail( _rid ) or {}
            -- 找到同类型的邮件
            local sameEmails = {}
            local collectEmail = {}
            local discoverEmails = {}
            local resourceHelpEmails = {}
            local scoutedEmails = {}
            local messageReplys = {}
            local mail
            for _, emailInfo in pairs( emails ) do
                if _emailType == Enum.EmailType.COLLECT then
                    -- 收藏邮件
                    if emailInfo.isCollect then
                        table.insert( sameEmails, emailInfo )
                    end
                else
                    mail = emailInfo.emailId and sMail[emailInfo.emailId] or nil
                    if mail and mail.type == _emailType then
                        table.insert( sameEmails, emailInfo )
                    end
                    -- 采集邮件
                    if EmailLogic:checkCollectEmail( nil, nil, emailInfo ) then
                        table.insert( collectEmail, emailInfo )
                    elseif EmailLogic:checkDiscoverEmail( nil, nil, emailInfo ) then
                        -- 探索发现邮件
                        table.insert( discoverEmails, emailInfo )
                    elseif EmailLogic:checkResourceHelpEmail( nil, nil, emailInfo ) then
                        -- 资源探索成功邮件
                        table.insert( resourceHelpEmails, emailInfo )
                    elseif EmailLogic:checkScoutedEmail( nil, nil, emailInfo ) then
                        -- 资源探索成功邮件
                        table.insert( scoutedEmails, emailInfo )
                    elseif EmailLogic:checkMessageReplyEmail( nil, nil, emailInfo ) then
                        -- 留言回复邮件
                        table.insert( messageReplys, emailInfo )
                    end
                end
            end

            local syncEmails = {}
            -- 本次新增的是采集日志，检查采集日志是否已满即可
            if _emailSubType then
                if _emailSubType == Enum.EmailSubType.RESOURCE_COLLECT then
                    local emailResource = CFG.s_Config:Get( "emailResourceSave" ) or 0
                    if #collectEmail >= emailResource then
                        -- 排序找到时间最久的邮件删除
                        table.sort( collectEmail, function ( a, b ) return a.sendTime < b.sendTime end )
                        for i = 1, #collectEmail - emailResource + 1 do
                            EmailLogic:deleteEmail( _rid, collectEmail[i].emailIndex, true )
                            syncEmails[collectEmail[i].emailIndex] = { emailIndex = collectEmail[i].emailIndex, emailId = -1 }
                        end
                    end
                elseif _emailSubType == Enum.EmailSubType.DISCOVER_REPORT then
                    -- 本次新增的是探索发现邮件
                    local mailExploreSave = CFG.s_Config:Get( "mailExploreSave" ) or 0
                    if #discoverEmails >= mailExploreSave then
                        -- 排序找到时间最久的且已探索过的邮件删除
                        table.sort( discoverEmails, function ( a, b ) return a.sendTime < b.sendTime end )
                        local index = 1
                        local deleteSize = 0
                        local needDeleteSize = #discoverEmails - mailExploreSave + 1
                        while index < #discoverEmails do
                            if discoverEmails[index] then
                                -- 发现圣地关卡可直接删除
                                -- 发现村庄山洞，探索后可删除
                                if ( discoverEmails[index].discoverReport.mapFixPointId or 0 ) <= 0
                                    or RoleLogic:checkVillageCave( _rid, discoverEmails[index].discoverReport.mapFixPointId ) then
                                    EmailLogic:deleteEmail( _rid, discoverEmails[index].emailIndex, true )
                                    syncEmails[discoverEmails[index].emailIndex] = { emailIndex = discoverEmails[index].emailIndex, emailId = -1 }
                                    deleteSize = deleteSize + 1
                                end
                                index = index + 1
                                if needDeleteSize <= deleteSize then
                                    break
                                end
                            else
                                break
                            end
                        end
                    end
                elseif _emailSubType == Enum.EmailSubType.RSS_HELP then
                    -- 本次新增的是资源援助成功邮件
                    local emailResourceHelpSave = CFG.s_Config:Get( "emailResourceHelpSave" ) or 0
                    if #resourceHelpEmails >= emailResourceHelpSave then
                        -- 排序找到时间最久的邮件删除
                        table.sort( resourceHelpEmails, function ( a, b ) return a.sendTime < b.sendTime end )
                        for i = 1, #resourceHelpEmails - emailResourceHelpSave + 1 do
                            EmailLogic:deleteEmail( _rid, resourceHelpEmails[i].emailIndex, true )
                            syncEmails[resourceHelpEmails[i].emailIndex] = { emailIndex = resourceHelpEmails[i].emailIndex, emailId = -1 }
                        end
                    end
                elseif _emailSubType == Enum.EmailSubType.SCOUTED then
                    -- 被侦查邮件
                    local emailBeScoutSave = CFG.s_Config:Get( "emailBeScoutSave" ) or 0
                    if #scoutedEmails >= emailBeScoutSave then
                        -- 排序找到时间最久的邮件删除
                        table.sort( scoutedEmails, function ( a, b ) return a.sendTime < b.sendTime end )
                        for i = 1, #scoutedEmails - emailBeScoutSave + 1 do
                            EmailLogic:deleteEmail( _rid, scoutedEmails[i].emailIndex, true )
                            syncEmails[scoutedEmails[i].emailIndex] = { emailIndex = scoutedEmails[i].emailIndex, emailId = -1 }
                        end
                    end
                elseif _emailSubType == Enum.EmailSubType.MESSAGE_REPLY then
                    -- 留言回复邮件
                    local emailMessageSave = CFG.s_Config:Get( "emailMessageSave" ) or 0
                    if #messageReplys >= emailMessageSave then
                        -- 排序找到时间最久的邮件删除
                        table.sort( messageReplys, function ( a, b ) return a.sendTime < b.sendTime end )
                        for i = 1, #messageReplys - emailMessageSave + 1 do
                            EmailLogic:deleteEmail( _rid, messageReplys[i].emailIndex, true )
                            syncEmails[messageReplys[i].emailIndex] = { emailIndex = messageReplys[i].emailIndex, emailId = -1 }
                        end
                    end
                end
            elseif _emailType == Enum.EmailType.ROLE or _emailType == Enum.EmailType.SEND then
                -- 个人邮件 个人已发送邮件
                local nLimit = CFG.s_Config:Get( "emailSave" )
                if nLimit > 1 and #sameEmails >= nLimit then
                    -- 排序找到时间最久的邮件删除
                    table.sort( sameEmails, function ( a, b ) return a.sendTime < b.sendTime end )

                    local idDelIndex = sameEmails[1].emailIndex
                    EmailLogic:deleteEmail( _rid, idDelIndex, true )
                    syncEmails[idDelIndex] = { emailIndex = idDelIndex, emailId = -1 }
                end
            else
                local emailSave = CFG.s_Config:Get( "emailSave" )
                if #sameEmails >= emailSave then
                    -- 该类型邮件存储已达上限
                    table.sort( sameEmails, function ( a, b ) return a.sendTime < b.sendTime end )
                    -- 删除邮件
                    local deleteCollect, deleteDiscover, deleteResourceHelp, deleteScouted, deleteMessageReply
                    local deleteEmails = 0
                    local needDeleteEmails = #sameEmails - emailSave + 1
                    -- for i = 1, #sameEmails - emailSave + 1 do
                    for _, emailInfo in pairs( sameEmails ) do
                        if EmailLogic:checkCollectEmail( nil, nil, emailInfo ) then
                            -- 采集邮件下面一起删除
                            if not deleteCollect then
                                deleteCollect = true
                                deleteEmails = deleteEmails + 1
                            end
                        elseif EmailLogic:checkDiscoverEmail( nil, nil, emailInfo ) then
                            -- 探索邮件下面一起删除
                            if not deleteDiscover then
                                deleteDiscover = true
                                deleteEmails = deleteEmails + 1
                            end
                        elseif EmailLogic:checkResourceHelpEmail( nil, nil, emailInfo ) then
                            -- 资源援助邮件下面一起删除
                            if not deleteResourceHelp then
                                deleteResourceHelp = true
                                deleteEmails = deleteEmails + 1
                            end
                        elseif EmailLogic:checkScoutedEmail( nil, nil, emailInfo ) then
                            -- 侦查邮件下面一起删除
                            if not deleteScouted then
                                deleteScouted = true
                                deleteEmails = deleteEmails + 1
                            end
                        elseif EmailLogic:checkMessageReplyEmail( nil, nil, emailInfo ) then
                            if not deleteMessageReply then
                                deleteMessageReply = true
                                deleteEmails = deleteEmails + 1
                            end
                        else
                            -- 不是采集邮件直接删除
                            if not emailInfo.rewards or table.empty( emailInfo.rewards ) or emailInfo.takeEnclosure then
                                EmailLogic:deleteEmail( _rid, emailInfo.emailIndex, true )
                                EmailLogic:checkDeleteGuildInviteEmail( _rid, emailInfo )
                                syncEmails[emailInfo.emailIndex] = { emailIndex = emailInfo.emailIndex, emailId = -1 }
                                deleteEmails = deleteEmails + 1
                            end
                        end
                        if deleteEmails >= needDeleteEmails then
                            break
                        end
                    end

                    -- 采集邮件是否要全部删除
                    if deleteCollect then
                        for _, emailInfo in pairs( collectEmail ) do
                            EmailLogic:deleteEmail( _rid, emailInfo.emailIndex, true )
                            syncEmails[emailInfo.emailIndex] = { emailIndex = emailInfo.emailIndex, emailId = -1 }
                        end
                    end
                    if deleteDiscover then
                        -- 发现邮件全部删除
                        for _, emailInfo in pairs( discoverEmails ) do
                            EmailLogic:deleteEmail( _rid, emailInfo.emailIndex, true )
                            syncEmails[emailInfo.emailIndex] = { emailIndex = emailInfo.emailIndex, emailId = -1 }
                        end
                    end
                    if deleteResourceHelp then
                        -- 资源援助邮件全部删除
                        for _, emailInfo in pairs( resourceHelpEmails ) do
                            EmailLogic:deleteEmail( _rid, emailInfo.emailIndex, true )
                            syncEmails[emailInfo.emailIndex] = { emailIndex = emailInfo.emailIndex, emailId = -1 }
                        end
                    end
                    if deleteScouted then
                        -- 侦查邮件全部删除
                        for _, emailInfo in pairs( scoutedEmails ) do
                            EmailLogic:deleteEmail( _rid, emailInfo.emailIndex, true )
                            syncEmails[emailInfo.emailIndex] = { emailIndex = emailInfo.emailIndex, emailId = -1 }
                        end
                    end
                    if deleteMessageReply then
                        -- 留言回复邮件全部删除
                        for _, emailInfo in pairs( messageReplys ) do
                            EmailLogic:deleteEmail( _rid, emailInfo.emailIndex, true )
                            syncEmails[emailInfo.emailIndex] = { emailIndex = emailInfo.emailIndex, emailId = -1 }
                        end
                    end
                end
            end
            -- 通知客户端
            if not table.empty( syncEmails ) then
                EmailLogic:syncEmail( _rid, nil, syncEmails, true )
            end

            if not emailIndexs[_rid] then
                local maxIndex = 0
                emails = EmailLogic:getEmail( _rid ) or {}
                for emailIndex in pairs( emails ) do
                    if maxIndex < emailIndex then
                        maxIndex = emailIndex
                    end
                end

                emailIndexs[_rid] = maxIndex
            end

            emailIndexs[_rid] = emailIndexs[_rid] + 1

            return emailIndexs[_rid]
        end
    )
end

---@see 邮件入库
function accept.addEmail( _rid, _emailIndex, _emailInfo )
    MSM.d_email[_rid].req.Add( _rid, _emailIndex, _emailInfo )
end

---@see 更新邮件
function accept.setEmail( _contentId, _field, _value )
    SM.c_email_content.req.Set( _contentId, _field, _value )
end

---@see 删除邮件
function accept.delEmail( _contentId )
    SM.c_email_content.req.Delete( _contentId )
end

---@see 发送邮件
function accept.sendEmail( _rid, _sEmailId, _otherInfo, _noSync )
    EmailLogic:sendEmail( _rid, _sEmailId, _otherInfo, _noSync )
end

---@see 发送战报
function accept.sendBattleReportEmail( _rid, _sEmailId, _reportSubTile, _battleReportEx, _mainHeroId, _noSync )
    EmailLogic:sendBattleReportEmail( _rid, _sEmailId, _reportSubTile, _battleReportEx, _mainHeroId, _noSync )
end