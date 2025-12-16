--[[
* @file : Email.lua
* @type : snax multi service
* @author : wsk
* @created : May 28 2020 16:43:50 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 邮件相关协议代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local EmailCountLogic = {}

function EmailCountLogic:run( _tCounter )
    for key in pairs(_tCounter) do
        _tCounter[key] = nil
    end
end

return EmailCountLogic