--[[
* @file : RechargeMgr.lua
* @type : multi snax service
* @author : chenlei
* @created : Fri May 22 2020 09:25:32 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色充值服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local queue = require "skynet.queue"
local RoleLogic = require "RoleLogic"
local cjson = require "cjson.safe"
local LogLogic = require "LogLogic"

local roleLock = {} -- { role = { lock = function } }

---@see 角色逻辑互斥锁
local function checkRoleLock( _rid )
    if not roleLock[_rid] then
        roleLock[_rid] = { lock = queue() }
    end
end


---@see 角色充值
function response.recharge( _data )
    -- 检查互斥锁
    checkRoleLock( _data.rid )

    return roleLock[_data.rid].lock(
        function ()
            local rid = _data.rid
            local pc_id = _data.pc_id
            local sn = _data.sn
            local iggid = _data.iggid
            local index = _data.index

            LOG_INFO("_data:%s", tostring(_data))

            local RechargeLogic = require "RechargeLogic"
            -- 判断订单号是否存在
            if RechargeLogic:checkSn( sn ) then
                return cjson.encode( { code = Enum.WebError.RECHARGE_SN_EXIST } )
            end

            -- 判断角色是否存在
            if not RoleLogic:getRole( rid, Enum.Role.rid ) then
                LOG_INFO("rid(%d) recharge not found roleinfo", rid )
                return cjson.encode( { code = Enum.WebError.RECHARGE_RID_ERROR } )
            end

            -- 判断角色是否存在
            if type(iggid) == "number" then
                iggid = tostring(iggid)
            end

            if iggid ~= RoleLogic:getRole( rid, Enum.Role.iggid ) then
                LOG_INFO("iggid(%s) recharge self iggid(%s)", iggid, RoleLogic:getRole( rid, Enum.Role.iggid ) )
                return cjson.encode( { code = Enum.WebError.RECHARGE_RID_ERROR } )
            end

            local ret, code
            RechargeLogic:addSnInfo( sn, rid, pc_id, iggid )
            ret, code = pcall( RechargeLogic.recharge, RechargeLogic, rid, pc_id, index )
            if ret and code == Enum.WebError.SUCCESS then
                local data = {}
                local price = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.PRICE )[pc_id]
                local roleInfo = RoleLogic:getRole( rid, { Enum.Role.rechargeDollar, Enum.Role.iggid })
                local rechargeDollar = roleInfo.rechargeDollar or 0
                rechargeDollar = math.modf( rechargeDollar + 100 * price.price )
                RoleLogic:setRole( rid, Enum.Role.rechargeDollar, rechargeDollar )
                if price.rechargeType == Enum.RechargeType.SALE then
                    local newPrice = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.SALEPRICE )[pc_id]
                    if table.size(newPrice) > 1 then
                        local rechargeSale = RoleLogic:getRole( rid, Enum.Role.rechargeSale )
                        local sRechargeSale = CFG.s_RechargeSale:Get(CFG.s_Price:Get( price.ID ).rechargeTypeID)
                        local group = sRechargeSale.group
                        local rechargeSaleCFG = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.RECHARGE_SALE )[group]

                        -- sortRechargeTypeID 礼包需要按照降序排列 这样才能先买到未购买的礼包
                        local sortRechargeTypeID = {}
                        for rechargeTypeID in pairs( newPrice ) do
                            table.insert(sortRechargeTypeID, rechargeTypeID)
                        end
                        table.sort(sortRechargeTypeID, function(a, b)
                            return a > b
                        end)
                        for _, rechargeTypeID in pairs( sortRechargeTypeID ) do
                            local rechargeInfo = newPrice[rechargeTypeID]
                            sRechargeSale = CFG.s_RechargeSale:Get(rechargeTypeID)
                            local gears = sRechargeSale.gears
                            if not rechargeSaleCFG[gears - 1] or ( rechargeSale and rechargeSale[group] and
                                table.exist( rechargeSale[group].ids, rechargeSaleCFG[gears - 1].price )) then
                                price = rechargeInfo
                                break
                            end
                        end
                    end
                end
                LogLogic:roleRecharge( { rid = rid, price = price.price, id = price.ID, iggid = roleInfo.iggid } )
                local cn = CFG.s_LanguageServer:Get(price.l_nameID, "cn")
                data.packageName = cn
                return cjson.encode( { code = Enum.WebError.SUCCESS, data = data } )
            else
                if ret then
                    LOG_INFO("rid(%d) recharge , pc_id(%d) code(%d)", rid, pc_id, code or Enum.WebError.FAILED )
                end
                return cjson.encode( { code = code or Enum.WebError.FAILED } )
            end
        end
    )
end