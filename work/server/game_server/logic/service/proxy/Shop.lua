--[[
* @file : Shop.lua
* @type : snax multi service
* @author : chenlei
* @created : Thu Apr 02 2020 16:25:48 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 商店相关协议代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]
local RoleLogic = require "RoleLogic"
local ItemLogic = require "ItemLogic"
local RoleSync = require "RoleSync"
local TaskLogic = require "TaskLogic"

---@see 普通商店购买
function response.BuyShopItem( msg )
    local itemId = msg.itemId
    local rid = msg.rid
    local itemNum = msg.itemNum
    -- 判断道具是否在商店中出售
    local sItemInfo = CFG.s_Item:Get(itemId)
    if sItemInfo.shopPrice <= 0 then
        LOG_ERROR("rid(%d) BuyShopItem, itemId(%d) not sell in shop", rid, itemId )
        return nil, ErrorCode.SHOP_ITEM_NOT_SELL
    end
    local costDenar = itemNum * sItemInfo.shopPrice
    if not RoleLogic:checkDenar( rid, costDenar ) then
        LOG_ERROR("rid(%d) BuyShopItem, denar not enough", rid )
        return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
    end
    -- 扣除钻石
    RoleLogic:addDenar( rid, -costDenar, nil, Enum.LogType.SHOP_COST_DENAR )
    ItemLogic:addItem( { rid = rid, itemId = itemId, itemNum = itemNum, eventType = Enum.LogType.SHOP_GAIN_ITEM })
    -- 更新商店购买次数
    TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.SHOP_BUY, Enum.TaskArgDefault, 1 )

    return { itemId = itemId, itemNum = itemNum }
end

---@see 购买驿站道具
function response.BuyPostItem( msg )
    local rid = msg.rid
    local id = msg.id
    local mysteryStore = RoleLogic:getRole( rid, Enum.Role.mysteryStore )
    local sMysteryStore = CFG.s_MysteryStore:Get(id)
    if not mysteryStore or table.empty(mysteryStore) or not mysteryStore.mysteryStoreGoods or not mysteryStore.mysteryStoreGoods[id] then
        LOG_ERROR("rid(%d) BuyPostItem, item not exist", rid )
        return nil, ErrorCode.SHOP_POST_ITEM_NOT_EXIST
    end
    if mysteryStore.mysteryStoreGoods[id].isBuy then
        LOG_ERROR("rid(%d) BuyPostItem, item have buy", rid )
        return nil, ErrorCode.SHOP_POST_ITEM_HAVE_BUY
    end
    local price =  mysteryStore.mysteryStoreGoods[id].price
    if sMysteryStore.type == Enum.CurrencyType.food then
        if not RoleLogic:checkFood( rid, price ) then
            LOG_ERROR("rid(%d) BuyShopItem, food not enough", rid )
            return nil, ErrorCode.ROLE_FOOD_NOT_ENOUGH
        end
    elseif sMysteryStore.type == Enum.CurrencyType.wood then
        if not RoleLogic:checkWood( rid, price ) then
            LOG_ERROR("rid(%d) BuyShopItem, wood not enough", rid )
            return nil, ErrorCode.ROLE_WOOD_NOT_ENOUGH
        end
    elseif sMysteryStore.type == Enum.CurrencyType.stone then
        if not RoleLogic:checkStone( rid, price ) then
            LOG_ERROR("rid(%d) BuyShopItem, stone not enough", rid )
            return nil, ErrorCode.ROLE_STONE_NOT_ENOUGH
        end
    elseif sMysteryStore.type == Enum.CurrencyType.gold then
        if not RoleLogic:checkGold( rid, price ) then
            LOG_ERROR("rid(%d) BuyShopItem, gold not enough", rid )
            return nil, ErrorCode.ROLE_GOLD_NOT_ENOUGH
        end
    elseif sMysteryStore.type == Enum.CurrencyType.denar then
        if not RoleLogic:checkDenar( rid, price ) then
            LOG_ERROR("rid(%d) BuyShopItem, denar not enough", rid )
            return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
        end
    end
    RoleLogic:buyPostGoods( rid, id )

    return { id = id }
