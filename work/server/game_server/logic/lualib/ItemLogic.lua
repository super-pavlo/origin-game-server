--[[
* @file : ItemLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Tue Dec 24 2019 10:08:48 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 道具相关逻辑实现
* Copyright(C) 2017 IGG, All rights reserved
]]

local Random = require "Random"
local LogLogic = require "LogLogic"
local HeroLogic = require "HeroLogic"
local ItemLogic = {}

---@see 设置道具属性
function ItemLogic:setItem( _rid, _itemIndex, _field, _value )
    return MSM.d_item[_rid].req.Set( _rid, _itemIndex, _field, _value )
end

---@see 获取道具
function ItemLogic:getItem( _rid, _itemIndex, _fields )
    return MSM.d_item[_rid].req.Get( _rid, _itemIndex, _fields )
end

---@see 生成道具初始属性
function ItemLogic:initItem( _rid, _itemInfo )
    local itemInfo = {
        itemId = _itemInfo.ID,
        overlay = _itemInfo.overlay,
        rid = _rid,
    }

    return itemInfo
end

---@see 获取一个道具空索引
function ItemLogic:getFreeItemIndex( _rid, _itemInfos )
    _itemInfos = _itemInfos or self:getItem( _rid ) or {}
    local newIndex = 0
    for i = 1, table.size( _itemInfos ) do
        if not _itemInfos[i] then return i end
        newIndex = i
    end
    return newIndex + 1
end

---@see 角色创建是给予道具
function ItemLogic:createRoleGiveItems(_rid)
    local initialItemType = CFG.s_Config:Get("initialItemType")
    local initialItemNum = CFG.s_Config:Get("initialItemNum")

    local nTypeLen = table.size(initialItemType)
    local nNumLen = table.size(initialItemNum)
    local nLen = nTypeLen
    if (nTypeLen ~= nNumLen) then
        LOG_ERROR("nTypeLen ~= nNumLen")
        if nNumLen < nTypeLen then
            nLen = nNumLen
        end
    end

    for i=1, nLen do
        self:addItem( { rid = _rid, itemId = initialItemType[i], itemNum = initialItemNum[i], eventType = Enum.LogType.GUILD_CREATE_ROLE_GAIN_ITEM } )
    end
end

---@see 根据道具id添加道具
function ItemLogic:addItem( _args )
    local rid = _args.rid
    local itemId = _args.itemId
    local itemNum = _args.itemNum or 1
    local exclusive = _args.exclusive
    local noSync = _args.noSync
    local eventType = _args.eventType
    local eventArg = _args.eventArg

    -- 是否存在此道具
    local sitemInfo = CFG.s_Item:Get( itemId )
    if not sitemInfo or table.empty(sitemInfo) then
        LOG_ERROR("addItem error, not exist itemId(%d)", itemId)
        return
    end

    -- 如果是头像框类型的道具直接解锁对应头像框
    if sitemInfo.type == Enum.ItemType.HEAD then
        local RoleLogic = require "RoleLogic"
        RoleLogic:unlockRoleHead( _args.rid, _args.itemId )
        return {}
    end

    -- 是否有同类型道具
    local itemIndex, itemInfo
    local items = ItemLogic:getItem( rid )
    if not self:isEquipItem( sitemInfo.subType ) then
        for index, item in pairs( items ) do
            if item.itemId == itemId then
                itemIndex = index
                itemInfo = item
                break
            end
        end
    end

    local oldNum, newNum
    local syncItemInfo = {}
    if itemIndex then
        -- 背包存在此类型道具
        oldNum = itemInfo.overlay
        newNum = itemInfo.overlay + itemNum
        syncItemInfo[itemIndex] = { itemIndex = itemIndex, overlay = newNum }
        -- 更新道具数量
        MSM.d_item[rid].req.Set( rid, itemIndex, Enum.Item.overlay, newNum )
    else
        oldNum = 0
        newNum = itemNum
        -- 背包不存在此类型道具
        if not self:isEquipItem( sitemInfo.subType ) then
            itemInfo = self:initItem( rid, sitemInfo )
            itemInfo.overlay = itemNum
            itemIndex = self:getFreeItemIndex( rid, items )
            itemInfo.itemIndex = itemIndex
            itemInfo.exclusive = exclusive
            itemInfo.heroId = 0
            syncItemInfo[itemIndex] = itemInfo
            -- 增加道具
            MSM.d_item[rid].req.Add( rid, itemIndex, itemInfo )
        else
            -- 装备叠加上限为1
            for _ = 1, itemNum do
                itemInfo = self:initItem( rid, sitemInfo )
                itemInfo.overlay = 1
                itemIndex = self:getFreeItemIndex( rid )
                itemInfo.itemIndex = itemIndex
                itemInfo.exclusive = exclusive
                itemInfo.heroId = 0
                syncItemInfo[itemIndex] = itemInfo
                -- 增加道具
                MSM.d_item[rid].req.Add( rid, itemIndex, itemInfo )
            end
        end
    end

    if not noSync then
        self:syncItem( rid, nil, syncItemInfo, true )
    end
    if eventType then
        local RoleLogic = require "RoleLogic"
        local iggid = RoleLogic:getRole( rid, Enum.Role.iggid )
        -- 记录日志
        LogLogic:itemChange( {
            rid = rid, iggid = iggid, itemId = itemId, changeNum = itemNum, oldNum = oldNum,
            newNum = newNum, logType = eventType, logType2 = eventArg
        } )
    end

    -- 判断资源阈值
    local itemIdLimit = CFG.s_GameWarning:Get( itemId, "num" )
    if itemIdLimit and newNum > itemIdLimit then
        Common.sendResourceAlarm( rid, itemId, newNum )
    end

    return syncItemInfo
