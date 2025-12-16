--[[
* @file : RechargeLogic.lua
* @type : 充值相关
* @author : chenlei
* @created : Sat May 02 2020 05:18:57 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : TODO
* Copyright(C) 2017 IGG, All rights reserved
]]
local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local HeroLogic = require "HeroLogic"
local ItemLogic = require "ItemLogic"
local EmailLogic = require "EmailLogic"
local Timer = require "Timer"
local BuildingLogic = require "BuildingLogic"

local RechargeLogic = {}

function RechargeLogic:checkSn( _sn )
    return SM.c_recharge.req.Get( _sn )
end

---@see 检查订单号是否已经存在

function RechargeLogic:addSnInfo( _sn, _rid, _id, _iggId )
    if _sn then
        SM.c_recharge.req.Add( _sn, {
            rid = _rid,
            id = _id,
            sn = _sn,
            iggId = _iggId,
            time = os.time()
        } )
    end
end

---@see 购买宝石
function RechargeLogic:buyDenar( _rid, _id )
    local sPrice = CFG.s_Price:Get( _id )
    local id = sPrice.rechargeTypeID
    local sRechargeGemMall = CFG.s_RechargeGemMall:Get( id )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.recharge, Enum.Role.riseRoad, Enum.Role.rechargeFirst })
    local recharge = roleInfo.recharge
    -- 是否额外赠送
    local denarNum = sRechargeGemMall.denarNum
    if sRechargeGemMall.rechargeProgress and sRechargeGemMall.rechargeProgress > 0 then
        roleInfo.riseRoad = roleInfo.riseRoad + sRechargeGemMall.rechargeProgress
    end
    if not recharge[_id] then
        recharge[_id] = { id = _id, count = 1 }
        denarNum = denarNum + sRechargeGemMall.firstPresenter
    else
        denarNum = denarNum + sRechargeGemMall.presenter
    end
    local rewardInfo
    if not roleInfo.rechargeFirst then
        local sRechargeFirst = CFG.s_RechargeFirst:Get(1001)
        rewardInfo = ItemLogic:getItemPackage( _rid, sRechargeFirst.itemPackage, nil, nil, nil, nil, nil, true, nil, nil, sPrice.l_nameID )
        roleInfo.rechargeFirst = true
        EmailLogic:sendEmail( _rid, sRechargeFirst.mailID, { rewards = rewardInfo, takeEnclosure = true })
    end

    RoleLogic:setRole( _rid, roleInfo )
    RoleSync:syncSelf( _rid, { [Enum.Role.recharge] = { _id = recharge[_id] },
                               [Enum.Role.riseRoad] = roleInfo.riseRoad,
                               [Enum.Role.rechargeFirst] = roleInfo.rechargeFirst,
                             }, true )
    RoleLogic:addDenar( _rid, denarNum, nil, Enum.LogType.RECHARGE_GAIN_DENAR )
    -- 新增发货邮件提醒
    EmailLogic:sendEmail( _rid, sRechargeGemMall.mail, { emailContents = { sRechargeGemMall.denarNum, denarNum - sRechargeGemMall.denarNum }} )
    Common.syncMsg( _rid, "Recharge_RechargeInfo", {
        denar = denarNum
    } )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.RECHARGE_ACTION, 1 )
    return Enum.WebError.SUCCESS
end

---@see 购买每日特惠
function RechargeLogic:buyDailySpecial( _rid, _id )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.dailyPackage, Enum.Role.riseRoad, Enum.Role.rechargeFirst })
    local dailyPackage = roleInfo.dailyPackage
    -- 是否已经购买过了
    if dailyPackage and table.exist(dailyPackage, _id ) then
        return Enum.WebError.TODAY_BUY
    end
    local sPrice = CFG.s_Price:Get( _id )
    local id = sPrice.rechargeTypeID
    local sRechargeDailySpecial = CFG.s_RechargeDailySpecial:Get( id )
    local index = 0
    -- 判断英雄是否觉醒
    for i = 1, table.size( sRechargeDailySpecial.heroLimit ) do
        if not HeroLogic:checkHeroWake( _rid, sRechargeDailySpecial.heroLimit[i] ) then
            index = i
            break
        end
    end
    -- 英雄全部觉醒，无法购买
    if index == 0 then
        return Enum.WebError.HERO_ALL_WAKE
    end
    if not dailyPackage then dailyPackage = {} end
    table.insert(dailyPackage, _id)
    if sRechargeDailySpecial.rechargeProgress and sRechargeDailySpecial.rechargeProgress > 0 then
        roleInfo.riseRoad = roleInfo.riseRoad + sRechargeDailySpecial.rechargeProgress
    end
    local rewardInfo = {}
    if not roleInfo.rechargeFirst then
        local sRechargeFirst = CFG.s_RechargeFirst:Get(1001)
        local reward = ItemLogic:getItemPackage( _rid, sRechargeFirst.itemPackage, nil, nil, nil, nil, nil, true, nil, nil, sPrice.l_nameID )
        roleInfo.rechargeFirst = true
        EmailLogic:sendEmail( _rid, sRechargeFirst.mailID, { rewards = reward, takeEnclosure = true })
    end

    RoleLogic:setRole( _rid, roleInfo )
    RoleSync:syncSelf( _rid, { [Enum.Role.dailyPackage] = roleInfo.dailyPackage, [Enum.Role.riseRoad] = roleInfo.riseRoad,
                                [Enum.Role.rechargeFirst] = roleInfo.rechargeFirst }, true )

    ItemLogic:mergeReward( rewardInfo, ItemLogic:getItemPackage( _rid, sRechargeDailySpecial.itemPackage[index], nil, nil, nil, nil, nil, true, nil, nil, sPrice.l_nameID ) )
    EmailLogic:sendEmail( _rid, sRechargeDailySpecial.mailID, { rewards = rewardInfo, takeEnclosure = true,
                                    emailContents = { _id }, subTitleContents = { _id }
                                    })
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.RECHARGE_ACTION, 1 )
    return Enum.WebError.SUCCESS