end

---@see 驿站道具刷新
function response.RefreshPostItem( msg )
    local rid = msg.rid
    local mysteryStore = RoleLogic:getRole( rid, Enum.Role.mysteryStore )
    if not mysteryStore or table.empty(mysteryStore) then
        LOG_ERROR("rid(%d) BuyPostItem, post not exist", rid )
        return nil, ErrorCode.SHOP_POST_NOT_EXIST
    end
    if not mysteryStore.freeRefresh then
        mysteryStore.freeRefresh = true
    else
        if mysteryStore.refreshCount >= CFG.s_Config:Get("mysteryStoreRefresh") then
            LOG_ERROR("rid(%d) BuyShopItem, denar not enough", rid )
            return nil, ErrorCode.SHOP_POST_REFRESH_COUNT_LIMIT
        end
        if not RoleLogic:checkDenar( rid, CFG.s_Config:Get("mysteryStoreRefreshPrice")[mysteryStore.refreshCount+1] ) then
            LOG_ERROR("rid(%d) BuyShopItem, denar not enough", rid )
            return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
        end
        mysteryStore.refreshCount = mysteryStore.refreshCount + 1
        RoleLogic:addDenar( rid, -CFG.s_Config:Get("mysteryStoreRefreshPrice")[mysteryStore.refreshCount], nil, Enum.LogType.REFRESH_POST_COST_CURRENCY )
    end
    mysteryStore.mysteryStoreGoods = RoleLogic:refreshPostGoods( rid )
    RoleLogic:setRole( rid, { [Enum.Role.mysteryStore] = mysteryStore } )
    RoleSync:syncSelf( rid, { [Enum.Role.mysteryStore] = mysteryStore }, true, true )

    return { result = true }
end

