--[[
* @file : ClientItemLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Thu Jan 16 2020 19:29:12 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 客户端道具相关
* Copyright(C) 2017 IGG, All rights reserved
]]

local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"

function ClientLogic:itemchangeresource( mode, token, rid, itemIndex, itemNum )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:ItemChangeResource( ClientCommon._C2S_Request, itemIndex, itemNum ) ) )
end

function ClientLogic:ItemChangeResource( _C2S_Request, itemIndex, itemNum )
    return _C2S_Request( "Item_ItemChangeResource", { itemIndex = itemIndex, itemNum = itemNum }, 100 )
end

