--[[
* @file : ClientHeroLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Thu Jan 16 2020 17:33:07 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 客户端统帅相关
* Copyright(C) 2017 IGG, All rights reserved
]]

local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"

function ClientLogic:summonhero( mode, token, rid, heroId )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:SummonHero( ClientCommon._C2S_Request, heroId ) ) )
end

function ClientLogic:SummonHero( _C2S_Request, heroId )
    return _C2S_Request( "Hero_SummonHero", { heroId = heroId }, 100 )
end

function ClientLogic:heroSkillLevelUp( mode, token, rid, heroId )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:HeroSkillLevelUp( ClientCommon._C2S_Request, heroId ) ) )
end

function ClientLogic:HeroSkillLevelUp( _C2S_Request, heroId )
    return _C2S_Request( "Hero_HeroSkillLevelUp", { heroId = heroId }, 100 )
end

function ClientLogic:heroAwake( mode, token, rid, heroId )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:HeroAwake( ClientCommon._C2S_Request, heroId ) ) )
end

function ClientLogic:HeroAwake( _C2S_Request, heroId )
    return _C2S_Request( "Hero_HeroAwake", { heroId = heroId }, 100 )
end

function ClientLogic:exchangeHeroItem( mode, token, rid, heroId, itemNum )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:ExchangeHeroItem( ClientCommon._C2S_Request, heroId, itemNum ) ) )
end

function ClientLogic:ExchangeHeroItem( _C2S_Request, heroId, itemNum )
    return _C2S_Request( "Hero_ExchangeHeroItem", { heroId = heroId, itemNum = itemNum }, 100 )
end

function ClientLogic:addHeroExp( mode, token, rid, heroId, itemId, itemNum )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:AddHeroExp( ClientCommon._C2S_Request, heroId, itemId, itemNum ) ) )
end

function ClientLogic:AddHeroExp( _C2S_Request, heroId, itemId, itemNum )
    return _C2S_Request( "Hero_AddHeroExp", { heroId = heroId, itemId = itemId, itemNum = itemNum }, 100 )
end

function ClientLogic:heroStarUp( mode, token, rid, heroId, itemId, itemNum )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:HeroStarUp( ClientCommon._C2S_Request, heroId, itemId, itemNum ) ) )
end

function ClientLogic:HeroStarUp( _C2S_Request, heroId, itemId, itemNum )
    local items = {}
    table.insert(items, { itemId = itemId, itemNum = itemNum })
    return _C2S_Request( "Hero_HeroStarUp", { heroId = heroId, items = items }, 100 )
end