---@see 购买vip道具
function response.BuyVipStore( msg )
    local rid = msg.rid
    local id = msg.id
    local num = msg.num
    local sVipStore = CFG.s_VipStore:Get( id )
    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.vipStore, Enum.Role.vip } )
    local vipStore = roleInfo.vipStore
    if not vipStore[id] then vipStore[id] = { id = id, count = 0 } end
    -- 判断vip等级是否足够
    local vip = RoleLogic:getVipLv( roleInfo.vip )
    if vip < sVipStore.vipLevel then
        LOG_ERROR("rid(%d) BuyVipStore, vip not enough", rid )
        return nil, ErrorCode.SHOP_VIP_LEVEL_NOT_ENOUGH
    end
    -- 判断购买个数是否超出上限
    if num + vipStore[id].count > sVipStore.number then
        LOG_ERROR("rid(%d) BuyVipStore, buy count max", rid )
        return nil, ErrorCode.SHOP_VIP_NUM_MAX
    end
    -- 判断货币是否充足
    local price = sVipStore.price * num
    if sVipStore.type == Enum.CurrencyType.food then
        if not RoleLogic:checkFood( rid, price ) then
            LOG_ERROR("rid(%d) BuyShopItem, food not enough", rid )
            return nil, ErrorCode.ROLE_FOOD_NOT_ENOUGH
        end
    elseif sVipStore.type == Enum.CurrencyType.wood then
        if not RoleLogic:checkWood( rid, price ) then
            LOG_ERROR("rid(%d) BuyShopItem, wood not enough", rid )
            return nil, ErrorCode.ROLE_WOOD_NOT_ENOUGH
        end
    elseif sVipStore.type == Enum.CurrencyType.stone then
        if not RoleLogic:checkStone( rid, price ) then
            LOG_ERROR("rid(%d) BuyShopItem, stone not enough", rid )
            return nil, ErrorCode.ROLE_STONE_NOT_ENOUGH
        end
    elseif sVipStore.type == Enum.CurrencyType.gold then
        if not RoleLogic:checkGold( rid, price ) then
            LOG_ERROR("rid(%d) BuyShopItem, gold not enough", rid )
            return nil, ErrorCode.ROLE_GOLD_NOT_ENOUGH
        end
    elseif sVipStore.type == Enum.CurrencyType.denar then
        if not RoleLogic:checkDenar( rid, price ) then
            LOG_ERROR("rid(%d) BuyShopItem, denar not enough", rid )
            return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
        end
    end
    vipStore[id].count = vipStore[id].count + num
    RoleLogic:setRole( rid, { [Enum.Role.vipStore] = vipStore } )
    RoleSync:syncSelf( rid, { [Enum.Role.vipStore] = {[id] = vipStore[id]}}, true )
    -- 扣除宝石
    if sVipStore.type == Enum.CurrencyType.food then
        RoleLogic:addFood( rid, -price, nil, Enum.LogType.VIP_STORE_COST_CURRENCY )
    elseif sVipStore.type == Enum.CurrencyType.wood then
        RoleLogic:addWood( rid, -price, nil, Enum.LogType.VIP_STORE_COST_CURRENCY )
    elseif sVipStore.type == Enum.CurrencyType.stone then
        RoleLogic:addStone( rid, -price, nil, Enum.LogType.VIP_STORE_COST_CURRENCY )
    elseif sVipStore.type == Enum.CurrencyType.gold then
        RoleLogic:addGold( rid, -price, nil, Enum.LogType.VIP_STORE_COST_CURRENCY )
    elseif sVipStore.type == Enum.CurrencyType.denar then
        RoleLogic:addDenar( rid, -price, nil, Enum.LogType.VIP_STORE_COST_CURRENCY )
    end
    ItemLogic:addItem( { rid = rid, itemId = sVipStore.itemID, itemNum = num, eventType = Enum.LogType.VIP_STORE_GAIN_ITEM })
    -- 更新商店购买次数
    TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.SHOP_BUY, Enum.TaskArgDefault, 1 )
    return { itemId = sVipStore.itemID, itemNum = num }
end

