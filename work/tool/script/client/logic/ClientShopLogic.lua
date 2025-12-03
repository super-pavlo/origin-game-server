--[[
* @file : ClientShopLogic.lua
* @type : lua lib
* @author : chenlei
* @created : Fri Apr 03 2020 10:07:57 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 客户端商店相关
* Copyright(C) 2017 IGG, All rights reserved
]]

local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"

function ClientLogic:buyShopItem( mode, token, rid, itemId, itemNum )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:BuyShopItem( ClientCommon._C2S_Request, itemId, itemNum ) ) )
end

function ClientLogic:BuyShopItem( _C2S_Request, itemId, itemNum )
    return _C2S_Request( "Shop_BuyShopItem", { itemId = itemId, itemNum = itemNum }, 100 )
end


function ClientLogic:buyPostItem( mode, token, rid, id )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:BuyPostItem( ClientCommon._C2S_Request, id ) ) )
end

function ClientLogic:BuyPostItem( _C2S_Request, id )
    return _C2S_Request( "Shop_BuyPostItem", { id = id }, 100 )
end

function ClientLogic:refreshPostItem( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:RefreshPostItem( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:RefreshPostItem( _C2S_Request )
    return _C2S_Request( "Shop_RefreshPostItem", {}, 100 )
end

function ClientLogic:buyExpeditionStore( mode, token, rid, type, itemId )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:BuyExpeditionStore( ClientCommon._C2S_Request, type, itemId ) ) )
end

function ClientLogic:BuyExpeditionStore( _C2S_Request, type, itemId )
    return _C2S_Request( "Shop_BuyExpeditionStore", { type = type , itemId = itemId }, 100 )
end

function ClientLogic:refreshExpeditionStore( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:RefreshExpeditionStore( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:RefreshExpeditionStore( _C2S_Request )
    return _C2S_Request( "Shop_RefreshExpeditionStore", { }, 100 )
end

function ClientLogic:getLimitHeroInfo( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:GetLimitHeroInfo( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:GetLimitHeroInfo( _C2S_Request )
    return _C2S_Request( "Shop_GetLimitHeroInfo", { }, 100 )
end