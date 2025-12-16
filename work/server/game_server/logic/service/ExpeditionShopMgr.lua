--[[
* @file : ExpeditionShopMgr.lua
* @type : snax single service
* @author : chenlei
* @created : Wed May 13 2020 19:22:08 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 远征商店服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local Timer = require "Timer"
local expeditionShop
local refreshFlag
local pkId


---@see 刷新每周地煞阵法
local function refresh()
    if pkId then
        local shopInfo = SM.c_expeditionShop.req.Get(1)
        local s_ExpeditionHead = CFG.s_ExpeditionHead:Get( shopInfo.id + 1 )
        if not s_ExpeditionHead then
            return 1
        else
            return shopInfo.id + 1
        end
    else
        return 1
    end
end

local function refreshShopImpl()
    expeditionShop.id = refresh()

    -- 计算到下一个刷新点的时间
    expeditionShop.nextRefreshTime = Timer.GetDayX( CFG.s_Config:Get("heroHead1RefreshDay"))
    -- 保存数据
    if pkId then
        SM.c_expeditionShop.req.Set( 1, expeditionShop )
    else
        SM.c_expeditionShop.req.Add( 1, expeditionShop )
    end
    Timer.runAt( expeditionShop.nextRefreshTime, refreshShopImpl )
end

---@see 刷新每周元辰特性
local function refreshShop()
    local s_ExpeditionHead = CFG.s_ExpeditionHead:Get( )
    if table.empty( s_ExpeditionHead ) or table.size( s_ExpeditionHead ) == 0 then
        return
    end
    refreshFlag = false
    expeditionShop = SM.c_expeditionShop.req.Get(1)
    if expeditionShop then
        pkId = 1
    else
        expeditionShop = { nextRefreshTime = 0, id = 1 }
    end
    local now = os.time( )
    if expeditionShop.nextRefreshTime <= now then
        -- 刷新
        refreshShopImpl( )
    else
        Timer.runAt( expeditionShop.nextRefreshTime, refreshShopImpl )
    end
    refreshFlag = true
end

---@see 获取本周限时英雄id
function response.getHeroId()
    if refreshFlag then
        return expeditionShop.id
    end
end

---@see 获取本周限时英雄id以及刷新时间
function response.getHeroInfo()
    if refreshFlag then
        return { id =  expeditionShop.id, nextRefreshTime = expeditionShop.nextRefreshTime }
    end
end


function response.Init()
    refreshShop( )
end