end

---@see 每日重置信息
function RechargeLogic:resetRecharge( _rid, _isLogin, _isWeek, _isMonth )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.rechargeSale, Enum.Role.supply } )
    local roleChangeInfo = {}
    local syncChangeInfo = {}
    roleChangeInfo.dailyPackage = {}
    roleChangeInfo.freeDaily = false
    syncChangeInfo.dailyPackage = {}
    syncChangeInfo.freeDaily = false
    local sRechargeSale
    local syncRechargeSale = {}
    -- 超值礼包处理
    for group, rechargeSaleInfo in pairs(roleInfo.rechargeSale) do
        local id = rechargeSaleInfo.ids[1]
        if id then
            id = CFG.s_Price:Get(id).rechargeTypeID
            sRechargeSale = CFG.s_RechargeSale:Get(id)
            if sRechargeSale.giftType == Enum.SaleType.TIME_OPEN then
                local dayInfo = string.split(sRechargeSale.data1,"|")
                local year = math.tointeger(dayInfo[1])
                local month = math.tointeger(dayInfo[2])
                local day = math.tointeger(dayInfo[3])
                local next_day = { year = year, month = month, day = day, hour = CFG.s_Config:Get("systemDayTime") or 0, min = 0, sec = 0 }
                local time = os.time(next_day)
                if os.time() < time or os.time() > time + sRechargeSale.data2 then
                    rechargeSaleInfo.ids = {}
                    syncRechargeSale[group] = rechargeSaleInfo
                end
            end
            if sRechargeSale.giftType == Enum.SaleType.ACTIVITY then
                local firstActivity = SM.ActivityMgr.req.getActivityInfo(sRechargeSale.data1)
                local secondActivity = SM.ActivityMgr.req.getActivityInfo(sRechargeSale.data2)
                if os.time() < firstActivity.startTime or os.time() > secondActivity.endTime then
                    rechargeSaleInfo.ids = {}
                    syncRechargeSale[group] = rechargeSaleInfo
                end
            end
            if sRechargeSale.giftType == Enum.SaleType.DAY_RESET then
                rechargeSaleInfo.ids = {}
                syncRechargeSale[group] = rechargeSaleInfo
            end
            if sRechargeSale.giftType == Enum.SaleType.WEEK_RESET and _isWeek then
                rechargeSaleInfo.ids = {}
                syncRechargeSale[group] = rechargeSaleInfo
            end
            if sRechargeSale.giftType == Enum.SaleType.MONTH_RESET and _isMonth then
                rechargeSaleInfo.ids = {}
                syncRechargeSale[group] = rechargeSaleInfo
            end
        end
    end
    if not table.empty(syncRechargeSale) then
        syncChangeInfo.rechargeSale = syncRechargeSale
    end
    roleChangeInfo.rechargeSale = roleInfo.rechargeSale
    -- 城市补给站处理
    local sRechargesupply
    for id, supplyInfo in pairs(roleInfo.supply) do
        local day = Timer.getDiffDays(os.time(), supplyInfo.awardTime)
        if supplyInfo.award then day = day - 1 end
        sRechargesupply = CFG.s_RechargeSupply:Get( CFG.s_Price:Get(id).rechargeTypeID )
        for _=1,day do
            local rewardInfo = ItemLogic:getItemPackage( _rid, sRechargesupply.itemPackage, nil, nil, nil, nil, nil, true )
            EmailLogic:sendEmail( _rid, sRechargesupply.mailID, { rewards = rewardInfo, takeEnclosure = true, emailContents = { sRechargesupply.l_nameID }, titleContents = { sRechargesupply.l_nameID } })
        end
        supplyInfo.awardTime = os.time()
        supplyInfo.award = false
        if supplyInfo.expiredTime < os.time() then
            roleInfo.supply[id] = nil
        end
    end
    roleChangeInfo.supply = roleInfo.supply
    syncRechargeSale.supply = roleInfo.supply

    RoleLogic:setRole( _rid, roleChangeInfo )
    if not _isLogin then
        RoleSync:syncSelf( _rid, syncChangeInfo, true )
    end
end

