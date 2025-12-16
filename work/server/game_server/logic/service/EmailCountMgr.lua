--[[
* @file : EmailCountMgr.lua
* @type : snax multi service
* @author : wsk
* @created : May 28 2020 16:43:50 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 邮件相关协议代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local Timer = require "Timer"
local EmailCountLogic = require "EmailCountLogic"

local tCounter = {} -- k:rid  v:每小时发送的邮件数量

function init()
    Timer.runEveryHour( EmailCountLogic.run, EmailCountLogic, tCounter )
end

function response.Init()

end

function response.getSendEmails( _rid )
    return tCounter[_rid] and tCounter[_rid].sendEmails or 0
end

function accept.addSendEmails( _rid, nAdd )
    if not tCounter[_rid] then
        tCounter[_rid] = {
            sendEmails = 0,
            sendTimes = 0
        }
    end
    tCounter[_rid].sendEmails = tCounter[_rid].sendEmails + nAdd
end

function accept.addSendTimes( _rid )
    if not tCounter[_rid] then
        tCounter[_rid] = {
            sendEmails = 0,
            sendTimes = 0
        }
    end
    tCounter[_rid].sendTimes = tCounter[_rid].sendTimes + 1
end

function response.getSendTimes( _rid )
    return tCounter[_rid] and tCounter[_rid].sendTimes or 0
end