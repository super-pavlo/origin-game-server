--[[
 * @file : MapLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2019-12-09 11:47:36
 * @Last Modified time: 2019-12-09 11:47:36
 * @department : Arabic Studio
 * @brief : 地图相关逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local math = math
local Random = require "Random"
local MapProvinceLogic = require "MapProvinceLogic"
local skynet = require "skynet"

local MapLogic = {}

---@see 根据坐标计算所在瓦片
function MapLogic:getZoneIndexByPos( _posInfo )
    if not _posInfo or table.empty( _posInfo ) then
        return
    end

    -- 瓦片划分规则：
    -- 左下角开始为第一个瓦片，按X轴依次扩展，X轴到头后从左下角上方重新开始继续计算
    -- 瓦片为正方形s_Config中配置大小
    local sConfig = CFG.s_Config:Get()
    local xZoneSum
    local posMultiple = Enum.MapPosMultiple
    xZoneSum = sConfig.kingdomMapLength / sConfig.kingdomMapTileSize
    -- x坐标瓦片位置
    local xZoneNum = math.ceil( _posInfo.x / sConfig.kingdomMapTileSize / posMultiple )
    if xZoneNum == 0 then
        xZoneNum = 1
    end

    -- y坐标瓦片位置
    local yZoneNum = math.floor( _posInfo.y / sConfig.kingdomMapTileSize / posMultiple )
    if yZoneNum ~= 0 and _posInfo.y % ( sConfig.kingdomMapTileSize * posMultiple ) == 0 then
        yZoneNum = yZoneNum - 1
    end

    -- 计算瓦片索引
    return math.tointeger( xZoneSum * yZoneNum + xZoneNum )
end

---@see 获取最大瓦片索引
function MapLogic:getMaxZoneIndex()
    local sConfig = CFG.s_Config:Get()
    return math.tointeger( ( sConfig.kingdomMapLength / sConfig.kingdomMapTileSize ) * ( sConfig.kingdomMapWidth / sConfig.kingdomMapTileSize ) )
end

---@see 获取目标点索引和附近的瓦片索引
function MapLogic:getNearZoneIndexByPos( _pos )
    local zoneIndexs = {}
    local zoneIndex = self:getZoneIndexByPos( _pos )
    local sConfig = CFG.s_Config:Get()
    local maxZoneIndex = self:getMaxZoneIndex()
    -- X轴上的瓦片数
    local xZoneNum = math.tointeger( sConfig.kingdomMapLength / sConfig.kingdomMapTileSize )

    table.insert( zoneIndexs, zoneIndex )
    -- 下方瓦片是否存在
    if zoneIndex - xZoneNum > 0 then
        table.insert( zoneIndexs, zoneIndex - xZoneNum )
    end
    -- 上方瓦片是否存在
    if zoneIndex + xZoneNum < maxZoneIndex then
        table.insert( zoneIndexs, zoneIndex + xZoneNum )
    end

    local leftZoneIndex = zoneIndex - 1
    local rightZoneIndex = zoneIndex + 1

    -- 左侧瓦片是否存在
    if math.ceil( leftZoneIndex / xZoneNum ) == math.ceil( zoneIndex / xZoneNum ) then
        table.insert( zoneIndexs, leftZoneIndex )
        -- 左侧下方瓦片是否存在
        if leftZoneIndex - xZoneNum > 0 then
            table.insert( zoneIndexs, leftZoneIndex - xZoneNum )
        end
        -- 左侧上方瓦片是否存在
        if leftZoneIndex + xZoneNum < maxZoneIndex then
            table.insert( zoneIndexs, leftZoneIndex + xZoneNum )
        end
    end

    -- 右侧瓦片是否存在
    if math.ceil( rightZoneIndex / xZoneNum ) == math.ceil( zoneIndex / xZoneNum ) then
        table.insert( zoneIndexs, rightZoneIndex )
        -- 左侧下方瓦片是否存在
        if rightZoneIndex - xZoneNum > 0 then
            table.insert( zoneIndexs, rightZoneIndex - xZoneNum )
        end
        -- 左侧上方瓦片是否存在
        if rightZoneIndex + xZoneNum < maxZoneIndex then
            table.insert( zoneIndexs, rightZoneIndex + xZoneNum )
        end
    end

    return zoneIndexs
end

---@see 检查坐标半径区域是否为空闲
---@return boolean true 空闲 false 占用
function MapLogic:checkPosIdle( _pos, _radius, _isMonsterMap, _cityIndex, _isSet, _isMonsterCheck )
    return SM.NavMeshObstracleMgr.req.checkPosIdle( _pos, _radius, _isMonsterMap, _cityIndex, _isSet, _isMonsterCheck )
end

---@see 根据坐标和半径获取范围内所有的瓦片索引
function MapLogic:getZoneIndexsByPosRadius( _pos, _radius )
    local sConfig = CFG.s_Config:Get()
    local kingdomMapLength = sConfig.kingdomMapLength * Enum.MapPosMultiple
    local kingdomMapTileSize = sConfig.kingdomMapTileSize * Enum.MapPosMultiple
    local kingdomMapWidth = sConfig.kingdomMapWidth * Enum.MapPosMultiple

    local xZoneSum = math.tointeger( kingdomMapLength / kingdomMapTileSize )

    local topLeftPos = { x = _pos.x - _radius, y = _pos.y + _radius }
    if topLeftPos.x < 0 then topLeftPos.x = 0 end
    if topLeftPos.y > kingdomMapWidth then topLeftPos.y = kingdomMapWidth end
    -- 左上角坐标所在的瓦片索引
    local topLeftIndex = self:getZoneIndexByPos( topLeftPos )

    local bottomLeftPos = { x = _pos.x - _radius, y = _pos.y - _radius }
    if bottomLeftPos.x < 0 then bottomLeftPos.x = 0 end
    if bottomLeftPos.y < 0 then bottomLeftPos.y = 0 end
    -- 左下角坐标所在的瓦片索引
    local bottomLeftIndex = self:getZoneIndexByPos( bottomLeftPos )

    local bottomRightPos = { x = _pos.x + _radius, y = _pos.y - _radius }
    if bottomRightPos.x > kingdomMapLength then bottomRightPos.x = kingdomMapLength end
    if bottomRightPos.y < 0 then bottomRightPos.y = 0 end
    -- 右下角坐标所在的瓦片索引
    local bottomRightIndex = self:getZoneIndexByPos( bottomRightPos )
    -- 最下方一行的瓦片索引
    local bottomIndexs = {}
    for i = bottomLeftIndex, bottomRightIndex do
        table.insert( bottomIndexs, i )
    end
    -- 所有瓦片索引
    local allIndexs = {}
    for i = 0, math.tointeger( ( topLeftIndex - bottomLeftIndex ) / xZoneSum ) do
        for _, index in pairs( bottomIndexs ) do
            table.insert( allIndexs, index + i * xZoneSum )
        end
    end

    return allIndexs
end

---@see 检查指定位置是否在某个位置的指定范围内
function MapLogic:checkRadius( _pos, _targetPos, _radius )
    local x = _pos.x - _targetPos.x
    local y = _pos.y - _targetPos.y

    return x * x + y * y <= _radius * _radius
end

---@see 获取指定坐标半径内的地块坐标集合
function MapLogic:getAreaSetByPosRadius( _pos, _radius )
    local areaSet = {}
    -- 判断坐标点处于哪个区块
    local MapPosMultiple = Enum.MapPosMultiple
    _pos.x = math.floor(_pos.x / MapPosMultiple)
    _pos.y = math.floor(_pos.y / MapPosMultiple)
    local kingdonMapZoneRadius = CFG.s_Config:Get("kingdonMapZoneRadius")
    -- 判断半径覆盖的区块
    local maxSize = math.floor( Enum.MapSize / MapPosMultiple )
    -- 区域方块坐标
    local leftPos = _pos.x - _radius
    if leftPos < 0 then
        leftPos = 0
    end
    local rightPos = leftPos + _radius * 2 - 1
    if rightPos > maxSize then
        rightPos = maxSize
    end
    local bottomPos = _pos.y - _radius
    if bottomPos < 0 then
        bottomPos = 0
    end
    local topPos = bottomPos + _radius * 2 - 1
    if topPos > maxSize then
        topPos = maxSize
    end
    -- 查找地块
    local posIndex
    for x = leftPos, rightPos do
        for y = bottomPos, topPos do
            posIndex = self:getAreaByPos( { x = x, y = y }, kingdonMapZoneRadius )
            areaSet[posIndex] = true
        end
    end
    return areaSet
end

---@see 根据坐标获取属于哪个区块
function MapLogic:getAreaByPos( _pos, _kingdonMapZoneRadius )
    local MapPosMultiple = Enum.MapPosMultiple
    local x = math.ceil( _pos.x / (_kingdonMapZoneRadius * 2) )
    local y = math.floor( _pos.y / (_kingdonMapZoneRadius * 2) )
    local size = math.floor( Enum.MapSize / MapPosMultiple / ( _kingdonMapZoneRadius * 2 ) )
    return x + y * size, x, y
end

---@see 根据区块获取实际坐标
function MapLogic:getPosByAreaIndex( _areaIndex )
    local MapPosMultiple = Enum.MapPosMultiple
    local kingdonMapZoneRadius = CFG.s_Config:Get("kingdonMapZoneRadius")
    local size = math.floor( Enum.MapSize / MapPosMultiple / ( kingdonMapZoneRadius * 2 ) )
    local x = math.floor( _areaIndex % size * (kingdonMapZoneRadius * 2) - kingdonMapZoneRadius )
    local y = math.floor( _areaIndex / size) * (kingdonMapZoneRadius * 2) + kingdonMapZoneRadius
    return { x = x * MapPosMultiple, y = y * MapPosMultiple }
end

---@see 随机一个可放城市的坐标
function MapLogic:randomCityIdlePos( _rid, _uid, _provinceIndex, _isMoveCity, _isSet, _noCheck )
    local maxProvinceIndex = 6
    if _isMoveCity then
        maxProvinceIndex = 10
    end
    --local provinceIndex = _provinceIndex or ( _rid % maxProvinceIndex + 1 )
    local pos
    local cityRadiusCollide = CFG.s_Config:Get("cityRadiusCollide")
    local initialRandomLocation = CFG.s_Config:Get("initialRandomLocation")
    local initialRandomRadius = CFG.s_Config:Get("initialRandomRadius")
    local initialRandomTimes = CFG.s_Config:Get("initialRandomTimes")
    if _isMoveCity then
        initialRandomRadius = { table.remove( initialRandomRadius ) }
    end
    -- 获取已经填满的省份
    local sharedata = require "skynet.sharedata"
    local FullProvice = table.copy( sharedata.query( Enum.Share.FullProvice ), true )
    for provinceIndex = 1, maxProvinceIndex do
        -- 判断随机区域(此区域未被标记为满)
        if not FullProvice[provinceIndex] and ( _isMoveCity or initialRandomLocation[provinceIndex] == 1 ) then
            local provinceCenterCoordinate = CFG.s_Config:Get( "provinceCentreCoordinate" .. provinceIndex )
            -- 每个中心点随机
            local allCenterCount = math.floor(#provinceCenterCoordinate / 2)
            local startCenter = ( _rid % allCenterCount ) * 2 + 1
            -- 根据rid,选择优先随机的区域
            local centerPoints = { { x = provinceCenterCoordinate[startCenter], y = provinceCenterCoordinate[startCenter + 1] } }
            for c = 1, #provinceCenterCoordinate, 2 do
                if c ~= startCenter then
                    table.insert( centerPoints, { x = provinceCenterCoordinate[c], y = provinceCenterCoordinate[c+1] } )
                end
            end

            for _, centerXY in pairs(centerPoints) do
                local x = centerXY.x
                local y = centerXY.y
                local angle, distance, posx, posy
                -- 每个半径随机
                for i = 1, #initialRandomRadius do
                    local radiusDistance = initialRandomRadius[i-1] or 0
                    for _ = 1, initialRandomTimes do
                        -- 随机一个距离
                        distance = Random.Get( ( initialRandomRadius[i-1] or 0 ), initialRandomRadius[i] )
                        -- 随机一个角度
                        angle = Random.Get( 0, 360 )

                        posx = math.floor( ( distance * math.cos( math.rad(angle) ) + radiusDistance + x ) * 100 )
                        posy = math.floor( ( distance * math.sin( math.rad(angle) ) + radiusDistance + y ) * 100 )
                        pos = { x = posx, y = posy }

                        -- 判断目标点是否属于此省份
                        if MapProvinceLogic:getPosInProvince( pos ) == provinceIndex then
                            -- 判断此点是否可以创建
                            local isIdel, setObstracleRef = MapLogic:checkPosIdle( pos, cityRadiusCollide, nil, nil, _isSet )
                            if isIdel then
                                -- 不能处于圣地内
                                local HolyLandLogic = require "HolyLandLogic"
                                if not HolyLandLogic:checkInHolyLand( pos ) then
                                    return pos, setObstracleRef
                                else
                                    SM.NavMeshObstracleMgr.post.delObstracleByRef( setObstracleRef )
                                end
                            end
                        end
                    end
                end
            end
        end

        -- 标记此省份已满
        if not FullProvice[provinceIndex] then
            FullProvice[provinceIndex] = true
            sharedata.update( Enum.Share.FullProvice, FullProvice )
            sharedata.flush()
        end

        --[[
        provinceIndex = provinceIndex + 1
        if provinceIndex > maxProvinceIndex then
            provinceIndex = 1
        end
        ]]
    end

    if _isMoveCity then
        -- 返回当前点
        local RoleLogic = require "RoleLogic"
        return RoleLogic:getRole( _rid, Enum.Role.pos )
    else
        if _noCheck then
            local provinceCenterCoordinate = CFG.s_Config:Get("provinceCentreCoordinate1")
            return { x = provinceCenterCoordinate[1] * 100, y = provinceCenterCoordinate[2] * 100 }
        else
            LOG_ERROR("createRole, found city idle pos fail, uid(%d)", _uid)
        end
    end
end

---@see 定时清空已满的身份数据
function MapLogic:cleanFullProvince()
    local sharedata = require "skynet.sharedata"
    sharedata.update( Enum.Share.FullProvice, {} )
    sharedata.flush()
end

---@see 建筑添加到地图动态障碍
function MapLogic:addObstracle( _objectIndex, _objectType, _pos, _objectId )
    SM.NavMeshMapMgr.post.addObstracle( _objectIndex, _objectType, _pos, _objectId )
end

---@see 建筑从地图动态障碍移除
function MapLogic:delObstracle( _objectIndex, _findObstracleRef )
    SM.NavMeshMapMgr.post.delObstracle( _objectIndex, _findObstracleRef )
end

---@see 建筑更新地图动态障碍
function MapLogic:updateObstracle( _objectIndex, _pos )
    SM.NavMeshMapMgr.post.updateObstracle( _objectIndex, _pos )
end

---@see 根据对象坐标获取所在服务索引
function MapLogic:getObjectService( _pos, _zoneIndex )
    -- 根据坐标计算出瓦片索引
    local zoneIndex = _zoneIndex or MapLogic:getZoneIndexByPos( _pos )
    local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
    return zoneIndex % multiSnaxNum + 1
end

---@see 根据对象坐标获取所在服务索引
function MapLogic:getGroupZoneIndexs( _type, _group, _multiSnaxNum )
    if not _type then return end
    local groupZones = {}
    _multiSnaxNum = _multiSnaxNum or tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM

    -- 分组个数
    local freshTileGap
    if _type == Enum.MapObjectRefreshType.RESOURCE then
        freshTileGap = CFG.s_Config:Get( "resourceFreshTileGap" )
    elseif _type == Enum.MapObjectRefreshType.BARBARIAN_CITY then
        freshTileGap = CFG.s_Config:Get( "fortressFreshTileGap" )
    elseif _type == Enum.MapObjectRefreshType.BARBARIAN then
        freshTileGap = CFG.s_Config:Get( "barbarianFreshTileGap" )
    end

    if not freshTileGap or freshTileGap<= 1 then
        LOG_ERROR( "s_Config type(%d) resourceFreshTileGap(%s) cfg error", _type, tostring(freshTileGap) )
        freshTileGap = 18
    end

    if ( _group or 0 ) > freshTileGap then
        _group = 1
    end

    local zoneGroup, serviceIndex
    for i = 1, MapLogic:getMaxZoneIndex() do
        zoneGroup = i % freshTileGap
        if zoneGroup == 0 then
            -- 分组为 1,2,..., freshTileGap
            zoneGroup = freshTileGap
        end

        if zoneGroup == _group then
            -- 瓦片所在服务
            serviceIndex = i % _multiSnaxNum + 1
            if not groupZones[serviceIndex] then
                groupZones[serviceIndex] = {}
            end
            groupZones[serviceIndex][i] = true
        end
    end

    return groupZones
end

return MapLogic