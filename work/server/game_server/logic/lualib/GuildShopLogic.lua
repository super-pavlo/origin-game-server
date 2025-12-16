--[[
* @file : GuildShopLogic.lua
* @type : lualib
* @author : wsk
* @created : June 2 2020 14:09:18 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟礼物相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local GuildLogic = require "GuildLogic" 
local RoleLogic = require "RoleLogic"
local ItemLogic = require "ItemLogic"

local GuildShopLogic = {}

---@see 获取联盟商店
function GuildShopLogic:getGuildShop( _guildId, _fields )
    return SM.c_guild_shop.req.Get( _guildId, _fields )
end

function GuildShopLogic:addGuildShop( _guildId, _msg )
    return SM.c_guild_shop.req.Add( _guildId, _msg )
end

function GuildShopLogic:setGuildShop( _guildId, _msg )
    return SM.c_guild_shop.req.Set( _guildId, _msg )
end

function GuildShopLogic:shopStock( _guildId, _idItemType, _nCount, _rid, _name )
    local data = GuildShopLogic:getGuildShop( _guildId )

    local dict = CFG.s_AllianceShopItem:Get(_idItemType)
    if not dict then
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    local nReqLeaguePt = dict.stockPrice * _nCount
    if (nReqLeaguePt <= 0) then
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    if not GuildLogic:checkGuildCurrency( _guildId, Enum.CurrencyType.leaguePoints, nReqLeaguePt) then
        return nil, ErrorCode.GUILD_POINT_NOT_ENOUGH
    end

    -- 条件检查完 

    -- 消耗
    GuildLogic:addGuildCurrency(_guildId, Enum.CurrencyType.leaguePoints, -nReqLeaguePt)

    local tmpSell = { idItemType = _idItemType, nCount = _nCount }
    local tmpStock = { idItemType = _idItemType, nCount = _nCount, rid = _rid, name = _name, ts = os.time()  }
    
    if data and data.sell then
        -- 已有记录
        
        local bFind = false
        for _, value in pairs(data.sell) do
            if value and value.idItemType == _idItemType then
                value.nCount = value.nCount + _nCount
                bFind = true
                break
            end
        end

        -- 新进货的商品
        if not bFind then 
            table.insert(data.sell, tmpSell)
        end

        -- 进货记录
        do
            data.stock = data.stock or {}
            if (table.size(data.stock) >= CFG.s_Config:Get( "allianceShopRecordLimit" )) then
                table.remove(data.stock, 1)
            end
            table.insert(data.stock, tmpStock)   
        end

        GuildShopLogic:setGuildShop(_guildId, data)
    else
        -- 新增记录

        data = { sell = { tmpSell }, stock = { tmpStock }, buy = {} }
        GuildShopLogic:addGuildShop(_guildId, data)
    end

    return { result = true }
end

function GuildShopLogic:shopBuy( _guildId, _idItemType, _nCount, _rid, _name )
    local data = GuildShopLogic:getGuildShop( _guildId )
    if not data or not data.sell then
        return nil, ErrorCode.GUILD_SHOP_ITEM_NOT_EXIST
    end

    -- 检查商品是否存在且充足
    local bFind = false
    for _, value in pairs(data.sell) do
        if value.idItemType == _idItemType then
            if value.nCount < _nCount then
                return nil, ErrorCode.GUILD_SHOP_ITEM_NOT_ENOUGH
            else
                value.nCount = value.nCount - _nCount   -- 预先扣除数量
                bFind = true
                break
            end
        end
    end

    if not bFind then
        return nil, ErrorCode.GUILD_SHOP_ITEM_NOT_EXIST
    end

    local dict = CFG.s_AllianceShopItem:Get(_idItemType)
    if not dict then
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    local nReqPt = dict.sellingPrice * _nCount
    if (nReqPt <= 0) then
        return nil, ErrorCode.GUILD_ARG_ERROR
    end

    if not RoleLogic:checkGuildPoint(_rid, nReqPt) then
        return nil, ErrorCode.GUILD_INDIVIDUAL_POINT
    end

    -- 条件检查完

    -- 消耗
    do
        -- 扣除个人联盟积分
        RoleLogic:addGuildPoint(_rid, -nReqPt, nil, Enum.LogType.GUILD_SHOP_COST_POINT)

        -- 购买记录
        do
            data.buy = data.buy or {}
            if (table.size(data.buy) >= CFG.s_Config:Get( "allianceShopRecordLimit" )) then
                table.remove(data.buy, 1)
            end
            table.insert(data.buy, { idItemType = _idItemType, nCount = _nCount, rid = _rid, name = _name, ts = os.time() }) 
        end

        GuildShopLogic:setGuildShop(_guildId, data)
    end

    -- 产出
    do
        ItemLogic:addItem( { rid = _rid, itemId = _idItemType, itemNum = _nCount, eventType = Enum.LogType.GUILD_SHOP_GAIN_ITEM } )
    end

    return { result = true }
end

function GuildShopLogic:shopQuery(_guildId, _rid)
    local data = GuildShopLogic:getGuildShop( _guildId )
    local res = { lst = {} }
    if not data or not data.sell then
        return res
    end

    for _, value in pairs(data.sell) do
        table.insert(res.lst, { idItemType = value.idItemType, nCount = value.nCount })
    end

    return res
end

return GuildShopLogic