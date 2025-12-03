--[[
 * @file : MapProvinceLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-02-27 13:20:08
 * @Last Modified time: 2020-02-27 13:20:08
 * @department : Arabic Studio
 * @brief : 地图省份相关逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local MapProvinceLogic = {}

---@see 判断当前坐标处于哪个省份
function MapProvinceLogic:getPosInProvince( _pos )
    local pos = { x = math.floor( _pos.x / 100 ), y = math.floor( _pos.y / 100 ) }
    -- 计算出当前坐标所在区域块
    local mapZoneSFWidth = CFG.s_Config:Get("mapZoneSFWidth")
    local mapZoneSFSize = math.floor(7200 / mapZoneSFWidth)
    local x = math.ceil( pos.x / mapZoneSFWidth )
    local y = math.floor( pos.y / mapZoneSFWidth )
    local areaIndex = x + mapZoneSFSize * y
    -- 判断区域块处于哪个省份
    local sMapZoneSF = CFG.s_MapZoneSF:Get( areaIndex )
    if not sMapZoneSF then
        return 0
    end
    return sMapZoneSF.zoneOrder, sMapZoneSF
end

return MapProvinceLogic