---@see 购买远征商店道具
function response.BuyExpeditionStore( msg )
    local rid = msg.rid
    local type = msg.type
    local itemId = msg.itemId
    local price
    local expedition = RoleLogic:getRole( rid, Enum.Role.expedition )
    local update = false
    if type == Enum.ExpeditionType.HEAD then
        if itemId == 1 then
            local s_ExpeditionHead = CFG.s_ExpeditionHead:Get(SM.ExpeditionShopMgr.req.getHeroId())
            itemId = s_ExpeditionHead.itemID
            price = s_ExpeditionHead.price
            -- 判断远征币是否充足
            if not RoleLogic:checkExpeditionCoin( rid, price ) then
                LOG_ERROR("rid(%d) BuyExpeditionStore, expeditionCoin not enough ", rid )
                return nil, ErrorCode.ROLE_EXPEDITIONCOIN_NOT_ENOUGH
            end
        elseif itemId == 2 then
            local s_Config = CFG.s_Config:Get("heroHead2")
            itemId = s_Config[1]
            price = s_Config[2]
            if not RoleLogic:checkExpeditionCoin( rid, price ) then
                LOG_ERROR("rid(%d) BuyExpeditionStore, expeditionCoin not enough ", rid )
                return nil, ErrorCode.ROLE_EXPEDITIONCOIN_NOT_ENOUGH
            end
        elseif itemId == 3 then
            local s_Config = CFG.s_Config:Get("heroHead3")
            itemId = s_Config[1]
            -- 判断购买数量是否超出上限
            if expedition.headCount and expedition.headCount >= s_Config[3] then
                LOG_ERROR("rid(%d) BuyExpeditionStore, item count max ", rid )
                return nil, ErrorCode.SHOP_EXPEDITION_ITEM_COUNT_MAX
            end
            price = s_Config[2]
            if not RoleLogic:checkExpeditionCoin( rid, price ) then
                LOG_ERROR("rid(%d) BuyExpeditionStore, expeditionCoin not enough ", rid )
                return nil, ErrorCode.ROLE_EXPEDITIONCOIN_NOT_ENOUGH
            end
            expedition.headCount = expedition.headCount + 1
            update = true
        end
    else
        local s_ExpeditionShop = CFG.s_ExpeditionShop:Get(itemId)
        -- 判断购买数量是否超出上限
        if expedition.shopItem and expedition.shopItem[itemId] and expedition.shopItem[itemId].buyCount >= 1 then
            LOG_ERROR("rid(%d) BuyExpeditionStore, item count max", rid )
            return nil, ErrorCode.SHOP_EXPEDITION_ITEM_COUNT_MAX
        end
        if not RoleLogic:checkExpeditionCoin( rid, s_ExpeditionShop.price ) then
            LOG_ERROR("rid(%d) BuyExpeditionStore, expeditionCoin not enough ", rid )
            return nil, ErrorCode.ROLE_EXPEDITIONCOIN_NOT_ENOUGH
        end
        if not expedition.shopItem then expedition.shopItem = {} end
        if expedition.shopItem[itemId] then expedition.shopItem[itemId] = {itemId = itemId, buyCount = 0} end
        expedition.shopItem[itemId].buyCount = expedition.shopItem[itemId].buyCount + 1
        itemId = s_ExpeditionShop.itemID
        price = s_ExpeditionShop.price
        update = true
    end
    if update then
        RoleLogic:setRole( rid, { [Enum.Role.expedition] = expedition } )
        RoleSync:syncSelf( rid, { [Enum.Role.expedition] = expedition }, true, true )
    end
    RoleLogic:addExpeditionCoin( rid, -price, nil, Enum.LogType.EXPEDITION_SHOP_COST_CURRENCY )
    local syncItemInfo = ItemLogic:addItem( { rid = rid, itemId = itemId, itemNum = 1, eventType = Enum.LogType.EXPEDITION_SHOP_GAIN_ITEM, noSync = true })
    ItemLogic:syncItem( rid, nil, syncItemInfo, true, true )
    return { result = true }
end

---@see 刷新远征商店道具
function response.RefreshExpeditionStore( msg )
    local rid = msg.rid
    local expedition = RoleLogic:getRole( rid, Enum.Role.expedition )
    local refreshPrice = CFG.s_Config:Get("refreshPrice")
    -- 判断刷新次数
    if expedition.refreshCount and expedition.refreshCount >= table.size(refreshPrice) then
        LOG_ERROR("rid(%d) RefreshExpeditionStore, refresh count max ", rid )
        return nil, ErrorCode.SHOP_EXPEDITION_REFRESH_COUNT_MAX
    end
    -- 判断货币是否充足
    local price = refreshPrice[expedition.refreshCount + 1]
    if not RoleLogic:checkDenar( rid, price ) then
        LOG_ERROR("rid(%d) RefreshExpeditionStore, denar not enough ", rid )
        return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
    end
    -- 扣除钻石
    RoleLogic:addDenar( rid, -price, nil, Enum.LogType.EXPEDITION_REFRESH_COST_CURRENCY)
    expedition.refreshCount = expedition.refreshCount + 1
    expedition.shopItem = RoleLogic:refreshExpeditionStore()
    RoleLogic:setRole( rid, { [Enum.Role.expedition] = expedition } )
    RoleSync:syncSelf( rid, { [Enum.Role.expedition] = expedition }, true, true )
    return { result = true }
end

---@see 获取限时统帅
function response.GetLimitHeroInfo( msg )
    return SM.ExpeditionShopMgr.req.getHeroInfo()
end