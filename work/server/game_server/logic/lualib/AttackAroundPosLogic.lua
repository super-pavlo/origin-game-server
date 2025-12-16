--[[
 * @file : AttackAroundPosLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-09-23 09:41:40
 * @Last Modified time: 2020-09-23 09:41:40
 * @department : Arabic Studio
 * @brief : 对象站位调整逻辑
 * Copyright(C) 2020 IGG, All rights reserved
]]

local ArmyLogic = require "ArmyLogic"
local ArmyWalkLogic = require "ArmyWalkLogic"
local MapLogic = require "MapLogic"
local MapObjectLogic = require "MapObjectLogic"

local AttackAroundPosLogic = {}

---@see 获取关卡一侧的有效位置
function AttackAroundPosLogic:getCheckPointMovePoint( _posTo, _attackPos, _emptyPos )
    local newPos
    if _posTo == "180" then
        if _attackPos >= 2 and _attackPos <= 4 then
            if table.exist( _emptyPos, 2 ) then
                newPos = 2
            elseif table.exist( _emptyPos, 3 ) then
                newPos = 3
            elseif table.exist( _emptyPos, 4 ) then
                newPos = 4
            end
        else
            if table.exist( _emptyPos, 6 ) then
                newPos = 6
            elseif table.exist( _emptyPos, 7 ) then
                newPos = 7
            elseif table.exist( _emptyPos, 8 ) then
                newPos = 8
            end
        end
        table.removevalue( _emptyPos, newPos )
    else
        if _attackPos >= 3 and _attackPos <= 5 then
            if table.exist( _emptyPos, 3 ) then
                newPos = 3
            elseif table.exist( _emptyPos, 4 ) then
                newPos = 4
            elseif table.exist( _emptyPos, 5 ) then
                newPos = 5
            end
        else
            if table.exist( _emptyPos, 1 ) then
                newPos = 1
            elseif table.exist( _emptyPos, 7 ) then
                newPos = 7
            elseif table.exist( _emptyPos, 8 ) then
                newPos = 8
            end
        end
        table.removevalue( _emptyPos, newPos )
    end
    return newPos
end

---@see 调整对象站位
function AttackAroundPosLogic:updateAroundPos( _objectInfo, _attackIndex, _objectIndex, _maxPos, _aroundPos, _radius )
    local fixPos
    if _maxPos == 8 or _maxPos == 6 then
        fixPos = ArmyLogic:cacleAroudPosXY_8( _objectInfo.pos, _aroundPos, _radius )
    elseif _maxPos == 12 then
        fixPos = ArmyLogic:cacleAroudPosXY_12( _objectInfo.pos, _aroundPos, _radius )
    end

    -- 通知对象移动到此位置
    if _objectInfo then
        -- 如果新的站位不是阻挡点(建筑物不判断)
        if not MapObjectLogic:checkIsResourceObject( _objectInfo.objectType )
        and not MapObjectLogic:checkIsGuildBuildObject( _objectInfo.objectType )
        and not MapObjectLogic:checkIsHolyLandObject( _objectInfo.objectType )
        and _objectInfo.objectType ~= Enum.RoleType.EXPEDITION and _objectInfo.objectType ~= Enum.RoleType.CITY and _objectInfo.objectType ~= Enum.RoleType.MONSTER_CITY then
            if not MapLogic:checkPosIdle( fixPos, 0, nil, nil, nil, true ) then
                return false
            end
        end

        local attackInfo = MSM.MapObjectTypeMgr[_attackIndex].req.getObjectInfo( _attackIndex )
        if attackInfo then
            -- 计算当前准备走向哪里,避免跨位置调整(客户端会甩模型表现)
            local nowAroundPos
            if _maxPos == 8 then
                nowAroundPos = ArmyLogic:caclePosAround_8( attackInfo.pos, _objectInfo.pos )
            elseif _maxPos == 12 then
                nowAroundPos = ArmyLogic:caclePosAround_12( attackInfo.pos, _objectInfo.pos )
            end

            local path
            -- 不止差一个位置
            if nowAroundPos and math.abs(nowAroundPos - _aroundPos) > 1 and ( nowAroundPos ~= 1 or _aroundPos ~= _maxPos )
            and ( _aroundPos ~= 1 or nowAroundPos ~= _maxPos ) then
                -- 跨位置了,这边进行寻路处理
                path = { attackInfo.pos }
                local newPos, toPos
                toPos = _maxPos
                if _aroundPos > nowAroundPos and _aroundPos < _maxPos then
                    toPos = _aroundPos
                end

                for i = nowAroundPos, toPos do
                    if _maxPos == 8 or _maxPos == 6 then
                        newPos = ArmyLogic:cacleAroudPosXY_8( _objectInfo.pos, i, _radius )
                    elseif _maxPos == 12 then
                        newPos = ArmyLogic:cacleAroudPosXY_12( _objectInfo.pos, i, _radius )
                    end
                    table.insert( path, newPos )
                end

                if toPos ~= _aroundPos then
                    for i = 1, _aroundPos do
                        if _maxPos == 8 or _maxPos == 6 then
                            newPos = ArmyLogic:cacleAroudPosXY_8( _objectInfo.pos, i, _radius )
                        elseif _maxPos == 12 then
                            newPos = ArmyLogic:cacleAroudPosXY_12( _objectInfo.pos, i, _radius )
                        end
                        table.insert( path, newPos )
                    end
                end
            else
                path = { attackInfo.pos, fixPos }
            end

            -- 更新路径
            if attackInfo.objectType == Enum.RoleType.ARMY then
                MSM.MapMarchMgr[_attackIndex].post.fixArmyPath( _attackIndex, _objectIndex, path )
            elseif attackInfo.objectType == Enum.RoleType.EXPEDITION then
                MSM.MapMarchMgr[_attackIndex].post.fixExpeditionPath( _attackIndex, _objectIndex, path )
            elseif attackInfo.objectType == Enum.RoleType.MONSTER or attackInfo.objectType == Enum.RoleType.GUARD_HOLY_LAND
            or attackInfo.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
                MSM.MapMarchMgr[_attackIndex].post.fixMonsterPath( _attackIndex, attackInfo.objectType, _objectIndex, path )
            end
            return true
        end
    end