end

---@see 删除道具
function ItemLogic:delItem( _rid, _itemIndex, _itemNum, _noSync, _logType, _logExtraType )
    local itemInfo = self:getItem( _rid, _itemIndex )

    local newNum
    local syncItems = {}

    if itemInfo.overlay <= _itemNum then
        newNum = 0
        MSM.d_item[_rid].req.Delete( _rid, _itemIndex )
    else
        newNum = itemInfo.overlay - _itemNum
        MSM.d_item[_rid].req.Set( _rid, _itemIndex, Enum.Item.overlay, newNum )
    end

    if not _noSync then
        self:syncItem( _rid, _itemIndex, {
            [Enum.Item.overlay] = newNum
        }, true )
    end

    syncItems[itemInfo.itemIndex] = {
        [Enum.Item.itemIndex] = itemInfo.itemIndex,
        [Enum.Item.overlay] = newNum
    }

    local RoleLogic = require "RoleLogic"
    local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
    -- 记录日志
    LogLogic:itemChange( { rid = _rid, iggid = iggid, logType = _logType, logType2 = _logExtraType,
            itemId = itemInfo.itemId, changeNum = _itemNum, oldNum = itemInfo.overlay, newNum = newNum } )
    return syncItems
end

---@see 同步道具
function ItemLogic:syncItem( _rid, _itemIndex, _fields, _haskv, _block )
    local syncItem = {}
    if _haskv then
        if not _itemIndex then
            syncItem = _fields
        else
            _fields.itemIndex = _itemIndex
            syncItem[_itemIndex] = _fields
        end
    elseif _itemIndex then
        if not Common.isTable( _itemIndex ) then _itemIndex = { _itemIndex } end
        local itemInfo
        for _, itemIndex in pairs(_itemIndex) do
            itemInfo = self:getItem( _rid, itemIndex, _fields )
            if not itemInfo or table.empty(itemInfo) then itemInfo = { [Enum.Item.overlay] = 0 } end
            itemInfo.itemIndex = itemIndex
            syncItem[itemIndex] = itemInfo
        end
    else -- 推送全部道具
        syncItem = self:getItem( _rid )
    end

    Common.syncMsg( _rid, "Item_ItemInfo",  { itemInfo = syncItem }, _block )
end

---@see 根据道具id和数量判断道具是否足够
function ItemLogic:checkItemEnough( _rid, _itemId, _itemNum )
    local overlay = 0
    local itemInfos = self:getItem( _rid )
    for _, itemInfo in pairs( itemInfos ) do
        -- 道具为无限叠加, 找到第一个即可
        if itemInfo.itemId == _itemId then
            overlay = itemInfo.overlay
            return itemInfo.overlay >= _itemNum, overlay
        end
    end
    return false, overlay