---@see 领取日特惠免费礼包
function RechargeLogic:getFreeDaily( _rid )
    RoleLogic:setRole( _rid, { [Enum.Role.freeDaily] = true } )
    RoleSync:syncSelf( _rid, { [Enum.Role.freeDaily] = true }, true )
    return { rewardInfo = ItemLogic:getItemPackage( _rid, CFG.s_Config:Get("rechargeDailyGift"), nil, nil, nil, nil, nil, true ) }
end

---@see 购买首充大礼包
function RechargeLogic:BuyFirstPackage( _rid, _id )
    local rechargeFirst = RoleLogic:getRole( _rid, Enum.Role.rechargeFirst )
    if rechargeFirst then
        return Enum.WebError.FIRST_HAVE_BUY
    end
    local sPrice = CFG.s_Price:Get( _id )
    local id = sPrice.rechargeTypeID
    local sRechargeFirst = CFG.s_RechargeFirst:Get(id)
    local sVip = CFG.s_Vip:Get()
    local level
    for _, info in pairs(sVip) do
        if sRechargeFirst.vipSpecialBox == info.ID then
            level = info.level
            break
        end
    end
    local rewardInfo = RoleLogic:buyVipSpecialBox( _rid, level ).rewardInfo
    ItemLogic:mergeReward( rewardInfo, ItemLogic:getItemPackage( _rid, sRechargeFirst.itemPackage, nil, nil, nil, nil, nil, true, nil, nil, sPrice.l_nameID ) )
    EmailLogic:sendEmail( _rid, sRechargeFirst.mailID, { rewards = rewardInfo, takeEnclosure = true })
    RoleLogic:setRole( _rid, { [Enum.Role.rechargeFirst] = true } )
    RoleSync:syncSelf( _rid, { [Enum.Role.rechargeFirst] = true }, true )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.RECHARGE_ACTION, 1 )
    return Enum.WebError.SUCCESS
end

---@see 崛起之路领取
function RechargeLogic:awardRisePackage( _rid, _id )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.riseRoad, Enum.Role.riseRoadPackage })
    local sRechargeFirst = CFG.s_RechargeFirst:Get(_id)
    -- 判断前置是否购买
    if sRechargeFirst.frontID > 0 and not  table.exist( roleInfo.riseRoadPackage, sRechargeFirst.frontID )  then
        LOG_ERROR("rid(%d) awardRisePackage, frontID no award ", _rid)
        return nil, ErrorCode.RECHARGE_RISE_FRONT_NOT_AWARD
    end
    -- 判断是否达到领取条件
    if roleInfo.riseRoad < sRechargeFirst.needDenar then
        LOG_ERROR("rid(%d) awardRisePackage, denar not enough ", _rid)
        return nil, ErrorCode.RECHARGE_RISE_CAN_NOT_AWARD
    end
    -- 判断是否重复购买
    if roleInfo.riseRoadPackage and table.exist( roleInfo.riseRoadPackage, _id ) then
        LOG_ERROR("rid(%d) awardRisePackage, this id award ", _rid)
        return nil, ErrorCode.RECHARGE_RISE_AWARD
    end
    ItemLogic:getItemPackage( _rid, sRechargeFirst.itemPackage, nil, nil, nil, nil, nil, true )
    table.insert(roleInfo.riseRoadPackage, _id)
    RoleLogic:setRole( _rid, { [Enum.Role.riseRoadPackage] = roleInfo.riseRoadPackage } )
    RoleSync:syncSelf( _rid, { [Enum.Role.riseRoadPackage] = roleInfo.riseRoadPackage }, true )
end