end

---@see 判断对象调整位置是否已经被占
function AttackAroundPosLogic:checkAroundPosHadObject( _objectInfo, _objectAroundPosInfo,
                                                        _objectIndex, _toAroundPos, _maxPos, _radius )
    if not _objectAroundPosInfo[_toAroundPos] then
        return _toAroundPos
    end

    -- 调整后的位置上已经有对象,调整站位,不能调整主目标
    if table.size(_objectAroundPosInfo) >= _maxPos then
        -- 站位已经满了,不调整
        return _toAroundPos
    end

    local toAroundPos
    if _maxPos == 8 then
        toAroundPos = ArmyLogic:cacleAroudPosXY_8( _objectInfo.pos, _toAroundPos, _radius )
    elseif _maxPos == 12 then
        toAroundPos = ArmyLogic:cacleAroudPosXY_12( _objectInfo.pos, _toAroundPos, _radius )
    end

    -- 寻找一个最近的空位
    local targetEmptyPos, emptyRealPos
    local allEmptyPos = {}
    for i = 1, _maxPos do
        if not _objectAroundPosInfo[i] then
            table.insert( allEmptyPos, i )
        end
    end

    for _, newPos in pairs(allEmptyPos) do
        local isSetNew
        if not targetEmptyPos then
            isSetNew = true
        else
            local fixPos
            if _maxPos == 8 then
                fixPos = ArmyLogic:cacleAroudPosXY_8( _objectInfo.pos, newPos, _radius )
            elseif _maxPos == 12 then
                fixPos = ArmyLogic:cacleAroudPosXY_12( _objectInfo.pos, newPos, _radius )
            end
            if ArmyWalkLogic:cacleDistance( toAroundPos, emptyRealPos ) > ArmyWalkLogic:cacleDistance( toAroundPos, fixPos ) then
                isSetNew = true
            end
        end

        if isSetNew then
            targetEmptyPos = newPos
            if _maxPos == 8 then
                emptyRealPos = ArmyLogic:cacleAroudPosXY_8( _objectInfo.pos, targetEmptyPos, _radius )
            elseif _maxPos == 12 then
                emptyRealPos = ArmyLogic:cacleAroudPosXY_12( _objectInfo.pos, targetEmptyPos, _radius )
            end
        end
    end

    -- 计算出需要移动的位置(逆时针移动),在调整位置的区间内 _toAroundPos ~ targetEmptyPos
    local allMovePos = {}
    if _toAroundPos > targetEmptyPos then
        -- 跨过了_maxPos
        for i = _toAroundPos, _maxPos do
            if i == _maxPos then
                allMovePos[i] = 1
            else
                allMovePos[i] = i + 1
            end
        end

        for i = 1, targetEmptyPos do
            if i == _maxPos then
                allMovePos[i] = 1
            else
                allMovePos[i] = i + 1
            end
        end
    else
        for i = _toAroundPos, targetEmptyPos do
            if i == _maxPos then
                allMovePos[i] = 1
            else
                allMovePos[i] = i + 1
            end
        end
    end

    local oldAroundPosInfo = table.copy( _objectAroundPosInfo, true )
    -- 处理移动站位
    for oldPos, newPos in pairs(allMovePos) do
        if oldAroundPosInfo[oldPos] then
            for _, attackIndex in pairs(oldAroundPosInfo[oldPos]) do
                -- 目标往空位的方向移动一个位置
                if self:updateAroundPos( _objectInfo, attackIndex, _objectIndex, _maxPos, newPos, _radius ) then
                    -- 更新站位
                    table.removevalue( oldAroundPosInfo[oldPos], attackIndex )
                    table.removevalue( _objectAroundPosInfo[oldPos], attackIndex )
                    if not _objectAroundPosInfo[newPos] then
                        _objectAroundPosInfo[newPos] = {}
                    end
                    table.insert( _objectAroundPosInfo[newPos], attackIndex )
                end
            end
        end
    end
    return _toAroundPos
end

return AttackAroundPosLogic