end

---@see 根据道具ID删除道具
function ItemLogic:delItemById( _rid, _itemId, _itemNum, _noSync, _logType, _logExtraType )
    local itemInfos = self:getItem( _rid )
    -- 获取所有的该道具信息
    for itemIndex, itemInfo in pairs(itemInfos) do
        -- 道具为无限叠加, 找到第一个即可
        if itemInfo.itemId == _itemId then
            return self:delItem( _rid, itemIndex, _itemNum, _noSync, _logType, _logExtraType )
        end
    end
end

---@see 根据奖励组ID.获取奖励
function ItemLogic:getGroupPackage( _rid, _groupId, _noMerge, _openNum, _mergeHero )
    local food = 0
    local wood = 0
    local stone = 0
    local gold = 0
    local denar = 0
    local items = {}
    local soldiers = {}
    local heros = {}
    local actionForce = 0
    local itemList = {}
    local vip = 0
    local expeditionCoin = 0
    local openNum = _openNum or 1
    local guildGifts = {}
    local guildPoint = 0
    local activityActivePoint = 0
    local RoleLogic = require "RoleLogic"
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.country, Enum.Role.level } )
    -- 获取s_itemPackage group信息
    local sItemPackage = CFG.s_ItemPackage:Get( _groupId )
    if not sItemPackage or table.empty( sItemPackage ) then
        LOG_ERROR("rid(%d) getGroupPackage, s_ItemPackage no group(%d) cfg", _rid, _groupId)
        return {
            food = food, wood = wood, stone = stone, gold = gold, denar = denar, items = items, soldiers = soldiers, actionForce = actionForce,
            heros = heros, itemList = itemList, vip = vip, expeditionCoin = expeditionCoin, guildPoint = guildPoint, activityActivePoint = activityActivePoint
        }
    end

    -- 删除不满足角色的道具
    local newSItemPackage = {}
    for _, itemPackage in pairs( sItemPackage ) do
        if not itemPackage.civilization_limit or table.empty( itemPackage.civilization_limit )
            or table.exist( itemPackage.civilization_limit, 0 ) or table.exist( itemPackage.civilization_limit, roleInfo.country ) then
            if not newSItemPackage[itemPackage.randomGroup] then newSItemPackage[itemPackage.randomGroup] = {} end
            table.insert( newSItemPackage[itemPackage.randomGroup], { id = itemPackage, rate = itemPackage.odds } )
        end
    end

    local allPackages = {}
    local packageInfo, levelAddNumber, rangeRate, endNumber, turnTableId
    for _ = 1, openNum do
        for _, randomGroup in pairs( newSItemPackage ) do
            packageInfo = Random.GetId( randomGroup )
            turnTableId = packageInfo.ID
            -- 等级增量
            levelAddNumber = 0
            if roleInfo.level > packageInfo.numberStep_lv then
                levelAddNumber = math.floor( ( roleInfo.level - packageInfo.numberStep_lv ) * packageInfo.numberStep_increment )
            end
            -- 获取本次随机浮动比例
            if ( packageInfo.numberFloat_min == 0 and packageInfo.numberFloat_max == 0 )
                or packageInfo.numberFloat_min > packageInfo.numberFloat_max then
                rangeRate = 1
            else
                rangeRate = Random.GetRange( packageInfo.numberFloat_min, packageInfo.numberFloat_max, 1 )[1] / 1000
            end
            -- 随机组最终得到的奖励梳理
            endNumber = ( packageInfo.number + levelAddNumber // 1 ) * rangeRate // 1
            if endNumber < 1 then endNumber = 1 end
            if not allPackages[packageInfo.ID] then allPackages[packageInfo.ID] = {} end
            allPackages[packageInfo.ID] = {
                type = packageInfo.type, typeData = packageInfo.typeData,
                number = ( allPackages[packageInfo.ID].number or 0 ) + endNumber
            }
        end
    end

    local sArmy
    local sArms = CFG.s_Arms:Get()
    local subItemTypes = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.SUB_ITEM_TYPE ) or {}
    -- 整理所有奖励
    for _, package in pairs( allPackages ) do
        if package.type == Enum.ItemPackageType.CURRENCY then
            -- 货币类型
            if package.typeData == Enum.CurrencyType.food then
                -- 粮食
                food = food + package.number
            elseif package.typeData == Enum.CurrencyType.wood then
                -- 木材
                wood = wood + package.number
            elseif package.typeData == Enum.CurrencyType.stone then
                -- 石料
                stone = stone + package.number
            elseif package.typeData == Enum.CurrencyType.gold then
                -- 金币
                gold = gold + package.number
            elseif package.typeData == Enum.CurrencyType.denar then
                -- 宝石
                denar = denar + package.number
            elseif package.typeData == Enum.CurrencyType.actionForce then
                actionForce = actionForce + package.number
            elseif package.typeData == Enum.CurrencyType.vip then
                vip = vip + package.number
            elseif package.typeData == Enum.CurrencyType.expeditionCoin then
                expeditionCoin = expeditionCoin + package.number
            elseif package.typeData == Enum.CurrencyType.individualPoints then
                guildPoint = guildPoint + package.number
            elseif package.typeData == Enum.CurrencyType.activityActivePoint then
                activityActivePoint = activityActivePoint + package.number
            else
                LOG_ERROR("rid(%d) getGroupPackage, not support group(%d) typeData(%d)", _rid, _groupId, package.typeData)
            end
        elseif package.type == Enum.ItemPackageType.ITEM then
            -- 道具类型
            if not items[package.typeData] then
                items[package.typeData] = { itemNum = 0 }
            end
            items[package.typeData].itemNum = items[package.typeData].itemNum + package.number
            if _noMerge then
                table.insert( itemList, { itemId = package.typeData, itemNum = package.number } )
            end
        elseif package.type == Enum.ItemPackageType.SOLDIER then
            -- 士兵类型
            sArmy = sArms[package.typeData]
            if not soldiers[package.typeData] then
                soldiers[package.typeData] = { type = sArmy.armsType, level = sArmy.armsLv, num = package.number }
            else
                soldiers[package.typeData].num = soldiers[package.typeData].num + package.number
            end
        elseif package.type == Enum.ItemPackageType.SUB_ITEM_TYPE then
            -- 道具子类型
            if subItemTypes[package.typeData] and package.number > 0 then
                local itemId
                for _ = 1, package.number do
                    itemId = Random.GetId( subItemTypes[package.typeData] )
                    if not items[itemId] then
                        items[itemId] = { itemNum = 1 }
                    else
                        items[itemId].itemNum = items[itemId].itemNum + 1
                    end
                    if _noMerge then
                        table.insert( itemList, { itemId = itemId, itemNum = 1 } )
                    end
                end
            end
        elseif package.type == Enum.ItemPackageType.HERO then
            local heroInfo = HeroLogic:getHero( _rid, package.typeData )
            if not _mergeHero then
                local isNew = 1
                if (heroInfo and not table.empty(heroInfo)) or heroInfo[package.typeData] then isNew = 0 end
                heroInfo[package.typeData] = package.typeData
                table.insert(heros,{ heroId = package.typeData, num = package.number, isNew = isNew })
            else
                local isNew = 1
                if (heroInfo and not table.empty(heroInfo)) or heroInfo[package.typeData] then isNew = 0 end
                local insert = true
                for _, info in pairs(heros) do
                    if info.heroId == package.typeData then
                        info.num = info.num + package.number
                        insert = false
                        break
                    end
                end
                if insert then
                    table.insert(heros,{ heroId = package.typeData, num = package.number, isNew = isNew })
                end
            end
            -- else
            --     local sHeroInfo = CFG.s_Hero:Get(package.typeData)
            --     local itemId = sHeroInfo.getItem
            --     local itemNum = sHeroInfo.getItemNum
            --     if not items[itemId] then
            --         items[itemId] = { itemNum = itemNum }
            --     else
            --         items[itemId].itemNum = items[itemId].itemNum + itemNum
            --     end
            -- end
        elseif package.type == Enum.ItemPackageType.GUILD_GIFT then
            -- 联盟礼物
            if not guildGifts[package.typeData] then
                guildGifts[package.typeData] = 1
            else
                guildGifts[package.typeData] = guildGifts[package.typeData] + 1
            end
        end
    end
    return {
        food = food, wood = wood, stone = stone, gold = gold, denar = denar,
        items = items, soldiers = soldiers, actionForce = actionForce, heros = heros, itemList = itemList, vip = vip,
        expeditionCoin = expeditionCoin, guildGifts = guildGifts, guildPoint = guildPoint, activityActivePoint = activityActivePoint,
        turnTableId = turnTableId
    }