---@see 超值礼包
function RechargeLogic:buySalePackage( _rid, _id )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.riseRoad, Enum.Role.rechargeSale, Enum.Role.rechargeFirst })
    local sPrice = CFG.s_Price:Get( _id )
    local id = sPrice.rechargeTypeID
    local sRechargeSale = CFG.s_RechargeSale:Get(id)
    local group = sRechargeSale.group
    --@TODO 判断购买时间
    if sRechargeSale.giftType == Enum.SaleType.TIME_OPEN then
        local dayInfo = string.split(sRechargeSale.data1,"|")
        local year = math.tointeger(dayInfo[1])
        local month = math.tointeger(dayInfo[2])
        local day = math.tointeger(dayInfo[3])
        local next_day = { year = year, month = month, day = day, hour = CFG.s_Config:Get("systemDayTime") or 0, min = 0, sec = 0 }
        local time = os.time(next_day)
        if os.time() < time or os.time() > time + sRechargeSale.data2 then
            return Enum.WebError.TIME_OUT
        end
    elseif sRechargeSale.giftType == Enum.SaleType.ACTIVITY then
        local firstActivity = SM.ActivityMgr.req.getActivityInfo(sRechargeSale.data1)
        local secondActivity = SM.ActivityMgr.req.getActivityInfo(sRechargeSale.data2)
        if os.time() < firstActivity.startTime or os.time() > secondActivity.endTime then
            return Enum.WebError.ACTIVITY_NOT_OPEN
        end
    end
    -- 判断前置是否购买
    local rechargeSale = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.RECHARGE_SALE)[group]
    local gears = sRechargeSale.gears
    if rechargeSale[gears - 1] and ( not roleInfo.rechargeSale or not roleInfo.rechargeSale[group]
        or not table.exist( roleInfo.rechargeSale[group].ids, rechargeSale[gears - 1].price ) ) then
        return Enum.WebError.PRE_NOT_BUY
    end
    -- 判断是否重复购买
    if roleInfo.rechargeSale and roleInfo.rechargeSale[group] and table.exist( roleInfo.rechargeSale[group].ids, _id ) then
        return Enum.WebError.BUY_ONE_MORE
    end
    local rewardInfo = ItemLogic:getItemPackage( _rid, sRechargeSale.itemPackage, nil, nil, nil, nil, nil, true, nil, nil, sPrice.l_nameID )
    EmailLogic:sendEmail( _rid, sRechargeSale.mailID, { rewards = rewardInfo, takeEnclosure = true,
                                                    emailContents = { _id }, subTitleContents = { _id }
                                                    })
    if not roleInfo.rechargeSale[group] then roleInfo.rechargeSale[group] = { ids = {}, group = group } end
    table.insert(roleInfo.rechargeSale[group].ids, _id)
    roleInfo.rechargeSale[group].buyTime = os.time()
    if sRechargeSale.rechargeProgress and sRechargeSale.rechargeProgress > 0 then
        roleInfo.riseRoad = roleInfo.riseRoad + sRechargeSale.rechargeProgress
    end
    if not roleInfo.rechargeFirst then
        local sRechargeFirst = CFG.s_RechargeFirst:Get(1001)
        rewardInfo = ItemLogic:getItemPackage( _rid, sRechargeFirst.itemPackage, nil, nil, nil, nil, nil, true, nil, nil, sPrice.l_nameID )
        roleInfo.rechargeFirst = true
        EmailLogic:sendEmail( _rid, sRechargeFirst.mailID, { rewards = rewardInfo, takeEnclosure = true })
    end
    RoleLogic:setRole( _rid, { [Enum.Role.rechargeSale] = roleInfo.rechargeSale, [Enum.Role.riseRoad] = roleInfo.riseRoad, [Enum.Role.rechargeFirst] = roleInfo.rechargeFirst } )
    RoleSync:syncSelf( _rid, { [Enum.Role.rechargeSale] = roleInfo.rechargeSale, [Enum.Role.riseRoad] = roleInfo.riseRoad, [Enum.Role.rechargeFirst] = roleInfo.rechargeFirst }, true )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.RECHARGE_ACTION, 1 )
    return Enum.WebError.SUCCESS
end

---@see 购买成长基金
function RechargeLogic:buyGrowthFund( _rid )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.vip, Enum.Role.growthFund, Enum.Role.rechargeFirst })
    local vipLv = RoleLogic:getVipLv( roleInfo.vip )
    if vipLv < CFG.s_Config:Get("rechargeFundVipLimit") then
        return Enum.WebError.GROWN_VIP_NOT_ENOUGH
    end
    -- 已经购买过了
    if roleInfo.growthFund then
        return Enum.WebError.GROWN_HAVE_BUY
    end
    if not roleInfo.rechargeFirst then
        local sRechargeFirst = CFG.s_RechargeFirst:Get(1001)
        local rewardInfo = ItemLogic:getItemPackage( _rid, sRechargeFirst.itemPackage, nil, nil, nil, nil, nil, true )
        roleInfo.rechargeFirst = true
        EmailLogic:sendEmail( _rid, sRechargeFirst.mailID, { rewards = rewardInfo, takeEnclosure = true })
    end
    RoleLogic:setRole( _rid, { [Enum.Role.growthFund] = true, [Enum.Role.rechargeFirst] = roleInfo.rechargeFirst } )
    RoleSync:syncSelf( _rid, { [Enum.Role.growthFund] = true, [Enum.Role.rechargeFirst] = roleInfo.rechargeFirst }, true )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.RECHARGE_ACTION, 1 )
    return Enum.WebError.SUCCESS
end

---@see 领取成长基金
function RechargeLogic:getGrowthFundReward( _rid, _id )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.growthFundReward })
    table.insert(roleInfo.growthFundReward, _id )
    local sRechargeFund = CFG.s_RechargeFund:Get( _id )
    RoleLogic:setRole( _rid, { [Enum.Role.growthFundReward] = roleInfo.growthFundReward } )
    RoleSync:syncSelf( _rid, { [Enum.Role.growthFundReward] = roleInfo.growthFundReward }, true )
    RoleLogic:addDenar( _rid, sRechargeFund.gem, nil, Enum.LogType.FUND_GAIN_DENAR )
    return { denar = sRechargeFund.gem }
end

