--[[
* @file : PushMsg.lua
* @type : snax multi service
* @author : linfeng
* @created : Tue Nov 21 2017 18:49:21 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 推送消息服务(到客户端)
* Copyright(C) 2017 IGG, All rights reserved
]]

---@see 推送数据给客户端.阻塞版本
---@param _toRid any 玩家Rids
---@param _protoName string 协议名称
---@param _protoData table 协议内容
function response.syncMsg( _toRid, _protoName, _protoData, _sendNow, _notLog, _cache, _skipOnline )
    local usernames, agents = Common.getUserNameAndAgentByRid( _toRid )
    if usernames and agents then
        agents[1].req.push( usernames[1], _protoName, _protoData, _sendNow, _notLog, _cache, _skipOnline )
    end
end

---@see 推送数据给客户端.非阻塞版本
---@param _usernames any 玩家Rids
---@param _protoName string 协议名称
---@param _protoData table 协议内容
function accept.syncMsg( _toRid, _protoName, _protoData, _notLog, _notGame, _selfLine, _cache, _skipOnline )
    local usernames, agents = Common.getUserNameAndAgentByRid( _toRid )
    if usernames and agents then
        agents[1].post.push( usernames[1], _protoName, _protoData, _notLog, _cache, _skipOnline )
    end
end