--[[
* @file : Recharge.lua
* @type : snax multi service
* @author : chenlei
* @created : Sat May 09 2020 19:22:49 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 充值商城相关协议
* Copyright(C) 2017 IGG, All rights reserved
]]

local RechargeLogic = require "RechargeLogic"
local RoleLogic = require "RoleLogic"
local BuildingLogic = require "BuildingLogic"

---@see 领取成长基金奖励
function response.GetGrowthFundReward( msg )
    local rid = msg.rid
    local id = msg.id
    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.growthFundReward, Enum.Role.growthFund })
    local sRechargeFund = CFG.s_RechargeFund:Get( id )

    -- 是否买了成长基金
    if not roleInfo.growthFund then
        LOG_ERROR("rid(%d) GetGrowthFundReward, have not buy fund", rid)
        return nil, ErrorCode.RECHARGE_FUND_NOT_BUY
    end
    -- 领奖条件是否充足
    local townHall = BuildingLogic:getBuildingInfoByType( rid, Enum.BuildingType.TOWNHALL )[1]
    if townHall.level < sRechargeFund.needLv then
        LOG_ERROR("rid(%d) GetGrowthFundReward, condition not enough", rid)
        return nil, ErrorCode.RECHARGE_FUND_CONDITION_NOT_ENOUGH
    end
    if table.exist(roleInfo.growthFundReward, id) then
        LOG_ERROR("rid(%d) GetGrowthFundReward, have award ", rid)
        return nil, ErrorCode.RECHARGE_FUND_AWARDED
    end
    return RechargeLogic:getGrowthFundReward( rid, id )
end

---@see 领取崛起之路奖励
function response.AwardRisePackage( msg )
    local rid = msg.rid
    local id = msg.id
    return RechargeLogic:awardRisePackage( rid, id )
end


---@see 领取城市补给站奖励
function response.AwardRechargeSupply( msg )
    local rid = msg.rid
    local id = msg.id
    local supply = RoleLogic:getRole( rid, Enum.Role.supply )
    if not supply[id] or supply[id].expiredTime < os.time() then
        LOG_ERROR("rid(%d) BuyRechargeSupply, not buy", rid)
        return nil, ErrorCode.RECHARGE_SUPPLY_NOT_BUY
    end
    if supply[id] and supply[id].award then
        LOG_ERROR("rid(%d) BuyRechargeSupply, have award", rid)
        return nil, ErrorCode.RECHARGE_SUPPLY_AWARDED
    end
    return RechargeLogic:awardRechargeSupply( rid, id )
end