---@see 购买城市补给站
function RechargeLogic:buyRechargeSupply( _rid, _id )
    local sPrice = CFG.s_Price:Get( _id )
    local id = sPrice.rechargeTypeID
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.supply, Enum.Role.riseRoad, Enum.Role.rechargeFirst })
    local supply = roleInfo.supply
    local sRechargeSupply = CFG.s_RechargeSupply:Get( id )
    if not supply[_id] or supply[_id].expiredTime < os.time() then
        local time = Timer.GetDayX( sRechargeSupply.continueDays ) - 1
        supply[_id] = { id = _id, expiredTime = time, awardTime = os.time() }
    else
        supply[_id].expiredTime = supply[_id].expiredTime + sRechargeSupply.continueDays * 3600 * 24
    end
    if sRechargeSupply.rechargeProgress and sRechargeSupply.rechargeProgress > 0 then
        roleInfo.riseRoad = roleInfo.riseRoad + sRechargeSupply.rechargeProgress
    end
    if not roleInfo.rechargeFirst then
        local sRechargeFirst = CFG.s_RechargeFirst:Get(1001)
        local rewardInfo = ItemLogic:getItemPackage( _rid, sRechargeFirst.itemPackage, nil, nil, nil, nil, nil, true, nil, nil, sPrice.l_nameID )
        EmailLogic:sendEmail( _rid, sRechargeFirst.mailID, { rewards = rewardInfo, takeEnclosure = true })
        roleInfo.rechargeFirst = true
    end
    RoleLogic:addDenar( _rid, sRechargeSupply.giveGem, nil, Enum.LogType.SUPPLY_GAIN_DENAR )
    RoleLogic:setRole( _rid, { [Enum.Role.supply] = supply, [Enum.Role.riseRoad] = roleInfo.riseRoad, [Enum.Role.rechargeFirst] = roleInfo.rechargeFirst  } )
    RoleSync:syncSelf( _rid, { [Enum.Role.supply] = { [_id] = supply[_id] }, [Enum.Role.riseRoad] = roleInfo.riseRoad, [Enum.Role.rechargeFirst] = roleInfo.rechargeFirst }, true )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.RECHARGE_ACTION, 1 )
    return Enum.WebError.SUCCESS
end

---@see 领取城市补给站
function RechargeLogic:awardRechargeSupply( _rid, _id )
    local sPrice = CFG.s_Price:Get( _id )
    local id = sPrice.rechargeTypeID
    local supply = RoleLogic:getRole( _rid, Enum.Role.supply )
    local sRechargeSupply = CFG.s_RechargeSupply:Get( id )
    supply[_id].award = true
    supply[_id].awardTime = os.time()
    RoleLogic:setRole( _rid, { [Enum.Role.supply] = supply } )
    RoleSync:syncSelf( _rid, { [Enum.Role.supply] = { [_id] = supply[_id] } }, true )
    return { id = _id, rewardInfo = ItemLogic:getItemPackage( _rid, sRechargeSupply.itemPackage, nil, nil, nil, nil, nil, true, nil, nil, sPrice.l_nameID ) }
end

---@see 购买限时礼包
function RechargeLogic:buyLimitPackAge( _rid, _index, _id )
    local limitTimePackage = RoleLogic:getRole( _rid , Enum.Role.limitTimePackage )
    local synChangeInfo = {}
    if not _index then
        return Enum.WebError.ARG_TYPE_ERROR
    end
    _index = tonumber( _index )
    if not limitTimePackage[_index] or (limitTimePackage[_index] and _id == limitTimePackage[_index].id) then
        local sPrice = CFG.s_Price:Get( _id )
        local id = sPrice.rechargeTypeID
        local sRechargeLimitTimeBag = CFG.s_RechargeLimitTimeBag:Get( id )
        if limitTimePackage[_index] then
            limitTimePackage[_index] = nil
            synChangeInfo[_index] = { index = _index, id = -1 }
        end
        MSM.RoleTimer[_rid].req.deleteLimitPackageTimer( _rid, _index )
        local rewardInfo = ItemLogic:getItemPackage( _rid, sRechargeLimitTimeBag.itemPackage, nil, nil, nil, nil, nil, true, nil, nil, sPrice.l_nameID )
        EmailLogic:sendEmail( _rid, sRechargeLimitTimeBag.mailID, { rewards = rewardInfo, takeEnclosure = true,
                                emailContents = { _id },
                                subTitleContents = { _id },
                                })
        if table.size(limitTimePackage) >= 10 then
            for index, packageInfo in pairs( limitTimePackage ) do
                if packageInfo.expiredTime == -1 then
                    id = CFG.s_Price:Get(packageInfo.id).rechargeTypeID
                    sRechargeLimitTimeBag = CFG.s_RechargeLimitTimeBag:Get( id )
                    packageInfo.expiredTime = os.time() + sRechargeLimitTimeBag.time
                    MSM.RoleTimer[_rid].req.addLimitPackageTimer( _rid, index, packageInfo.expiredTime )
                    synChangeInfo[index] = packageInfo
                    break
                end
            end
        end
        local roleInfo = RoleLogic:getRole( _rid, {  Enum.Role.rechargeFirst })
        if not roleInfo.rechargeFirst then
            local sRechargeFirst = CFG.s_RechargeFirst:Get(1001)
            rewardInfo = ItemLogic:getItemPackage( _rid, sRechargeFirst.itemPackage, nil, nil, nil, nil, nil, true, nil, nil, sPrice.l_nameID )
            roleInfo.rechargeFirst = true
            EmailLogic:sendEmail( _rid, sRechargeFirst.mailID, { rewards = rewardInfo, takeEnclosure = true })
        end
        RoleLogic:setRole( _rid, { [Enum.Role.limitTimePackage] = limitTimePackage, [Enum.Role.rechargeFirst] = roleInfo.rechargeFirst } )
        RoleSync:syncSelf( _rid, { [Enum.Role.limitTimePackage] = synChangeInfo, [Enum.Role.rechargeFirst] = roleInfo.rechargeFirst }, true )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.RECHARGE_ACTION, 1 )
        return Enum.WebError.SUCCESS
    end
    return Enum.WebError.PACKAGE_NO_EXIST