end

---@see 发放奖励
function ItemLogic:giveReward( _rid, _rewards, _groupId, _noSync, _noHeroShow, _block, _isBuyGift, _packageNameId )
    if not _rewards or table.empty(_rewards) then return end

    local RoleLogic = require "RoleLogic"
    local ArmyTrainLogic = require "ArmyTrainLogic"

    local currencyLogType = Enum.LogType.PACKAGE_GAIN_CURRENCY
    local itemLogType = Enum.LogType.PACKAGE_GAIN_ITEM
    local armyLogType = Enum.LogType.PACKAGE_GAIN_ARMY

    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0

    local syncRoleInfo = {}
    local syncItemInfo = {}
    for name, value in pairs( _rewards ) do
        if name == "food" then
            syncRoleInfo.food = RoleLogic:addFood( _rid, value, _noSync, currencyLogType, _groupId )
        elseif name == "wood" then
            syncRoleInfo.wood = RoleLogic:addWood( _rid, value, _noSync, currencyLogType, _groupId )
        elseif name == "stone" then
            syncRoleInfo.stone = RoleLogic:addStone( _rid, value, _noSync, currencyLogType, _groupId )
        elseif name == "gold" then
            syncRoleInfo.gold = RoleLogic:addGold( _rid, value, _noSync, currencyLogType, _groupId )
        elseif name == "denar" then
            syncRoleInfo.denar = RoleLogic:addDenar( _rid, value, _noSync, currencyLogType, _groupId )
        elseif name == "actionForce" then
            syncRoleInfo.actionForce = RoleLogic:addActionForce( _rid, value, _noSync, currencyLogType, _groupId )
        elseif name == "vip" then
            syncRoleInfo.vip = RoleLogic:addVip( _rid, value, _noSync, currencyLogType, _groupId )
        elseif name == "expeditionCoin" then
            syncRoleInfo.expeditionCoin = RoleLogic:addExpeditionCoin( _rid, value, _noSync, currencyLogType, _groupId )
        elseif name == "guildPoint" then
            syncRoleInfo.guildPoint = RoleLogic:addGuildPoint( _rid, value, _noSync, currencyLogType, _groupId )
        elseif name == "items" then
            for _, itemInfo in pairs( value ) do
                local newItemInfo = self:addItem( { rid = _rid, itemId = itemInfo.itemId, itemNum = itemInfo.itemNum, eventType = itemLogType, eventArg = _groupId, noSync = true } ) or {}
                for itemIndex, item in pairs(newItemInfo) do
                    if syncItemInfo[itemIndex] then
                        syncItemInfo[itemIndex].overlay = item.overlay
                    else
                        syncItemInfo[itemIndex] = item
                    end
                end
            end
        elseif name == "soldiers" then
            for _, soldierInfo in pairs( value ) do
                table.mergeEx(
                    syncRoleInfo,
                    ArmyTrainLogic:addSoldiers( _rid, soldierInfo.type, soldierInfo.level, soldierInfo.num, armyLogType, _groupId, nil, _noSync ) or {}
                )
            end
            -- 计算角色当前战力
            local _, changeInfo = RoleLogic:cacleSyncHistoryPower( _rid, nil, true )
            table.mergeEx( syncRoleInfo, changeInfo or {} )
        elseif name == "heros" then
            for _, heroInfo in pairs(value) do
                for _ = 1, heroInfo.num do
                    local newItemInfo =  HeroLogic:addHero( _rid, heroInfo.heroId, nil, _noHeroShow, true ) or {}
                    for itemIndex, item in pairs(newItemInfo) do
                        if syncItemInfo[itemIndex] then
                            syncItemInfo[itemIndex].overlay = item.overlay
                        else
                            syncItemInfo[itemIndex] = item
                        end
                    end
                end
            end
        elseif name == "guildGifts" then
            if guildId > 0 then
                local buyRid
                if _isBuyGift then
                    buyRid = _rid
                end
                for _, giftInfo in pairs( value ) do
                    for _ = 1, giftInfo.giftNum do
                        MSM.GuildMgr[guildId].post.sendGuildGift( guildId, giftInfo.giftType, buyRid, nil, _packageNameId )
                    end
                end
            end
        elseif name == "activityActivePoint" then
            syncRoleInfo.activityActivePoint = RoleLogic:addActivityActivePoint( _rid, value, _noSync, currencyLogType, _groupId )
        end
    end

    if not _noSync and not table.empty( syncItemInfo ) then
        self:syncItem( _rid, nil, syncItemInfo, true, _block )
    end

    return syncRoleInfo, syncItemInfo
