--[[
* @file : GuildGiftDef.lua
* @type : lualib
* @author : dingyuchao
* @created : Fri May 29 2020 11:53:14 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 定义联盟礼物相关属性结构
* Copyright(C) 2017 IGG, All rights reserved
]]

local GuildGiftDef = {}

---@class defaultGuildGiftAttrClass
local defaultGuildGiftAttr = {
    giftIndex                   =       0,                          -- 礼物索引
    giftType                    =       0,                          -- 1 礼物 2 珍藏
    giftId                      =       0,                          -- 礼物ID
    treasureId                  =       0,                          -- 珍藏ID
    sendTime                    =       0,                          -- 发放时间(根据发放时间判断是否已过期)
    sendType                    =       0,                          -- 1 购买礼包发放
    buyRoleName                 =       "",                         -- 购买礼包的角色名称 空则为设置隐藏
    receives                    =       {},                         -- 礼物领取信息
    cleanRids                   =       {},                         -- 已清除的角色ID
    packageNameId               =       0,                          -- 购买礼包名称
    giftArgs                    =       {},                         -- 礼物参数

    ---------------------------------------以下数据不落地-------------------------
    status                      =       0,                          -- 礼物状态: 1 未领取 2 已领取
}

---@see 获取联盟礼物默认属性
---@return defaultGuildGiftAttrClass
function GuildGiftDef:getDefaultGuildGiftAttr()
    return const( table.copy( defaultGuildGiftAttr ) )
end

return GuildGiftDef