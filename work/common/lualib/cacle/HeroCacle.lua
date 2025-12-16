--[[
* @file : HeroCacle.lua
* @type : lualib
* @author : dingyuchao
* @created : Mon Dec 30 2019 14:57:59 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 统帅相关属性计算
* Copyright(C) 2017 IGG, All rights reserved
]]

local HeroCacle = {}

---@see 计算统帅战力
function HeroCacle:caclePower( _heroInfo )
    -- 基础战力
    local sHero = CFG.s_Hero:Get( _heroInfo.heroId )
    local power = sHero.score or 0
    -- 等级战力
    local heroLevelId = sHero.rare * 10000 + _heroInfo.level
    power = power + CFG.s_HeroLevel:Get( heroLevelId, "score" )
    -- 技能战力
    for _, skillInfo in pairs( _heroInfo.skills ) do
        power = power + CFG.s_HeroSkillEffect:Get( skillInfo.skillId * 1000 + skillInfo.skillLevel ).score
    end
    -- 天赋战力
    local talentTree = {}
    if _heroInfo.talentTrees and _heroInfo.talentTrees[_heroInfo.talentIndex] then
        talentTree = _heroInfo.talentTrees[_heroInfo.talentIndex].talentTree
    end
    local talentCount = {}
    for _, id in pairs(talentTree) do
        local sHeroTalentGainTree = CFG.s_HeroTalentGainTree:Get( id )
        if sHeroTalentGainTree.score and sHeroTalentGainTree.score > 0 then
            power = power + sHeroTalentGainTree.score
        end
        local gainTree = sHeroTalentGainTree.gainTree
        if not talentCount[gainTree] then talentCount[gainTree] = 0 end
        talentCount[gainTree] = talentCount[gainTree] + 1
    end

    -- 天赋专精战力
    local sHeroTalentMastery = CFG.s_HeroTalentMastery:Get()
    for gainTree, count in pairs(talentCount) do
        for i=count,1, -1 do
            local heroTalentMastery = sHeroTalentMastery[gainTree][i]
            if heroTalentMastery and heroTalentMastery.score and heroTalentMastery.score > 0 then
                power = power + heroTalentMastery.score
            end
        end
    end

    return power
end


return HeroCacle