end

---@see 获得礼包组奖励
function ItemLogic:getItemPackage( _rid, _groupId, _noAdd, _noSync, _noHeroShow, _noMerge, _block, _isBuyGift, _openNum, _mergeHero, _packageNameId )
    if not _groupId or _groupId <= 0 then return end

    local packageInfo = self:getGroupPackage( _rid, _groupId, _noMerge, _openNum, _mergeHero )

    local rewardItems = {}
    for itemId, itemInfo in pairs( packageInfo.items or {} ) do
        table.insert( rewardItems, { itemId = itemId, itemNum = itemInfo.itemNum } )
    end
    local rewardSoldiers = {}
    for id, soldierInfo in pairs( packageInfo.soldiers or {} ) do
        table.insert( rewardSoldiers, {
            id = id, type = soldierInfo.type, level = soldierInfo.level, num = soldierInfo.num
        } )
    end

    local guildGifts = {}
    for giftType, giftNum in pairs( packageInfo.guildGifts or {} ) do
        table.insert( guildGifts, { giftType = giftType, giftNum = giftNum } )
    end

    local rewardInfo = {
        food = packageInfo.food and packageInfo.food > 0 and packageInfo.food or nil,
        wood = packageInfo.wood and packageInfo.wood > 0 and packageInfo.wood or nil,
        stone = packageInfo.stone and packageInfo.stone > 0 and packageInfo.stone or nil,
        gold = packageInfo.gold and packageInfo.gold > 0 and packageInfo.gold or nil,
        denar = packageInfo.denar and packageInfo.denar > 0 and packageInfo.denar or nil,
        actionForce = packageInfo.actionForce and packageInfo.actionForce > 0 and packageInfo.actionForce or nil,
        vip = packageInfo.vip and packageInfo.vip > 0 and packageInfo.vip or nil,
        expeditionCoin = packageInfo.expeditionCoin and packageInfo.expeditionCoin > 0 and packageInfo.expeditionCoin or nil,
        guildPoint = packageInfo.guildPoint and packageInfo.guildPoint > 0 and packageInfo.guildPoint or nil,
        items = not table.empty( rewardItems ) and rewardItems or nil,
        soldiers = not table.empty( rewardSoldiers ) and rewardSoldiers or nil,
        heros = not table.empty( packageInfo.heros ) and packageInfo.heros or nil,
        guildGifts = not table.empty( guildGifts ) and guildGifts or nil,
        activityActivePoint = packageInfo.activityActivePoint and packageInfo.activityActivePoint > 0 and packageInfo.activityActivePoint or nil,
        groupId = _groupId,
    }

    if not _noAdd then
        -- 发放奖励
        self:giveReward( _rid, rewardInfo, _groupId, _noSync, _noHeroShow, _block, _isBuyGift, _packageNameId )
    end
    -- 不合并改变返回值
    if _noMerge then
        rewardInfo.items = not table.empty( packageInfo.itemList ) and packageInfo.itemList or nil
    end
    return rewardInfo, packageInfo.turnTableId