end

---@see 检测是否有待激活的礼包
function RechargeLogic:checkLimitPackage( _rid, _index )
    local limitTimePackage = RoleLogic:getRole( _rid , Enum.Role.limitTimePackage )
    limitTimePackage[_index] = nil
    local synChangeInfo = {}
    synChangeInfo[_index] = { index = _index, id = -1 }
    if table.size(limitTimePackage) >= 10 then
        for index, packageInfo in pairs( limitTimePackage ) do
            if packageInfo.expiredTime == -1 then
                local id = CFG.s_Price:Get(packageInfo.id).rechargeTypeID
                local sRechargeLimitTimeBag = CFG.s_RechargeLimitTimeBag:Get( id )
                packageInfo.expiredTime = os.time() + sRechargeLimitTimeBag.time
                MSM.RoleTimer[_rid].req.addLimitPackageTimer( _rid, index, packageInfo.expiredTime )
                synChangeInfo[index] = packageInfo
                break
            end
        end
    end
    RoleLogic:setRole( _rid, { [Enum.Role.limitTimePackage] = limitTimePackage } )
    RoleSync:syncSelf( _rid, { [Enum.Role.limitTimePackage] = synChangeInfo }, true )
end

---@see 登录增加限时礼包定时器
function RechargeLogic:limitPackageLogin( _rid )
    local limitTimePackage = RoleLogic:getRole( _rid , Enum.Role.limitTimePackage )
    for index, packageInfo in pairs( limitTimePackage ) do
        if packageInfo.expiredTime > -1 then
            MSM.RoleTimer[_rid].req.addLimitPackageTimer( _rid, index, packageInfo.expiredTime )
        end
    end
end

