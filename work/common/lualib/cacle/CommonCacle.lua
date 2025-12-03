--[[
 * @file : CommonCacle.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-06-10 15:02:13
 * @Last Modified time: 2020-06-10 15:02:13
 * @department : Arabic Studio
 * @brief : 通用计算
 * Copyright(C) 2019 IGG, All rights reserved
]]

local CommonCacle = {}

---@see 计算部队半径
function CommonCacle:getArmyRadius( _soldiers, _isRallyArmy )
    local squareGroup
    if _isRallyArmy then
        squareGroup = Enum.MapObjectSquareGroup.RALLY_ARMY
    else
        squareGroup = Enum.MapObjectSquareGroup.ARMY
    end

    -- 计算兵种数量
    local soldierTypes = {}
    if not _soldiers then
        _soldiers = {}
    end
    for _, soldierInfo in pairs(_soldiers) do
        if soldierInfo.num > 0 then
            if not soldierTypes[soldierInfo.type] then
                soldierTypes[soldierInfo.type] = 0
            end
            soldierTypes[soldierInfo.type] = soldierTypes[soldierInfo.type] + soldierInfo.num
        end
    end

    local armyRadius = 0
    -- 将领高度
    local sSquareSpacing = CFG.s_SquareSpacing:Get( 10000 )
    armyRadius = armyRadius + sSquareSpacing.spacing
    sSquareSpacing = CFG.s_SquareSpacing:Get( 20000 )
    armyRadius = armyRadius + sSquareSpacing.spacing
    -- 兵种高度
    for soldierType in pairs(soldierTypes) do
        sSquareSpacing = CFG.s_SquareSpacing:Get( 10000 + squareGroup * 100 + soldierType )
        if sSquareSpacing then
            armyRadius = armyRadius + sSquareSpacing.spacing
        end
    end
    for soldierType in pairs(soldierTypes) do
        sSquareSpacing = CFG.s_SquareSpacing:Get( 20000 + squareGroup * 100 + soldierType )
        if sSquareSpacing then
            armyRadius = armyRadius + sSquareSpacing.spacing
        end
    end

    -- 最大兵种高度
    local soldierHeight = 4
    if _isRallyArmy then
        soldierHeight = 7
    end

    -- 兵种额外高度
    if table.size(soldierTypes) < soldierHeight then
        local allSoldierTypeInfo = {}
        for soldierType, soldierNum in pairs(soldierTypes) do
            table.insert( allSoldierTypeInfo, { type = soldierType, num = soldierNum } )
        end
        table.sort( allSoldierTypeInfo, function (a, b)
            return a.num > b.num
        end)
        -- 小于 soldierHeight 种兵种,计算额外高度,补足到 soldierHeight 行
        local sSquareNumberBySum = CFG.s_SquareNumberBySum:Get()
        local leftShowRow = soldierHeight - #allSoldierTypeInfo
        while leftShowRow > 0 and #allSoldierTypeInfo > 0 do
            --获取兵种显示数量
            local squareNumber = 0
            local squareType
            for _, sSquareNumberBySumInfo in pairs(sSquareNumberBySum) do
                if sSquareNumberBySumInfo.type == allSoldierTypeInfo[1].type
                and squareGroup == sSquareNumberBySumInfo.group
                and sSquareNumberBySumInfo.rangeMin <= allSoldierTypeInfo[1].num
                and ( sSquareNumberBySumInfo.rangeMax < 0 or sSquareNumberBySumInfo.rangeMax >= allSoldierTypeInfo[1].num ) then
                    squareNumber = sSquareNumberBySumInfo.num
                    squareType = sSquareNumberBySumInfo.type
                    break
                end
            end

            if squareNumber > 0 then
                -- 判断是否超过一行的显示
                local sSquareMaxNumber = CFG.s_SquareMaxNumber:Get( ( squareGroup + 1 ) * 100 + squareType )
                if squareNumber > sSquareMaxNumber.num then
                    local showRow = math.ceil( squareNumber / sSquareMaxNumber.num ) - 1
                    leftShowRow = leftShowRow - showRow
                    for _ = 1, showRow do
                        -- 兵种高度
                        sSquareSpacing = CFG.s_SquareSpacing:Get( 10000 + squareGroup * 100 + squareType )
                        armyRadius = armyRadius + sSquareSpacing.spacing
                        sSquareSpacing = CFG.s_SquareSpacing:Get( 20000 + squareGroup * 100 + squareType )
                        armyRadius = armyRadius + sSquareSpacing.spacing
                    end
                end
                table.remove(allSoldierTypeInfo, 1)
            else
                break
            end
        end
    end

    return math.floor( armyRadius / 2 * 100 )
end

---@see 计算是否被觉醒技能增强
function CommonCacle:checkIsAwakeEnhance( _skillId, _skills )
    local sSkillInfo
    for _, skillInfo in pairs(_skills) do
        sSkillInfo = CFG.s_HeroSkill:Get( skillInfo.skillId )
        if sSkillInfo and sSkillInfo.type == 4 then
            -- 觉醒技能强化其他技能
            if sSkillInfo.awakenEnhance and sSkillInfo.awakenEnhance == _skillId then
                return sSkillInfo.skillBattleID
            end
        end
    end
end

return CommonCacle