end

---@see 合并奖励信息
function ItemLogic:mergeReward( _rawReward, _addReward )
    local flag
    _rawReward = _rawReward or {}
    if not _addReward or table.empty( _addReward ) then return _rawReward end

    for name, value in pairs( _addReward ) do
        if name == "food" or name == "wood" or name == "stone" or name == "gold" or name == "denar" or name == "actionForce" or name == "vip"
            or name == "expeditionCoin" or name == "guildPoint" or name == "activityActivePoint" then
            _rawReward[name] = ( _rawReward[name] or 0 ) + value
        elseif name == "items" then
            if not _rawReward.items then _rawReward.items = {} end
            for _, item in pairs( value ) do
                flag = false
                for index, itemInfo in pairs( _rawReward.items ) do
                    if itemInfo.itemId == item.itemId then
                        flag = true
                        _rawReward.items[index].itemNum = itemInfo.itemNum + item.itemNum
                        break
                    end
                end
                if not flag then
                    table.insert( _rawReward.items, item )
                end
            end
        elseif name == "soldiers" then
            if not _rawReward.soldiers then _rawReward.soldiers = {} end
            for _, soldier in pairs( value ) do
                flag = false
                for index, soldierInfo in pairs( _rawReward.soldiers ) do
                    if soldierInfo.id == soldier.id then
                        flag = true
                        _rawReward.soldiers[index].num = soldierInfo.num + soldier.num
                        break
                    end
                end
                if not flag then
                    table.insert( _rawReward.soldiers, soldier )
                end
            end
        elseif name == "heros" then
            if not _rawReward.heros then _rawReward.heros = {} end
            for _, hero in pairs( value ) do
                flag = false
                for index, heroInfo in pairs( _rawReward.heros ) do
                    if heroInfo.heroId == hero.heroId then
                        flag = true
                        _rawReward.heros[index].num = heroInfo.num + hero.num
                        _rawReward.heros[index].isNew = heroInfo.isNew + hero.isNew
                        break
                    end
                end
                if not flag then
                    table.insert( _rawReward.heros, hero )
                end
            end
        elseif name == "guildGifts" then
            if not _rawReward.guildGifts then _rawReward.guildGifts = {} end
            for _, gift in pairs( value ) do
                flag = false
                for index, giftInfo in pairs( _rawReward.guildGifts ) do
                    if giftInfo.giftType == gift.giftType then
                        flag = true
                        _rawReward.guildGifts[index].giftNum = giftInfo.giftNum + gift.giftNum
                        break
                    end
                end
                if not flag then
                    table.insert( _rawReward.guildGifts, gift )
                end
            end
        end
    end

    return _rawReward
