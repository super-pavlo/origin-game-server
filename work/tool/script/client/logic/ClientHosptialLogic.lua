--[[
* @file : ClientHosptialLogic.lua
* @type : lua lib
* @author : chenlei
* @created : Fri Jan 17 2020 13:19:43 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 客户端医院相关
* Copyright(C) 2017 IGG, All rights reserved
]]

local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"

function ClientLogic:treatment( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )
    local soldiers = {}
    soldiers[101] = { id = 101 , type = 1, level = 1, num= 500 }
    soldiers[102] = { id = 102 , type = 1, level = 2, num= 500 }
    soldiers[103] = { id = 103 , type = 1, level = 3, num= 500 }
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Treatment( ClientCommon._C2S_Request, soldiers ) ) )
end

function ClientLogic:awardTreatment( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:AwardTreatment( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:AwardTreatment( _C2S_Request )
    return _C2S_Request( "Role_AwardTreatment", {}, 100 )
end

function ClientLogic:Treatment( _C2S_Request, _soldiers )
    return _C2S_Request( "Role_Treatment", { soldiers = _soldiers, treatmentQueueIndex = 1 }, 100 )
end