---@see 触发限时礼包
function RechargeLogic:triggerLimitPackage( _rid, _args )
    local sRechargeLimitTimeBag = CFG.s_RechargeLimitTimeBag:Get()
    local roleInfo = RoleLogic:getRole( _rid , { Enum.Role.limitTimePackage, Enum.Role.newLimitPackageCount } )
    local limitTimePackage = roleInfo.limitTimePackage
    local newLimitPackageCount = roleInfo.newLimitPackageCount
    local townHall = BuildingLogic:getBuildingInfoByType( _rid, Enum.BuildingType.TOWNHALL )[1]
    local newIndex = self:getFreeIndex( _rid )
    local synChangeInfo = {}
    local offLine = Common.offOnline( _rid )
    if _args.type == Enum.LimitTimeType.TOWNHALL then
        for _, v in pairs(sRechargeLimitTimeBag) do
            if v.type == _args.type and v.data1 == _args.level and
                ( v.limitLvMin == -1 or (townHall.level >= v.limitLvMin and townHall.level <= v.limitLvMax) ) then
                if v.limitTime == -1 or not newLimitPackageCount[v.price] or v.limitTime < newLimitPackageCount[v.price].count then
                    limitTimePackage[newIndex] = { index = newIndex, id = v.price, expiredTime = -1 }
                    if table.size(limitTimePackage) <= 10 and not offLine then
                        limitTimePackage[newIndex].expiredTime = os.time() + v.time
                        MSM.RoleTimer[_rid].req.addLimitPackageTimer( _rid, newIndex, limitTimePackage[newIndex].expiredTime )
                    end
                    synChangeInfo[newIndex] = limitTimePackage[newIndex]
                    if not newLimitPackageCount[v.price] then newLimitPackageCount[v.price] = { id = v.price, count = 0 } end
                    newLimitPackageCount[v.price].count = newLimitPackageCount[v.price].count + 1
                end
            end
        end
    elseif _args.type == Enum.LimitTimeType.NEW_HERO then
        for _, v in pairs(sRechargeLimitTimeBag) do
            if v.type == _args.type and v.data1 == _args.rare and
                ( v.limitLvMin == -1 or (townHall.level >= v.limitLvMin and townHall.level <= v.limitLvMax) ) then
                if v.limitTime == -1 or not newLimitPackageCount[v.price] or v.limitTime < newLimitPackageCount[v.price].count then
                    limitTimePackage[newIndex] = { index = newIndex, id = v.price, expiredTime = -1 }
                    if table.size(limitTimePackage) <= 10 and not offLine then
                        limitTimePackage[newIndex].expiredTime = os.time() + v.time
                        MSM.RoleTimer[_rid].req.addLimitPackageTimer( _rid, newIndex, limitTimePackage[newIndex].expiredTime )
                    end
                    synChangeInfo[newIndex] = limitTimePackage[newIndex]
                    if not newLimitPackageCount[v.price] then newLimitPackageCount[v.price] = { id = v.price, count = 0 } end
                    newLimitPackageCount[v.price].count = newLimitPackageCount[v.price].count + 1
                end
            end
        end
    elseif _args.type == Enum.LimitTimeType.HERO_LEVEL_UP then
        for _, v in pairs(sRechargeLimitTimeBag) do
            if v.type == _args.type and v.data1 == _args.rare and v.data2 == _args.level and
                ( v.limitLvMin == -1 or (townHall.level >= v.limitLvMin and townHall.level <= v.limitLvMax) ) then
                if v.limitTime == -1 or not newLimitPackageCount[v.price] or v.limitTime < newLimitPackageCount[v.price].count then
                    limitTimePackage[newIndex] = { index = newIndex, id = v.price, expiredTime = -1 }
                    if table.size(limitTimePackage) <= 10 and not offLine then
                        limitTimePackage[newIndex].expiredTime = os.time() + v.time
                        MSM.RoleTimer[_rid].req.addLimitPackageTimer( _rid, newIndex, limitTimePackage[newIndex].expiredTime )
                    end
                    synChangeInfo[newIndex] = limitTimePackage[newIndex]
                    if not newLimitPackageCount[v.price] then newLimitPackageCount[v.price] = { id = v.price, count = 0 } end
                    newLimitPackageCount[v.price].count = newLimitPackageCount[v.price].count + 1
                end
            end
        end
    elseif _args.type == Enum.LimitTimeType.AGE_CHANGE then
        for _, v in pairs(sRechargeLimitTimeBag) do
            if v.type == _args.type and v.data1 == _args.age and
                ( v.limitLvMin == -1 or (townHall.level >= v.limitLvMin and townHall.level <= v.limitLvMax) ) then
                if v.limitTime == -1 or not newLimitPackageCount[v.price] or v.limitTime < newLimitPackageCount[v.price].count then
                    limitTimePackage[newIndex] = { index = newIndex, id = v.price, expiredTime = -1 }
                    if table.size(limitTimePackage) <= 10 and not offLine then
                        limitTimePackage[newIndex].expiredTime = os.time() + v.time
                        MSM.RoleTimer[_rid].req.addLimitPackageTimer( _rid, newIndex, limitTimePackage[newIndex].expiredTime )
                    end
                    synChangeInfo[newIndex] = limitTimePackage[newIndex]
                    if not newLimitPackageCount[v.price] then newLimitPackageCount[v.price] = { id = v.price, count = 0 } end
                    newLimitPackageCount[v.price].count = newLimitPackageCount[v.price].count + 1
                end
            end
        end
    elseif _args.type == Enum.LimitTimeType.TECH_UNLOCK then
        for _, v in pairs(sRechargeLimitTimeBag) do
            if v.type == _args.type and v.data1 == _args.id and
                ( v.limitLvMin == -1 or (townHall.level >= v.limitLvMin and townHall.level <= v.limitLvMax) ) then
                if v.limitTime == -1 or not newLimitPackageCount[v.price] or v.limitTime < newLimitPackageCount[v.price].count then
                    limitTimePackage[newIndex] = { index = newIndex, id = v.price, expiredTime = -1 }
                    if table.size(limitTimePackage) <= 10 and not offLine then
                        limitTimePackage[newIndex].expiredTime = os.time() + v.time
                        MSM.RoleTimer[_rid].req.addLimitPackageTimer( _rid, newIndex, limitTimePackage[newIndex].expiredTime )
                    end
                    synChangeInfo[newIndex] = limitTimePackage[newIndex]
                    if not newLimitPackageCount[v.price] then newLimitPackageCount[v.price] = { id = v.price, count = 0 } end
                    newLimitPackageCount[v.price].count = newLimitPackageCount[v.price].count + 1
                end
            end
        end
    elseif _args.type == Enum.LimitTimeType.POWER_LOST then
        for _, v in pairs(sRechargeLimitTimeBag) do
            if v.type == _args.type and v.data1 <= _args.power and
                ( v.limitLvMin == -1 or (townHall.level >= v.limitLvMin and townHall.level <= v.limitLvMax) ) then
                if v.limitTime == -1 or not newLimitPackageCount[v.price] or v.limitTime < newLimitPackageCount[v.price].count then
                    limitTimePackage[newIndex] = { index = newIndex, id = v.price, expiredTime = -1 }
                    if table.size(limitTimePackage) <= 10 and not offLine then
                        limitTimePackage[newIndex].expiredTime = os.time() + v.time
                        MSM.RoleTimer[_rid].req.addLimitPackageTimer( _rid, newIndex, limitTimePackage[newIndex].expiredTime )
                    end
                    RoleLogic:setRole( _rid, { [Enum.Role.battleLostPower] = 0 } )
                    synChangeInfo[newIndex] = limitTimePackage[newIndex]
                    if not newLimitPackageCount[v.price] then newLimitPackageCount[v.price] = { id = v.price, count = 0 } end
                    newLimitPackageCount[v.price].count = newLimitPackageCount[v.price].count + 1
                end
            end
        end
    end
    RoleLogic:setRole( _rid, { [Enum.Role.limitTimePackage] = limitTimePackage, [Enum.Role.newLimitPackageCount] = newLimitPackageCount } )
    RoleSync:syncSelf( _rid, { [Enum.Role.limitTimePackage] = synChangeInfo }, true )
