--[[
 * @file : Chat.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2020-04-10 15:16:00
 * @Last Modified time: 2020-04-10 15:16:00
 * @department : Arabic Studio
 * @brief : 聊天协议处理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local RoleChatLogic = require "RoleChatLogic"
local GuildLogic = require "GuildLogic"

---@see 私聊信息
function response.SendPrivateMsg( msg )
    local rid = msg.rid
    local toRid = msg.toRid
    local msgContent = msg.msgContent

    -- 检测参数
    if not msgContent then
        return nil, ErrorCode.CHAT_ARG_ERROR
    end

    -- 检查字符限制
    local channelWordLimit = CFG.s_Config:Get("channelWordLimit")
    if utf8.len(msgContent) > channelWordLimit then
        return nil, ErrorCode.CHAT_WORD_LIMIT
    end

    local dict = CFG.s_ChatChannel:Get(Enum.ChatChannel.PRIVATE)
    if not dict then
        return nil, ErrorCode.CHAT_INVALID_TYPE
    end

    local roleBrief = RoleLogic:getRoleBrief(rid)
    if roleBrief.level < dict.lvLimit then
        return nil, ErrorCode.CHAT_LEVEL_LESS
    end

    local toRoleBrief = RoleLogic:getRoleBrief(toRid)
    if not toRoleBrief then
        return nil, ErrorCode.ROLE_NOT_EXIST
    end

    -- 发送到目标服务器
    local nowTime = os.time()
    local toGameNode = RoleLogic:getRoleGameNode( toRid )
    local msgInfo = {
        channelType = Enum.ChatChannel.PRIVATE,
        timeStamp = nowTime,
        msg = msgContent,
        rid = roleBrief.rid,
        name = roleBrief.name,
        guildName = roleBrief.guildName,
        guildId = roleBrief.guildId,
        headId = roleBrief.headId,
        headFrameID = roleBrief.headFrameID,
        toRid = toRid
    }
    local ret = Common.rpcMultiCall( toGameNode, "ChatPrivate", "dispatchPrivateMsg", toRid, rid, msgInfo )
    if ret then
        -- 推送消息
        Common.syncMsg( rid, "Chat_PushMsg", { pushMsgInfos = { msgInfo } } )
        -- 记录聊天消息
        RoleChatLogic:addChatRecord( rid, toRid, { timeStamp = nowTime, msg = msgContent, toRid = toRid } )
    end
end

---@see 查询私聊对象列表
function response.Msg2GSQueryPrivateChatLst(msg)
    local kvRecord = RoleChatLogic:getChat(msg.rid)

    local lst = {}
    local res = { lst = lst}
    if not kvRecord or table.empty(kvRecord) then
        return res
    end

    local ts = os.time()
    local nExpireSec = (CFG.s_Config:Get("privateChatSaveTime") or 15) * 24 * 3600

    for rid, v in pairs(kvRecord) do
        repeat
            local roleBrief = RoleLogic:getRoleBrief(rid)
            if not roleBrief then
                break
            end

            v.tsLastRead = v.tsLastRead or 0

            -- 过期消息 和 未读红点处理
            local nNotReadCnt = 0
            do
                local lstData = {}
                for i = 1, #v.lstChat do
                    local tmp = v.lstChat[i]
                    -- 删除过期聊天信息
                    if (tmp.timeStamp + nExpireSec > ts) then
                        table.insert(lstData, { msg = tmp.msg, timeStamp = tmp.timeStamp, toRid = tmp.toRid })

                        if tmp.timeStamp > v.tsLastRead then
                            nNotReadCnt = nNotReadCnt + 1
                        end
                    end
                end
                if (table.size(lstData) ~= #v.lstChat) then
                    RoleChatLogic:setChat(msg.rid, rid, { lstChat = lstData, tsLastRead = v.tsLastRead })
                end

                v.lstChat = lstData
            end
            local lastMsg
            local lastMsgTS

            local nSize = 0
            if v.lstChat then
                nSize = table.size(v.lstChat)
            end

            if nSize > 0 then
                lastMsg = v.lstChat[nSize].msg
                lastMsgTS = v.lstChat[nSize].timeStamp
            end
            local guildAbbr
            if roleBrief.guildId ~= 0 then
                guildAbbr = GuildLogic:getGuild( roleBrief.guildId, Enum.Guild.abbreviationName )
            end

            table.insert( lst, {
                rid = rid,
                headId = roleBrief.headId,
                name = roleBrief.name,
                guildId = roleBrief.guildId,
                guildAbbr = guildAbbr,
                headFrameID = roleBrief.headFrameID,
                lastMsg = lastMsg,
                lastMsgTS = lastMsgTS,
                lastReadTS = v.tsLastRead,
                notReadCnt = nNotReadCnt
            } )
        until true
    end

    return res
end

---@see 查询与具体玩家的私聊信息
function response.Msg2GSQueryPrivateChatByRid(msg)
    local tRecord = RoleChatLogic:getChat(msg.rid, msg.toRid)

    local lst = {}
    local res = { lst = lst, toRid = msg.toRid}
    if not tRecord or table.empty(tRecord) then
        return res
    end

    if not tRecord.lstChat then
        return res
    end

    local ts = os.time()
    local nExpireSec = (CFG.s_Config:Get("privateChatSaveTime") or 15) * 24 * 3600

    for i = 1, #tRecord.lstChat do
        local tmp = tRecord.lstChat[i]

        -- 删除过期聊天信息
        if (tmp.timeStamp + nExpireSec > ts) then
            table.insert(lst, { msg = tmp.msg, timeStamp = tmp.timeStamp, toRid = tmp.toRid })
        end
    end

    if (table.size(lst) ~= #tRecord.lstChat) then
        RoleChatLogic:setChat(msg.rid, msg.toRid, {lstChat = lst})
    end

    return res
end

---@see 设置私聊已读时间戳
function response.Msg2GSReadPrivateChat(msg)
    local tRecord = RoleChatLogic:getChat(msg.rid, msg.toRid)

    if not tRecord or table.empty(tRecord) then
        return
    end

    if tRecord.tsLastRead == msg.tsLastRead then
        return
    end

    tRecord.tsLastRead = msg.tsLastRead
    RoleChatLogic:setChat(msg.rid, msg.toRid, { lstChat = tRecord.lstChat, tsLastRead = msg.tsLastRead })
end

---@see 更新最大已读聊天索引
function response.SendMaxUniqueIndex( msg )
    local rid = msg.rid
    local maxChatUniqueIndex = msg.chatReadInfo

    RoleLogic:setRole( rid, Enum.Role.maxChatUniqueIndex, maxChatUniqueIndex )
end

---@see 设置消息免打扰
function response.SendChatMsgNoDisturb( msg )
    local rid = msg.rid
    local chatNoDisturbInfo = msg.chatNoDisturbInfo

    local roleChatNoDisturbInfo = RoleLogic:getRole( rid, Enum.Role.chatNoDisturbInfo )
    for channelType, subChatNoDisturbInfo in pairs(chatNoDisturbInfo) do
        roleChatNoDisturbInfo[channelType] = subChatNoDisturbInfo
    end
    RoleLogic:setRole( rid, Enum.Role.chatNoDisturbInfo, roleChatNoDisturbInfo )
end