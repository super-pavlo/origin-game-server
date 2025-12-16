--[[
 * @file : RoleEnum.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2019-12-06 17:50:35
 * @Last Modified time: 2019-12-06 17:50:35
 * @department : Arabic Studio
 * @brief : 角色相关枚举
 * Copyright(C) 2019 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 每个小迷雾大小
---@class DesenFogSizeClass
Enum.DesenFogSize           =               1800
---@see 地图尺寸
Enum.MapSize                =               720000
---@see 坐标放大倍数
Enum.MapPosMultiple         =               100
---@see 默认AOI半径
Enum.AoiRadius              =               9000
---@see 远征Y坐标偏移值
Enum.ExpeditionPosY         =               21600
---@see 寻路中断距离
Enum.FindPathDistance       =               3000

---@see 地图层级
---@class MapLevelEnumClass
local MapLevel = {
    ---@see 城堡
    CITY                    =               1,
    ---@see 军队
    ARMY                    =               2,
    ---@see 资源
    RESOURCE                =               3,
    ---@see 联盟
    GUILD                   =               4,
    ---@see 地图预览层
    PREVIEW                 =               5,
    ---@see 远征地图起始层级
    EXPEDITION              =               100,
}
Enum.MapLevel = MapLevel

---@see 地图行军目标类型
---@class MapMarchTargetTypeEnumClass
local MapMarchTargetType = {
    ---@see 空地
    SPACE                   =               0,
    ---@see 攻击
    ATTACK                  =               1,
    ---@see 增援
    REINFORCE               =               2,
    ---@see 集结
    RALLY                   =               3,
    ---@see 采集
    COLLECT                 =               4,
    ---@see 撤退
    RETREAT                 =               5,
    ---@see 侦查
    SCOUTS                  =               6,
    ---@see 驻扎
    STATION                 =               7,
    ---@see 回城.斥候
    SCOUTS_BACK             =               8,
    ---@see 追击
    FOLLOWUP                =               9,
    ---@see 移动
    MOVE                    =               10,
    ---@see 资源援助
    TRANSPORT               =               11,
    ---@see 资源援助回城
    TRANSPORT_BACK          =               12,
    ---@see 集结攻击
    RALLY_ATTACK            =               13,
    ---@see 战损援助
    BATTLELOSE_TRANSPORT    =               14,
}
Enum.MapMarchTargetType = MapMarchTargetType

---@see 迁城类型
---@class MapCityMoveTypeEnumClass
local MapCityMoveType = {
    ---@see 新手迁城
    NOVICE                  =               1,
    ---@see 领土迁城
    TERRITORY               =               2,
    ---@see 定点迁城
    FIX_POS                 =               3,
    ---@see 随机迁城
    RANDOM                  =               4,
}
Enum.MapCityMoveType = MapCityMoveType

---@see s_MapPointFix表Group类型
---@class MapPointFixGroupEnumClass
local MapPointFixGroup = {
    ---@see 村庄.山洞
    VILLAGE_CAVE            =               1,
    ---@see 联盟资源点
    GUILD_RESOURCE_POINT    =               2,
}
Enum.MapPointFixGroup = MapPointFixGroup

---@see 运输状态
---@class TransportStatusEnumClass
local TransportStatus = {
    ---@see 成功
    SUCCESS                 =               1,
    ---@see 失败
    FAIL                    =               2,
    ---@see 返回
    RETURN                  =               3,
    ---@see 出发
    LEAVE                   =               4,
    ---@see 运输战损
    BATTLELOSE              =               5,
}
Enum.TransportStatus = TransportStatus

---@see 地图对象视野类型
---@class MapUnitViewTypeEnumClass
local MapUnitViewType = {
    ---@see 玩家主城
    CITY                    =               1,
    ---@see 玩家部队
    ARMY                    =               2,
    ---@see 关卡
    CHECKPOINT              =               3,
    ---@see 圣所
    SANCTUARY               =               4,
    ---@see 圣坛
    ALTAR                   =               5,
    ---@see 圣祠
    HOLY_SHRINE             =               6,
    ---@see 神庙
    TEMPLE                  =               7,
    ---@see 王国地图
    KINGDOM_MAP             =               8,
    ---@see 联盟要塞
    FORTRESS                =               9,
    ---@see 联盟成员主城
    GUILD_CITY              =               10,
    ---@see 远征对象
    EXPEDITION              =               11,
}
Enum.MapUnitViewType = MapUnitViewType

---@see 地图领地线条方向
---@class MapTerritoryLineDirectionEnumClass
local MapTerritoryLineDirection = {
    ---@see 左侧
    LEFT                    =               1,
    ---@see 右侧
    RIGHT                   =               2,
}
Enum.MapTerritoryLineDirection = MapTerritoryLineDirection

---@see 地图书签类型
---@class MapMarkerTypeEnumClass
local MapMarkerType = {
    ---@see 个人书签
    PERSON                  =               1,
    ---@see 联盟书签
    GUILD                   =               2,
}
Enum.MapMarkerType = MapMarkerType

---@see 地图书签状态
---@class MapMarkerStatusEnumClass
local MapMarkerStatus = {
    ---@see 删除书签
    DELETE                  =               -1,
    ---@see 未读书签
    NO_READ                 =               0,
    ---@see 已读书签
    READ                    =               1,
}
Enum.MapMarkerStatus = MapMarkerStatus

---@see 地图对象刷新类型
---@class MapObjectRefreshTypeEnumClass
local MapObjectRefreshType = {
    ---@see 野外资源田
    RESOURCE                =               1,
    ---@see 野蛮人
    BARBARIAN               =               2,
    ---@see 野蛮人城寨
    BARBARIAN_CITY          =               3,
}
Enum.MapObjectRefreshType = MapObjectRefreshType

---@see 地图对象半径范围分组类型
---@class MapObjectSquareGroupEnumClass
local MapObjectSquareGroup = {
    ---@see 角色部队
    ARMY                    =               0,
    ---@see 野蛮人
    BARBARIAN               =               1,
    ---@see 野蛮人
    RALLY_ARMY              =               2,
    ---@see 守护者
    GUARD                   =               3,
}
Enum.MapObjectSquareGroup = MapObjectSquareGroup