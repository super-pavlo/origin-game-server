--[[
* @file : ExpeditionAoiSpaceMgr.lua
* @type : snax single service
* @author : dingyuchao
* @created : Tue Nov 17 2020 17:28:55 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 远征 aoi space 管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local mapIndexs = {}

function response.Init()
    -- 生成空闲的mapIndex池
    local mapIndex
    for _ = 1, 100 do
        mapIndex = Common.newExpeditionMapIndex()
        MSM.AoiMgr[mapIndex].req.initMapAoi( mapIndex, mapIndex, 720000 )
        table.insert( mapIndexs, mapIndex )
    end
end

---@see 初始化远征地图
function response.getFreeMapIndex()
    if table.size( mapIndexs ) > 0 then
        return table.remove( mapIndexs, 1 )
    else
        local mapIndex = Common.newExpeditionMapIndex()
        MSM.AoiMgr[mapIndex].req.initMapAoi( mapIndex, mapIndex, 720000 )

        return mapIndex
    end
end

---@see 回收远征地图
function accept.addFreeMapIndex( _mapIndex )
    table.insert( mapIndexs, _mapIndex )
end