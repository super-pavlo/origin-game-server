--[[
* @file : Hero.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Thu Dec 26 2019 16:16:24 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 统帅相关协议代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local ItemLogic = require "ItemLogic"
local HeroLogic = require "HeroLogic"
local Random = require "Random"
local RoleLogic = require "RoleLogic"
local TaskLogic = require "TaskLogic"

---@see 召唤统帅
function response.SummonHero( msg )
    local rid = msg.rid
    local heroId = msg.heroId

    -- 参数检查
    if not heroId then
        LOG_ERROR("rid(%d) SummonHero, no heroId arg", rid)
        return nil, ErrorCode.HERO_ARG_ERROR
    end

    local sHero = CFG.s_Hero:Get( heroId )
    if not sHero or table.empty( sHero ) then
        LOG_ERROR("rid(%d) SummonHero, s_Hero no heroId(%d) cfg", rid, heroId)
        return nil, ErrorCode.CFG_ERROR
    end

    -- 所在王国是否满足该统帅解锁天数条件
    local openDays = Common.getSelfNodeOpenDays()
    if openDays < ( sHero.getLimit or 0 ) then
        LOG_ERROR("rid(%d) SummonHero, openDays(%d) not enough getLimit(%d)", rid, heroId, sHero.getLimit)
        return nil, ErrorCode.HERO_OPEN_DAYS_NOT_ENOUGH
    end

    -- 统帅是否已存在
    local heroInfo = HeroLogic:getHero( rid, heroId )
    if heroInfo and not table.empty( heroInfo ) then
        LOG_ERROR("rid(%d) SummonHero, heroId(%d) exist", rid, heroId)
        return nil, ErrorCode.HERO_ALREADY_EXIST
    end

    -- 所需召唤道具是否足够
    if not ItemLogic:checkItemEnough( rid, sHero.getItem, sHero.getItemNum ) then
        LOG_ERROR("rid(%d) SummonHero, summon item not enough", rid)
        return nil, ErrorCode.HERO_SUMMON_ITEM_NOT_ENOUGH
    end

    -- 扣除道具
    ItemLogic:delItemById( rid, sHero.getItem, sHero.getItemNum, nil, Enum.LogType.SUMMON_HERO_COST_ITEM )
    -- 获得统帅
    HeroLogic:addHero( rid, heroId )
end

---@see 统帅技能升级
function response.HeroSkillLevelUp( msg )
    local rid = msg.rid
    local heroId = msg.heroId
    -- 判断是否拥有该统帅
    local heroInfo = HeroLogic:getHero( rid, heroId )
    if not heroInfo or table.empty( heroInfo ) then
        LOG_ERROR("rid(%d) HeroSkillLevelUp, heroId(%d) not exist", rid, heroId)
        return nil, ErrorCode.HERO_NOT_EXIST
    end
    -- 判断当前统帅技能是否全满
    if HeroLogic:checkHeroSkillFull( rid, heroId ) then
        LOG_ERROR("rid(%d) HeroSkillLevelUp, heroId(%d) skill full", rid, heroId)
        return nil, ErrorCode.HERO_SKILL_MAX
    end
    -- 判断升级道具是否充足
    local count = HeroLogic:getUpLevelSkillItemCount( rid, heroId )
    local sHero = CFG.s_Hero:Get(heroId)
    if not ItemLogic:checkItemEnough( rid, sHero.getItem, count) then
        LOG_ERROR("rid(%d) HeroSkillLevelUp, skill uplevel item not enough", rid)
        return nil, ErrorCode.HERO_LEVEL_ITEM_NOT_ENOUGH
    end
    return HeroLogic:heroSkillLevelUp( rid, heroId )
end

---@see 统帅觉醒
function response.HeroAwake( msg )
    local rid = msg.rid
    local heroId = msg.heroId
    -- 判断是否拥有该统帅
    local heroInfo = HeroLogic:getHero( rid, heroId )
    if not heroInfo or table.empty( heroInfo ) then
        LOG_ERROR("rid(%d) HeroAwake, heroId(%d) not exist", rid, heroId)
        return nil, ErrorCode.HERO_NOT_EXIST
    end
    -- 判断该统帅是否存在第五个技能
    if not CFG.s_HeroSkill:Get( heroId * 100 + 5) then
        LOG_ERROR("rid(%d) HeroAwake, heroId(%d) can not awake", rid, heroId)
        return nil, ErrorCode.HERO_NOT_AWAKE
    end
    -- 判断统帅是否达到觉醒条件
    if not table.size(heroInfo.skills) < 4 or not HeroLogic:checkHeroSkillFull( rid, heroId ) then
        LOG_ERROR("rid(%d) HeroAwake, heroId(%d) skill not max", rid, heroId)
        return nil, ErrorCode.HERO_SKILL_NOT_MAX
    end
    return HeroLogic:heroAwake( rid, heroId )
end

---@see 雕像兑换
function response.ExchangeHeroItem( msg )
    local rid = msg.rid
    local heroId = msg.heroId
    local itemNum = msg.itemNum
    local sHero = CFG.s_Hero:Get( heroId )
    local heroInfo = HeroLogic:getHero( rid, heroId )
    if not heroInfo and table.empty(heroInfo) then
        LOG_ERROR("rid(%d) ExchangeHeroItem, heroId(%d) not exist", rid, heroId)
        return nil, ErrorCode.HERO_NOT_EXIST
    end
    if Enum.Exchange.NO == sHero.exchange then
        LOG_ERROR("rid(%d) ExchangeHeroItem, heroId(%d) not exchange", rid, heroId)
        return nil, ErrorCode.HERO_NOT_EXCHANGE
    end
    -- 判断统帅是否达到觉醒条件
    if table.size(heroInfo.skills) >= 4 and HeroLogic:checkHeroSkillFull( rid, heroId ) then
        LOG_ERROR("rid(%d) ExchangeHeroItem, heroId(%d) skill not max", rid, heroId)
        return nil, ErrorCode.HERO_EXCHANGE_SKILL_MAX
    end
    if not ItemLogic:checkItemEnough( rid, sHero.exchange, itemNum ) then
        LOG_ERROR("rid(%d) ExchangeHeroItem, item not enough", rid)
        return nil, ErrorCode.HERO_EXCHANGE_ITEM_NOT_ENOUGH
    end
    ItemLogic:delItemById( rid, sHero.exchange, itemNum, nil, Enum.LogType.HERO_EXCHANGE_COST_ITEM )
    ItemLogic:addItem( { rid = rid, itemId = sHero.getItem, itemNum = itemNum, eventType = Enum.LogType.HERO_EXCHANGE_GAIN_ITEM } )
    return { result = true }
end

---@see 使用道具增加统帅经验
function response.AddHeroExp( msg )
    local rid = msg.rid
    local heroId = msg.heroId
    local itemId = msg.itemId
    local itemNum = msg.itemNum

    local heroInfo = HeroLogic:getHero( rid, heroId )
    local sHeroStar = CFG.s_HeroStar:Get(heroInfo.star)

    -- 判断是否达到等级上限
    if heroInfo.level == sHeroStar.starLimit then
        LOG_ERROR("rid(%d) useItemAddHeroExp, hero level limit", rid)
        return nil, ErrorCode.HERO_LEVEL_LIMIT
    end

    -- 判断道具是否充足
    if not ItemLogic:checkItemEnough( rid, itemId, itemNum ) then
        LOG_ERROR("rid(%d) ExchangeHeroItem, item not enough", rid)
        return nil, ErrorCode.ITEM_NOT_ENOUGH
    end

    local sItem = CFG.s_Item:Get(itemId)
    local addExp = sItem.desData1 * itemNum
    ItemLogic:delItemById( rid, itemId, itemNum, nil, Enum.LogType.HERO_ADD_EXP_COST_ITEM )
    HeroLogic:addHeroExp( rid, heroId, addExp )
    -- 更新任务进度
    TaskLogic:updateItemUseTaskSchedule( rid, nil, itemNum, sItem )

    return { result = true, itemId = itemId, itemNum = itemNum }
end

---@see 统帅升星
function response.HeroStarUp( msg )
    local rid = msg.rid
    local heroId = msg.heroId
    local items = msg.items

    local heroInfo = HeroLogic:getHero( rid, heroId )
    local sHeroStar = CFG.s_HeroStar:Get(heroInfo.star)
    local sHero = CFG.s_Hero:Get(heroId)
    -- 判断是否达到等级上限
    if not CFG.s_HeroStar:Get(heroInfo.star + 1) then
        LOG_ERROR("rid(%d) heroStarUp, hero star max", rid)
        return nil, ErrorCode.HERO_STAR_MAX
    end

    -- 判断能否升星
    if heroInfo.level < sHeroStar.starLimit then
        LOG_ERROR("rid(%d) heroStarUp, hero level not enough", rid)
        return nil, ErrorCode.HERO_LEVEL_NO_ENOUGH
    end

    -- 判断道具是否为空
    if table.empty(items) then
        LOG_ERROR("rid(%d) heroStarUp, no item", rid)
        return nil, ErrorCode.HERO_NO_ITEM
    end

    -- 判断道具是否都可以用来升星
    for _, itemInfo in pairs( items ) do
        if sHero.rare ~= CFG.s_HeroStarExp:Get( itemInfo.itemId, "rareGroup" ) then
            LOG_ERROR("rid(%d) heroStarUp, items can not use upStar", rid)
            return nil, ErrorCode.HERO_ITEM_ERROR
        end
    end

    local itemNum = 0
    -- 判断道具是否充足
    for _, itemInfo in pairs( items ) do
        itemNum = itemNum + itemInfo.itemNum
        if not ItemLogic:checkItemEnough( rid, itemInfo.itemId, itemInfo.itemNum ) then
            LOG_ERROR("rid(%d) heroStarUp, item not enough", rid)
            return nil, ErrorCode.ITEM_NOT_ENOUGH
        end
    end

    if itemNum > 6 then
        LOG_ERROR("rid(%d) heroStarUp, item too much ", rid)
        return nil, ErrorCode.HERO_ITEM_TO_MUCH
    end

    local lucky = 0
    local addExp = 0
    local sHeroStarExp

    -- 删除道具
    for _, itemInfo in pairs( items ) do
        sHeroStarExp = CFG.s_HeroStarExp:Get( itemInfo.itemId )
        lucky = lucky + sHeroStarExp.lucky * itemInfo.itemNum
        addExp = addExp + sHeroStarExp.exp * itemInfo.itemNum
        ItemLogic:delItemById( rid, itemInfo.itemId, itemInfo.itemNum, nil, Enum.LogType.HERO_ADD_STAR_COST_ITEM )
    end

    if lucky >= Random.Get( 1, 100 ) then
        addExp = addExp * 2
    end

    HeroLogic:addHeroStarExp( rid, heroId, addExp )
    return { result = true }
end

---@see 统帅天赋升级
function response.TalentUp( msg )
    local rid = msg.rid
    local heroId = msg.heroId
    local id = msg.id
    local index = msg.index

    -- 判断英雄是否存在
    local heroInfo = HeroLogic:getHero( rid, heroId )
    if not heroInfo then
        LOG_ERROR("rid(%d) TalentUp, heroId(%d) not exist", rid, heroId)
        return nil, ErrorCode.HERO_NOT_EXIST
    end
    -- 判断天赋点数是否足够
    if not HeroLogic:checkTalentPoint( rid, heroId, index ) then
        LOG_ERROR("rid(%d) TalentUp, heroId(%d) talent point not enough", rid, heroId )
        return nil, ErrorCode.HERO_TALENT_POINT_NOT_ENOUGH
    end
    -- 判断该统帅能否学习本天赋
    if not HeroLogic:checkHeroStudyTalent( heroId, id ) then
        LOG_ERROR("rid(%d) TalentUp, heroId(%d) can't study this talent(%d) ", rid, heroId, id )
        return nil, ErrorCode.HERO_CAN_NOT_STUDY_TALENT
    end
    -- 判断该天赋前置是否学习
    if not HeroLogic:checkHeroStudyTalentPre( rid, heroId, index, id ) then
        LOG_ERROR("rid(%d) TalentUp, heroId(%d) should study pro talent ", rid, heroId, id )
        return nil, ErrorCode.HERO_TALENT_PRE_NOT_STUDY
    end
    -- 判断是否学习了该级天赋
    if not HeroLogic:checkHeroStudyTalentSame( rid, heroId, index, id ) then
        LOG_ERROR("rid(%d) TalentUp, heroId(%d) study same level talent", rid, heroId, id )
        return nil, ErrorCode.HERO_STUDY_SAME_LEVEL_TALENT
    end
    return HeroLogic:upLevelTalent( rid, heroId, id, index )
end

---@see 切换分页
function response.ChangeTalentIndex( msg )
    local rid = msg.rid
    local heroId = msg.heroId
    local index = msg.index
    local useDenar = msg.useDenar

    -- 判断英雄是否存在
    local heroInfo = HeroLogic:getHero( rid, heroId )
    if not heroInfo then
        LOG_ERROR("rid(%d) ChangeTalentIndex, heroId(%d) not exist", rid, heroId)
        return nil, ErrorCode.HERO_NOT_EXIST
    end

    -- 判断分页是否有效
    if index > 3 then
        LOG_ERROR("rid(%d) ChangeTalentIndex, index error", rid, heroId)
        return nil, ErrorCode.HERO_TALENT_INDEX_ERROR
    end

    -- 判断分页是否相同
    if heroInfo.talentIndex == index then
        LOG_ERROR("rid(%d) ChangeTalentIndex, index same ", rid, heroId )
        return nil, ErrorCode.HERO_TALENT_INDEX_SAME
    end
    local itemId = CFG.s_Config:Get("talentResetItemID")
    if not useDenar then
        if not ItemLogic:checkItemEnough( rid, itemId, 1 ) then
            LOG_ERROR("rid(%d) ChangeTalentIndex, item not enough ", rid, heroId )
            return nil, ErrorCode.ITEM_NOT_ENOUGH
        end
        ItemLogic:delItemById( rid, itemId, 1, nil, Enum.LogType.CHANGE_TALENT_COST_ITEM )
    else
        local shortcutPrice = CFG.s_Item:Get(itemId, "shortcutPrice")
        if not RoleLogic:checkDenar( rid, shortcutPrice ) then
            LOG_ERROR("rid(%d) ChangeTalentIndex, denar not enough ", rid, heroId )
            return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
        end
        RoleLogic:addDenar( rid, -shortcutPrice, nil, Enum.LogType.CHANGE_TALENT_COST_CURRENCY )
    end
    heroInfo.talentIndex = index

    HeroLogic:setHero( rid, heroId, heroInfo )
    HeroLogic:syncHero( rid, heroId, heroInfo, true, true)

    -- 计算统帅天赋战力
    RoleLogic:cacleSyncHistoryPower( rid, nil, nil, true )
    -- 更新地图部队
    HeroLogic:updateMapArmyHero( rid, heroId )
    return { result = true }
end

---@see 重置天赋
function response.ResetTalent( msg )
    local rid = msg.rid
    local heroId = msg.heroId
    local index = msg.index
    local useDenar = msg.useDenar

    -- 判断英雄是否存在
    local heroInfo = HeroLogic:getHero( rid, heroId )
    if not heroInfo then
        LOG_ERROR("rid(%d) ChangeTalentIndex, heroId(%d) not exist", rid, heroId)
        return nil, ErrorCode.HERO_NOT_EXIST
    end

    -- 判断分页是否有效
    if index > 3 then
        LOG_ERROR("rid(%d) ChangeTalentIndex, index error", rid, heroId)
        return nil, ErrorCode.HERO_TALENT_INDEX_ERROR
    end

    -- 判断分页是否相同
    if heroInfo.talentIndex == index then
        local itemId = CFG.s_Config:Get("talentResetItemID")
        if not useDenar then
            if not ItemLogic:checkItemEnough( rid, itemId, 1 ) then
                LOG_ERROR("rid(%d) ChangeTalentIndex, item not enough ", rid, heroId )
                return nil, ErrorCode.ITEM_NOT_ENOUGH
            end
            ItemLogic:delItemById( rid, itemId, 1, nil, Enum.LogType.CHANGE_TALENT_COST_ITEM )
        else
            local shortcutPrice = CFG.s_Item:Get(itemId, "shortcutPrice")
            if not RoleLogic:checkDenar( rid, shortcutPrice ) then
                LOG_ERROR("rid(%d) ChangeTalentIndex, denar not enough ", rid, heroId )
                return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
            end
            RoleLogic:addDenar( rid, -shortcutPrice, nil, Enum.LogType.CHANGE_TALENT_COST_CURRENCY )
        end
    end
    heroInfo.talentTrees[index].talentTree = {}

    HeroLogic:setHero( rid, heroId, heroInfo )
    HeroLogic:syncHero( rid, heroId, heroInfo, true, true)
    -- 计算统帅天赋战力
    RoleLogic:cacleSyncHistoryPower( rid, nil, nil, true )
    -- 更新地图部队
    HeroLogic:updateMapArmyHero( rid, heroId )

    return { result = true }
end

---@see 修改天赋页名称
function response.ModifyTalentName( msg )
    local rid = msg.rid
    local name = msg.name
    local index = msg.index
    local heroId = msg.heroId
    -- 名称长度判断
    local strLen = utf8.len( name )
    local heroNameLimit = CFG.s_Config:Get("heroNameLimit")

    if heroNameLimit[1] > strLen or heroNameLimit[2] < strLen then
        LOG_ERROR("rid(%d) ModifyTalentName, name(%s) length error", rid, name)
        return nil, ErrorCode.HERO_TALENT_NAME_LENGTH_ERROR
    end

    -- 判断英雄是否存在
    local heroInfo = HeroLogic:getHero( rid, heroId )
    if not heroInfo then
        LOG_ERROR("rid(%d) ChangeTalentIndex, heroId(%d) not exist", rid, heroId)
        return nil, ErrorCode.HERO_NOT_EXIST
    end

    -- 判断分页是否有效
    if index > 3 then
        LOG_ERROR("rid(%d) ChangeTalentIndex, index error", rid, heroId)
        return nil, ErrorCode.HERO_TALENT_INDEX_ERROR
    end
    if not heroInfo.talentTrees[index] then heroInfo.talentTrees[index] = { index = index, talentTree = {}, name = "" } end
    heroInfo.talentTrees[index].name = name

    HeroLogic:setHero( rid, heroId, heroInfo )
    HeroLogic:syncHero( rid, heroId, heroInfo, true, true)

    return { result = true }
end

---@see 统帅穿戴装备
function response.HeroWearEquip(msg)
    local rid = msg.rid
    local heroId = msg.heroId
    local itemIndex = msg.itemIndex
    local equipIndex = msg.equipIndex

    local itemInfo = ItemLogic:getItem( rid, itemIndex )
    local sItem = CFG.s_Item:Get( itemInfo.itemId )
    local sEquip = CFG.s_Equip:Get( itemInfo.itemId )

    -- 判断是否拥有该装备
    if not itemInfo or table.empty( itemInfo ) then
        LOG_ERROR("rid(%d) ItemChangeResource, itemIndex(%d) no item", rid, itemIndex)
        return nil, ErrorCode.ITEM_NOT_EXIST
    end
    local equips = {}
    equips[1] = { subType = Enum.ItemSubType.HELMET, attr = Enum.Hero.head }
    equips[2] = { subType = Enum.ItemSubType.BREASTPLATE, attr = Enum.Hero.breastPlate }
    equips[3] = { subType = Enum.ItemSubType.ARMS, attr = Enum.Hero.weapon }
    equips[4] = { subType = Enum.ItemSubType.GLOVES, attr = Enum.Hero.gloves }
    equips[5] = { subType = Enum.ItemSubType.PANTS, attr = Enum.Hero.pants }
    equips[6] = { subType = Enum.ItemSubType.ACCESSORIES, attr = Enum.Hero.accessories1 }
    equips[7] = { subType = Enum.ItemSubType.ACCESSORIES, attr = Enum.Hero.accessories2 }
    equips[8] = { subType = Enum.ItemSubType.SHOES, attr = Enum.Hero.shoes }

    -- 判断部位不符合要求
    if sItem.subType ~= equips[equipIndex].subType then
        LOG_ERROR("rid(%d) HeroWearEquip, itemIndex(%d) no item", rid, itemIndex)
        return nil, ErrorCode.HERO_EQUIP_SUBTYPE_ERROR
    end

    -- 统帅是否满足该装备的穿戴等级需求
    local heroInfo = HeroLogic:getHero( rid, heroId )
    if heroInfo.level < sEquip.useLevel then
        LOG_ERROR("rid(%d) HeroWearEquip, hero lv not enough", rid)
        return nil, ErrorCode.HERO_EQUIP_LV_NO_ENOUGH
    end

    -- 判断统帅是否在城内
    if not HeroLogic:checkHeroIdle( rid, heroId ) then
        LOG_ERROR("rid(%d) HeroWearEquip, hero not in city ", rid)
        return nil, ErrorCode.HERO_EQUIP_NOT_IN_CITY
    end

    -- 该装备是否已被统帅穿戴
    if itemInfo.heroId and itemInfo.heroId > 0 then
        local beforeHeroInfo = HeroLogic:getHero( rid, itemInfo.heroId )
        local attr = equips[equipIndex].attr
        if beforeHeroInfo[attr] > 0 then
            beforeHeroInfo[attr] = 0
            HeroLogic:setHero( rid, itemInfo.heroId, beforeHeroInfo )
            HeroLogic:syncHero( rid, itemInfo.heroId, beforeHeroInfo, true, true)
        end
    end
    local attr = equips[equipIndex].attr
    if heroInfo[attr] > 0 then
        local oldEquipInfo = ItemLogic:getItem( rid, heroInfo[attr] )
        oldEquipInfo.heroId = 0
        ItemLogic:setItem( rid, heroInfo[attr], oldEquipInfo )
        ItemLogic:syncItem( rid, heroInfo[attr], oldEquipInfo, true, true )
    end
    heroInfo[attr] = itemIndex
    itemInfo.heroId = heroId

    HeroLogic:setHero( rid, heroId, heroInfo )
    HeroLogic:syncHero( rid, heroId, heroInfo, true, true)
    ItemLogic:setItem( rid, itemIndex, itemInfo )
    ItemLogic:syncItem( rid, itemIndex, itemInfo, true, true )
    return { result = true }
end

---@see 卸下装备
function response.TakeOffEquip( msg )
    local rid = msg.rid
    local heroId = msg.heroId
    local equipIndex = msg.equipIndex

    -- 判断统帅是否在城内
    if not HeroLogic:checkHeroIdle( rid, heroId ) then
        LOG_ERROR("rid(%d) HeroWearEquip, hero lv not enough", rid  )
        return nil, ErrorCode.HERO_EQUIP_NOT_IN_CITY
    end

    local equips = {}
    equips[1] = { subType = Enum.ItemSubType.HELMET, attr = Enum.Hero.head }
    equips[2] = { subType = Enum.ItemSubType.BREASTPLATE, attr = Enum.Hero.breastPlate }
    equips[3] = { subType = Enum.ItemSubType.ARMS, attr = Enum.Hero.weapon }
    equips[4] = { subType = Enum.ItemSubType.GLOVES, attr = Enum.Hero.gloves }
    equips[5] = { subType = Enum.ItemSubType.PANTS, attr = Enum.Hero.pants }
    equips[6] = { subType = Enum.ItemSubType.ACCESSORIES, attr = Enum.Hero.accessories1 }
    equips[7] = { subType = Enum.ItemSubType.ACCESSORIES, attr = Enum.Hero.accessories2 }
    equips[8] = { subType = Enum.ItemSubType.SHOES, attr = Enum.Hero.shoes }

    local attr = equips[equipIndex].attr
    local heroInfo = HeroLogic:getHero( rid, heroId )

    if heroInfo[attr] > 0 then
        local itemInfo = ItemLogic:getItem( rid, heroInfo[attr] )
        itemInfo.heroId = 0
        ItemLogic:setItem( rid, heroInfo[attr], itemInfo )
        ItemLogic:syncItem( rid, itemInfo.itemIndex, itemInfo, true, true )
        heroInfo[attr] = 0
        HeroLogic:setHero( rid, heroId, heroInfo )
        HeroLogic:syncHero( rid, heroId, heroInfo, true, true)
        return { result = true }
    end
    return { result = false}
end