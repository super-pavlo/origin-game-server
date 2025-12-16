--[[
* @file : Item.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Thu Jan 09 2020 16:38:29 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 道具相关协议代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local ItemLogic = require "ItemLogic"
local RoleLogic = require "RoleLogic"
local DenseFogLogic = require "DenseFogLogic"
local TaskLogic = require "TaskLogic"
local BuildingLogic = require "BuildingLogic"
local RoleSync = require "RoleSync"

---@see 使用道具兑换资源
function response.ItemChangeResource( msg )
    local rid = msg.rid
    local itemIndex = msg.itemIndex
    local itemNum = msg.itemNum

    -- 参数检查
    if not itemIndex or not itemNum then
        LOG_ERROR("rid(%d) ItemChangeResource, no itemIndex or no itemNum arg", rid)
        return nil, ErrorCode.ITEM_ARG_ERROR
    end

    local itemInfo = ItemLogic:getItem( rid, itemIndex )

    -- 道具是否存在
    if not itemInfo or table.empty( itemInfo ) then
        LOG_ERROR("rid(%d) ItemChangeResource, itemIndex(%d) no item", rid, itemIndex)
        return nil, ErrorCode.ITEM_NOT_EXIST
    end

    local sItem = CFG.s_Item:Get( itemInfo.itemId )
    -- 道具是否是资源类道具
    if sItem.type ~= Enum.ItemType.RESOURCE and sItem.subType ~= Enum.ItemSubType.ACTION_FORCE then
        LOG_ERROR("rid(%d) ItemChangeResource, itemIndex(%d) itemId(%d) no resource item", rid, itemIndex)
        return nil, ErrorCode.ITEM_NOT_RESOURCE_ITEM
    end

    -- 道具是否足够
    if itemInfo.overlay < itemNum then
        LOG_ERROR("rid(%d) ItemChangeResource, itemIndex(%d) overlay(%d) no enough", rid, itemIndex, itemInfo.overlay)
        return nil, ErrorCode.ITEM_NOT_ENOUGH
    end

    -- 扣除道具
    ItemLogic:delItem( rid, itemIndex, itemNum, nil, Enum.LogType.RESOURCE_CHANGE_COST_ITEM )
    local currencyLogType = Enum.LogType.RESOURCE_CHANGE_GAIN_CURRENCY
    -- 赠送资源
    if sItem.subType == Enum.ItemSubType.GOLD then
        -- 金币
        RoleLogic:addGold( rid, sItem.data1 * itemNum, nil, currencyLogType )
    elseif sItem.subType == Enum.ItemSubType.STONE then
        -- 石料
        RoleLogic:addStone( rid, sItem.data1 * itemNum, nil, currencyLogType )
    elseif sItem.subType == Enum.ItemSubType.WOOD then
        -- 木材
        RoleLogic:addWood( rid, sItem.data1 * itemNum, nil, currencyLogType )
    elseif sItem.subType == Enum.ItemSubType.GRAIN then
        -- 粮食
        RoleLogic:addFood( rid, sItem.data1 * itemNum, nil, currencyLogType )
    elseif sItem.subType == Enum.ItemSubType.VIP then
        -- vip经验
        RoleLogic:addVip( rid, sItem.data1 * itemNum, nil, currencyLogType)
    elseif sItem.subType == Enum.ItemSubType.ACTION_FORCE then
        -- 行动力
        RoleLogic:addActionForce( rid, sItem.data1 * itemNum, nil, currencyLogType)
    end

    -- 更新道具使用任务进度
    TaskLogic:updateItemUseTaskSchedule( rid, nil, itemNum, sItem )

    return { result = true, itemId = itemInfo.itemId, itemNum = itemNum }
end

---@see 使用道具
function response.ItemUse( msg )
    local rid = msg.rid
    local itemIndex = msg.itemIndex
    local itemNum = msg.itemNum
    local id = msg.id
    -- 参数检查
    if not itemIndex or not itemNum then
        LOG_ERROR("rid(%d) ItemUse, no itemIndex or no itemNum arg", rid)
        return nil, ErrorCode.ITEM_ARG_ERROR
    end

    local itemInfo = ItemLogic:getItem( rid, itemIndex )
    local sitem = CFG.s_Item:Get( itemInfo.itemId )
    local rewardId
    -- 道具是否存在
    if not itemInfo or table.empty( itemInfo ) then
        LOG_ERROR("rid(%d) ItemUse, itemIndex(%d) no item", rid, itemIndex)
        return nil, ErrorCode.ITEM_NOT_EXIST
    end

    -- 判断道具能否使用
    if sitem.itemFunction == Enum.ItemFunctionType.NOT_USE then
        LOG_ERROR("rid(%d) ItemUse, itemIndex(%d) itemId(%d) can not use", rid, itemIndex, itemInfo.itemId)
        return nil, ErrorCode.ITEM_NOT_USE
    end

    -- 判断能否批量使用
    if itemNum > 1 and sitem.batchUse == Enum.ItemBatchUse.NO then
        LOG_ERROR("rid(%d) ItemUse, itemIndex(%d) itemId(%d) can not batch use", rid, itemIndex, itemInfo.itemId)
        return nil, ErrorCode.ITEM_NOT_BATCH_USE
    end

    -- 联盟积分道具判断是否加入联盟
    if sitem.itemFunction == Enum.ItemFunctionType.LEAGUE_POINTS and not RoleLogic:checkRoleGuild( rid ) then
        return nil, ErrorCode.ITEM_NOT_JOIN_GUILD
    end

    -- 道具是否足够
    if itemInfo.overlay < itemNum then
        LOG_ERROR("rid(%d) ItemUse, itemIndex(%d) overlay(%d) no enough", rid, itemIndex, itemInfo.overlay)
        return nil, ErrorCode.ITEM_NOT_ENOUGH
    end

    -- 道具召唤怪物
    local objectIndex, monsterPos
    if sitem.itemFunction == Enum.ItemFunctionType.SUMMON_MONSTER then
        objectIndex = Common.newMapObjectIndex()
        monsterPos = MSM.MonsterSummonMgr[objectIndex].req.summonMonster( rid, sitem.data2, objectIndex )
        if not monsterPos then
            LOG_ERROR("rid(%d) ItemUse, itemIndex(%d) itemId(%d) summon monster failed", rid, itemIndex, itemInfo.itemId)
            return nil, ErrorCode.ITEM_SOMMON_MONSTER_FAILED
        end
    elseif sitem.itemFunction == Enum.ItemFunctionType.CHOOSE_ITEMPACKAGE then
        local sItemRewardChoice = CFG.s_ItemRewardChoice:Get()[sitem.data2]
        if not sItemRewardChoice[id] then
            LOG_ERROR("rid(%d) ItemUse, itemIndex(%d) itemId(%d) package not exist", rid, itemIndex, itemInfo.itemId)
            return nil, ErrorCode.ITEM_PACKAGEID_NOT_EXIST
        end
    end

    ItemLogic:delItem( rid, itemIndex, itemNum, nil, Enum.LogType.USE_BAG_ITEM_COST_ITEM )

    -- 更新道具使用任务进度
    TaskLogic:updateItemUseTaskSchedule( rid, nil, itemNum, sitem )

    local rewardInfo
    if sitem.itemFunction == Enum.ItemFunctionType.OPEN_ITEMPACKAGE or sitem.itemFunction == Enum.ItemFunctionType.RECYCLE then
        -- 打开礼包组、活动材料回收
        rewardId = sitem.data2
    elseif sitem.itemFunction == Enum.ItemFunctionType.CHOOSE_ITEMPACKAGE then
        local sItemRewardChoice = CFG.s_ItemRewardChoice:Get()[sitem.data2]
        rewardId = sItemRewardChoice[id].reward
    elseif sitem.itemFunction == Enum.ItemFunctionType.CITY_BUFF then
        RoleLogic:addCityBuff( rid, sitem.data2 )
        return { itemId = itemInfo.itemId, itemNum = itemNum }
    elseif sitem.itemFunction == Enum.ItemFunctionType.VIP then
        RoleLogic:addVip( rid, sitem.data1 * itemNum , nil, Enum.LogType.ITEM_GAIN_VIP )
        return { itemId = itemInfo.itemId, itemNum = itemNum }
    elseif sitem.itemFunction == Enum.ItemFunctionType.ACTION_FORCE then
        RoleLogic:addActionForce( rid, sitem.data1 * itemNum , nil, Enum.LogType.ITEM_GAIN_VIP )
        return { itemId = itemInfo.itemId, itemNum = itemNum }
    elseif sitem.itemFunction == Enum.ItemFunctionType.KINGDOM_MAP then
        -- 王国地图
        if not DenseFogLogic:openNearDenseFog( rid, msg.pos ) then
            -- 开启失败,给道具
            rewardInfo = ItemLogic:getItemPackage( rid, sitem.data2 )
            if rewardInfo.items and not table.empty(rewardInfo.items) then
                local allItems = {}
                for _, subItemInfo in pairs(rewardInfo.items) do
                    table.insert( allItems, { itemId = subItemInfo.itemId, itemNum = subItemInfo.itemNum } )
                end
                rewardInfo.items = allItems
            end
        end
        return { itemId = itemInfo.itemId, itemNum = itemNum, rewardInfo = rewardInfo }
    elseif sitem.itemFunction == Enum.ItemFunctionType.LEAGUE_POINTS then
        local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
        local GuildLogic = require "GuildLogic"
        GuildLogic:addGuildCurrency( guildId, Enum.CurrencyType.leaguePoints, sitem.data1 * itemNum )
        rewardInfo = {}
        rewardInfo.leaguePoints = sitem.data1 * itemNum
        return { itemId = itemInfo.itemId, itemNum = itemNum, rewardInfo = rewardInfo }
    elseif sitem.itemFunction == Enum.ItemFunctionType.SECONDE_QUEUE then
        local size = 0
        local buildQueue = RoleLogic:getRole( rid, Enum.Role.buildQueue )
        for _, queueInfo in pairs(buildQueue) do
            if queueInfo.expiredTime == -1 then
                size = size + 1
            end
        end
        -- 删除道具，发放奖励
        local status
        rewardInfo = {}
        if size >= CFG.s_Config:Get("workQueueMax") then
            rewardInfo = ItemLogic:getItemPackage( rid, sitem.data2 )
            status = 3
        else
            status = BuildingLogic:unlockQueue( rid, CFG.s_Config:Get("workQueueTime") )
        end
        return { itemId = itemInfo.itemId, itemNum = itemNum, rewardInfo = rewardInfo, status = status }
    elseif sitem.itemFunction == Enum.ItemFunctionType.TRAIN_NUM then
        local roleInfo = RoleLogic:getRole( rid, { Enum.Role.itemAddTroopsCapacity, Enum.Role.itemAddTroopsCapacityCount })
        if roleInfo.itemAddTroopsCapacity == sitem.data1 then
            roleInfo.itemAddTroopsCapacityCount = roleInfo.itemAddTroopsCapacityCount + itemNum
        else
            roleInfo.itemAddTroopsCapacity = sitem.data1
            roleInfo.itemAddTroopsCapacityCount = itemNum
        end
        RoleLogic:setRole( rid, { [Enum.Role.itemAddTroopsCapacity] = roleInfo.itemAddTroopsCapacity,
                            [Enum.Role.itemAddTroopsCapacityCount] = roleInfo.itemAddTroopsCapacityCount } )
        RoleSync:syncSelf( rid, { [Enum.Role.itemAddTroopsCapacity] = roleInfo.itemAddTroopsCapacity,
                            [Enum.Role.itemAddTroopsCapacityCount] = roleInfo.itemAddTroopsCapacityCount  }, true, true )
    end

    if rewardId and rewardId > 0 then
        rewardInfo = ItemLogic:getItemPackage( rid, rewardId, nil, nil, nil, nil, nil, nil, itemNum )
    end

    return { itemId = itemInfo.itemId, itemNum = itemNum, rewardInfo = rewardInfo, objectIndex = objectIndex, pos = monsterPos }
end