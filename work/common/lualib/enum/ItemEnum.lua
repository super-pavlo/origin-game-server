--[[
* @file : ItemEnum.lua
* @type : lualib
* @author : dingyuchao
* @created : Tue Dec 24 2019 10:17:21 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 道具相关枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 物品品质类型
---@class ItemQualityTypeEnumClass
local ItemQualityType = {
    ---@see 白
    WHITE                   =                   1,
    ---@see 绿
    GREEN                   =                   2,
    ---@see 蓝
    BLUE                    =                   3,
    ---@see 紫
    PURPLE                  =                   4,
    ---@see 橙
    ORANGE                  =                   5,
}
Enum.ItemQualityType = ItemQualityType

---@see 物品分组类型
---@class ItemTypeEnumClass
local ItemType = {
    ---@see 资源
    RESOURCE                =                   1,
    ---@see 加速
    SPEED                   =                   2,
    ---@see 增益
    GAIN                    =                   3,
    ---@see 装备
    EQUIP                   =                   4,
    ---@see 其他
    OTHER                   =                   5,
    ---@see 头像解锁使用
    HEAD                    =                   6,
}
Enum.ItemType = ItemType

---@see 物品子分组类型
---@class ItemSubTypeEnumClass
local ItemSubType = {
    ---@see VIP点数
    VIP                     =                   10101,
    ---@see 金币
    GOLD                    =                   10102,
    ---@see 石料
    STONE                   =                   10103,
    ---@see 木材
    WOOD                    =                   10104,
    ---@see 粮食
    GRAIN                   =                   10105,
    ---@see 全加速
    ALL_SPEED               =                   20101,
    ---@see 建筑加速
    BUILD_SPEED             =                   20102,
    ---@see 训练加速
    TRAIN_SPEED             =                   20103,
    ---@see 研究加速
    RESEARCH_SPEED          =                   20104,
    ---@see 治疗加速
    HEAL_SPEED              =                   20105,
    ---@see 金币增产
    GOLD_GAIN               =                   30101,
    ---@see 石料增产
    STONE_GAIN              =                   30102,
    ---@see 木材增产
    WOOD_GAIN               =                   30103,
    ---@see 粮食增产
    GRAIN_GAIN              =                   30104,
    ---@see 军队扩编
    ARMY_EXPANSION          =                   30105,
    ---@see 疑兵
    SUSPECT                 =                   30106,
    ---@see 反侦察
    ANTI_SCOUT              =                   30107,
    ---@see 防御强化
    DEFENCE_ENHANCE         =                   30108,
    ---@see 攻击强化
    ATTACK_ENHANCE          =                   30109,
    ---@see 采集强化
    COLLECT_ENHANCE         =                   30110,
    ---@see 和平护盾
    PEACE_SHIELD            =                   30111,
    ---@see 装备材料羽毛
    EQUIP_MATERIAL_FEATHER  =                   40101,
    ---@see 装备材料皮革
    EQUIP_MATERIAL_LEATHER  =                   40102,
    ---@see 装备材料铁石矿
    EQUIP_MATERIAL_IRON     =                   40103,
    ---@see 装备材料兽骨
    EQUIP_MATERIAL_BONE     =                   40104,
    ---@see 装备材料水晶
    EQUIP_MATERIAL_CRYSTAL  =                   40105,
    ---@see 装备材料丝绸
    EQUIP_MATERIAL_SILK     =                   40106,
    ---@see 装备材料乌木
    EQUIP_MATERIAL_WOOD     =                   40107,
    ---@see 武器装备图纸
    EQUIP_BOOK_WEAPON       =                   40301,
    ---@see 头盔装备图纸
    EQUIP_BOOK_HEAD         =                   40302,
    ---@see 铠甲装备图纸
    EQUIP_BOOK_CLOTH        =                   40303,
    ---@see 手套装备图纸
    EQUIP_BOOK_GLOVE        =                   40304,
    ---@see 裤子装备图纸
    EQUIP_BOOK_TROUSERS     =                   40305,
    ---@see 鞋子装备图纸
    EQUIP_BOOK_SHOES        =                   40306,
    ---@see 项链装备图纸
    EQUIP_BOOK_NECKLACE     =                   40307,
    ---@see 经验书
    EXP                     =                   50101,
    ---@see 改名卡
    MODIFY_NAME_CARD        =                   50201,
    ---@see 工人招募道具
    RECRUIT_WORKER          =                   50202,
    ---@see 迁城道具
    MIGRATE_CITY            =                   50203,
    ---@see 钥匙
    KEY                     =                   50204,
    ---@see 文明更换
    CIVILIZATION_CHANGE     =                   50205,
    ---@see 天赋重置
    TALENT_RESET            =                   50206,
    ---@see 建筑升级类
    BUILD_LEVELUP           =                   50207,
    ---@see 行动力
    ACTION_FORCE            =                   50208,
    ---@see 升星材料.绿
    STAR_MATERIAL_GREEN     =                   50301,
    ---@see 升星材料.蓝
    STAR_MATERIAL_BLUE      =                   50302,
    ---@see 升星材料.紫
    STAR_MATERIAL_PURPLE    =                   50303,
    ---@see 升星材料.橙
    STAR_MATERIAL_ORANGE    =                   50304,
    ---@see 技能材料
    SKILL_MATERIAL          =                   50305,
    ---@see 英雄雕像
    HERO_STATUE             =                   50901,
    ---@see 武器
    ARMS                    =                   40201,
    ---@see 头盔
    HELMET                  =                   40202,
    ---@see 胸甲
    BREASTPLATE             =                   40203,
    ---@see 手套
    GLOVES                  =                   40204,
    ---@see 裤子
    PANTS                   =                   40205,
    ---@see 鞋子
    SHOES                   =                   40206,
    ---@see 饰品
    ACCESSORIES             =                   40207,
}
Enum.ItemSubType = ItemSubType

---@see 道具是否可以批量使用
---@class ItemBatchUseEnumClass
local ItemBatchUse = {
    ---@see 否
    NO                      =                   0,
    ---@see 是
    YES                     =                   1,
}
Enum.ItemBatchUse = ItemBatchUse

---@see 奖励类型
---@class ItemPackageTypeEnumClass
local ItemPackageType = {
    ---@see 空类型
    NONE                    =                   0,
    ---@see 货币
    CURRENCY                =                   100,
    ---@see 道具
    ITEM                    =                   200,
    ---@see 士兵
    SOLDIER                 =                   300,
    ---@see 统帅
    HERO                    =                   400,
    ---@see 道具子类型
    SUB_ITEM_TYPE           =                   500,
    ---@see 联盟礼物
    GUILD_GIFT              =                   600,
}
Enum.ItemPackageType = ItemPackageType

---@see 加速道具类型
---@class ItemSpeedTypeEnumClass
local ItemSpeedType = {
    ---@see 通用
    COMMON                  =                   20101,
    ---@see 建筑
    BUILDING                =                   20102,
    ---@see 训练
    TRINA                   =                   20103,
    ---@see 研究
    TECHNOLOGY              =                   20104,
    ---@see 建筑
    TREATMENT               =                   20105,
}
Enum.ItemSpeedType = ItemSpeedType

---@see 村庄奖励类型
---@class VillageRewardTypeEnumClass
local VillageRewardType = {
    ---@see 士兵
    SOLDIER                 =                   1,
    ---@see 道具
    ITEM                    =                   2,
}
Enum.VillageRewardType = VillageRewardType

---@see 道具使用类型
---@class ItemFunctionTypeEnumClass
local ItemFunctionType = {
    ---@see 无法使用
    NOT_USE                 =                   0,
    ---@see 使用后触发打开礼包组功能
    OPEN_ITEMPACKAGE        =                   1,
    ---@see 使用后触发打开可选礼包组功能
    CHOOSE_ITEMPACKAGE      =                   2,
    ---@see 使用后触发活动材料回收功能
    RECYCLE                 =                   3,
    ---@see 城市buff道具使用
    CITY_BUFF               =                   4,
    ---@see VIP道具使用
    VIP                     =                   5,
    ---@see 行动力道具使用
    ACTION_FORCE            =                   6,
    ---@see 王国地图
    KINGDOM_MAP             =                   10,
    ---@see 召唤怪物
    SUMMON_MONSTER          =                   12,
    ---@see 工人小屋
    SECONDE_QUEUE           =                   13,
    ---@see 预备部队
    TRAIN_NUM               =                   14,
    ---@see 联盟积分
    LEAGUE_POINTS           =                   35,
}
Enum.ItemFunctionType = ItemFunctionType

---@see 能否批量使用
---@class BatchUseEnumClass
local BatchUse = {
    ---@see 不能批量使用
    NOT                     =                   0,
    ---@see 可以批量使用
    YES                     =                   1,
}
Enum.BatchUse = BatchUse