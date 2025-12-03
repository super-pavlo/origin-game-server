--[[
* @file : GuildTerritoryLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Wed Apr 22 2020 17:30:53 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟领土相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local skynet = require "skynet"
local MapObjectLogic = require "MapObjectLogic"

local GuildTerritoryLogic = {}

---@see 根据坐标获取领地编号
function GuildTerritoryLogic:getPosTerritoryId( _pos, _sConfig, _noMulti )
    if not _pos or table.empty( _pos ) then return end

    -- 领地编号划分规则：
    -- 左下角开始为第一个领地，按X轴依次扩展，X轴到头后从左下角上方重新开始继续计算
    -- 领地区块为正方形s_Config中配置大小
    local sConfig = _sConfig or CFG.s_Config:Get()
    local xSum = sConfig.kingdomMapLength / sConfig.territorySizeMin
    local posMultiple = Enum.MapPosMultiple
    if _noMulti then
        posMultiple = 1
    end
    -- x坐标领地位置
    local xNum = math.ceil( _pos.x / sConfig.territorySizeMin / posMultiple )
    if xNum == 0 then
        xNum = 1
    end

    -- y坐标领地位置
    local yNum = math.floor( _pos.y / sConfig.territorySizeMin / posMultiple )
    if yNum ~= 0 and _pos.y % ( sConfig.territorySizeMin * posMultiple ) == 0 then
        yNum = yNum - 1
    end

    -- 计算领地编号
    return math.tointeger( xSum * yNum + xNum )
end

---@see 获取最大领地编号
function GuildTerritoryLogic:getMaxTerritoryId()
    local sConfig = CFG.s_Config:Get()
    return math.tointeger( ( sConfig.kingdomMapLength / sConfig.territorySizeMin ) * ( sConfig.kingdomMapWidth / sConfig.territorySizeMin ) )
end

---@see 根据坐标获取附近的领地信息
function GuildTerritoryLogic:getPosTerritoryIds( _pos, _territorySize )
    local territoryIds = {}
    local sConfig = CFG.s_Config:Get()
    local territoryId = self:getPosTerritoryId( _pos )
    local maxTerritoryId = self:getMaxTerritoryId()
    local xSum = sConfig.kingdomMapLength / sConfig.territorySizeMin

    local territoryNum = ( math.tointeger( _territorySize / sConfig.territorySizeMin ) - 1 ) / 2
    -- 坐标所在的领地编号
    local xTerritoryIds = {}
    table.insert( xTerritoryIds, territoryId )
    -- 添加x轴上的领地编号
    local leftTerritoryId, rightTerritoryId
    for i = 1, territoryNum do
        -- 左侧的领地编号是否存在
        leftTerritoryId = math.tointeger( territoryId - i )
        if math.ceil( leftTerritoryId / xSum ) == math.ceil( territoryId / xSum ) then
            table.insert( xTerritoryIds, leftTerritoryId )
        end
        -- 右侧的领地编号是否存在
        rightTerritoryId = math.tointeger( territoryId + i )
        if math.ceil( rightTerritoryId / xSum ) == math.ceil( territoryId / xSum ) then
            table.insert( xTerritoryIds, rightTerritoryId )
        end
    end
    -- 添加y轴上的领地编号
    for _, id in pairs( xTerritoryIds ) do
        table.insert( territoryIds, id )
        for i = 1, territoryNum do
            -- 上方的领地编号是否存在
            if id + xSum * i < maxTerritoryId then
                table.insert( territoryIds, math.tointeger( id + xSum * i ) )
            end
            -- 下放的领地编号是否存在
            if id - xSum * i > 0 then
                table.insert( territoryIds, math.tointeger( id - xSum * i ) )
            end
        end
    end

    return territoryIds
end

---@see 检查某个坐标所在的领地区块是否为联盟有效领地
function GuildTerritoryLogic:checkGuildTerritory( _rid, _guildId, _pos )
    _guildId = _guildId or RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0

    return MSM.GuildTerritoryMgr[_guildId].req.checkGuildTerritoryPos( _guildId, _pos )
end

---@see 获取指定地块上下左右方向的地块ID
function GuildTerritoryLogic:getAroundTerritoryIds( _territoryId )
    local territoryIds = {}
    local sConfig = CFG.s_Config:Get()
    local maxTerritoryId = self:getMaxTerritoryId()
    local xSum = sConfig.kingdomMapLength / sConfig.territorySizeMin

    -- 上方地块
    if _territoryId + xSum < maxTerritoryId then
        territoryIds[_territoryId + xSum] = true
    end

    -- 下方地块
    if _territoryId - xSum > 0 then
        territoryIds[_territoryId - xSum] = true
    end

    -- 左侧地块
    local leftTerritoryId = math.tointeger( _territoryId - 1 )
    if math.ceil( leftTerritoryId / xSum ) == math.ceil( _territoryId / xSum ) then
        territoryIds[leftTerritoryId] = true
    end

    -- 右侧地块
    local rightTerritoryId = math.tointeger( _territoryId + 1 )
    if math.ceil( rightTerritoryId / xSum ) == math.ceil( _territoryId / xSum ) then
        territoryIds[rightTerritoryId] = true
    end

    return territoryIds
end

---@see 检查地图对象所在联盟领地是否为指定联盟领地或是否与指定联盟领地接壤
function GuildTerritoryLogic:checkObjectGuildTerritory( _objectIndex, _guildId )
    local targetInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )
    if not targetInfo or table.empty( targetInfo ) then return false end

    if MapObjectLogic:checkIsAttackGuildBuildObject( targetInfo.objectType ) then
        -- 检查该联盟建筑与_guildId是否接壤
        local GuildBuildLogic = require "GuildBuildLogic"

        local buildType = GuildBuildLogic:objectTypeToBuildType( targetInfo.objectType )
        -- 联盟建筑所占领地宽度
        local territorySize = CFG.s_AllianceBuildingType:Get( buildType, "territorySize" )
        -- 联盟建筑占用地块
        local territoryIds = self:getPosTerritoryIds( targetInfo.pos, territorySize )
        -- 删除圣地占用地块
        territoryIds = SM.HolyLandMgr.req.deleteHolyLandTerritoryIds( territoryIds )
        -- 删除其他联盟占用地块
        territoryIds = SM.TerritoryMgr.req.deleteOtherGuildTerritory( territoryIds, targetInfo.guildId, true )
        local centerTerritoryId = GuildTerritoryLogic:getPosTerritoryId( targetInfo.pos )

        -- 该建筑占用的地块附近是否为指定联盟地块
        return MSM.GuildTerritoryMgr[_guildId].req.checkGuildValidTerritory( _guildId, territoryIds, centerTerritoryId )
    elseif MapObjectLogic:checkIsHolyLandObject( targetInfo.objectType ) then
        -- 判断该圣地或关卡与_guildId是否接壤
        local holyLandType = CFG.s_StrongHoldData:Get( targetInfo.strongHoldId, "type" )
        local territorySize = CFG.s_StrongHoldType:Get( holyLandType, "territorySize" )
        -- 圣地关卡占用地块
        local territoryIds = self:getPosTerritoryIds( targetInfo.pos, territorySize )
        local centerTerritoryId = GuildTerritoryLogic:getPosTerritoryId( targetInfo.pos )

        -- 该建筑占用的地块附近是否为指定联盟地块
        return MSM.GuildTerritoryMgr[_guildId].req.checkGuildValidTerritory( _guildId, territoryIds, centerTerritoryId )
    end
end


---@see 联盟地块ID转换为联盟寻路地图坐标
function GuildTerritoryLogic:territoryIdToSearchMapPos( _territoryIds )
    local sConfig = CFG.s_Config:Get()
    local xSum = math.tointeger( sConfig.kingdomMapLength / sConfig.territorySizeMin )

    if not Common.isTable( _territoryIds ) then
        _territoryIds = { _territoryIds }
    end

    local searchMapPos = {}
    for _, territoryId in pairs( _territoryIds ) do
        table.insert(
            searchMapPos,
            {
                x = territoryId % xSum,
                y = math.ceil( territoryId / xSum )
            }
        )
    end

    return searchMapPos
end

---@see 地图坐标转换为联盟寻路坐标
function GuildTerritoryLogic:mapPosToSearchMapPos( _pos )
    return self:territoryIdToSearchMapPos( self:getPosTerritoryId( _pos ) )
end

---@see 获取地块所属联盟简称
function GuildTerritoryLogic:getTerritoryGuildAbbName( _territoryId, _pos )
    local HolyLandLogic = require "HolyLandLogic"

    _territoryId = _territoryId or self:getPosTerritoryId( _pos )
    local ret, guildId = HolyLandLogic:checkInHolyLand( nil, _territoryId, true )
    if not ret then
        guildId = SM.TerritoryMgr.req.getTerritoryGuildId( _territoryId )
    end
    if guildId and guildId > 0 then
        local GuildLogic = require "GuildLogic"
        return GuildLogic:getGuild( guildId, Enum.Guild.abbreviationName )
    end
end

---@see 角色登录推送地图联盟领土信息
function GuildTerritoryLogic:pushMapTerritories( _rid )
    local synTerritories = {}
    local guildTerritories = {}

    local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
    for i = 1, multiSnaxNum do
        table.mergeEx( guildTerritories, MSM.GuildTerritoryMgr[i].req.getGuildTerritories() or {} )
    end

    local size = 0
    for guildId, territories in pairs( guildTerritories ) do
        synTerritories[guildId] = {
            guildId = guildId,
            colorId = territories.colorId,
            validTerritoryIds = table.indexs( territories.validTerritoryIds ),
            invalidTerritoryIds = table.indexs( territories.invalidTerritoryIds ),
            preOccupyTerritoryIds = table.indexs( territories.preOccupyTerritoryIds ),
        }
        size = size + 1
        if size >= 2 then
            Common.syncMsg( _rid, "Map_GuildTerritories", { guildTerritories = synTerritories }, true, true )
            size = 0
            synTerritories = {}
        end
    end

    if size > 0 then
        Common.syncMsg( _rid, "Map_GuildTerritories", { guildTerritories = synTerritories }, true, true )
    end
end

---@see 推送联盟领土线条信息
function GuildTerritoryLogic:pushMapTerritoryLines( _rid )
    local synTerritoryLines = {}
    local guildTerritoryLines = {}
    local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
    for i = 1, multiSnaxNum do
        table.mergeEx( guildTerritoryLines, MSM.GuildTerritoryMgr[i].req.getGuildTerritoryLines() or {} )
    end

    local size = 0
    for guildId, territoryLines in pairs( guildTerritoryLines ) do
        synTerritoryLines[guildId] = {
            guildId = guildId,
            colorId = territoryLines.colorId,
            validLines = territoryLines.validLines,
            invalidLines = territoryLines.invalidLines,
        }
        size = size + 1
        if size >= 2 then
            Common.syncMsg( _rid, "Map_GuildTerritoryLines", { guildTerritoryLines = synTerritoryLines }, true, true )
            size = 0
            synTerritoryLines = {}
        end
    end

    if size > 0 then
        Common.syncMsg( _rid, "Map_GuildTerritoryLines", { guildTerritoryLines = synTerritoryLines }, true, true )
    end
end


---@see 通知联盟领土信息
function GuildTerritoryLogic:syncGuildTerritories( _toRids, _guildTerritories, _addGuildTerritories, _delGuildTerritories )
    _toRids = _toRids or SM.OnlineMgr.req.getAllOnlineRid()
    if #_toRids > 0 then
        Common.syncMsg( _toRids, "Map_GuildTerritories",
            {
                guildTerritories = _guildTerritories,
                addGuildTerritories = _addGuildTerritories,
                delGuildTerritories = _delGuildTerritories,
            }
        )
    end
end

---@see 联盟领土buff变化通知联盟所有成员野外部队
function GuildTerritoryLogic:updateArmyTerritoryBuff( _guildId )
    local GuildLogic = require "GuildLogic"
    local ArmyLogic = require "ArmyLogic"

    local armys, armyObjectIndexs, objectIndex
    local members = GuildLogic:getGuild( _guildId, Enum.Guild.members ) or {}
    for memberRid in pairs( members ) do
        armys = ArmyLogic:getArmy( memberRid ) or {}
        armyObjectIndexs = MSM.RoleArmyMgr[memberRid].req.getRoleArmyIndex( memberRid ) or {}
        for armyIndex in pairs( armys ) do
            objectIndex = armyObjectIndexs[armyIndex]
            if objectIndex then
                MSM.SceneArmyMgr[objectIndex].post.updateArmyBuff( objectIndex )
            end
        end
    end
end

---@see 是否地图外围边坐标点
function GuildTerritoryLogic:isMapSidePos( _pos, _kingdomMapWidth, _kingdomMapLength )
    return _pos.x == 0 or _pos.x == _kingdomMapLength or _pos.y == 0 or _pos.y == _kingdomMapWidth
end

---@see 获取领土块坐标信息
function GuildTerritoryLogic:getAllTerritoryVertexPoses( _territoryIds, _width, _sConfig )
    local xPos, yPos
    local territoryPos = {}
    for territoryId in pairs( _territoryIds ) do
        -- 左下点
        xPos = ( territoryId % _width - 1 ) * _sConfig.territorySizeMin
        yPos = math.floor( territoryId / _width ) * _sConfig.territorySizeMin
        if not territoryPos[xPos] then
            territoryPos[xPos] = {}
        end
        if not territoryPos[xPos][yPos] then
            territoryPos[xPos][yPos] = { num = 1, use = false }
        else
            territoryPos[xPos][yPos] = { num = territoryPos[xPos][yPos].num + 1, use = false }
        end
        -- 右下点
        xPos = xPos + _sConfig.territorySizeMin
        if not territoryPos[xPos] then
            territoryPos[xPos] = {}
        end
        if not territoryPos[xPos][yPos] then
            territoryPos[xPos][yPos] = { num = 1, use = false }
        else
            territoryPos[xPos][yPos] = { num = territoryPos[xPos][yPos].num + 1, use = false }
        end

        -- 右上点
        yPos = yPos + _sConfig.territorySizeMin
        if not territoryPos[xPos][yPos] then
            territoryPos[xPos][yPos] = { num = 1, use = false }
        else
            territoryPos[xPos][yPos] = { num = territoryPos[xPos][yPos].num + 1, use = false }
        end

        -- 左上点
        xPos = xPos - _sConfig.territorySizeMin
        if not territoryPos[xPos][yPos] then
            territoryPos[xPos][yPos] = { num = 1, use = false }
        else
            territoryPos[xPos][yPos] = { num = territoryPos[xPos][yPos].num + 1, use = false }
        end
    end

    return territoryPos
end

---@see 获取下一个坐标点
function GuildTerritoryLogic:getTerritoryNextPos( _pos, _searchDirection, _length )
    if _searchDirection == 1 then
        -- 左侧坐标
        return { x = _pos.x - _length, y = _pos.y }
    elseif _searchDirection == 2 then
        -- 上方坐标
        return { x = _pos.x, y = _pos.y + _length }
    elseif _searchDirection == 3 then
        -- 左侧坐标
        return { x = _pos.x + _length, y = _pos.y }
    elseif _searchDirection == 4 then
        -- 下方坐标
        return { x = _pos.x, y = _pos.y - _length }
    end
end

---@see 是否是联盟领土线
function GuildTerritoryLogic:isGuildTerritoryLine( _pos, _nextPos, _direction, _territoryIds, _width, _sConfig )
    local territoryId
    if _direction == 1 then
        territoryId = self:getPosTerritoryId( _pos, _sConfig, true )
        if self:isMapSidePos( _pos, _sConfig.kingdomMapWidth, _sConfig.kingdomMapLength )
            and self:isMapSidePos( _nextPos, _sConfig.kingdomMapWidth, _sConfig.kingdomMapLength ) then
            return _territoryIds[territoryId]
        else
            return ( _territoryIds[territoryId] and not _territoryIds[territoryId + _width] )
                or ( not _territoryIds[territoryId] and _territoryIds[territoryId + _width] )
        end
    elseif _direction == 2 then
        territoryId = self:getPosTerritoryId( _nextPos, _sConfig, true )
        if self:isMapSidePos( _pos, _sConfig.kingdomMapWidth, _sConfig.kingdomMapLength )
            and self:isMapSidePos( _nextPos, _sConfig.kingdomMapWidth, _sConfig.kingdomMapLength ) then
            return _territoryIds[territoryId]
        else
            return ( _territoryIds[territoryId] and not _territoryIds[territoryId + 1] )
                or ( not _territoryIds[territoryId] and _territoryIds[territoryId + 1] )
        end
    elseif _direction == 3 then
        territoryId = self:getPosTerritoryId( _nextPos, _sConfig, true )
        if self:isMapSidePos( _pos, _sConfig.kingdomMapWidth, _sConfig.kingdomMapLength )
            and self:isMapSidePos( _nextPos, _sConfig.kingdomMapWidth, _sConfig.kingdomMapLength ) then
            return _territoryIds[territoryId]
        else
            return ( _territoryIds[territoryId] and not _territoryIds[territoryId + _width] )
                or ( not _territoryIds[territoryId] and _territoryIds[territoryId + _width] )
        end
    elseif _direction == 4 then
        territoryId = self:getPosTerritoryId( _pos, _sConfig, true )
        if self:isMapSidePos( _pos, _sConfig.kingdomMapWidth, _sConfig.kingdomMapLength )
            and self:isMapSidePos( _nextPos, _sConfig.kingdomMapWidth, _sConfig.kingdomMapLength ) then
            return _territoryIds[territoryId]
        else
            return ( _territoryIds[territoryId] and not _territoryIds[territoryId + 1] )
                or ( not _territoryIds[territoryId] and _territoryIds[territoryId + 1] )
        end
    end
end

---@see 计算领土的线条信息
function GuildTerritoryLogic:calculateTerritoryLine( _territoryIds, _territoryPos, _width, _sConfig )
    local line = {}
    local startPos
    -- 找到第一个不在领土内部的坐标点
    for xPos, posInfo in pairs( _territoryPos ) do
        for yPos, useInfo in pairs( posInfo ) do
            if useInfo.num < 4 and not useInfo.use then
                startPos = { x = xPos, y = yPos }
                table.insert( line, startPos )
                posInfo[yPos].use = true
                break
            end
        end
        if startPos then
            break
        end
    end

    if startPos then
        -- local startDirection = 1
        local direction = 1
        local pos = startPos
        local nextPos
        local findDirection = 0
        local lineFirstPos = startPos
        local lineSecondPos
        while true do
            nextPos = self:getTerritoryNextPos( pos, direction, _sConfig.territorySizeMin )
            findDirection = findDirection + 1
            if not _territoryPos[nextPos.x] or not _territoryPos[nextPos.x][nextPos.y]
                or _territoryPos[nextPos.x][nextPos.y].num >= 4
                or ( nextPos.x == startPos.x and nextPos.y == startPos.y ) then
                -- 坐标不属于该联盟领土 或 该坐标属于内部点或者找到起始点
                direction = direction + 1
                if direction > 4 then
                    direction = 1
                end
            else
                if self:isGuildTerritoryLine( pos, nextPos, direction, _territoryIds, _width, _sConfig ) then
                    -- 找到的坐标点与pos构成的线是否属于联盟
                    if not lineSecondPos then
                        lineSecondPos = nextPos
                    elseif ( lineFirstPos.x == lineSecondPos.x and lineFirstPos.x == nextPos.x )
                        or ( lineFirstPos.y == lineSecondPos.y and lineFirstPos.y == nextPos.y ) then
                        -- 3个点在一条线上
                        table.remove( line, #line )
                        lineSecondPos = nextPos
                    else
                        -- 3个点不在一条线上
                        lineFirstPos = lineSecondPos
                        lineSecondPos = nextPos
                    end
                    table.insert( line, nextPos )
                    pos = nextPos
                    direction = direction - 1
                    if direction <= 0 then
                        direction = 4
                    end
                    findDirection = 1
                    _territoryPos[nextPos.x][nextPos.y].use = true
                else
                    direction = direction + 1
                    if direction > 4 then
                        direction = 1
                    end
                end
            end
            if findDirection >= 4 then
                -- 检查最后一个点是否在同一直线上
                if lineFirstPos and lineSecondPos and ( ( lineFirstPos.x == lineSecondPos.x and lineFirstPos.x == startPos.x )
                    or ( lineFirstPos.y == lineSecondPos.y and lineFirstPos.y == startPos.y ) ) then
                    table.remove( line, #line )
                end
                -- 检查第一个点是否属于直线的中间点
                local lineSize = #line
                if ( ( line[1].x == line[2].x and line[1].x == line[lineSize].x )
                    or ( line[1].y == line[2].y and line[1].y == line[lineSize].y ) ) then
                    table.remove( line, 1 )
                end
                break
            end
        end
    end

    return line
end

---@see 获取线条方向
function GuildTerritoryLogic:getLineDirection( _startPos, _endPos, _territoryIds, _sConfig )
    if _startPos.x == _endPos.x then
        if _startPos.x == 0 then
            -- 左侧地图边
            if _endPos.y > _startPos.y then
                return Enum.MapTerritoryLineDirection.RIGHT
            end
            return Enum.MapTerritoryLineDirection.LEFT
        elseif _startPos.x == _sConfig.kingdomMapLength then
            -- 右侧地图边
            if _endPos.y > _startPos.y then
                return Enum.MapTerritoryLineDirection.LEFT
            end
            return Enum.MapTerritoryLineDirection.RIGHT
        else
            -- 不在地图边上
            if _endPos.y > _startPos.y then
                local territoryId = self:getPosTerritoryId( _endPos, _sConfig, true )
                if _territoryIds[territoryId] then
                    return Enum.MapTerritoryLineDirection.LEFT
                end
                return Enum.MapTerritoryLineDirection.RIGHT
            else
                local territoryId = self:getPosTerritoryId( _startPos, _sConfig, true )
                if _territoryIds[territoryId] then
                    return Enum.MapTerritoryLineDirection.RIGHT
                end
                return Enum.MapTerritoryLineDirection.LEFT
            end
        end
    elseif _startPos.y == _endPos.y then
        if _startPos.y == 0 then
            -- 地图下面的边
            if _endPos.x > _startPos.x then
                return Enum.MapTerritoryLineDirection.LEFT
            end
            return Enum.MapTerritoryLineDirection.RIGHT
        elseif _startPos.y == _sConfig.kingdomMapWidth then
            -- 地图上面的边
            if _endPos.x > _startPos.x then
                return Enum.MapTerritoryLineDirection.RIGHT
            end
            return Enum.MapTerritoryLineDirection.LEFT
        else
            -- 不在地图边上
            if _endPos.x > _startPos.x then
                local territoryId = self:getPosTerritoryId( _endPos, _sConfig, true )
                if _territoryIds[territoryId] then
                    return Enum.MapTerritoryLineDirection.RIGHT
                end
                return Enum.MapTerritoryLineDirection.LEFT
            else
                local territoryId = self:getPosTerritoryId( _startPos, _sConfig, true )
                if _territoryIds[territoryId] then
                    return Enum.MapTerritoryLineDirection.LEFT
                end
                return Enum.MapTerritoryLineDirection.RIGHT
            end
        end
    end
end

---@see 计算联盟领地线条
function GuildTerritoryLogic:refreshTerritoryLines( _territoryIds )
    local line
    local lines = {}
    local sConfig = CFG.s_Config:Get()
    local xSum = sConfig.kingdomMapLength / sConfig.territorySizeMin
    local territoryPos = self:getAllTerritoryVertexPoses( _territoryIds, xSum, sConfig )
    while not table.empty( territoryPos ) do
        line = self:calculateTerritoryLine( _territoryIds, territoryPos, xSum, sConfig )
        if not table.empty( line ) then
            table.insert( lines, {
                linePos = line,
                direction = self:getLineDirection( line[1], line[2], _territoryIds, sConfig )
            } )
        else
            break
        end
    end

    return lines
end

---@see 领地划线测试代码
function GuildTerritoryLogic:testTerritoryLine()
    local sConfig = CFG.s_Config:Get()
    local xSum = sConfig.kingdomMapLength / sConfig.territorySizeMin
    -- 计算领土块坐标点
    local territoryIds = {}
    for i = 1, 160000, 400 do
        territoryIds[i] = i
        territoryIds[i+1] = i+1
        territoryIds[i+2] = i+2

        territoryIds[i+4] = i+4
        territoryIds[i+5] = i+5
        territoryIds[i+6] = i+6

        territoryIds[i+8] = i+8
        territoryIds[i+9] = i+9
        territoryIds[i+10] = i+10

        territoryIds[i+12] = i+12
        territoryIds[i+13] = i+13
        territoryIds[i+14] = i+14
        territoryIds[i+15] = i+15
        territoryIds[i+16] = i+16
        territoryIds[i+17] = i+17
    end

    local validTerritoryPos = GuildTerritoryLogic:getAllTerritoryVertexPoses( territoryIds, xSum, sConfig )
    local line
    local lines = {}
    -- print(table.size( territoryIds ))
    -- local timercore = require "timer.core"
    -- print(timercore.getmillisecond())
    while not table.empty( validTerritoryPos ) do
        line = self:calculateTerritoryLine( territoryIds, validTerritoryPos, xSum, sConfig )
        -- print( validTerritoryPos, line )
        if not table.empty( line ) then
            table.insert( lines, line )
        else
            break
        end
    end
    -- print(timercore.getmillisecond())
end

return GuildTerritoryLogic