end

---@see 获取山洞村庄奖励
function ItemLogic:getVillageReward( _rid )
    local RoleLogic = require "RoleLogic"
    local level = RoleLogic:getRole( _rid, Enum.Role.level )

    local allRewards = {}
    local sVillageRewardData = CFG.s_VillageRewardData:Get()
    -- 获取所有等级满足的村庄奖励信息
    for reqLevel, levelGroup in pairs( sVillageRewardData ) do
        if level >= reqLevel then
            table.merge( allRewards, levelGroup )
        end
    end

    if not table.empty( allRewards ) then
        local reward = Random.GetId( allRewards )

        if reward.type == Enum.VillageRewardType.SOLDIER then
            -- 士兵
            local sArms = CFG.s_Arms:Get( reward.typeData )
            if sArms and not table.empty( sArms ) then
                local ArmyTrainLogic = require "ArmyTrainLogic"
                ArmyTrainLogic:addSoldiers( _rid, sArms.armsType, sArms.armsLv, reward.typeNum, Enum.LogType.ARMY_VILLAGE_ADD )
                -- 计算角色当前战力
                RoleLogic:cacleSyncHistoryPower( _rid, nil, nil, nil, nil, Enum.RoleCombatPowerType.VILLAGE )
            end
        elseif reward.type == Enum.VillageRewardType.ITEM then
            -- 道具
            self:addItem( {
                rid = _rid, itemId = reward.typeData, itemNum = reward.typeNum,
                eventType = Enum.LogType.VILLAGE_GAIN_ITEM
            } )
        end

        return reward.ID
    end
end

---@see 检查道具是否是装备
function ItemLogic:isEquipItem( _subType )
    return _subType == Enum.ItemSubType.ARMS or _subType == Enum.ItemSubType.HELMET or _subType == Enum.ItemSubType.BREASTPLATE
        or _subType == Enum.ItemSubType.GLOVES or _subType == Enum.ItemSubType.PANTS or _subType == Enum.ItemSubType.ACCESSORIES
        or _subType == Enum.ItemSubType.SHOES
end

return ItemLogic