end

---@see 获取空索引
function RechargeLogic:getFreeIndex( _rid )
    local limitTimePackage = RoleLogic:getRole( _rid, Enum.Role.limitTimePackage )
    local newIndex = 0
    for index in pairs(limitTimePackage) do
        if index > newIndex then
            newIndex = index
        end
    end
    return newIndex + 1
end

---@see 登录处理
function RechargeLogic:onRolelogin( _rid )
    local limitTimePackage = RoleLogic:getRole( _rid , Enum.Role.limitTimePackage )
    local count = 0
    for index, packageInfo in pairs( limitTimePackage ) do
        if not packageInfo.expiredTime or ( packageInfo.expiredTime <= os.time() and packageInfo.expiredTime > -1 )then
            limitTimePackage[index] = nil
        elseif packageInfo.expiredTime > os.time() then
            MSM.RoleTimer[_rid].req.addLimitPackageTimer( _rid, packageInfo.index, packageInfo.expiredTime )
            count = count + 1
        end
    end
    local sRechargeLimitTimeBag
    if table.size(limitTimePackage) <= 10 then
        for _, packageInfo in pairs( limitTimePackage ) do
            if packageInfo.expiredTime == -1 then
                local id = CFG.s_Price:Get(packageInfo.id).rechargeTypeID
                sRechargeLimitTimeBag = CFG.s_RechargeLimitTimeBag:Get(id)
                packageInfo.expiredTime = os.time() + sRechargeLimitTimeBag.time
                MSM.RoleTimer[_rid].req.addLimitPackageTimer( _rid, packageInfo.index, packageInfo.expiredTime )
            end
        end
    else
        for _, packageInfo in pairs( limitTimePackage ) do
            if packageInfo.expiredTime == -1 and count < 10 then
                local id = CFG.s_Price:Get(packageInfo.id).rechargeTypeID
                sRechargeLimitTimeBag = CFG.s_RechargeLimitTimeBag:Get(id)
                packageInfo.expiredTime = os.time() + sRechargeLimitTimeBag.time
                MSM.RoleTimer[_rid].req.addLimitPackageTimer( _rid, packageInfo.index, packageInfo.expiredTime )
                count = count + 1
            end
        end
    end
    RoleLogic:setRole( _rid, { [Enum.Role.limitTimePackage] = limitTimePackage } )

end

function RechargeLogic:recharge( _rid, _id, _index )
    local price = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.PRICE )[_id]
    local id = _id
    _id = price.ID
    local type = price.rechargeType
    if type == Enum.RechargeType.DENAR then
        return RechargeLogic:buyDenar( _rid, _id )
    elseif type == Enum.RechargeType.DAILY_SALE then
        return RechargeLogic:buyDailySpecial( _rid, _id )
    elseif type == Enum.RechargeType.GROWN then
        return RechargeLogic:buyGrowthFund( _rid )
    elseif type == Enum.RechargeType.FIRST then
        return RechargeLogic:BuyFirstPackage( _rid, _id )
    elseif type == Enum.RechargeType.CITY then
        return RechargeLogic:buyRechargeSupply( _rid, _id )
    elseif type == Enum.RechargeType.SALE then
        price = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.SALEPRICE )[id]

        if table.size( price ) > 1 then
            local rechargeSale = RoleLogic:getRole( _rid, Enum.Role.rechargeSale )
            local sRechargeSale = CFG.s_RechargeSale:Get(CFG.s_Price:Get( _id ).rechargeTypeID)
            local group = sRechargeSale.group
            local rechargeSaleCFG = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.RECHARGE_SALE)[group]

            -- sortRechargeTypeID 礼包需要按照降序排列 这样才能先买到未购买的礼包
            local sortRechargeTypeID = {}
            for rechargeTypeID in pairs( price ) do
                table.insert(sortRechargeTypeID, rechargeTypeID)
            end
            table.sort(sortRechargeTypeID, function(a, b)
                return a > b
            end)

            for _, rechargeTypeID in pairs( sortRechargeTypeID ) do
                local rechargeInfo = price[rechargeTypeID]
                sRechargeSale = CFG.s_RechargeSale:Get(rechargeTypeID)
                local gears = sRechargeSale.gears
                if not rechargeSaleCFG[gears - 1] or ( rechargeSale and rechargeSale[group] and
                    table.exist( rechargeSale[group].ids, rechargeSaleCFG[gears - 1].price )) then
                    _id = rechargeInfo.ID
                    break
                end
            end
        end
        return RechargeLogic:buySalePackage( _rid, _id )
    elseif type == Enum.RechargeType.LIMIT then
        return RechargeLogic:buyLimitPackAge( _rid, _index, _id )
    elseif type == Enum.RechargeType.VIP then
        local level
        for _, vipInfo in pairs(CFG.s_Vip:Get()) do
            if vipInfo.ID == price.rechargeTypeID then
                level = vipInfo.level
            end
        end
        if level and level >= 0 then
            return RoleLogic:buyVipSpecialBox( _rid, level )
        end
    end
end

return RechargeLogic